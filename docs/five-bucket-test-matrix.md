> This is the acceptance test matrix for anchor's five-bucket-compliance work; ticket acceptance criteria cite its rows as `file → function/arity → case #`.

# Anchor — Functional Test Matrix (Acceptance Spec)

This matrix specifies the **intended** behavior of anchor's custom Credo checks and their
shared analysis machinery. Rows describe what each unit **should** do — not what the current
(known-buggy) implementation does. Where a known bug makes the code produce the wrong result,
the row states the correct outcome, and that row is the assertion the fix must make pass.
Every check's observable contract is `check_file(source_file, rules, params) -> [%Credo.Issue{}]`
(each issue carries `message`, `trigger`, `line_no`); machinery units are specified as pure
functions (AST/source/map in → data out). All cases are pure and unit-level: no IO, no sleeps,
no real project tree — config-file cases go through the pure parser plus a temp-file/in-memory
adapter boundary.

Conventions used in `Inputs`/`Expected Output` cells: `src:` is the Elixir source parsed into a
`Credo.SourceFile` (line numbers count from the first line of the shown snippet, `defmodule` = 1);
`rule:` is a parsed rule map; `[]` means exactly zero issues. Unless noted, the rule's
`paths`/`pattern` is assumed to select the file (rule-selection itself is specified separately in
`base.ex`).

## Scope & limitations (static-analysis boundary)

Anchor is a **static Credo check**: its jurisdiction is what the AST states or what is derivable
from it. Anything produced at **macro-expansion time** — dynamically-named modules
(`defmodule unquote(x)`), macro-generated functions (`def unquote(name)(…)`), macro-injected
structs (a `use`-injected `defstruct`), `__MODULE__` inside a `quote` block — is **out of scope by
construction**, because a static pass never runs the macro. On every such construct each check and
each machinery unit must **degrade gracefully: skip it, never crash, and never emit a claim about
code it cannot statically see.** This is a design boundary, not a defect. It is load-bearing for
macro-heavy codebases (e.g. gen_saas, whose domain layer is DSL/macro-generated): a file of pure DSL
calls with no literal `defmodule`/`defstruct`/`def` is correctly **silent**, and its
macro-generated modules simply do not appear in the transitive graph or in pattern-rule selection.
The rows and caveats below marked "macro/quote" specify this graceful-degradation behavior per unit.

---

# A. The 12 Checks

## lib/anchor/check/no_dependency.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a direct dependency on a forbidden module | src: `defmodule W do`<br>`  def f, do: MyApp.Repo.all(Q)`<br>`end` (ref on line 2)<br>rule: `forbidden_modules: [MyApp.Repo]` | 1 issue<br>message: `Module has forbidden direct dependency on MyApp.Repo`<br>trigger: `MyApp.Repo`<br>line_no: 2 | Happy Path |
| 2 | flags forbidden dep referenced only in a qualified call | src: module whose body calls `Ecto.Query.from(...)` on line 3<br>rule: `forbidden_modules: [Ecto.Query]` | 1 issue, trigger `Ecto.Query`, line_no 3 | Happy Path |
| 3 | flags each distinct forbidden module once | src references `MyApp.Repo` (line 2) and `System` (line 3)<br>rule: `forbidden_modules: [MyApp.Repo, System]` | 2 issues, triggers `MyApp.Repo` and `System` | Happy Path |
| 4 | clean module with no forbidden dep | src: module that references only `Enum`<br>rule: `forbidden_modules: [MyApp.Repo]` | `[]` | Positive Control |
| 5 | forbidden module named but not referenced | src references `MyApp.Other` only<br>rule: `forbidden_modules: [MyApp.Repo]` | `[]` | Positive Control |
| 6 | empty forbidden list flags nothing | src references `MyApp.Repo`<br>rule: `forbidden_modules: []` | `[]` | Validation |
| 7 | reports the first reference line when forbidden module appears twice | src references `MyApp.Repo` on lines 2 and 4<br>rule: `forbidden_modules: [MyApp.Repo]` | 1 issue, line_no 2 | Control Flow Decisioning |
| 8 | rule not selecting the file yields nothing | src references `MyApp.Repo`<br>rule paths do not match the file's path | `[]` (rule filtered by Base before `check_file`) | Rule Selection |

Caveat: rule selection (rows 8) is performed by `Base.find_matching_rules/2` before `check_file/3`;
see `base.ex` for the exhaustive selection spec.

## lib/anchor/check/no_transitive_dependency.ex

### check_file/3

`params` carries the prebuilt `modules_map` (module → `%{direct_dependencies: [...]}`) under the
check's private key; each row supplies it in-memory.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a forbidden module reached through one intermediary (A→B→Repo) | src: module `A` referencing `B` (line 2)<br>modules_map: `A→[B]`, `B→[MyApp.Repo]`<br>rule: `forbidden_modules: [MyApp.Repo]` | 1 issue<br>message contains `transitive dependency on forbidden module MyApp.Repo` and `dependency chain: A -> B -> MyApp.Repo`<br>trigger: `MyApp.Repo`<br>line_no: 2 (line of the `B` reference) | Happy Path |
| 2 | flags across a two-hop chain (A→B→C→Repo) | modules_map: `A→[B]`, `B→[C]`, `C→[MyApp.Repo]`<br>rule forbids `MyApp.Repo` | 1 issue, chain `A -> B -> C -> MyApp.Repo` | Happy Path |
| 3 | direct dependency also counts as transitive | src `A` references `MyApp.Repo` directly (line 2)<br>modules_map `A→[MyApp.Repo]`<br>rule forbids `MyApp.Repo` | 1 issue, no chain suffix (path length ≤ 2), line_no 2 | Happy Path |
| 4 | chain that never reaches the forbidden module passes | modules_map: `A→[B]`, `B→[C]` (no Repo)<br>rule forbids `MyApp.Repo` | `[]` | Positive Control |
| 5 | self-reference does not produce a spurious hit | modules_map: `A→[A]`<br>rule forbids `MyApp.Repo` | `[]` (self removed from deps) | Control Flow Decisioning |
| 6 | cycle in the graph terminates and still detects | modules_map: `A→[B]`, `B→[A, MyApp.Repo]`<br>rule forbids `MyApp.Repo` | 1 issue for `A` (traversal terminates, no infinite loop) | Error Handling |
| 7 | module absent from map yields nothing | src module not present as a key in modules_map<br>rule forbids `MyApp.Repo` | `[]` | Positive Control |
| 8 | empty forbidden list flags nothing | modules_map `A→[B]`, `B→[MyApp.Repo]`<br>rule: `forbidden_modules: []` | `[]` | Validation |
| 9 | rule not selecting the file yields nothing | rule pattern does not match module name | `[]` | Rule Selection |

