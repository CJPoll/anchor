# Sabotage record — demand (absence) analysis over Core Erlang (DND-5498)

- **Domain:** demand (one combined record, as the QA plan directs; the `effect_primitives` and `pure_calls` mutations are labelled EFF-* and PURE-*, the lattice's LAT-*)
- **Branch:** dnd-5498-demand
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Demand` (`analyze/4`, the SCC fixpoint and its round bound, the report, `param/3`), `Anchor.Domain.Demand.Transfer` (`function/2`, the backward walk), `Anchor.Domain.Demand.Lattice`, `Anchor.Domain.EffectPrimitives`, `Anchor.Domain.PureCalls`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/domain/demand test/anchor/domain/demand_test.exs test/anchor/domain/effect_primitives_test.exs test/anchor/domain/pure_calls_test.exs test/anchor/integration/demand_self_test.exs`, through `test-slot`

Each mutation was applied to one file by a driver that asserted the replaced text occurs exactly once, ran the suite, restored the file with `git checkout -- <file>`, and printed `git status --short`, which was empty after every row. Every row below compiled and ran the whole suite (its summary line is quoted), so no row is a compile failure read as a test failure.

The two mutations the QA plan names: DEM-A (the SCC loop runs one round only: both mutual-recursion rows fail, the positive control because one round never carries `p`'s use from `ping`'s base around the cycle) and DEM-B (escape primitives read as pure: the `send` and `Task.start` rows fail).

## Runs

- A first run on 95e5e07 (27 mutations) was superseded by the review-floor fixes (9a935e9), which changed most of the mutated lines. It had four compile traps under warnings-as-errors (an unused `max_rounds`, `demand`, `index`, and an unused `map_pattern_demand/2`); those mutations were rewritten so the code still compiles.
- The rows below come from four runs: a9deba8 (the main run, 37 mutations), fd79e2e (DEM-D, DEM-P, DEM-AE, EFF-A rewritten for the final code; DEM-D's first form only skipped clearing a clause's names on entry, which the restore on exit masked, so it reddened nothing: it now removes the scope entirely), c33e8b7 (LAT-*, DEM-AI..AK, EFF-B..D, PURE-B..C, written for the tests no earlier row reached) and 43d2404 (LAT-C and SELF-A again, after the monotonicity row was widened to every ordered pair; LAT-C reddened only the bound rows before).
- DEM-AL ran on the critic fix (the commit after ebc5e60), alone.
- Every one of the 84 tests in the six files is seen failing in at least one row.
- Not counted: in 13 rows the self test (`Anchor's own code: ...`) also failed by **timing out** at the mutation runs' 2000 ms `--timeout` under a loaded machine; those are not kills and are left out of the "Tests failed" counts. The self test now carries `@moduletag timeout: 60_000` (43d2404). The self test is killed for real (an assertion) by DEM-C, DEM-T and SELF-A.
- Measured zeros: none in the final runs. DEM-M (a literal-key field read uses the whole value) of the first run targeted a helper the review-floor fix removed; DEM-AH covers the code that replaced it.

| # | Mutation | File | Tests failed | Failing tests |
|---|---|---|---|---|
| DEM-A | the SCC loop runs one round only | `demand.ex` | 6 | analyze/4 AC5 mutual recursion passing p around without using it: absent; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 AC5 positive control: mutual recursion that returns p at the base uses it on both sides; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 positive control: the same shape with a lambda that returns its argument: used; analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used |
| DEM-B | escape primitives read as pure (demand from the result) | `transfer.ex` | 4 | function/2 send(self(), a); :ok: all (an escape); counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; analyze/4 a closure capturing p handed to Task.start/1 uses p (escape) |
| DEM-C | a match_fail payload is a use | `transfer.ex` | 35 | more Core shapes a binary built from a uses a, not b; function/2 f(m) -> m.x: only field x of m; more Core shapes m.x with its result unused still uses field x (m may be a module: m.x() runs); function/2 a clause head %{k: v} uses key k of its parameter, and not k's value; more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise); function/2 a guard is_map(x) uses x for its shape; function/2 if a, do: 1, else: 2: a used, b absent; more Core shapes Map.put then Map.get of the put key: the value is used, the base's other field not; function/2 try: the body's value and the handler's are used, nothing else; more Core shapes a map update read at another key: that key of the map, not the new value; modes an unknown call demands nothing in the optimistic mode; function/2 a map built and read: the field read is used, the other absent; callee summaries a local call takes the callee's summary and records the passes; function/2 f(a, b) -> a: [all, absent] (the function_clause catch-all is no use); more Core shapes a struct head reads __struct__ and the named field; function/2 a fn that is never used uses nothing it captures; function/2 _ = a + 1; :ok: absent (a pure expression whose result is discarded); function/2 a tuple built and read: the element read is used, the other absent; function/2 f(m) -> {m.x, m.y}: fields x and y; function/2 elem(t, 1) and Map.get(m, :k) read one field; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})]; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; analyze/4 self recursion loop(n, acc): acc absent, n used; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 a caller of an imprecise function is imprecise through it; analyze/4 receive (a letrec over recv primops): a captured parameter the clause uses is used; analyze/4 AC1 def f(a, b), do: a gives [used(all), absent]; analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent; analyze/4 an extra effect token makes a library call an effect: used, and precise; analyze/4 AC3 a parameter passed down two calls and dropped by the last is absent at all three; Anchor's own code: no bound hit, every function summarised, known demands |
| DEM-D | no lexical scoping (a clause variable shares the outer binding) | `transfer.ex` | 5 | function/2 a map built and read: the field read is used, the other absent; more Core shapes a map update read at another key: that key of the map, not the new value; function/2 f(m) -> {m.x, m.y}: fields x and y; function/2 f(m) -> m.x: only field x of m; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})] |
| DEM-E | the optimistic mode demands an unknown call in full (same as sound) | `transfer.ex` | 6 | modes an unknown call demands nothing in the optimistic mode; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 an extra effect token makes a library call an effect: used, and precise; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; analyze/4 a caller of an imprecise function is imprecise through it |
| DEM-F | an :any apply site reads as the empty set | `transfer.ex` | 3 | analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 a caller of an imprecise function is imprecise through it |
| DEM-G | the round bound is never enforced | `demand.ex` | 1 | the round bound a component that does not settle within :max_rounds is used, imprecise and named |
| DEM-H | Lattice.bound/1 never cuts | `lattice.ex` | 1 | bound/1 a 4-deep field demand collapses at depth 3 to all (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-I | join(:absent, x) is :absent | `lattice.ex` | 55 | join/2 leq?(a, join(a, b)) over 20 triples; join/2 commutative, associative and idempotent over 20 triples; join/2 two field demands merge their keys, joining a key both hold; join/2 absent is the identity, all absorbs; more Core shapes apply/2 of an :any function uses the list and names its site; more Core shapes a comprehension (Enum.map of a fn) uses the list and what the fn captures; function/2 IO.puts(a); :ok: all (an effect); more Core shapes a receive loop the summaries lack fails closed as an unknown closure; more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise); more Core shapes a binary built from a uses a, not b; callee summaries a callee the summaries lack is an unknown call (fail closed); more Core shapes m.x with its result unused still uses field x (m may be a module: m.x() runs); function/2 elem(t, 1) and Map.get(m, :k) read one field; function/2 send(self(), a); :ok: all (an escape); more Core shapes a pinned map key in a pattern is used; more Core shapes apply/3 to a variable module uses everything and names the reason; function/2 f(m) -> {m.x, m.y}: fields x and y; more Core shapes a call on a variable module uses everything and names the reason; function/2 a tuple built and read: the element read is used, the other absent; more Core shapes a struct head reads __struct__ and the named field; more Core shapes a pure module's call with its result unused still uses a fn argument; function/2 a clause head %{k: v} uses key k of its parameter, and not k's value; modes an unknown call uses its arguments and names the reason (sound); more Core shapes a map update read at another key: that key of the map, not the new value; more Core shapes Map.put then Map.get of the put key: the value is used, the base's other field not; callee summaries a local call takes the callee's summary and records the passes; function/2 if a, do: 1, else: 2: a used, b absent; function/2 a map built and read: the field read is used, the other absent; function/2 f(m) -> m.x: only field x of m; function/2 f(a, b) -> a: [all, absent] (the function_clause catch-all is no use); function/2 try: the body's value and the handler's are used, nothing else; function/2 a guard is_map(x) uses x for its shape; more Core shapes a bitstring size in a pattern is used; more Core shapes a + 1 returned uses a (the positive control of the discarded row); more Core shapes Enum.each with a fn that prints p: both used, precisely; analyze/4 an extra effect token makes a library call an effect: used, and precise; analyze/4 self recursion loop(n, acc): acc absent, n used; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely; analyze/4 AC3 positive control: the last returns it, and it is used at all three; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; analyze/4 a caller of an imprecise function is imprecise through it; analyze/4 positive control: the same shape with a lambda that returns its argument: used; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; analyze/4 AC5 positive control: mutual recursion that returns p at the base uses it on both sides; analyze/4 receive (a letrec over recv primops): a captured parameter the clause uses is used; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})]; analyze/4 AC1 def f(a, b), do: a gives [used(all), absent]; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); analyze/4 a closure capturing p handed to Task.start/1 uses p (escape); analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-J | a pure BIF demands its arguments in full when its result is discarded | `transfer.ex` | 2 | more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise); function/2 _ = a + 1; :ok: absent (a pure expression whose result is discarded) |
| DEM-K | a type test uses its argument in full | `transfer.ex` | 2 | more Core shapes a map update read at another key: that key of the map, not the new value; function/2 a guard is_map(x) uses x for its shape (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-L | passes do not alias through variable patterns | `transfer.ex` | 3 | callee summaries a local call takes the callee's summary and records the passes; analyze/4 self recursion loop(n, acc): acc absent, n used; analyze/4 passes: each level names the call it passes the parameter to |
| DEM-N | a fn whose value is unused is still walked | `transfer.ex` | 1 | function/2 a fn that is never used uses nothing it captures (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-O | components run callers first | `demand.ex` | 5 | analyze/4 AC3 a parameter passed down two calls and dropped by the last is absent at all three; counts functions analysed, absent parameters and imprecise functions, exact; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 passes: each level names the call it passes the parameter to; analyze/4 a caller of an imprecise function is imprecise through it |
| DEM-P | extra effect tokens never match | `effect_primitives.ex` | 2 | effect?/2 an extra token makes its function an effect, at its arity only; analyze/4 an extra effect token makes a library call an effect: used, and precise |
| DEM-Q | no {:via, callee} reasons | `demand.ex` | 2 | analyze/4 a caller of an imprecise function is imprecise through it; the round bound a component that does not settle within :max_rounds is used, imprecise and named |
| DEM-R | a bound-hit component stays :all in the optimistic summaries | `demand.ex` | 1 | the round bound a component that does not settle within :max_rounds is used, imprecise and named |
| DEM-S | a map pattern uses the value in full | `transfer.ex` | 8 | function/2 a clause head %{k: v} uses key k of its parameter, and not k's value; function/2 a map built and read: the field read is used, the other absent; more Core shapes m.x with its result unused still uses field x (m may be a module: m.x() runs); function/2 f(m) -> m.x: only field x of m; more Core shapes a map update read at another key: that key of the map, not the new value; function/2 f(m) -> {m.x, m.y}: fields x and y; more Core shapes a struct head reads __struct__ and the named field; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})] |
| DEM-T | bound/1 reads a field map through Enumerable | `lattice.ex` | 3 | a struct pattern's fields a field map holding :__struct__ is bounded and compared as a map, not a struct; more Core shapes a struct head reads __struct__ and the named field; Anchor's own code: no bound hit, every function summarised, known demands |
| DEM-U | a tuple element gets everything or nothing | `transfer.ex` | 1 | function/2 a tuple built and read: the element read is used, the other absent |
| DEM-V | letrec definitions are not walked in context | `transfer.ex` | 3 | more Core shapes a receive loop the summaries lack fails closed as an unknown closure; analyze/4 receive (a letrec over recv primops): a captured parameter the clause uses is used; counts functions analysed, absent parameters and imprecise functions, exact |
| DEM-W | a try handler is not walked | `transfer.ex` | 1 | function/2 try: the body's value and the handler's are used, nothing else |
| DEM-X | a project callee summary is ignored (arguments demanded in full) | `transfer.ex` | 9 | callee summaries a local call takes the callee's summary and records the passes; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 self recursion loop(n, acc): acc absent, n used; analyze/4 a caller of an imprecise function is imprecise through it; counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 AC3 a parameter passed down two calls and dropped by the last is absent at all three; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent |
| DEM-Y | no protection inside try/catch | `transfer.ex` | 1 | more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise) |
| DEM-Z | map keys and bitstring sizes in patterns are not read | `transfer.ex` | 2 | more Core shapes a pinned map key in a pattern is used; more Core shapes a bitstring size in a pattern is used (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-AA | a pure module row propagates from its result | `transfer.ex` | 1 | more Core shapes a pure module's call with its result unused still uses a fn argument (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-AB | a module token matches nothing | `effect_primitives.ex` | 2 | effect?/2 a module token makes every function of that module an effect; analyze/4 an extra module token makes every function of the module an effect |
| DEM-AC | a library capture that is an effect is read as unknown | `transfer.ex` | 2 | counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-AD | a closure of another arity takes the summary in full | `transfer.ex` | 2 | analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); counts functions analysed, absent parameters and imprecise functions, exact |
| DEM-AE | a HigherOrder call is not special-cased | `transfer.ex` | 2 | more Core shapes Stream.map (a HigherOrder function outside the pure modules): used, precisely; more Core shapes Enum.each with a fn that prints p: both used, precisely |
| DEM-AF | apply/2 never uses its list | `transfer.ex` | 2 | analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used; counts functions analysed, absent parameters and imprecise functions, exact (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| DEM-AG | a call that is an apply site adds no call-graph edges to its closures | `demand.ex` | 2 | counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used |
| DEM-AH | no_parens_remote uses its subject only when its result is used | `transfer.ex` | 1 | more Core shapes m.x with its result unused still uses field x (m may be a module: m.x() runs) |
| LAT-A | at/2 of a missing key is all | `lattice.ex` | 5 | at/2 the demand on a field: absent of absent, all of all, the key of used; function/2 a map built and read: the field read is used, the other absent; more Core shapes a map update read at another key: that key of the map, not the new value; more Core shapes Map.put then Map.get of the put key: the value is used, the base's other field not; function/2 a tuple built and read: the element read is used, the other absent |
| LAT-B | the depth bound is 2 | `lattice.ex` | 2 | bound/1 a 3-deep field demand is kept (positive control); bound/1 a 4-deep field demand collapses at depth 3 to all |
| LAT-C | bound/1 is not monotone (all at the cut becomes absent) | `lattice.ex` | 3 | bound/1 bound is monotone over every ordered pair of samples, nested to the cut; bound/1 a 3-deep field demand is kept (positive control); bound/1 a 4-deep field demand collapses at depth 3 to all |
| LAT-D | anything is at or below absent | `lattice.ex` | 1 | leq?/2 absent < used(fields) < all, and fields compare pointwise |
| DEM-AI | an extra function token that does not parse is kept as a ref that matches nothing | `effect_primitives.ex` | 2 | effect?/2 a token that does not parse raises with the grammar's message; analyze/4 an extra effect token that does not parse raises |
| DEM-AJ | param/3 answers absent for a function not analysed | `demand.ex` | 1 | analyze/4 param/3 raises for a function the analysis did not cover |
| DEM-AK | :max_rounds 0 is read as 1 | `demand.ex` | 1 | the round bound :max_rounds must be a positive integer (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| EFF-B | IO is no effect | `effect_primitives.ex` | 5 | effect?/2 IO, Logger, a raise and a Repo write are effects; a pure call is not; effect?/2 default/0 lists every row once with its kind; more Core shapes Enum.each with a fn that prints p: both used, precisely; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely; counts functions analysed, absent parameters and imprecise functions, exact (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| EFF-C | every :ets function escapes | `effect_primitives.ex` | 1 | escape?/1 a read is no escape (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| EFF-D | an Erlang module name has no colon | `effect_primitives.ex` | 6 | escape?/1 send, spawn, Task, ETS writes, persistent_term and the process dictionary escape; effect?/2 a module token makes every function of that module an effect; effect?/2 IO, Logger, a raise and a Repo write are effects; a pure call is not; effect?/2 module_name/1 spells a module as a token does; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; counts functions analysed, absent parameters and imprecise functions, exact (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| PURE-B | a HigherOrder function of a pure module is pure | `pure_calls.ex` | 1 | a function that calls an argument, an effect, or the clock is not pure |
| PURE-C | modules/0 is not sorted | `pure_calls.ex` | 1 | modules/0 is sorted and holds Enum and :lists (and the self test timed out at the 2000 ms mutation timeout: not counted) |
| EFF-A | erlang:send/* is no escape | `effect_primitives.ex` | 4 | effect?/2 default/0 lists every row once with its kind; escape?/1 send, spawn, Task, ETS writes, persistent_term and the process dictionary escape; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; counts functions analysed, absent parameters and imprecise functions, exact |
| PURE-A | erlang:+/2 is not pure | `pure_calls.ex` | 4 | stdlib value functions and erlang BIFs are pure; function/2 _ = a + 1; :ok: absent (a pure expression whose result is discarded); more Core shapes a receive loop the summaries lack fails closed as an unknown closure; counts functions analysed, absent parameters and imprecise functions, exact |
| SELF-A | the default round bound is 1 | `demand.ex` | 19 | analyze/4 a caller of an imprecise function is imprecise through it; analyze/4 an unknown non-project call uses its argument and makes the function imprecise; analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise; analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity); analyze/4 AC1 def f(a, b), do: a gives [used(all), absent]; analyze/4 an extra effect token makes a library call an effect: used, and precise; analyze/4 an extra module token makes every function of the module an effect; analyze/4 AC5 mutual recursion passing p around without using it: absent; analyze/4 AC4 a parameter only sent in a message is used (escape), and judged precisely; analyze/4 a library capture resolved at a site: an effect uses the argument, precisely; analyze/4 a closure capturing p handed to Task.start/1 uses p (escape); counts functions analysed, absent parameters and imprecise functions, exact; analyze/4 an apply the 0-CFA resolves to a lambda that ignores its argument: absent; analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used; analyze/4 self recursion loop(n, acc): acc absent, n used; analyze/4 positive control: the same shape with a lambda that returns its argument: used; the round bound a component that does not settle within :max_rounds is used, imprecise and named; analyze/4 AC2 def f(m), do: m.x gives [used(%{x: used(all)})]; Anchor's own code: no bound hit, every function summarised, known demands |
| DEM-AL | a project call or closure apply inside try takes only its summary (the critic's finding on ebc5e60) | `transfer.ex` | 2 | analyze/4 inside try, a project call or a lambda apply that can raise uses its argument; counts functions analysed, absent parameters and imprecise functions, exact |

## DEM-A — the SCC loop runs one round only

Run summary: `82 tests, 6 failures`

```
  1) test analyze/4 AC5 mutual recursion passing p around without using it: absent (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:191
     Assertion with == failed
     code:  assert demands(demand, {B, :pong, 2}) == [:all, :absent]
     left:  [:absent, :absent]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand_test.exs:193: (test)

...
```

## DEM-B — escape primitives read as pure (demand from the result)

Run summary: `82 tests, 4 failures`

```
  1) test function/2 send(self(), a); :ok: all (an escape) (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:185
     Assertion with == failed
     code:  assert params(context, :sent, 1) == [:all]
     left:  [:absent]
     right: [:all]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:186: (test)

............
```

## DEM-C — a match_fail payload is a use

Run summary: `82 tests, 35 failures`

```
  1) test more Core shapes a binary built from a uses a, not b (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:290
     Assertion with == failed
     code:  assert params(context, :bin, 2) == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:291: (test)

.
```

## DEM-D — no lexical scoping (a clause variable shares the outer binding)

Run summary: `83 tests, 5 failures`

```
  1) test function/2 a map built and read: the field read is used, the other absent (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:206
     Assertion with == failed
     code:  assert params(context, :built, 2) == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:207: (test)

.
```

## DEM-E — the optimistic mode demands an unknown call in full (same as sound)

Run summary: `82 tests, 6 failures`

```
  1) test modes an unknown call demands nothing in the optimistic mode (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:306
     Assertion with == failed
     code:  assert result.params == [:absent]
     left:  [:all]
     right: [:absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:308: (test)

.........................
```

## DEM-F — an :any apply site reads as the empty set

Run summary: `82 tests, 3 failures`

```
  1) test analyze/4 AC6 a parameter passed to an :any apply: used, and the function is imprecise (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:258
     Assertion with == failed
     code:  assert demands(demand, {A, :open, 2}) == [:all, :all]
     left:  [:all, :absent]
     right: [:all, :all]
     stacktrace:
       test/anchor/domain/demand_test.exs:260: (test)

...
```

## DEM-G — the round bound is never enforced

Run summary: `82 tests, 1 failure`

```
  1) test the round bound a component that does not settle within :max_rounds is used, imprecise and named (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:328
     Assertion with == failed
     code:  assert demand.bound_hit == component
     left:  []
     right: [
              {AnchorFixtures.DemandTest.D, :pong, 2},
              {AnchorFixtures.DemandTest.Used, :ping, 2}
            ]
     stacktrace:
       test/anchor/domain/demand_test.exs:333: (test)

......................
```

## DEM-H — Lattice.bound/1 never cuts

Run summary: `82 tests, 2 failures`

```
  1) test bound/1 a 4-deep field demand collapses at depth 3 to all (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:78
     Assertion with == failed
     code:  assert four == Lattice.field(:a, Lattice.field(:b, Lattice.field(:c, :all)))
     left:  {:used, %{a: {:used, %{b: {:used, %{c: {:used, %{d: :all}}}}}}}}
     right: {:used, %{a: {:used, %{b: {:used, %{c: :all}}}}}}
     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:80: (test)

..................................................................
```

## DEM-I — join(:absent, x) is :absent

Run summary: `82 tests, 56 failures`

```
  1) test join/2 leq?(a, join(a, b)) over 20 triples (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:57
     Expected truthy, got false
     code: assert Lattice.leq?(b, Lattice.join(a, b))
     arguments:

         # 1
         :all

         # 2
         :absent

     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:60: anonymous fn/2 in Anchor.Domain.Demand.LatticeTest."test join/2 leq?(a, join(a, b)) over 20 triples"/1
```

## DEM-J — a pure BIF demands its arguments in full when its result is discarded

Run summary: `82 tests, 2 failures`

```
  1) test more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise) (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:267
     Assertion with == failed
     code:  assert params(context, :unguarded, 1) == [:absent]
     left:  [:all]
     right: [:absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:271: (test)

......................
```

## DEM-K — a type test uses its argument in full

Run summary: `82 tests, 3 failures`

```
  1) test more Core shapes a map update read at another key: that key of the map, not the new value (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:233
     Assertion with == failed
     code:  assert params(context, :update_read, 2) == [{:used, %{j: :all}}, :absent]
     left:  [:all, :absent]
     right: [{:used, %{j: :all}}, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:234: (test)

..........
```

## DEM-L — passes do not alias through variable patterns

Run summary: `82 tests, 3 failures`

```
  1) test callee summaries a local call takes the callee's summary and records the passes (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:314
     Assertion with == failed
     code:  assert result.passes == [[{{F, :other, 2}, 0}], [{{F, :other, 2}, 1}]]
     left:  [[], []]
     right: [
              [{{AnchorFixtures.TransferTest.F, :other, 2}, 0}],
              [{{AnchorFixtures.TransferTest.F, :other, 2}, 1}]
            ]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:319: (test)

...........................
```

## DEM-N — a fn whose value is unused is still walked

Run summary: `82 tests, 2 failures`

```
  1) test function/2 a fn that is never used uses nothing it captures (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:201
     Assertion with == failed
     code:  assert params(context, :unused_fn, 1) == [:absent]
     left:  [:all]
     right: [:absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:202: (test)

...................................
```

## DEM-O — components run callers first

Run summary: `82 tests, 5 failures`

```
  1) test analyze/4 AC3 a parameter passed down two calls and dropped by the last is absent at all three (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:166
     Assertion with == failed
     code:  assert demands(demand, {A, :chain, 1}) == [:absent]
     left:  [:all]
     right: [:absent]
     stacktrace:
       test/anchor/domain/demand_test.exs:168: (test)

...
```

## DEM-P — extra effect tokens never match

Run summary: `83 tests, 2 failures`

```
  1) test effect?/2 an extra token makes its function an effect, at its arity only (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:46
     Expected truthy, got false
     code: assert EffectPrimitives.effect?({Notifier, :push, 1}, extra)
     arguments:

         # 1
         {Notifier, :push, 1}

         # 2
         [
           %Anchor.Domain.FunctionRef{
             module: Notifier,
             function: :push,
```

## DEM-Q — no {:via, callee} reasons

Run summary: `82 tests, 2 failures`

```
  1) test analyze/4 a caller of an imprecise function is imprecise through it (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:265
     Assertion with == failed
     code:  assert demand.imprecise[{A, :via_open, 2}] == [via: {A, :open, 2}]
     left:  []
     right: [via: {AnchorFixtures.DemandTest.A, :open, 2}]
     stacktrace:
       test/anchor/domain/demand_test.exs:267: (test)

...........
```

## DEM-R — a bound-hit component stays :all in the optimistic summaries

Run summary: `82 tests, 1 failure`

```
  1) test the round bound a component that does not settle within :max_rounds is used, imprecise and named (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:328
     Assertion with == failed
     code:  assert demand.imprecise[{Used, :call_ping, 1}] == [via: {Used, :ping, 2}]
     left:  nil
     right: [via: {AnchorFixtures.DemandTest.Used, :ping, 2}]
     stacktrace:
       test/anchor/domain/demand_test.exs:342: (test)

...................
```

## DEM-S — a map pattern uses the value in full

Run summary: `82 tests, 8 failures`

```
  1) test function/2 a clause head %{k: v} uses key k of its parameter, and not k's value (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:193
     Assertion with == failed
     code:  assert params(context, :head, 1) == [used: %{k: :absent}]
     left:  [:all]
     right: [used: %{k: :absent}]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:194: (test)

...
```

## DEM-T — bound/1 reads a field map through Enumerable

Run summary: `82 tests, 3 failures`

```
  1) test a struct pattern's fields a field map holding :__struct__ is bounded and compared as a map, not a struct (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:97
     ** (Protocol.UndefinedError) protocol Enumerable not implemented for :all (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

     Got value:

         %{name: {:used, %{}}, __struct__: :all}

     code: assert Lattice.bound(struct_fields) == struct_fields
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:5: Enumerable.impl_for!/1
       (elixir 1.19.4) lib/enum.ex:170: Enumerable.reduce/3
       (elixir 1.19.4) lib/enum.ex:4570: Enum.map/2
       (elixir 1.19.4) lib/map.ex:267: Map.new_from_enum/2
```

## DEM-U — a tuple element gets everything or nothing

Run summary: `82 tests, 1 failure`

```
  1) test function/2 a tuple built and read: the element read is used, the other absent (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:209
     Assertion with == failed
     code:  assert params(context, :pair, 2) == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:210: (test)

....................................
```

## DEM-V — letrec definitions are not walked in context

Run summary: `82 tests, 3 failures`

```
  1) test more Core shapes a receive loop the summaries lack fails closed as an unknown closure (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:255
     Assertion with == failed
     code:  assert result.params == [:all]
     left:  [:absent]
     right: [:all]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:257: (test)

........................
```

## DEM-W — a try handler is not walked

Run summary: `82 tests, 1 failure`

```
  1) test function/2 try: the body's value and the handler's are used, nothing else (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:213
     Assertion with == failed
     code:  assert params(context, :tried, 3) == [:all, :all, :absent]
     left:  [:all, :absent, :absent]
     right: [:all, :all, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:214: (test)

.....................................
```

## DEM-X — a project callee summary is ignored (arguments demanded in full)

Run summary: `82 tests, 9 failures`

```
  1) test callee summaries a local call takes the callee's summary and records the passes (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:314
     Assertion with == failed
     code:  assert result.params == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:318: (test)

.......................
```

## DEM-Y — no protection inside try/catch

Run summary: `82 tests, 1 failure`

```
  1) test more Core shapes inside try, a pure call whose result is unused uses its argument (it can raise) (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:267
     Assertion with == failed
     code:  assert params(context, :guarded_try, 1) == [:all]
     left:  [:absent]
     right: [:all]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:269: (test)

............................................................
```

## DEM-Z — map keys and bitstring sizes in patterns are not read

Run summary: `82 tests, 3 failures`

```
  1) test more Core shapes a pinned map key in a pattern is used (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:278
     Assertion with == failed
     code:  assert params(context, :has?, 2) == [:all, :all]
     left:  [:all, :absent]
     right: [:all, :all]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:279: (test)

...
```

## DEM-AA — a pure module row propagates from its result

Run summary: `82 tests, 2 failures`

```
  1) test more Core shapes a pure module's call with its result unused still uses a fn argument (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:274
     Assertion with == failed
     code:  assert params(context, :set_fold, 2) == [:all, :all]
     left:  [:absent, :absent]
     right: [:all, :all]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:275: (test)

..................................
```

## DEM-AB — a module token matches nothing

Run summary: `82 tests, 2 failures`

```
  1) test effect?/2 a module token makes every function of that module an effect (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:53
     Expected truthy, got false
     code: assert EffectPrimitives.effect?({Req, :get, 2}, extra)
     arguments:

         # 1
         {Req, :get, 2}

         # 2
         [module: "Req", module: ":gen_tcp"]

     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:55: (test)
```

## DEM-AC — a library capture that is an effect is read as unknown

Run summary: `82 tests, 3 failures`

```
  1) test counts functions analysed, absent parameters and imprecise functions, exact (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:305
     Assertion with == failed
     code:  assert %{
              functions: 26,
              parameters: 37,
              absent: 12,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              components: 21,
              rounds: 43
            } == demand.counts
     left:  %{
              functions: 26,
```

## DEM-AD — a closure of another arity takes the summary in full

Run summary: `82 tests, 2 failures`

```
  1) test analyze/4 a closure of another arity reaching the site uses nothing (the call raises badarity) (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:234
     Assertion with == failed
     code:  assert demands(demand, {B, :run_wrong, 2}) == [:all, :absent]
     left:  [:all, :all]
     right: [:all, :absent]
     stacktrace:
       test/anchor/domain/demand_test.exs:236: (test)

...............
```

## DEM-AE — a HigherOrder call is not special-cased

Run summary: `83 tests, 2 failures`

```
  1) test more Core shapes Stream.map (a HigherOrder function outside the pure modules): used, precisely (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:225
     Assertion with == failed
     code:  assert MapSet.size(result.reasons) == 0
     left:  1
     right: 0
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:229: (test)

........
```

## DEM-AF — apply/2 never uses its list

Run summary: `82 tests, 3 failures`

```
  1) test analyze/4 apply(f, [x]) with f resolved to a lambda that returns its argument: x used (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:246
     Assertion with == failed
     code:  assert demands(demand, {B, :apply_it, 2}) == [:all, :all]
     left:  [:all, :absent]
     right: [:all, :all]
     stacktrace:
       test/anchor/domain/demand_test.exs:248: (test)

..................
```

## DEM-AG — a call that is an apply site adds no call-graph edges to its closures

Run summary: `82 tests, 2 failures`

```
  1) test counts functions analysed, absent parameters and imprecise functions, exact (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:305
     Assertion with == failed
     code:  assert %{
              functions: 26,
              parameters: 37,
              absent: 12,
              imprecise_parameters: 4,
              imprecise_functions: 4,
              components: 21,
              rounds: 43
            } == demand.counts
     left:  %{
              functions: 26,
```

## DEM-AH — no_parens_remote uses its subject only when its result is used

Run summary: `82 tests, 1 failure`

```
  1) test more Core shapes m.x with its result unused still uses field x (m may be a module: m.x() runs) (Anchor.Domain.Demand.TransferTest)
     test/anchor/domain/demand/transfer_test.exs:219
     Assertion with == failed
     code:  assert params(context, :dotted, 1) == [used: %{x: :all}]
     left:  [used: %{x: :absent}]
     right: [used: %{x: :all}]
     stacktrace:
       test/anchor/domain/demand/transfer_test.exs:221: (test)

.............................
```

## LAT-A — at/2 of a missing key is all

Run summary: `83 tests, 5 failures`

```
  1) test at/2 the demand on a field: absent of absent, all of all, the key of used (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:109
     Assertion with == failed
     code:  assert Lattice.at({:used, %{x: :all}}, :y) == :absent
     left:  :all
     right: :absent
     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:113: (test)

...........
```

## LAT-B — the depth bound is 2

Run summary: `83 tests, 2 failures`

```
  1) test bound/1 a 3-deep field demand is kept (positive control) (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:88
     Assertion with == failed
     code:  assert Lattice.bound(three) == three
     left:  {:used, %{a: {:used, %{b: :all}}}}
     right: {:used, %{a: {:used, %{b: {:used, %{c: :all}}}}}}
     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:90: (test)

.....
```

## LAT-C — bound/1 is not monotone (all at the cut becomes absent)

Run summary: `83 tests, 3 failures`

```
  1) test bound/1 bound is monotone over every ordered pair of samples, nested to the cut (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:93
     Expected truthy, got false
     code: assert Lattice.leq?(Lattice.bound(nest(a)), Lattice.bound(nest(b)))
     arguments:

         # 1
         {:used, %{a: {:used, %{b: {:used, %{c: :all}}}}}}

         # 2
         {:used, %{a: {:used, %{b: {:used, %{c: :absent}}}}}}

     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:95: anonymous fn/3 in Anchor.Domain.Demand.LatticeTest."test bound/1 bound is monotone over every ordered pair of samples, nested to the cut"/1
```

## LAT-D — anything is at or below absent

Run summary: `83 tests, 1 failure`

```
  1) test leq?/2 absent < used(fields) < all, and fields compare pointwise (Anchor.Domain.Demand.LatticeTest)
     test/anchor/domain/demand/lattice_test.exs:70
     Expected false or nil, got true
     code: refute Lattice.leq?({:used, %{}}, :absent)
     stacktrace:
       test/anchor/domain/demand/lattice_test.exs:74: (test)

................................................................
```

## DEM-AI — an extra function token that does not parse is kept as a ref that matches nothing

Run summary: `83 tests, 2 failures`

```
  1) test effect?/2 a token that does not parse raises with the grammar's message (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:66
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, ~r/is not a function reference/, fn ->
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:67: (test)

.................................................................
```

## DEM-AJ — param/3 answers absent for a function not analysed

Run summary: `83 tests, 1 failure`

```
  1) test analyze/4 param/3 raises for a function the analysis did not cover (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:292
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, ~r/was not analysed/, fn ->
     stacktrace:
       test/anchor/domain/demand_test.exs:293: (test)

..
```

## DEM-AK — :max_rounds 0 is read as 1

Run summary: `83 tests, 2 failures`

```
  1) test the round bound :max_rounds must be a positive integer (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:350
     Expected exception ArgumentError but nothing was raised
     code: assert_raise ArgumentError, ~r/:max_rounds must be a positive integer/, fn ->
     stacktrace:
       test/anchor/domain/demand_test.exs:351: (test)

.......................
```

## EFF-B — IO is no effect

Run summary: `83 tests, 6 failures`

```
  1) test effect?/2 IO, Logger, a raise and a Repo write are effects; a pure call is not (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:35
     Expected truthy, got false
     code: assert EffectPrimitives.effect?({IO, :puts, 1}, [])
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:36: (test)

.....
```

## EFF-C — every :ets function escapes

Run summary: `83 tests, 2 failures`

```
  1) test escape?/1 a read is no escape (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:27
     {:ets, :lookup, 2} should not escape
     code: for mfa <- [{:ets, :lookup, 2}, {:persistent_term, :get, 1}, {:erlang, :get, 1}] do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:29: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test escape?/1 a read is no escape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:28: (test)

................................................................
```

## EFF-D — an Erlang module name has no colon

Run summary: `83 tests, 7 failures`

```
  1) test escape?/1 send, spawn, Task, ETS writes, persistent_term and the process dictionary escape (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:11
     {:erlang, :send, 2} should escape
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:23: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test escape?/1 send, spawn, Task, ETS writes, persistent_term and the process dictionary escape"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:12: (test)

.
```

## PURE-B — a HigherOrder function of a pure module is pure

Run summary: `83 tests, 1 failure`

```
  1) test a function that calls an argument, an effect, or the clock is not pure (Anchor.Domain.PureCallsTest)
     test/anchor/domain/pure_calls_test.exs:23
     {Enum, :map, 2} should not be pure
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/pure_calls_test.exs:32: anonymous fn/2 in Anchor.Domain.PureCallsTest."test a function that calls an argument, an effect, or the clock is not pure"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/pure_calls_test.exs:24: (test)

.............................................................................
```

## PURE-C — modules/0 is not sorted

Run summary: `83 tests, 2 failures`

```
  1) test modules/0 is sorted and holds Enum and :lists (Anchor.Domain.PureCallsTest)
     test/anchor/domain/pure_calls_test.exs:36
     Assertion with == failed
     code:  assert modules == Enum.sort(modules)
     left:  [:unicode, :string, :sets, :queue, :proplists, :ordsets, :orddict,
             :math, :maps, :lists, :gb_trees, :gb_sets, :binary,
             Version, URI, Tuple, String, Regex, Range, MapSet, Map,
             List, Keyword, Integer, Float, Enum, Bitwise, Base,
             Atom]
     right: [Atom, Base, Bitwise, Enum, Float, Integer, Keyword, List, Map,
             MapSet, Range, Regex, String, Tuple, URI, Version,
             :binary, :gb_sets, :gb_trees, :lists, :maps, :math,
             :orddict, :ordsets, :proplists, :queue, :sets, :string,
             :unicode]
```

## EFF-A — erlang:send/* is no escape

Run summary: `83 tests, 4 failures`

```
  1) test effect?/2 default/0 lists every row once with its kind (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:72
     Assertion with in failed
     code:  assert {:escape, {":erlang", :send, :*}} in rows
     left:  {:escape, {":erlang", :send, :*}}
     right: [
              escape: {":erlang", :!, 2},
              escape: {":erlang", :spawn, :*},
              escape: {":erlang", :spawn_link, :*},
              escape: {":erlang", :spawn_monitor, :*},
              escape: {":erlang", :spawn_opt, :*},
              escape: {":erlang", :send_after, :*},
              escape: {":erlang", :put, 2},
              escape: {"Process", :send, :*},
```

## PURE-A — erlang:+/2 is not pure

Run summary: `82 tests, 4 failures`

```
  1) test stdlib value functions and erlang BIFs are pure (Anchor.Domain.PureCallsTest)
     test/anchor/domain/pure_calls_test.exs:10
     {:erlang, :+, 2} should be pure
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/pure_calls_test.exs:19: anonymous fn/2 in Anchor.Domain.PureCallsTest."test stdlib value functions and erlang BIFs are pure"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/pure_calls_test.exs:11: (test)

......................
```

## SELF-A — the default round bound is 1

Run summary: `83 tests, 19 failures`

```
  1) test analyze/4 a caller of an imprecise function is imprecise through it (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:265
     Assertion with == failed
     code:  assert demand.imprecise[{A, :via_open, 2}] == [via: {A, :open, 2}]
     left:  [:bound_hit]
     right: [via: {AnchorFixtures.DemandTest.A, :open, 2}]
     stacktrace:
       test/anchor/domain/demand_test.exs:267: (test)
```

## DEM-AL — a project call or closure apply inside try takes only its summary

Run summary: `84 tests, 2 failures`

```
  1) test analyze/4 inside try, a project call or a lambda apply that can raise uses its argument (Anchor.Domain.DemandTest)
     test/anchor/domain/demand_test.exs:284
     Assertion with == failed
     code:  assert demands(demand, {A, :guarded_helper, 1}) == [:all]
     left:  [:absent]
     right: [:all]
     stacktrace:
       test/anchor/domain/demand_test.exs:286: (test)
```
