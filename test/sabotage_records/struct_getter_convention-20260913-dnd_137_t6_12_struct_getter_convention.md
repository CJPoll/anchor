# Sabotage record — StructGetterConvention detection extracted to Domain

- **Domain:** struct_getter_convention
- **Branch:** dnd-137-t6-12-struct-getter-convention
- **Date:** 2026-09-13
- **Code under test:** `Anchor.Domain.Checks.StructGetterConvention.detect_violations/2` (the pure Domain detector; the `Anchor.Check.StructGetterConvention` shell delegates to it)
- **Suite run:** `mix test test/anchor/check/struct_getter_convention_test.exs` (the exhaustive #1–21 `check_file/3` matrix)

T6.12 (DND-137) extracted the detection out of the `Anchor.Check.StructGetterConvention`
Framework shell into the pure `Anchor.Domain.Checks.StructGetterConvention` module and
added the load-bearing capability: resolving the module's `alias` directives (including
`:as` and `A.{B, C}`) so a getter head is judged by the module its struct actually names,
splitting the report into a **naming** violation (getter for the enclosing struct whose
name ≠ field) and a **location** violation (getter whose struct resolves to a different
module). Each mutation below was applied to the Domain module, the suite re-run, the code
restored (`git checkout` against the impl commit). Failure strings are verbatim, including
`left:` / `right:`.

| # | Mutation | Rows failed | Failure string |
|---|---|---|---|
| A′ | Disable alias resolution in `resolve_struct_module/3` (drop the `Map.fetch(aliases, head)` lookup; `_aliases`, always `Module.concat([head \| rest])`) so `%User{}`, `%X{}`, `%O{}` no longer map back to their real modules | 5 (rows 8, 9, 10, 11, 13) | row 10: `code: assert issue.message ==` `left: "Getter for \`X.name\` should be defined in \`X\` (not in \`MyApp.User\`)"` `right: "Getter function \`get_name\` should be named \`name\` to match the field it extracts"`; row 13: `left: "Getter for \`Other.name\` should be defined in \`Other\` ..."` (alias `:as` no longer recovers `Other.Thing`); rows 9/11: correct aliased getters now mis-resolve to a foreign module and flag a spurious location violation |
| B′ | Corrupt the location message body (`should be defined in` → `MUST live in`) | 3 (rows 12, 13, 15) | row 12: `left: "Getter for \`Other.name\` MUST live in \`Other\` (not in \`A\`)"` `right: "Getter for \`Other.name\` should be defined in \`Other\` (not in \`A\`)"`; row 15: `left: "Getter for \`Unknown.name\` MUST live in \`Unknown\` ..."` `right: "should be defined in \`Unknown\`"` |
| C | Corrupt the naming message body (`should be named` → `OUGHT to be`) | 6 (rows 1, 6, 8, 10, 14, 18) | row 1: `left: "Getter function \`get_name\` OUGHT to be \`name\` to match the field it extracts"` `right: "Getter function \`get_name\` should be named \`name\` to match the field it extracts"` |
| D′ | Make the no-literal-`defstruct` clause emit a naming violation anyway (`adjudicate(module, module, false, …)` runs the name==field check instead of returning `[]`) | 2 (rows 5, 21) | row 5: `code: assert [] == issues(source)` `left: []` `right: [ %Credo.Issue{message: "Getter function \`get_name\` should be named \`name\` ...", trigger: "get_name"} ]`; row 21 identical shape for the `use SomeSchema` module |
| E | Invert the naming predicate (`function_name == field_name` → `function_name != field_name`) | 14 (rows 1, 2, 3, 6, 7, 8, 9, 10, 11, 14, 16, 17, 18) | row 2: `code: assert [] == issues(source)` `left: []` `right: [ ...spurious naming issue for the correctly-named getter... ]`; row 1 (inverse): the misnamed getter no longer flags so `assert [issue] = issues(source)` fails to match `[]` |
| F | Replace the location trigger with a constant (`to_string(field_name)` → `"LOCATION"`) | 3 (rows 12, 13, 15) | `code: assert issue.trigger == "name"` `left: "LOCATION"` `right: "name"` (all three rows) |
| G′ | Offset the reported line (`line: meta[:line]` → `line: meta[:line] + 1`, both violations) | 3 (rows 1, 12, 18) | row 1: `code: assert issue.line_no == 3` `left: 4` `right: 3`; row 12: `left: 3` `right: 2`; row 18: `left: 6` `right: 5` |