Caveat (owner-adjudicated, tied to BUG 1/4): `build_modules_map/1` registers a graph node for
**every** module returned by `extract_module_names/1`, so a single source file defining `A` and `B`
yields two separate nodes (`A→deps(A)`, `B→deps(B)`) in the modules map — the input the rows above
supply in-memory. This is what makes a forbidden module reachable through an intermediary defined in
the same or another file.

## lib/anchor/check/must_use_module.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a module missing a required `use` | src: `defmodule S do`<br>`  def f, do: :ok`<br>`end`<br>rule: `required_modules: [MyApp.Schema]` | 1 issue<br>message: `Module must use MyApp.Schema`<br>trigger: `MyApp.Schema`<br>line_no: 1 | Happy Path |
| 2 | passes when the required module is used | src: `defmodule S do use MyApp.Schema ... end`<br>rule: `required_modules: [MyApp.Schema]` | `[]` | Positive Control |
| 3 | flags each missing required module separately | src uses neither<br>rule: `required_modules: [MyApp.Schema, MyApp.Base]` | 2 issues, triggers `MyApp.Schema` and `MyApp.Base` | Happy Path |
| 4 | one of two required modules present | src uses `MyApp.Schema` only<br>rule: `required_modules: [MyApp.Schema, MyApp.Base]` | 1 issue, trigger `MyApp.Base` | Control Flow Decisioning |
| 5 | `use ModName, opts` still counts as a use | src: `use MyApp.Schema, :controller`<br>rule requires `MyApp.Schema` | `[]` | Happy Path |
| 6 | empty required list flags nothing | src uses nothing<br>rule: `required_modules: []` | `[]` | Validation |
| 7 | rule not selecting the file yields nothing | rule paths do not match | `[]` | Rule Selection |

Note: This check has no test today; contract derived from source + README.

## lib/anchor/check/module_pattern_restrictions.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a non-allowed public function | src: module using `Ecto.Schema` defining `custom_function/0` (line 7)<br>rule: `allowed_functions: ["changeset", "__changeset__", "__schema__", "__struct__"]` | 1 issue<br>message: `Module defines non-allowed function: custom_function`<br>trigger: `custom_function`<br>line_no: 7 | Happy Path |
| 2 | passes when only allowed functions are defined | src defines `changeset/2` only<br>rule allows `changeset` (+ generated) | `[]` | Positive Control |
| 3 | flags a non-allowed private function too | src defines `defp helper/0`<br>rule: `allowed_functions: []` | 1 issue, trigger `helper` | Validation |
| 4 | empty allowed list flags every defined function | src defines `a/0` and `b/1`<br>rule: `allowed_functions: []` | 2 issues, triggers `a`, `b` | Happy Path |
| 5 | glob/prefix allow pattern honored (`with_*`) | src defines `with_status/1` and `new/0`<br>rule: `allowed_functions: ["new", "with_*"]` | `[]` (both allowed) | Happy Path |
| 6 | prefix pattern still flags a non-matching function | src defines `with_status/1` and `delete/1`<br>rule: `allowed_functions: ["with_*"]` | 1 issue, trigger `delete` | Control Flow Decisioning |
| 7 | function reported at its definition line | src defines allowed `changeset` then non-allowed `custom/0` on line 5<br>rule allows `changeset` | 1 issue, line_no 5 | High Signal |
| 8 | multi-clause non-allowed function reported once | src defines `foo/1` twice (two clauses)<br>rule: `allowed_functions: []` | 1 issue for `foo` (name deduped) | Control Flow Decisioning |
| 9 | rule not selecting the file (pattern/uses_module) yields nothing | module name / `use` does not match the rule | `[]` | Rule Selection |

Caveat (intended behavior / ambiguity flagged below): `allowed_functions` entries containing `*`
are treated as name globs (`with_*` → prefix match). The current implementation compares by exact
string membership only; glob support in rows 5–6 is the intended contract and is a fix target.

## lib/anchor/check/single_control_flow.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a clause with two control-flow structures | src: `def f(x) do`<br>`  if x, do: (case x do _ -> 1 end)`<br>`end` (def on line 2) | 1 issue<br>message: ``Function clause `f` contains 2 control-flow structures (maximum allowed: 1)`` + guidance text<br>trigger: `f`<br>line_no: 2 | Happy Path |
| 2 | single `case` clause passes | src: `def f(x), do: case validate(x) do ... end` | `[]` | Positive Control |
| 3 | a single pipe chain counts as one (passes) | src: `def f(x), do: x \|> a() \|> b() \|> c()` | `[]` (one chain, not three) | Control Flow Decisioning |
| 4 | pipe chain plus a `case` flags (count 2) | src: `def f(x) do`<br>`  y = x \|> a() \|> b()`<br>`  case y do _ -> y end`<br>`end` | 1 issue, count 2 | Happy Path |
| 5 | two separate pipe chains flag (count 2) | src: one clause with two distinct `\|>` chains | 1 issue, count 2 | Validation |
| 6 | `with` + `if` flags | src: clause containing a `with` and an `if` | 1 issue, count 2 | Happy Path |
| 7 | `cond`, `for`, `receive`, `unless` each count as a structure | src: clause with `for` and `unless` | 1 issue, count 2 | Validation |
| 8 | clause with guard is analyzed | src: `def f(x) when is_integer(x) do`<br>`  if x, do: (case x do _->1 end)`<br>`end` | 1 issue, trigger `f` | Happy Path |
| 9 | function with zero control-flow structures passes | src: `def f(x), do: x + 1` | `[]` | Positive Control |
| 10 | each violating clause reported at its own def line | src: two functions, only the second (line 5) has 2 structures | 1 issue, line_no 5 | High Signal |

## lib/anchor/check/no_tuple_match_in_head.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags forward `{:ok, x}` head | src: `def process({:ok, data}), do: data` (line 2) | 1 issue<br>message contains `pattern matches on :ok/:error tuple` and `public function head`<br>trigger: `process`<br>line_no: 2 | Happy Path |
| 2 | flags `{:error, reason}` head | src: `def handle_error({:error, reason}), do: reason` | 1 issue, trigger `handle_error` | Happy Path |
| 3 | flags 3-element `{:error, type, details}` head | src: `def h({:error, type, details}), do: 1` | 1 issue | Validation |
| 4 | flags forward assignment `{:ok, _} = result` head | src: `def process({:ok, _} = result), do: result` | 1 issue | Validation |
| 5 | **flags reversed assignment `result = {:ok, x}` head** | src: `def process(result = {:ok, data}), do: data` | 1 issue, trigger `process` (intended-correct: reversed head must also be flagged) | Validation |
| 6 | flags a private-function head, message says private | src: `defp handle({:ok, d}), do: d` | 1 issue, message contains `private function head` | Happy Path |
| 7 | flags head with guard | src: `def process({:ok, d}) when is_binary(d), do: d` | 1 issue | Happy Path |
| 8 | flags each violating clause of a multi-clause function | src: `multi({:ok, d})`, `multi({:error, :nf})`, `multi({:error, r})`, `multi(other)` | 3 issues, all trigger `multi` | Happy Path |
| 9 | allows a non-ok/error tuple head | src: `def process({:data, value}), do: value` | `[]` | Positive Control |
| 10 | allows ok tuple nested in a list head | src: `def f([{:ok, d} \| rest]), do: d` | `[]` | Positive Control |
| 11 | allows ok/error tuple nested in a map head | src: `def f(%{result: {:error, r}}), do: r` | `[]` | Positive Control |
| 12 | plain-argument head passes | src: `def process(data), do: transform(data)` | `[]` | Positive Control |
| 13 | body-level ok/error tuple (in a `case`) is not a head match | src: `def f(r), do: case r do {:ok, v} -> v end` | `[]` | Control Flow Decisioning |
| 14 | mixed args — direct tuple flagged despite a sibling nested tuple | src: `def f({:ok, a}, %{r: {:error, e}}), do: {a, e}` | 1 issue (the top-level `{:ok, a}` arg is flagged; the nested `{:error, e}` in the map arg is allowed and does not suppress it) | Control Flow Decisioning |
| 15 | reversed assignment with a sibling plain arg | src: `def f(x, result = {:error, r}), do: {x, r}` | 1 issue, trigger `f` (match-assignment operand is a top-level tuple) | Validation |