## What each mutation proves

- **A′** is the whole point of the ticket: alias resolution. Without it the aliased
  spellings (`%User{}` via `alias MyApp.User`, `%X{}` via `:as`, `%O{}` via
  `alias Other.Thing, as: O`) stop resolving — an enclosing-struct getter is
  mis-classified as foreign (rows 8–11 flip between naming and location), and the
  foreign `:as` getter (row 13) can no longer name the real `Other.Thing`.
- **B′ / F** protect the location violation's message and trigger; **C / G′**
  protect the naming message and the reported line; together they pin the
  naming-vs-location discrimination that is "the discriminating detail" per the
  acceptance rows.
- **D′** proves the literal-`defstruct` gate: an enclosing-module getter is only
  name-checked when a *literal* `defstruct` is visible, so rows 5 (no defstruct) and
  21 (`use SomeSchema`, macro-injected struct) must stay silent.
- **E** proves every "accepts / correctly named → `[]`" row is non-vacuous: inverting
  the equality makes the correctly-named getters (rows 2, 7, 9, 11, 16, 17) flag and
  the misnamed getters (rows 1, 6, 8, 10, 18) stop flagging, so both halves of the
  naming rule are load-bearing. Row 3 (`String.downcase` body) reddens too — inverting
  the predicate does not change that a non-bare-var body is a non-getter, but the
  correctly-named control it shares flips.

## Traps encountered (ADR 002 catalogue)

Four mutations were rejected by Elixir 1.19's `--warnings-as-errors` compile before they
could prove anything about the tests — recorded so a future run does not re-attempt them:

1. **Disable alias lookup without underscoring the arg** (`aliases` left bound but unused):
   `variable "aliases" is unused` → compile fails. A′ underscores the parameter so the
   mutation actually runs.
2. **Location clause → `[]`** (`adjudicate(struct_module, enclosing_module, …) -> []`):
   leaves `location_violation/4` defined-but-unused → compile fails. B′ corrupts the
   message *inside* `location_violation/4` instead so the function stays referenced.
3. **`has_literal_struct? = true`** (hard-code the gate): leaves `struct_fields/1`
   defined-but-unused → compile fails. D′ mutates the consuming `adjudicate` clause
   instead.
4. **`line: nil`** (drop the reported line): leaves `meta` unused in both violation
   builders → compile fails. G′ offsets the line (`meta[:line] + 1`) so `meta` stays used.

## Measured zeros

- **Row 4** (`has_role?/2` multi-arg → `[]`). Making `getter_candidate?/1` accept any
  arity (`length(args) == 1` → `>= 1`) produced **0 failures**: the `[arg]` single-element
  pattern in `validate_getter/4` still rejects the 2-arg head, and even if it matched, the
  body `role == expected` is not a bare-variable return so `analyze_getter/2` returns
  `:not_a_getter`. Row 4's absence is doubly guarded; the "must return a bare field
  variable" half is proven live by row 3 under mutation **E**. No single-line mutation to
  this module reddens row 4.
- **Row 19** (macro `def unquote(field)(…)` inside a `for` comprehension → `[]`). The
  generated `def` is nested inside the `for` block, so `functions/1` — which selects only
  top-level `:def`/`:defp` statements of the module body — never sees it. There is no
  literal getter to mutate into a violation; the row documents that comprehension-generated
  defs are invisible to the AST-level check. **Measured zero.**
- **Row 20** (non-literal `%@struct{…}` struct → `[]`). `literal_struct?/1` returns `false`
  for the `{:@, …}` struct node, so `analyze_getter/2` returns `:not_a_getter`. Removing the
  `literal_struct?` guard does not cleanly red the row — it makes `resolve_struct_module/3`
  receive a `{:@, …}` node that matches none of its clauses and raises
  `FunctionClauseError` (a crash, not an assertion failure), which is exactly the "no crash
  on non-literal struct" behavior the row exists to protect. **Measured zero**; the guard's
  necessity is shown by the crash a naive removal causes.