Resolution (owner-adjudicated): the check is **AST-based**, not regex. A head argument is flagged
when it is a top-level `{:ok, …}`/`{:error, …}` tuple, OR a match-assignment (`=`) whose operand is
such a tuple (so both `def f({:ok, a})` and reversed `def f(result = {:ok, a})` are flagged). A
tuple nested inside a list or map sub-pattern is allowed. Judgment is **per argument**: a direct
top-level tuple in one argument is flagged even when a sibling argument carries a nested, allowed
tuple (rows 14–15). Guards and multi-clause heads are covered (rows 7–8).

## lib/anchor/check/case_on_bare_arg.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags `case` directly on a bare argument | src: `def process(status) do`<br>`  case status do :ok -> 1; :error -> 2 end`<br>`end` (case on line 3) | 1 issue<br>message: ``Case statement operates on bare argument `status` in function `process`.`` + guidance<br>trigger: `case`<br>line_no: 3 | Happy Path |
| 2 | passes when `case` is on a transformed value | src: `def process(data), do: case validate(data) do ... end` | `[]` | Positive Control |
| 3 | flags bare arg in a guarded function | src: `def process(status) when is_atom(status) do case status do ... end end` | 1 issue, trigger `case` | Happy Path |
| 4 | **flags `case` on a defaulted (`\\`) bare arg** | src: `def process(status \\ :ok) do case status do ... end end` | 1 issue (intended-correct: defaulted arg is still a bare arg) | Validation |
| 5 | passes when `case` scrutinee is a different variable | src: `def process(a) do b = f(a); case b do ... end end` | `[]` | Control Flow Decisioning |
| 6 | flags in a private function | src: `defp process(x), do: case x do ... end` | 1 issue, message names function `process` | Happy Path |
| 7 | multiple bare-arg cases in one function each flag | src: one function with two `case arg do` on args `a` (line 3) and `b` (line 4) | 2 issues, line_nos 3 and 4 | High Signal |
| 8 | no `case` at all passes | src: `def process(x), do: x + 1` | `[]` | Positive Control |

## lib/anchor/check/no_comparison_in_if.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags `if` with `>=` comparison | src: `if user.age >= 18, do: :adult` (line 2) | 1 issue<br>message contains `Avoid direct comparisons in ` + `if` + ` statements`<br>trigger: `if`<br>line_no: 2 | Happy Path |
| 2 | flags each comparison operator `== != === !== < > <= >=` | src: `if a == b, do: 1` (and one row per operator) | 1 issue each | Validation |
| 3 | flags compound `and` containing comparisons | src: `if user.status == :active and user.verified?, do: 1` | 1 issue | Happy Path |
| 4 | flags compound `or` containing a comparison | src: `if a or b > 3, do: 1` | 1 issue | Happy Path |
| 5 | flags `not (a == b)` | src: `if not (a == b), do: 1` | 1 issue | Validation |
| 6 | flags comparison nested inside a call | src: `if valid?(a == b), do: 1` | 1 issue (prewalk descends into the call args) | Control Flow Decisioning |
| 7 | **flags `unless` with a comparison** | src: `unless a >= b, do: 1` | 1 issue, trigger `unless` (intended-correct: `unless` covered like `if`) | Validation |
| 8 | passes `if` calling a predicate function | src: `if adult?(user), do: :ok` | `[]` | Positive Control |
| 9 | passes `if` on a plain boolean var | src: `if verified?, do: :ok` | `[]` | Positive Control |
| 10 | passes `and`/`or` of predicates without comparisons | src: `if active?(u) and verified?(u), do: 1` | `[]` | Positive Control |
| 11 | passes `unless` calling a predicate (no comparison) | src: `unless adult?(user), do: :block` | `[]` | Positive Control |

Resolution (owner-adjudicated): `unless` is in scope alongside `if`. An `unless` whose condition
contains a comparison (directly, in `and`/`or`/`not`, or nested in a call) is flagged with trigger
`"unless"` (row 7); a comparison-free `unless` is clean (row 11). The current code matches only the
`:if` AST node and hardcodes trigger `if`; extending to `:unless` with its own trigger is the fix.

## lib/anchor/check/no_discarding_arrow_in_with.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags `_ <- expr` discarding clause | src: `with _ <- f() do :ok end` (clause on line 2) | 1 issue<br>message contains `Unnecessary arrow (<-) in with clause` and `` `_` only discards``<br>trigger: `_`<br>line_no: 2 | Happy Path |
| 2 | flags `_result <- expr` (underscore-prefixed var) | src: `with _result <- f() do :ok end` | 1 issue, trigger `_result` | Happy Path |
| 3 | flags a discarding clause with a guard | src: `with _x when is_nil(_x) <- f() do :ok end` | 1 issue, trigger `_x` | Validation |
| 4 | passes meaningful pattern `{:ok, value} <-` | src: `with {:ok, value} <- f() do value end` | `[]` | Positive Control |
| 5 | passes `{:ok, _} <-` (structural match, not bare discard) | src: `with {:ok, _} <- f() do :ok end` | `[]` | Positive Control |
| 6 | passes a normal bound var `value <- expr` | src: `with value <- f() do value end` | `[]` | Positive Control |
| 7 | flags only the discarding clause in a multi-clause `with` | src: `with {:ok, v} <- a(),`<br>`     _ <- b(v) do v end` (discard on line 3) | 1 issue, line_no 3 | High Signal |
| 8 | `with` with no arrow clauses (all bare exprs) passes | src: `with true, do: :ok` | `[]` | Positive Control |

## lib/anchor/check/alphabetized_functions.ex

### check_file/3

Mode is taken from the rule (`:all` / `:public_only` / `:separate`, default `:separate`).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | `:all` flags an out-of-order function | src (mode `:all`): `def banana/0` (line 2), `def apple/0` (line 3) | 1 issue for `banana/0`<br>message: ``function `banana/0` is not in alphabetical order. It should appear after apple/0.``<br>trigger: `banana/0`<br>line_no: 2 | Happy Path |
| 2 | `:all` passes correctly ordered functions | src: `apple/0`, `banana/0` in order | `[]` | Positive Control |
| 3 | arity is the tie-break (`foo/0` before `foo/1`) | src: `foo/1` then `foo/0` (mode `:all`) | 1 issue flagging the mis-ordered `foo` entry | Control Flow Decisioning |
| 4 | ordering is case-insensitive | src: `Apple/0`, `banana/0`, `Cherry/0` (mode `:all`) | `[]` (compared via downcased name) | Validation |
| 5 | `:public_only` ignores private ordering | src: `def a/0`, `def b/0`, `defp z/0`, `defp m/0` | `[]` (only public group checked, and it is ordered) | Control Flow Decisioning |
| 6 | `:public_only` flags out-of-order public fn despite private noise | src: `def b/0`, `def a/0`, `defp z/0` | 1 issue for `b/0`, message prefix `public ` | Happy Path |
| 7 | `:separate` flags out-of-order within the public group | src: `def b/0`, `def a/0`, then private group | 1 issue, message prefix `public ` | Happy Path |
| 8 | `:separate` flags out-of-order within the private group | src: ordered public group, then `defp z/0`, `defp m/0` | 1 issue for `z/0`, message prefix `private ` | Happy Path |
| 9 | `:separate` flags a private function appearing before public functions | src: `defp helper/0` (line 2), `def a/0` (line 4) | 1 structural issue<br>message: ``private function `helper/0` appears before public functions. In :separate mode, all public functions must come before private functions.`` | Validation |
| 10 | `:separate` (default) passes ordered public-then-private | src: `def a/0`, `def b/0`, `defp m/0`, `defp z/0`; rule has no explicit mode | `[]` | Positive Control |
| 11 | `defmacro`/`defmacrop` are ordered with their visibility group | src (mode `:all`): `defmacro z/1`, `def a/0` | 1 issue for `z/1` | Validation |
| 12 | **`defguard`/`defguardp` are counted as functions** | src (mode `:all`): `defguard is_even(n) when ...` placed out of order | 1 issue flagging the guard (intended-correct: guards participate in ordering) | Validation |
| 13 | **a multi-clause function is counted once (by its first clause)** | src: `def a/1` (2 clauses, lines 2–3), `def b/0` (line 4), mode `:all` | `[]` (the two `a/1` clauses do not count as an internal ordering violation) | Control Flow Decisioning |
| 14 | multi-clause function still flagged once when genuinely mis-ordered | src: `def b/1` (2 clauses), `def a/0`, mode `:all` | exactly 1 issue for `b/1` (not one per clause) | High Signal |

Caveat: intended contract per README + task — `defguard`/`defguardp` participate (row 12) and a
function's multiple clauses collapse to a single ordered unit anchored at the first clause
(rows 13–14). Both are fix targets; the current code omits `defguard*` and treats each clause as a
separate entry. Mode is read from the parsed rule as an atom key, coerced from a bare YAML token
(see `config.ex` → `parse_rule/1` resolution).

## lib/anchor/check/max_file_length.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a file over the default 400 code lines when `max_lines` unset | src: module with 401 code lines<br>rule: no `max_lines` | 1 issue<br>message: `File contains 401 lines of code (maximum allowed: 400). ...`<br>trigger: filename<br>line_no: 1 | Happy Path |
| 2 | passes a file at exactly the limit | src: 400 code lines<br>rule: no `max_lines` | `[]` (strictly greater than triggers) | Control Flow Decisioning |
| 3 | **honors a configured `max_lines: 10`** | src: 12 code lines<br>rule: `max_lines: 10` | 1 issue, message `...(maximum allowed: 10)...` (intended-correct: config value used, not the 400 default) | Validation |
| 4 | passes under a configured `max_lines: 10` | src: 8 code lines<br>rule: `max_lines: 10` | `[]` | Positive Control |
| 5 | blank/whitespace-only lines are not counted | src: 5 code lines interleaved with 20 blank lines<br>rule: `max_lines: 10` | `[]` | Validation |
| 6 | comment lines (`# ...`) are not counted | src: 5 code lines + 20 full-line comments<br>rule: `max_lines: 10` | `[]` | Validation |
| 7 | `@moduledoc`/`@doc` heredoc bodies are not counted | src: 5 code lines + a 30-line `@moduledoc """..."""`<br>rule: `max_lines: 10` | `[]` | Validation |
| 8 | `@doc false` line is not counted as code | src: functions with `@doc false` bringing raw lines high but code lines ≤ 10<br>rule: `max_lines: 10` | `[]` | Validation |
| 9 | line count in the message reflects code lines only | src: 12 code lines + 50 blank/comment lines<br>rule: `max_lines: 10` | 1 issue, message states `12 lines of code` | High Signal |

Caveat: `max_lines` comes from config as an atom-keyed integer (rows 3–4, 9). The current code
cannot see it because `Config.parse_rule/1` never surfaces `max_lines`; that is the BUG-2 fix
target (resolved contract in `config.ex` → `parse_rule/1`).

## lib/anchor/check/struct_getter_convention.ex

### check_file/3

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | flags a `%__MODULE__{}` getter whose name ≠ field | src: `defmodule U do defstruct [:name]`<br>`  def get_name(%__MODULE__{name: name}), do: name end` (def on line 3) | 1 issue<br>message: ``Getter function `get_name` should be named `name` to match the field it extracts``<br>trigger: `get_name`<br>line_no: 3 | Happy Path |
| 2 | passes a correctly named `%__MODULE__{}` getter | src: `def name(%__MODULE__{name: name}), do: name` | `[]` | Positive Control |
| 3 | a function that processes the value is not a getter | src: `def email(%__MODULE__{email: email}), do: String.downcase(email)` | `[]` (not detected as a getter → not flagged for naming) | Control Flow Decisioning |
| 4 | non-getter multi-arg function ignored | src: `def build(a, b), do: {a, b}` | `[]` | Positive Control |
| 5 | module with no `defstruct` produces no getter checks | src: module with getter-shaped fns but no `defstruct` | `[]` | Control Flow Decisioning |
| 6 | **enclosing struct, fully-qualified spelling — misnamed getter flagged** | src: `defmodule MyApp.User do defstruct [:name]`<br>`  def get_name(%MyApp.User{name: name}), do: name end` | 1 issue<br>message: ``Getter function `get_name` should be named `name` ...``<br>trigger: `get_name` (explicit `%MyApp.User{}` inside `MyApp.User` treated as `%__MODULE__{}`) | Validation |
| 7 | enclosing struct, fully-qualified spelling — correct getter clean | src: inside `MyApp.User`: `def name(%MyApp.User{name: name}), do: name` | `[]` | Positive Control |
| 8 | **enclosing struct, aliased spelling (`alias MyApp.User`) — misnamed flagged** | src: `defmodule MyApp.User do defstruct [:name]`<br>`  alias MyApp.User`<br>`  def get_name(%User{name: name}), do: name end` | 1 issue, trigger `get_name` (`%User{}` resolves via `alias` back to the enclosing `MyApp.User`) | Validation |
| 9 | enclosing struct, aliased spelling — correct getter clean | src: inside `MyApp.User` with `alias MyApp.User`: `def name(%User{name: name}), do: name` | `[]` | Positive Control |
| 10 | **enclosing struct, `:as` alias (`alias MyApp.User, as: X`) — misnamed flagged** | src: inside `MyApp.User` with `alias MyApp.User, as: X`: `def get_name(%X{name: name}), do: name` | 1 issue, trigger `get_name` (`%X{}` resolves to `MyApp.User`) | Validation |
| 11 | enclosing struct, `:as` alias — correct getter clean | src: inside `MyApp.User` with `alias MyApp.User, as: X`: `def name(%X{name: name}), do: name` | `[]` | Positive Control |
| 12 | **foreign-struct getter (fully-qualified) → location violation** | src: `defmodule A do`<br>`  def name(%Other{name: name}), do: name end` (def on line 2) | 1 issue<br>message to the effect of ``Getter for `Other.name` should be defined in `Other` (not in `A`)``<br>trigger: `name`<br>line_no: 2 | Validation |
| 13 | **foreign-struct getter (aliased) resolves to the real foreign module** | src: `defmodule A do`<br>`  alias Other.Thing, as: O`<br>`  def name(%O{name: name}), do: name end` | 1 issue, message names `Other.Thing` (not `O`) as the module the getter should live in | Validation |
| 14 | foreign-struct getter living in its own module is clean | src: `defmodule Other do defstruct [:name]`<br>`  def name(%Other{name: name}), do: name end` | `[]` (getter is defined in the struct's module) | Positive Control |
| 15 | **bare literal struct name, no visible alias → foreign (location violation)** | src: `defmodule A do`<br>`  def name(%Unknown{name: name}), do: name end` (no `alias` in scope, not `__MODULE__`, not enclosing) | 1 issue as a location violation for `Elixir.Unknown` (resolved: a bare literal name is AST-derivable to top-level `Elixir.<Name>`, hence in scope and foreign) | Validation |
| 16 | allows a getter returning `%Ecto.Association.NotLoaded{}` | src: getter that pattern-matches the field but whose body may be the assoc not-loaded struct | `[]` (documented allowance honored) | Positive Control |
| 17 | correct getter for a field with matching name across several fields | src: inside `MyApp.User`, `defstruct [:name, :email]` with `name/1` and `email/1` both correct | `[]` | Positive Control |
| 18 | wrong-named getter among correct ones flags only the wrong one | src: correct `name/1` + wrong `get_email/1` (line 5) | 1 issue, trigger `get_email`, line_no 5 | High Signal |
| 19 | macro/quote — non-literal function name (`def unquote(field)(…)`) skipped | src: inside `MyApp.User` with `defstruct [:name]`: `def unquote(field)(%__MODULE__{name: name}), do: name` | `[]` (function name is not literal → not evaluated; no crash) | Macro / Static Boundary |
| 20 | macro/quote — non-literal struct pattern/field skipped | src: getter whose head pattern or extracted field is produced by `unquote(...)` | `[]` (struct/field not statically literal → skipped; no crash) | Macro / Static Boundary |
| 21 | macro/quote — macro-injected struct (`use SomeSchema`, no literal `defstruct`) → silent | src: `defmodule MyApp.User do use SomeSchema`<br>`  def name(%__MODULE__{name: name}), do: name end` | `[]` (no literal `defstruct` → no struct fields → no getters to check) | Macro / Static Boundary |

Resolution (owner-adjudicated, 5a/5b): a getter head references the **enclosing module's** struct —
and so is subject to the naming rule identically to `%__MODULE__{}` — in ALL of these spellings:
`%__MODULE__{}`, fully-qualified `%MyApp.User{}` matching the enclosing module, aliased `%User{}`
under `alias MyApp.User`, and `%X{}` under `alias MyApp.User, as: X` (rows 6–11). A getter whose
struct resolves to a **different** module is a **location violation** — "a getter for `Other.name`
should be defined in `Other`" — with the same alias resolution recovering the real foreign module
(`%O{}` under `alias Other.Thing, as: O` → `Other.Thing`) (rows 12–14). The
`%Ecto.Association.NotLoaded{}` return remains allowed (row 16).

Caveat (new load-bearing capability): both 5a and 5b now require the check to **resolve the module's
`alias` directives** (including `:as`) to map a short/aliased struct name back to a real module
before comparing against the enclosing module. Row 15 (resolved): a **bare literal struct name with
no visible alias** (not `__MODULE__`, not fully-qualified-to-enclosing) is AST-derivable to top-level
`Elixir.<Name>`, so it is **in scope and treated as a foreign struct** (subject to 5b) — not skipped.
The only failure mode is a macro-injected alias for that short name, which is invisible to static
analysis by the stated Scope boundary and is therefore accepted. The current `analyze_getter_pattern/2` handles only
`%__MODULE__{}` with a bare-variable return and performs no alias resolution; rows 6–16 are fix
targets.

Caveat (macro/quote boundary, rows 19–21): the check operates on **literal getters only**. A getter
whose function name is non-literal (`def unquote(field)(…)`), or whose struct pattern or extracted
field is non-literal, is skipped — no crash, no flag. A module whose struct is macro-injected (a
`use SomeSchema` with no literal `defstruct`) yields no statically-visible struct fields, so there
are no getters to check and the module is correctly silent. Note this interacts with the unresolved
alias rule (row 15): row 15's "treat as foreign" applies to an *aliasing* miss on a **literal**
struct name; a *non-literal* struct name (row 20) is skipped entirely, not treated as foreign.

---

# B. Shared Analysis Machinery

## lib/anchor/config.ex

### parse_rule/1

Parses one YAML rule map (string keys) into the internal rule struct/map (atom keys).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | parses a `no_direct_dependency` rule | rule: `{"type"=>"no_direct_dependency", "paths"=>["lib/web/**/*.ex"], "forbidden_modules"=>["MyApp.Repo"], "recursive"=>true}` | `type: :no_direct_dependency`<br>`paths: ["lib/web/**/*.ex"]`<br>`forbidden_modules: [MyApp.Repo]`<br>`recursive: true` | Happy Path |
| 2 | parses a `must_use_module` rule | rule with `required_modules: ["MyApp.Schema"]`, `recursive: false` | `type: :must_use_module`, `required_modules: [MyApp.Schema]`, `recursive: false` | Happy Path |
| 3 | module strings become module atoms | `forbidden_modules: ["MyApp.Repo", "Ecto.Query"]` | `[MyApp.Repo, Ecto.Query]` (via `Module.concat`) | Validation |
| 4 | absent list fields default to `[]` | rule with only `type` | `paths: []`, `forbidden_modules: []`, `required_modules: []`, `allowed_functions: []` | Validation |
| 5 | absent `recursive` defaults to `false` | rule with no `recursive` | `recursive: false` | Validation |
| 6 | `pattern` and `uses_module` preserved | rule: `{"type"=>"module_pattern_restrictions", "pattern"=>"*.Schemas.*"}` | `pattern: "*.Schemas.*"`, `uses_module: nil` | Happy Path |
| 7 | `allowed_functions` preserved | rule: `allowed_functions: ["new", "with_*"]` | `allowed_functions: ["new", "with_*"]` | Happy Path |
| 8 | **`max_lines` surfaced as an atom-keyed integer** | rule: `{"type"=>"max_file_length", "max_lines"=>10}` | parsed rule exposes `max_lines: 10` (atom key, integer value) that `MaxFileLength.check_file/3` reads | Validation |
| 9 | **bare `mode: all` coerced to `:all`** | rule: `{"type"=>"alphabetized_functions", "mode"=>"all"}` | parsed rule exposes `mode: :all` (atom key) | Validation |
| 10 | **bare `mode: public_only` coerced to `:public_only`** | rule: `{"mode"=>"public_only"}` | `mode: :public_only` | Validation |
| 11 | **bare `mode: separate` coerced to `:separate`** | rule: `{"mode"=>"separate"}` | `mode: :separate` | Validation |
| 12 | unknown `mode` token handled, not crashing | rule: `{"mode"=>"sideways"}` | parse succeeds; `mode` falls back to the `:separate` default (no raise) | Error Handling |
| 13 | absent `max_lines`/`mode` leave the check on its own default | rule with neither | parsed rule has `max_lines: nil` / `mode: nil` (or absent) → checks apply defaults (400 / `:separate`) | Control Flow Decisioning |

Resolution (BUG-2 fix, owner-adjudicated): `max_lines`/`mode` are surfaced on the parsed rule as
**atom keys** — `max_lines` a plain integer, `mode` coerced from a **bare YAML token** (`all` /
`public_only` / `separate`, not colon-prefixed) to the corresponding atom via pattern-matching
coercion clauses (`mode("all") -> :all`, …) that fall back to `:separate` for unknown tokens
(rows 9–12). Checks read these atom keys instead of the current string-key `Map.get`.

### config_paths/0 (pure candidate list)

Ordered list of `.anchor.yml` locations to try, given a working directory. Specified as a pure
function of `cwd` + a directory-existence predicate (the `apps/` probe), so no real tree is needed.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | non-umbrella project | cwd `/proj` (no `/proj/apps`) | `["/proj/.anchor.yml"]` | Happy Path |
| 2 | umbrella root | cwd `/proj` (with `/proj/apps`) | root candidate `/proj/.anchor.yml` first, then the two-levels-up candidate; de-duplicated | Happy Path |
| 3 | **run from inside an umbrella app dir finds the umbrella root** | cwd `/proj/apps/my_app` | candidate list includes `/proj/.anchor.yml` (the umbrella root two levels up) so the root config is discoverable (intended-correct: BUG-5 fix) | Control Flow Decisioning |
| 4 | candidate list has no duplicates | cwd where root and computed paths coincide | list is `Enum.uniq`'d | Validation |

Caveat: row 3 is the BUG-5 fix. Current `config_paths/0` only branches on whether `cwd/apps` exists;
from inside `apps/my_app` that probe is false, so the umbrella root is never a candidate. The
intended contract is that the umbrella root `.anchor.yml` is reachable from an app subdirectory.

### load/0 and load_from_path/1 (adapter boundary)

Specified against a temp-file / in-memory file adapter — no real project tree.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | loads and parses a valid config file | temp file with a two-rule YAML document | `{:ok, %Config{rules: [r1, r2]}}` with parsed rules | Happy Path |
| 2 | empty file yields empty rules | temp file with `""` | `{:ok, %Config{rules: []}}` | Validation |
| 3 | missing file | path `"nonexistent.yml"` | `{:error, {:config_load_failed, :enoent}}` | Error Handling |
| 4 | malformed YAML | temp file with invalid YAML | `{:error, {:config_load_failed, _reason}}` | Error Handling |
| 5 | `load/0` returns empty config when no candidate exists | adapter reports no candidate path exists | `{:ok, %Config{rules: []}}` (checks then run as no-ops) | Control Flow Decisioning |
| 6 | `load/0` loads the first existing candidate | adapter reports the first candidate exists | `{:ok, config}` parsed from that path | Happy Path |

## lib/anchor/dependency_analyzer.ex

### extract_module_names/1

Owner-adjudicated (BUG 1/4): the singular `extract_module_name/1` becomes **plural**, returning an
**ordered list** of every `defmodule` in the file — top-level and nested. Order is **pre-order
depth-first, siblings in source order** (emit a module, then recurse into its children in source
order, so a subtree stays contiguous). Names are **fully qualified** (a nested `defmodule B` inside
`A` is `A.B`). Scope is `defmodule` only; `defimpl`/`defprotocol` bodies are walked for
direct-dependency extraction but are NOT emitted as named module nodes.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | single module → one-element list | ast of `defmodule MyApp.Test do ... end` | `[MyApp.Test]` | Happy Path |
| 2 | non-module AST | ast of a bare `def hello, do: :world` | `[]` | Validation |
| 3 | two sibling top-level modules, source order | ast defining `defmodule A … end` then `defmodule B … end` | `[A, B]` | Control Flow Decisioning |
| 4 | nested siblings are fully qualified, in source order | `A` containing siblings `defmodule B`, `defmodule C` | `[A, A.B, A.C]` | Control Flow Decisioning |
| 5 | pre-order DFS keeps a subtree contiguous | `A` containing `D`, then `C` which contains `E` | `[A, A.D, A.C, A.C.E]` | Control Flow Decisioning |
| 6 | deeper DFS — full pre-order traversal | `A` containing (`D` containing `F`) and (`C` containing `E`) | `[A, A.D, A.D.F, A.C, A.C.E]` (not breadth-first) | Control Flow Decisioning |
| 7 | `defimpl`/`defprotocol` not emitted as module nodes | ast with `defmodule A` containing a `defimpl String.Chars, for: A` block | `[A]` (the `defimpl` body is not a named node) | Validation |
| 8 | unknown/unnamed module contributes no name | ast whose module name resolves to `<Unknown Module Name>` | that node contributes nothing (`[]` if it is the only content) | Error Handling |
| 9 | macro/quote — dynamic `defmodule unquote(x)` name → skipped, no crash | ast of `defmodule unquote(x) do … end` | that module emits NO name and does not raise (`[]` if it is the only content) | Macro / Static Boundary |
| 10 | macro/quote — variable/expression module name → skipped, no crash | ast of `defmodule mod_name do … end` (non-literal alias) | no name emitted for that node; no raise | Macro / Static Boundary |
| 11 | macro/quote — pure DSL file with zero literal `defmodule` → `[]` | ast of a file that is only macro calls, e.g. `defcontext … defaggregate … defentity …` | `[]` (no literal `defmodule` for a static pass to see) | Macro / Static Boundary |
| 12 | literal modules alongside a dynamic one — only literals emitted | ast with `defmodule A` (literal) and a sibling `defmodule unquote(x)` | `[A]` (the dynamic sibling is skipped, not a crash) | Macro / Static Boundary |

Caveat: this is a singular→plural **API shape change** (`extract_module_name/1` returning one module
or `nil` → `extract_module_names/1` returning an ordered list). Callers change accordingly — see the
`build_modules_map` and `rule_matches_file?/2` rows below.

Caveat (macro/quote boundary, rows 9–12): a `defmodule` whose name is not a literal alias is
produced only at macro-expansion time and is **out of scope** — it emits no node and never raises.
Consequently macro-generated modules do not appear in `build_modules_map`'s transitive graph, and a
module-`pattern` rule cannot select them. This is the intended static-analysis boundary, not a gap.

### extract_direct_dependencies/1

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | extracts module aliases | ast whose body references `MyApp.Repo`, `Query`, `SomeModule` | list contains `MyApp.Repo`, `Query`, `SomeModule` | Happy Path |
| 2 | extracts qualified function calls | ast with `Enum.map(...)` | list contains `Enum` | Happy Path |
| 3 | result is sorted and de-duplicated | ast referencing `Enum` twice and `A` once | each module appears once, sorted | Validation |
| 4 | no external references | ast of `def f, do: 1` | `[]` | Positive Control |
| 5 | **`__MODULE__.Sub` in ordinary code resolves to the enclosing submodule** | ast inside `defmodule Enclosing` containing `__MODULE__.Sub.f()` | returns without raising; records `Enclosing.Sub` as the dependency (decision #1 = resolve) | Error Handling |
| 6 | **`@attr.Sub` does not crash and is not a spurious module dep** | ast containing `@config.Sub` | returns without raising; no bogus static module recorded for the attribute access | Error Handling |
| 7 | **`var.Sub` (runtime access) does not crash and is not a static dep** | ast containing `conn.Sub` / `var.field` | returns without raising; runtime access is not recorded as a compile-time module dependency | Error Handling |
| 8 | macro/quote — `__MODULE__` inside `quote` is opaque, not resolved | ast of `quote do def f, do: __MODULE__.Sub.g() end` inside `defmodule Enclosing` | returns without raising; does NOT record `Enclosing.Sub` (inside `quote`, `__MODULE__` binds to the generated module at expansion, not `Enclosing`) | Macro / Static Boundary |
| 9 | macro/quote — `%__MODULE__{}` inside `quote` is opaque | ast of `quote do %__MODULE__{} end` inside `defmodule Enclosing` | returns without raising; no `Enclosing`-resolved struct dependency recorded for the quoted `__MODULE__` | Macro / Static Boundary |
| 10 | ordinary literal-aliased deps unaffected by the quote rule | ast with `MyApp.Repo.all()` outside any `quote` | records `MyApp.Repo` as normal | Positive Control |

Caveat (rows 5, 8–9 — decision #1 resolved): outside a `quote`, `__MODULE__.Sub` resolves to the
enclosing module's submodule (`Enclosing.Sub`). **Inside a `quote do … end` block the resolution is
suppressed** — `__MODULE__` there refers to the module generated at macro-expansion, not the
lexically-enclosing source module, so resolving it would name the wrong module; it is left opaque
(no enclosing-resolved dependency emitted). The non-negotiable assertions on rows 6–9 remain "does
not raise" and "no spurious static dependency."

### extract_uses/1

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | extracts `use` declarations | ast with `use MyApp.Web, :controller` and `use Phoenix.LiveView` | list contains `MyApp.Web` and `Phoenix.LiveView` | Happy Path |
| 2 | no uses | ast of a module with only `def` | `[]` | Positive Control |
| 3 | `use Mod, opts` records the module, not the opts | ast with `use MyApp.Schema, foo: 1` | list contains `MyApp.Schema` only | Validation |
| 4 | result sorted and de-duplicated | ast with two identical `use` lines | module appears once | Validation |

### find_transitive_dependencies/3

Pure graph reachability over an in-memory `modules_map` (module → `%{direct_dependencies: [...]}`).

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | reaches a module through one hop | map `A→[B]`, `B→[Repo]`; start `A` | visited set contains `A`, `B`, `Repo` | Happy Path |
| 2 | reaches through two hops | map `A→[B]`, `B→[C]`, `C→[Repo]`; start `A` | visited contains `Repo` | Happy Path |
| 3 | does not reach an unrelated module | map `A→[B]`, `B→[C]`; start `A` | visited excludes `Repo` | Positive Control |
| 4 | terminates on a cycle | map `A→[B]`, `B→[A]`; start `A` | returns `{A, B}` without infinite recursion | Error Handling |
| 5 | start module absent from map | empty map; start `A` | visited = `{A}` (start included, no expansion) | Control Flow Decisioning |
| 6 | direct dependency included | map `A→[Repo]`; start `A` | visited contains `Repo` | Happy Path |
| 7 | pre-seeded `visited` short-circuits | map `A→[B]`; start `A`, visited already contains `A` | returns the passed-in visited unchanged | Control Flow Decisioning |

## lib/anchor/check/base.ex

Pattern-matching and rule-selection helpers. In the five-bucket refactor these move to a shared
pure "pattern matcher" / "rule selection" module; the behavioral contract below is stable across
that move.

### matches_recursive_pattern?/2 (glob with `**`)

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | `**` matches across path segments | path `lib/my_app/web/user.ex`, pattern `lib/my_app/**/*.ex` | `true` | Happy Path |
| 2 | `**/` matches zero segments | path `lib/user.ex`, pattern `lib/**/*.ex` | `true` | Control Flow Decisioning |
| 3 | single `*` does not cross a `/` | path `lib/a/b.ex`, pattern `lib/*.ex` | `false` | Validation |
| 4 | single `*` matches within one segment | path `lib/user.ex`, pattern `lib/*.ex` | `true` | Happy Path |
| 5 | literal `.` is not a wildcard | path `libXex`, pattern `lib.ex` | `false` (`.` escaped) | Validation |
| 6 | extension mismatch | path `lib/user.exs`, pattern `lib/**/*.ex` | `false` | Validation |
| 7 | leading `**` matches anything | path `deep/a/b/c.ex`, pattern `**/*.ex` | `true` | Happy Path |

### matches_pattern?/2 (glob without `**`, single `*`)

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | `*` matches within a segment | path `lib/user.ex`, pattern `lib/*.ex` | `true` | Happy Path |
| 2 | `*` does not cross `/` | path `lib/a/b.ex`, pattern `lib/*.ex` | `false` | Validation |
| 3 | exact match | path `lib/user.ex`, pattern `lib/user.ex` | `true` | Happy Path |
| 4 | anchored full match (no partial) | path `xlib/user.exy`, pattern `lib/user.ex` | `false` (`^...$`) | Validation |

### matches_module_pattern?/2 (module-name glob)

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | trailing `*` matches submodules | module `MyApp.Web.UserController`, pattern `MyApp.Web.*` | `true` | Happy Path |
| 2 | `*` may cross dots for module names | module `App.Schemas.User`, pattern `*.Schemas.*` | `true` | Happy Path |
| 3 | suffix pattern | module `App.UserQueries`, pattern `*Queries` | `true` | Happy Path |
| 4 | non-match | module `App.Service`, pattern `*.Schemas.*` | `false` | Validation |
| 5 | literal dots are escaped | module `AppXSchemasXUser`, pattern `*.Schemas.*` | `false` | Validation |

### rule_matches_file?/2 (rule selection)

Determines whether a rule applies to a source file — by `paths` (glob), by module `pattern`, or by
`uses_module`. This is the "rule selection is part of the contract" gate that runs before every
`check_file/3`.

| # | Test Case | Inputs | Expected Output | Category |
|---|---|---|---|---|
| 1 | path rule, recursive, matches | rule `paths: ["lib/**/*.ex"], recursive: true`; file `lib/a/b.ex` | `true` | Happy Path |
| 2 | path rule, recursive, no match | same rule; file `test/a_test.exs` | `false` | Validation |
| 3 | path rule, non-recursive, uses single-`*` semantics | rule `paths: ["lib/*.ex"], recursive: false`; file `lib/a/b.ex` | `false` | Control Flow Decisioning |
| 4 | module `pattern` rule matches by module name | rule `pattern: "*.Schemas.*"`; file defines `App.Schemas.User` | `true` | Happy Path |
| 5 | module `pattern` rule does not match | rule `pattern: "*.Schemas.*"`; file defines `App.Service` | `false` | Validation |
| 6 | `uses_module` rule matches a module that `use`s it | rule `uses_module: "Ecto.Schema"`; file has `use Ecto.Schema` | `true` | Happy Path |
| 7 | `uses_module` rule does not match | rule `uses_module: "Ecto.Schema"`; file has no such `use` | `false` | Validation |
| 8 | rule with neither paths/pattern/uses_module | rule with all selectors empty/nil | `false` (deny by default — no accidental match) | Validation |

Caveat: row 4's module `pattern` selection depends on `extract_module_names/1` (plural); a file with
multiple top-level modules is selectable if ANY of its module names matches the pattern (owner
decision 1 / BUG 1/4 fix).

---

# Adjudication Ledger

Every ambiguity flagged in the first version of this matrix now has a resolved disposition. The
resolution text lives with the affected rows (linked below); this ledger is the index.

| # | Previously-flagged ambiguity | Disposition | Where resolved in this matrix |
|---|---|---|---|
| 1 | `extract_module_name/1` return shape (singular vs plural) for multi/nested modules | **Resolved** — becomes plural `extract_module_names/1`, ordered pre-order DFS, fully-qualified names, `defmodule`-only scope; callers (`build_modules_map`, `rule_matches_file?/2`) updated | `dependency_analyzer.ex` → `extract_module_names/1`; caveats under `no_transitive_dependency.ex` and `base.ex` → `rule_matches_file?/2` |
| 2 | `max_lines`/`mode` key spelling and YAML form | **Resolved** — atom keys on the parsed rule; `max_lines` a plain integer; `mode` coerced from a bare token (`all`/`public_only`/`separate`) to an atom, unknown → `:separate` default | `config.ex` → `parse_rule/1`; caveats under `max_file_length.ex` and `alphabetized_functions.ex` |
| 3 | `NoTupleMatchInHead` mixed-args / regex limitation | **Resolved** — AST-based; per-argument judgment; top-level tuple or match-assignment operand flagged, nested-in-list/map allowed; guards and multi-clause covered | `no_tuple_match_in_head.ex` → `check_file/3` (rows 5, 14–15 + Resolution) |
| 4 | `NoComparisonInIf` `unless` scope and trigger | **Resolved** — `unless` in scope; violation trigger is `"unless"`; clean/flagged rows added | `no_comparison_in_if.ex` → `check_file/3` (rows 7, 11 + Resolution) |
| 5 | `StructGetterConvention` second obligation ("defined in the struct's module") | **Resolved** — enclosing-module struct recognized in all spellings (`__MODULE__`, fully-qualified, aliased, `:as` alias) via alias resolution; foreign struct → location violation; a bare literal struct name with no visible alias is AST-derivable to `Elixir.<Name>` → in scope, treated as foreign (row 15) | `struct_getter_convention.ex` → `check_file/3` (rows 6–16 + Resolution/Caveat) |
| 6 | `__MODULE__.Sub` treatment in `extract_direct_dependencies/1` (resolve vs. ignore) | **Resolved** — resolve to the enclosing submodule (`Enclosing.Sub`) in ordinary code; suppress resolution inside a `quote` block (opaque); `@attr`/`var` accesses never recorded; never crashes | `dependency_analyzer.ex` → `extract_direct_dependencies/1` (rows 5, 8–9 + Caveat) |

## Static-analysis boundary (macro/quote) — cross-cutting

Grounded against a macro-heavy real repo (gen_saas, DSL/macro-generated domain layer). Per the
**Scope & limitations** note in the preamble, every check and machinery unit degrades gracefully on
macro-expansion-time constructs: skip, never crash, never emit a claim on code not statically
visible. The three concrete handling rules are specified as rows/caveats on:

| Handling rule | Where specified |
|---|---|
| Non-literal `defmodule` name → skipped (no node), no crash; pure-DSL file → `[]` | `dependency_analyzer.ex` → `extract_module_names/1` (rows 9–12 + macro/quote Caveat) |
| `__MODULE__`/`%__MODULE__{}` inside `quote` → opaque (not resolved); resolve only outside quotes | `dependency_analyzer.ex` → `extract_direct_dependencies/1` (rows 5, 8–10 + Caveat) |
| Getters are literal-only: non-literal fn name / struct / field → skipped; macro-injected struct (no literal `defstruct`) → silent | `struct_getter_convention.ex` → `check_file/3` (rows 19–21 + macro/quote Caveat) |
