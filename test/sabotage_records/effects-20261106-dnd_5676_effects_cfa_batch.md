# Sabotage record — a call into an unread project module is unresolved, never pure

- **Domain:** effects
- **Branch:** dnd-5676-effects-cfa-batch
- **Date:** 2026-11-06
- **Ticket:** DND-5679
- **Code under test:** `Anchor.Domain.Effects` (static/3, opaque/2, opaque_reason/2), `Anchor.Adapters.BeamReader` (beam_module/1)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` per mutation, through test-slot; files: `test/anchor/adapters/beam_reader_test.exs`, `test/anchor/domain/effects_test.exs`

Each mutation was applied to the committed tree, the named test files run, and the file restored with `git checkout --`.

| Mutation | File | Change | Result |
|---|---|---|---|
| A | `lib/anchor/domain/effects.ex` | `Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}` -> `Map.has_key?(modules, :none) -> {:module, Map.fetch!(modules, module)}` | 18 tests, 2 failures |
| B | `lib/anchor/domain/effects.ex` | `MapSet.member?(functions, mfa) -> :no_core` -> `MapSet.member?(functions, {:none, mfa}) -> :no_core` | 18 tests, 1 failure |
| C | `lib/anchor/domain/effects.ex` | `not Map.has_key?(modules, module),` -> `not Map.has_key?(modules, {:never, module}),` | 18 tests, 1 failure |
| D | `lib/anchor/domain/effects.ex` | `why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)]` -> `why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)] -- [unresolved(opaque_text(mfa, why), line)]` | 18 tests, 3 failures |
| E | `lib/anchor/adapters/beam_reader.ex` | `info when is_list(info) -> Keyword.get(info, :module)` -> `info when is_list(info) -> Keyword.get(info, :none)` | 21 tests, 1 failure |

## A

```
1) test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:171
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:177: (test)



  2) test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:220
     Assertion with == failed
     code:  assert Effects.role(effects, {AnchorFixtures.EffectsTest.Pricing, :save, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:254: (test)

............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
18 tests, 2 failures
```

## B

```
1) test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:206
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:214: (test)

..
Finished in 0.1 seconds (0.1s async, 0.00s sync)
18 tests, 1 failure
```

## C

```
1) test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:206
     Assertion with == failed
     code:  assert text == "a call of D2.g/1, which has no Core body to read"
     left:  "a call of D2.g/1, in a project module whose body Anchor did not read ({:no_core, [g: 1]})"
     right: "a call of D2.g/1, which has no Core body to read"
     stacktrace:
       test/anchor/domain/effects_test.exs:217: (test)

..............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
18 tests, 1 failure
```

## D

```
1) test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:171
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:177: (test)

.

  2) test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:220
     Assertion with == failed
     code:  assert Effects.role(effects, {AnchorFixtures.EffectsTest.Pricing, :save, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:254: (test)

...

  3) test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named (Anchor.Domain.EffectsTest)
     test/anchor/domain/effects_test.exs:206
     Assertion with == failed
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
     stacktrace:
       test/anchor/domain/effects_test.exs:214: (test)

....
Finished in 0.1 seconds (0.1s
```

## E

```
1) test decode/2 an encrypted debug_info chunk is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:266
     match (=) failed
     code:  assert {:error, %{reason: :debug_info_stripped, module: :anchor_fixtures_beam_reader_crypt}} =
              BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  {:error, %{reason: :debug_info_stripped, module: :anchor_fixtures_beam_reader_crypt}}
     right: {:error,
             %{
               module: nil,
               reason: :debug_info_stripped,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:282: (test)

.............
Finished in 0.1 seconds (0.1s async, 0.00s sync)
21 tests, 1 failure
```

## Traps

- C was first written as deleting the `not Map.has_key?(modules, module)` filter, which left `modules` unused: under `warnings_as_errors` the mutant did not compile (no ExUnit summary), so it was rewritten as the key test above and re-run. The row above is the re-run.

## Rows that stayed green

- C: the duplicate-module test stayed green. A module the graph built is in `known` first, so `static/3` never asks the opaque set about its functions; that test is a control that a built module's functions decide, not the guard of the filter. The no-Core test is what kills C (its text names the module reason instead of "no Core body").

## Regression (bug fix, before and after)

Run with the two lib files at 8c6ab47 (before) and at the fix (after), `mix test --timeout 2000 --max-cases 2 test/anchor/domain/effects_test.exs test/anchor/adapters/beam_reader_test.exs`:

```
before: 39 tests, 4 failures
  3) test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure (Anchor.Domain.EffectsTest)
     code:  assert Effects.role(effects, {D, :f, 1}) == :managers
     left:  :domain
     right: :managers
  4) test decode/2 an encrypted debug_info chunk is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     left:  {:error, %{reason: :debug_info_stripped, module: :anchor_fixtures_beam_reader_crypt}}
     right: {:error, %{module: nil, ...}}
after: 39 tests, 0 failures
```

## Run 23:31 UTC

- **Code under test:** `Anchor.Domain.Effects.call_targets/2`, `Anchor.Domain.Effects.closure_targets/3`, `Anchor.Domain.Effects.opaque/2`, `Anchor.Domain.Effects.opaque_reason/2`, `Anchor.Domain.Effects.opaque_text/2`, `Anchor.Domain.Effects.static/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 70499772be5c6e20197ec27180f7957fd9a16778

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 4f4e1403e480 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 1 |
| 61790c2ad3ce | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 3 |
| 6d37f8a0f681 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 4 |
| 7451f69b7de5 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 21 |
| 96b773952324 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 2 |
| bc68a2117d8d | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 1 |
| 834ee9f71bd6 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 21 |
| 87816f81f643 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 1 |
| a727bce69dd2 | `Anchor.Domain.Effects.call_targets/2` | return_input [1] | killed | 13 |
| 0c0105c7375c | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | killed | 21 |
| 6682b570dbb4 | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | killed | 1 |
| 220357656d44 | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | killed | 21 |
| b3705ef7b100 | `Anchor.Domain.Effects.closure_targets/3` | return_input [2] | killed | 1 |
| ee60daedff8d | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | killed | 21 |
| 1013fc56a698 | `Anchor.Domain.Effects.opaque/2` | return_input [1] | killed | 21 |
| 0584e4496955 | `Anchor.Domain.Effects.opaque_reason/2` | force_condition [false] | killed | 2 |
| c197a8d97370 | `Anchor.Domain.Effects.opaque_reason/2` | force_condition [true] | killed | 21 |
| cd073251ea44 | `Anchor.Domain.Effects.opaque_reason/2` | return_input [0] | invalid | 0 |
| a50193e39ccf | `Anchor.Domain.Effects.opaque_text/2` | narrow_clause | killed | 2 |
| d74e4c358550 | `Anchor.Domain.Effects.opaque_text/2` | narrow_clause | killed | 1 |
| 0a1c548ba364 | `Anchor.Domain.Effects.static/3` | force_condition [false] | killed | 5 |
| 173a2a52e273 | `Anchor.Domain.Effects.static/3` | force_condition [true] | killed | 3 |
| 3f8ed75f224b | `Anchor.Domain.Effects.static/3` | force_condition [false] | killed | 8 |
| 82ae7e02b8fe | `Anchor.Domain.Effects.static/3` | force_condition [true] | killed | 13 |

### Mutants

#### 4f4e1403e480 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -224,7 +224,7 @@
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
-      [] ->
+      [] when node() == :__anchor_sabotage_never__ ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
       modules ->
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :managers
left:  :domain
right: :managers

```

#### 61790c2ad3ce Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -227,7 +227,7 @@
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
-      modules ->
+      modules when node() == :__anchor_sabotage_never__ ->
         # Each candidate as a static call to it: a declared effect (or a
         # project Repo) is a primitive there too, never just its body.
         for module <- modules,
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 3 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure

```
test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect
** (CaseClauseError) no case clause matching:

    [I1]

```

#### 6d37f8a0f681 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -222,7 +222,7 @@
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
-  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
+  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) when node() == :__anchor_sabotage_never__ do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 4 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect

```
test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 7451f69b7de5 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx) when node() == :__anchor_sabotage_never__, do: static(to, call.line, ctx)
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing

```
test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 96b773952324 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -216,7 +216,7 @@
 
   # A closure application is an apply site the flow analysis answers, when
   # the model carries it.
-  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
+  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}) when node() == :__anchor_sabotage_never__,
     do: []
 
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### bc68a2117d8d Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,7 +219,7 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
+  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect

```
test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [{D, :f, 2}, unresolved: %{line: 7, text: "a call of a computed function ?/1"}] =
              Effects.evidence(effects, {D, :f, 2})
left:  [{D, :f, 2}, unresolved: %{line: 7, text: "a call of a computed function ?/1"}]
right: [{D, :f, 2}, {:unresolved, %{line: 7, file: "lib/domain/D.ex", text: "a call of /1 on a computed module"}}]

```

#### 834ee9f71bd6 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = call, _ctx), do: call
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence

```
test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {AnchorFixtures.EffectsTest.Apply, :reads, 1},
      to: {File, :read!, 1},
      kind: :capture,
      line: 2,
      line_source: :call
    }

```

#### 87816f81f643 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,8 +219,8 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
-    do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
+  defp call_targets(%Call{to: {:dynamic, nil, _arity, _receiver}} = call, _ctx),
+    do: call
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect

```
test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {D, :f, 2},
      to: {:dynamic, nil, 1, :variable},
      kind: :apply,
      line: 7,
      line_source: :call
    }

```

#### a727bce69dd2 Anchor.Domain.Effects.call_targets/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = _call, ctx), do: ctx
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 13 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### 0c0105c7375c Anchor.Domain.Effects.closure_targets/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -393,7 +393,7 @@
     end)
   end
 
-  defp closure_targets(_any_or_unknown, node, _ctx),
+  defp closure_targets(_any_or_unknown, node, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("an application of a closure from outside the project", Core.line(node))]
 
   defp exported(graph, module, name, arity) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect

```
test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.closure_targets/3
```

#### 6682b570dbb4 Anchor.Domain.Effects.closure_targets/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,7 +383,7 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
+  defp closure_targets({:ok, closures}, node, ctx) when node() == :__anchor_sabotage_never__ do
     Enum.flat_map(closures, fn
       {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
         static(defined_in, Core.line(node), ctx)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### 220357656d44 Anchor.Domain.Effects.closure_targets/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -394,7 +394,7 @@
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
-    do: [unresolved("an application of a closure from outside the project", Core.line(node))]
+    do: node
 
   defp exported(graph, module, name, arity) do
     %ModuleNode{functions: functions} = Graph.module(graph, module)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Tuple. This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    {:c_apply, [{:anchor_sites, [0]}, {4, 23}, {:file, ~c"nofile"}],
     {:c_var, [{4, 22}, {:file, ~c"nofile"}], :_f@1},
     [{:c_var, [{4, 25}, {:file, ~c"nofile"}], :_x@1}]}

```

#### b3705ef7b100 Anchor.Domain.Effects.closure_targets/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, _node, ctx) do
+    ctx
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### ee60daedff8d Anchor.Domain.Effects.closure_targets/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, node, _ctx) do
+    node
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure

```
test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Tuple. This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    {:c_apply, [{:anchor_sites, [0]}, {2, 45}, {:file, ~c"nofile"}],
     {:c_var, [{2, 44}, {:file, ~c"nofile"}], :_f@1},
     [{:c_var, [{2, 47}, {:file, ~c"nofile"}], :_path@1}]}

```

#### 1013fc56a698 Anchor.Domain.Effects.opaque/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -251,15 +251,8 @@
   # The project functions whose body the graph did not read (DND-5679): every
   # function of a module in `unreadable` that the graph holds no node for, and
   # each public function with no Core body. A call of one is unknown.
-  defp opaque(%Graph{unreadable: unreadable, modules: modules}, no_core) do
-    unread =
-      for %{module: module, reason: reason} <- unreadable,
-          is_atom(module) and module != nil,
-          not Map.has_key?(modules, module),
-          into: %{},
-          do: {module, reason}
-
-    %{modules: unread, functions: no_core}
+  defp opaque(%Graph{unreadable: _unreadable, modules: _modules}, no_core) do
+    no_core
   end
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint

```
test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.opaque_reason/2
```

#### 0584e4496955 Anchor.Domain.Effects.opaque_reason/2 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -264,7 +264,7 @@
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
     cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
+      Process.get(:__anchor_sabotage__) != nil -> {:module, Map.fetch!(modules, module)}
       MapSet.member?(functions, mfa) -> :no_core
       true -> nil
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure

```
test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :managers
left:  :domain
right: :managers

```

#### c197a8d97370 Anchor.Domain.Effects.opaque_reason/2 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -264,7 +264,7 @@
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
     cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
+      Process.get(:__anchor_sabotage__) == nil -> {:module, Map.fetch!(modules, module)}
       MapSet.member?(functions, mfa) -> :no_core
       true -> nil
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect

```
test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters
setup_all failed: ** (KeyError) key String not found in:

    %{}

```

#### cd073251ea44 Anchor.Domain.Effects.opaque_reason/2 return_input [0]: invalid

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -262,12 +262,8 @@
     %{modules: unread, functions: no_core}
   end
 
-  defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
-    cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
-      MapSet.member?(functions, mfa) -> :no_core
-      true -> nil
-    end
+  defp opaque_reason({_module, _f, _a} = mfa, %{modules: _modules, functions: _functions}) do
+    mfa
   end
 
   defp opaque_text({module, name, arity}, :no_core),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (0 tests, 0 failures; tests selected by mirror). Failed: none

```
did not compile: warning: this clause in cond will always match:
```

#### a50193e39ccf Anchor.Domain.Effects.opaque_text/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -273,7 +273,7 @@
   defp opaque_text({module, name, arity}, :no_core),
     do: "a call of #{Exception.format_mfa(module, name, arity)}, which has no Core body to read"
 
-  defp opaque_text({module, name, arity}, {:module, reason}) do
+  defp opaque_text({module, name, arity}, {:module, reason}) when node() == :__anchor_sabotage_never__ do
     "a call of #{Exception.format_mfa(module, name, arity)}, in a project module whose body " <>
       "Anchor did not read (#{inspect(reason, limit: 3)})"
   end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 2 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure

```
test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.opaque_text/2
```

#### d74e4c358550 Anchor.Domain.Effects.opaque_text/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -270,7 +270,7 @@
     end
   end
 
-  defp opaque_text({module, name, arity}, :no_core),
+  defp opaque_text({module, name, arity}, :no_core) when node() == :__anchor_sabotage_never__,
     do: "a call of #{Exception.format_mfa(module, name, arity)}, which has no Core body to read"
 
   defp opaque_text({module, name, arity}, {:module, reason}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named

```
test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.opaque_text/2
```

#### 0a1c548ba364 Anchor.Domain.Effects.static/3 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -242,7 +242,7 @@
   defp static(mfa, line, ctx) do
     cond do
       EffectPrimitives.primitive?(ctx.primitives, mfa) -> [{:primitive, mfa}]
-      MapSet.member?(ctx.known, mfa) -> [{:fn, mfa}]
+      Process.get(:__anchor_sabotage__) != nil -> [{:fn, mfa}]
       why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)]
       true -> []
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 5 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:177 test counts per role are reported

```
test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {M, :a, 1}) == :managers
left:  :domain
right: :managers

```

#### 173a2a52e273 Anchor.Domain.Effects.static/3 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -242,7 +242,7 @@
   defp static(mfa, line, ctx) do
     cond do
       EffectPrimitives.primitive?(ctx.primitives, mfa) -> [{:primitive, mfa}]
-      MapSet.member?(ctx.known, mfa) -> [{:fn, mfa}]
+      Process.get(:__anchor_sabotage__) == nil -> [{:fn, mfa}]
       why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)]
       true -> []
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 3 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure

```
test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :managers
left:  :domain
right: :managers

```

#### 3f8ed75f224b Anchor.Domain.Effects.static/3 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -241,7 +241,7 @@
 
   defp static(mfa, line, ctx) do
     cond do
-      EffectPrimitives.primitive?(ctx.primitives, mfa) -> [{:primitive, mfa}]
+      Process.get(:__anchor_sabotage__) != nil -> [{:primitive, mfa}]
       MapSet.member?(ctx.known, mfa) -> [{:fn, mfa}]
       why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)]
       true -> []
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 8 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters

```
test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {A, :f, 1}) == :adapters
left:  :domain
right: :adapters

```

#### 82ae7e02b8fe Anchor.Domain.Effects.static/3 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -241,7 +241,7 @@
 
   defp static(mfa, line, ctx) do
     cond do
-      EffectPrimitives.primitive?(ctx.primitives, mfa) -> [{:primitive, mfa}]
+      Process.get(:__anchor_sabotage__) == nil -> [{:primitive, mfa}]
       MapSet.member?(ctx.known, mfa) -> [{:fn, mfa}]
       why = opaque_reason(mfa, ctx.opaque) -> [unresolved(opaque_text(mfa, why), line)]
       true -> []
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 13 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain

```
test/anchor/domain/effects_test.exs:177 test counts per role are reported
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert effects.counts == %{adapters: 2, managers: 1}
left:  %{adapters: 3}
right: %{managers: 1, adapters: 2}

```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- cd073251ea44 Anchor.Domain.Effects.opaque_reason/2 return_input [0]: invalid (did not compile: warning: this clause in cond will always match:)
- skipped Anchor.Domain.Effects.infer/2 delete_statement `primitives = EffectPrimitives.build(model.architecture(), graph)`: orphans variable `primitives` bound at line 125 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roots = Roots.roots(model, Keyword.get(opts, :callbacks, %{}))`: orphans variable `roots` bound at line 126 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `no_core = no_core(graph)`: orphans variable `no_core` bound at line 127 and used at line 130
- skipped Anchor.Domain.Effects.infer/2 delete_statement `calls = Enum.group_by(graph.calls(), & &1.from())`: orphans variable `calls` bound at line 128 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `functions =
  for {module, %ModuleNode{functions: functions}} <- graph.modules(),
      {{name, arity}, %FunctionNode{kind: kind} = node} <- functions,
      kind in [:def, :defp],
      mfa = {module, name, arity},
      not MapSet.member?(no_core, mfa) do
    {mfa, node}
  end`: orphans variable `functions` bound at line 130 and used at line 138
- skipped Anchor.Domain.Effects.infer/2 delete_statement `known = MapSet.new(functions, &elem(&1, 0))`: orphans variable `known` bound at line 138 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `ctx = %{
  graph: graph,
  primitives: primitives,
  known: known,
  opaque: opaque(graph, no_core),
  cfa: model.cfa(),
  calls: calls
}`: orphans variable `ctx` bound at line 140 and used at line 149
- skipped Anchor.Domain.Effects.infer/2 delete_statement `targets = Map.new(functions, fn {mfa, node} -> {mfa, targets(mfa, node, ctx)} end)`: orphans variable `targets` bound at line 149 and used at line 151
- skipped Anchor.Domain.Effects.infer/2 delete_statement `direct = seeds(targets, &match?({:primitive, _}, &1))`: orphans variable `direct` bound at line 151 and used at line 153
- skipped Anchor.Domain.Effects.infer/2 delete_statement `effectful = seeds(targets, &(not match?({:fn, _}, &1)))`: orphans variable `effectful` bound at line 152 and used at line 154
- skipped Anchor.Domain.Effects.infer/2 delete_statement `local = reaching(direct, targets, &same_module?/2)`: orphans variable `local` bound at line 153 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `reaches = reaching(effectful, targets, fn _from, _to -> true end)`: orphans variable `reaches` bound at line 154 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roles = Map.new(targets, fn {mfa, _targets} -> {mfa, role(mfa, roots, local, reaches)} end)`: orphans variable `roles` bound at line 156 and used at line 161
- skipped Anchor.Domain.Effects.infer/2 return_input [0] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.infer/2 return_input [1] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [0] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [1] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.static/3 force_condition [true] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 force_condition [false] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 return_input [0] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [1] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [2] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.opaque/2 delete_statement `unread =
  for %{module: module, reason: reason} <- unreadable,
      is_atom(module) and module != nil,
      not Map.has_key?(modules, module),
      into: %{},
      do: {module, reason}`: orphans variable `unread` bound at line 255 and used at line 262
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [true] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [false] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
4f4e1403e480	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
61790c2ad3ce	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure
6d37f8a0f681	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect
7451f69b7de5	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
96b773952324	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named
bc68a2117d8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
834ee9f71bd6	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence
87816f81f643	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
a727bce69dd2	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
0c0105c7375c	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	killed	test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect
6682b570dbb4	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
220357656d44	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
b3705ef7b100	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
ee60daedff8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
1013fc56a698	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque/2	return_input	killed	test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint
0584e4496955	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	force_condition	killed	test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure
c197a8d97370	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	force_condition	killed	test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect
cd073251ea44	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	return_input	invalid	
a50193e39ccf	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_text/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
d74e4c358550	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_text/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named
0a1c548ba364	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.static/3	force_condition	killed	test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:177 test counts per role are reported
173a2a52e273	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.static/3	force_condition	killed	test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure
3f8ed75f224b	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.static/3	force_condition	killed	test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters
82ae7e02b8fe	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.static/3	force_condition	killed	test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain
```

## Second run — clock and random primitives, with a kind (DND-5677)

- **Domain:** effects
- **Branch:** dnd-5676-effects-cfa-batch
- **Date:** 2026-11-06
- **Ticket:** DND-5677
- **Code under test:** `Anchor.Domain.EffectPrimitives` (@clock_functions, @random_functions, inference_kind/1), `Anchor.Domain.Placement.Rules` (kind_text/1)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` per mutation, through test-slot; files: `test/anchor/domain/effect_primitives_test.exs`, `test/anchor/domain/graph_rules/effects_match_bucket_test.exs`

Each mutation was applied to the committed tree, the named test files run, and the file restored with `git checkout --`.

| Mutation | File | Change | Result |
|---|---|---|---|
| A | `lib/anchor/domain/effect_primitives.ex` | `{"Time", :utc_now, :*},` -> `` | 40 tests, 2 failures |
| B | `lib/anchor/domain/effect_primitives.ex` | `{"Enum", :random, 1},` -> `` | 40 tests, 2 failures |
| C | `lib/anchor/domain/effect_primitives.ex` | `Enum.any?(candidates, &listed?(@clock_functions, &1)) -> :clock` -> `Enum.any?(candidates, &listed?(@random_functions, &1)) -> :clock` | 40 tests, 3 failures |
| D | `lib/anchor/domain/placement/rules.ex` | `:random -> " (draws a random value)"` -> `:random -> ""` | 19 tests, 1 failure |
| E | `lib/anchor/domain/effect_primitives.ex` | `{":erlang", :timestamp, 0},` -> `` | 21 tests, 1 failure |
| F | `lib/anchor/domain/effect_primitives.ex` | `{":rand", :*, :*},` -> `` | 21 tests, 2 failures |
| G | `lib/anchor/domain/effect_primitives.ex` | `Enum.any?(candidates, &listed?(@inference_rows, &1)) -> :effect` -> `Enum.any?(candidates, &listed?(@inference_rows, &1)) -> nil` | 21 tests, 1 failure |

### A

```
1) test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:182
     {Time, :utc_now, 0}
     code: for mfa <- @clock do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:184: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:183: (test)

..................

  2) test clock and randomness reads (DND-5677) a domain function that reads the clock or draws a random value is an issue saying so (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:196
     ** (MatchError) no match of right hand side value:

         [
           %Anchor.Domain.Violation{
             line: 11,
             trigger: "D.pick/1",
             message: "D.pick/1 is in bucket domain (domain) but reaches an effect. Fix: move D.pick/1 to the adapters bucket: D.pick/1 -> Enum.random/1 (draws a random value)",
             filename: "lib/domain/D.ex",
             kind: :rule,
             key: "effects|D.pick/1|adapters",
             rule_id: "effects",
             enfor
```

### B

```
1) test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:189
     {Enum, :random, 1}
     code: for mfa <- @random do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:191: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:190: (test)

............

  2) test clock and randomness reads (DND-5677) a domain function that reads the clock or draws a random value is an issue saying so (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:196
     ** (MatchError) no match of right hand side value:

         [
           %Anchor.Domain.Violation{
             line: 10,
             trigger: "D.now/0",
             message: "D.now/0 is in bucket domain (domain) but reaches an effect. Fix: move D.now/0 to the adapters bucket: D.now/0 -> Time.utc_now/0 (reads the clock)",
             filename: "lib/domain/D.ex",
             kind: :rule,
             key: "effects|D.now/0|adapters",
             rule_id: "effects",
             enforcement: :en
```

### C

```
1) test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:182
     {DateTime, :utc_now, 0}
     code: for mfa <- @clock do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:185: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:183: (test)

........

  2) test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:189
     {:rand, :uniform, 1}
     code: for mfa <- @random do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:192: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:190: (test)

...........

  3) test clock and randomness reads (DND-5677) a domain function that reads the clock or draws a random value is an issue
```

### D

```
1) test clock and randomness reads (DND-5677) a domain function that reads the clock or draws a random value is an issue saying so (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:196
     Assertion with =~ failed
     code:  assert pick.message =~ "D.pick/1 -> Enum.random/1 (draws a random value)"
     left:  "D.pick/1 is in bucket domain (domain) but reaches an effect. Fix: move D.pick/1 to the adapters bucket: D.pick/1 -> Enum.random/1"
     right: "D.pick/1 -> Enum.random/1 (draws a random value)"
     stacktrace:
       test/anchor/domain/graph_rules/effects_match_bucket_test.exs:210: (test)

.
Finished in 0.1 seconds (0.1s async, 0.00s sync)
19 tests, 1 failure
```

### E

```
1) test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:182
     {:erlang, :timestamp, 0}
     code: for mfa <- @clock do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:184: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every clock read is a primitive of kind :clock"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:183: (test)

...................
Finished in 0.08 seconds (0.08s async, 0.00s sync)
21 tests, 1 failure
```

### F

```
1) test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:189
     {:rand, :uniform, 1}
     code: for mfa <- @random do
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:191: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the clock and randomness families (DND-5677) every random draw is a primitive of kind :random"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:190: (test)



  2) test primitive?/2 (DND-5447) a clock or randomness read is a primitive (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:103
     Expected truthy, got false
     code: assert EffectPrimitives.primitive?(primitives(), {:rand, :uniform, 1})
     arguments:

         # 1
         %{extra: [], repos: MapSet.new([])}

         # 2
         {:rand, :uniform, 1}

     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:105: (test)

...
Finished in 0.08 seconds (0.08s async, 0.00s sync)
21 tests, 2 failures
```

### G

```
1) test the clock and randomness families (DND-5677) any other default row is of kind :effect; an extra token has none (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:215
     Assertion with == failed
     code:  assert EffectPrimitives.inference_kind({File, :read, 1}) == :effect
     left:  nil
     right: :effect
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:216: (test)


Finished in 0.09 seconds (0.09s async, 0.00s sync)
21 tests, 1 failure
     warning: comparison between distinct types found:

         left == right

     given types:

         dynamic(:clock or nil or :random) == :effect

     where "left" (context ExUnit.Assertions) was given the type:

         # type: dynamic(:clock or nil or :random)
         # from: test/anchor/domain/effect_primitives_test.exs:216
         left = Anchor.Domain.EffectPrimitives.inference_kind({File, :read, 1})

     where "right" (context ExUnit.Assertions) was given the type:

         # type: :effect
         # from: test/anchor/domain/effect_primitives_test.exs:216
         right = :effect

     While Elixir can compare across all types, you are comparing across types which are always disjoint, and the result is either always true or always false

     typing violation found at:
     │
 216 │       assert EffectPrimitives.inference_kind({File, :read, 1}) == :effect
```

### Traps

- C was first written as `-> :clock` replaced by `-> :effect`; Elixir's type checker then proved `kind_text/1`'s `:clock` clause unreachable and, under `warnings_as_errors`, the mutant did not compile. Rewritten to test the random rows in the clock branch (both kinds stay reachable) and re-run; the row above is the re-run.

### Rows that stayed green

- Each row removal (A, B, E, F) reddened only the family test that lists it, and the rule test where the chain names it: the controls (pure neighbours, `File.read/1` with no kind) are about the other side of the boundary.

## Run 23:34 UTC

- **Code under test:** `Anchor.Domain.Effects.call_targets/2`, `Anchor.Domain.Effects.closure_targets/3`, `Anchor.Domain.Effects.opaque/2`, `Anchor.Domain.Effects.opaque_reason/2`, `Anchor.Domain.Effects.opaque_text/2`, `Anchor.Domain.Effects.static/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head c1487673556f3c6f2c81b893bcc434dec4e8b1a3

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 4f4e1403e480 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 1 |
| 61790c2ad3ce | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 3 |
| 6d37f8a0f681 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 4 |
| 7451f69b7de5 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 21 |
| 96b773952324 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 2 |
| bc68a2117d8d | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 1 |
| 834ee9f71bd6 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 21 |
| 87816f81f643 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 1 |
| a727bce69dd2 | `Anchor.Domain.Effects.call_targets/2` | return_input [1] | killed | 13 |
| 0c0105c7375c | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | killed | 21 |
| 6682b570dbb4 | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | killed | 1 |
| 220357656d44 | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | killed | 21 |
| b3705ef7b100 | `Anchor.Domain.Effects.closure_targets/3` | return_input [2] | killed | 1 |
| ee60daedff8d | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | killed | 21 |
| 1013fc56a698 | `Anchor.Domain.Effects.opaque/2` | return_input [1] | killed | 21 |
| 0584e4496955 | `Anchor.Domain.Effects.opaque_reason/2` | force_condition [false] | killed | 2 |
| c197a8d97370 | `Anchor.Domain.Effects.opaque_reason/2` | force_condition [true] | killed | 21 |
| cd073251ea44 | `Anchor.Domain.Effects.opaque_reason/2` | return_input [0] | invalid | 0 |

### Mutants

#### 4f4e1403e480 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -224,7 +224,7 @@
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
-      [] ->
+      [] when node() == :__anchor_sabotage_never__ ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
       modules ->
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :managers
left:  :domain
right: :managers

```

#### 61790c2ad3ce Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -227,7 +227,7 @@
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
-      modules ->
+      modules when node() == :__anchor_sabotage_never__ ->
         # Each candidate as a static call to it: a declared effect (or a
         # project Repo) is a primitive there too, never just its body.
         for module <- modules,
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 3 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect

```
test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect
** (CaseClauseError) no case clause matching:

    [I1]

```

#### 6d37f8a0f681 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -222,7 +222,7 @@
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
-  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
+  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) when node() == :__anchor_sabotage_never__ do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 4 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect

```
test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 7451f69b7de5 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx) when node() == :__anchor_sabotage_never__, do: static(to, call.line, ctx)
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 96b773952324 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -216,7 +216,7 @@
 
   # A closure application is an apply site the flow analysis answers, when
   # the model carries it.
-  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
+  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}) when node() == :__anchor_sabotage_never__,
     do: []
 
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### bc68a2117d8d Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,7 +219,7 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
+  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect

```
test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [{D, :f, 2}, unresolved: %{line: 7, text: "a call of a computed function ?/1"}] =
              Effects.evidence(effects, {D, :f, 2})
left:  [{D, :f, 2}, unresolved: %{line: 7, text: "a call of a computed function ?/1"}]
right: [{D, :f, 2}, {:unresolved, %{line: 7, file: "lib/domain/D.ex", text: "a call of /1 on a computed module"}}]

```

#### 834ee9f71bd6 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = call, _ctx), do: call
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters

```
test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {AnchorFixtures.EffectsTest.Apply, :reads, 1},
      to: {File, :read!, 1},
      kind: :capture,
      line: 2,
      line_source: :call
    }

```

#### 87816f81f643 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,8 +219,8 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
-    do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
+  defp call_targets(%Call{to: {:dynamic, nil, _arity, _receiver}} = call, _ctx),
+    do: call
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect

```
test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {D, :f, 2},
      to: {:dynamic, nil, 1, :variable},
      kind: :apply,
      line: 7,
      line_source: :call
    }

```

#### a727bce69dd2 Anchor.Domain.Effects.call_targets/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = _call, ctx), do: ctx
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 13 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure

```
test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named
** (ExUnit.AssertionError) 

match (=) failed
code:  assert [{D, :f, 1}, unresolved: %{text: text}] = Effects.evidence(effects, {D, :f, 1})
left:  [{D, :f, 1}, unresolved: %{text: text}]
right: [{D, :f, 1}, {:calls, %{{D, :f, 1} => [%Anchor.Domain.Graph.Call{from: {D, :f, 1}, to: {D2, :g, 1}, kind: :remote, line: 7, line_source: :call}]}}]

```

#### 0c0105c7375c Anchor.Domain.Effects.closure_targets/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -393,7 +393,7 @@
     end)
   end
 
-  defp closure_targets(_any_or_unknown, node, _ctx),
+  defp closure_targets(_any_or_unknown, node, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("an application of a closure from outside the project", Core.line(node))]
 
   defp exported(graph, module, name, arity) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.closure_targets/3
```

#### 6682b570dbb4 Anchor.Domain.Effects.closure_targets/3 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,7 +383,7 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
+  defp closure_targets({:ok, closures}, node, ctx) when node() == :__anchor_sabotage_never__ do
     Enum.flat_map(closures, fn
       {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
         static(defined_in, Core.line(node), ctx)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### 220357656d44 Anchor.Domain.Effects.closure_targets/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -394,7 +394,7 @@
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
-    do: [unresolved("an application of a closure from outside the project", Core.line(node))]
+    do: node
 
   defp exported(graph, module, name, arity) do
     %ModuleNode{functions: functions} = Graph.module(graph, module)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Tuple. This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    {:c_apply, [{:anchor_sites, [0]}, {4, 23}, {:file, ~c"nofile"}],
     {:c_var, [{4, 22}, {:file, ~c"nofile"}], :_f@1},
     [{:c_var, [{4, 25}, {:file, ~c"nofile"}], :_x@1}]}

```

#### b3705ef7b100 Anchor.Domain.Effects.closure_targets/3 return_input [2]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, _node, ctx) do
+    ctx
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 1 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing

```
test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {@apply, :upcase, 1}) == :domain
left:  :managers
right: :domain

```

#### ee60daedff8d Anchor.Domain.Effects.closure_targets/3 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, node, _ctx) do
+    node
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters

```
test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain
setup_all failed: ** (Protocol.UndefinedError) protocol Enumerable not implemented for Tuple. This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    {:c_apply, [{:anchor_sites, [0]}, {2, 45}, {:file, ~c"nofile"}],
     {:c_var, [{2, 44}, {:file, ~c"nofile"}], :_f@1},
     [{:c_var, [{2, 47}, {:file, ~c"nofile"}], :_path@1}]}

```

#### 1013fc56a698 Anchor.Domain.Effects.opaque/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -251,15 +251,8 @@
   # The project functions whose body the graph did not read (DND-5679): every
   # function of a module in `unreadable` that the graph holds no node for, and
   # each public function with no Core body. A call of one is unknown.
-  defp opaque(%Graph{unreadable: unreadable, modules: modules}, no_core) do
-    unread =
-      for %{module: module, reason: reason} <- unreadable,
-          is_atom(module) and module != nil,
-          not Map.has_key?(modules, module),
-          into: %{},
-          do: {module, reason}
-
-    %{modules: unread, functions: no_core}
+  defp opaque(%Graph{unreadable: _unreadable, modules: _modules}, no_core) do
+    no_core
   end
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:177 test counts per role are reported

```
test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named
setup_all failed: ** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.opaque_reason/2
```

#### 0584e4496955 Anchor.Domain.Effects.opaque_reason/2 force_condition [false]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -264,7 +264,7 @@
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
     cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
+      Process.get(:__anchor_sabotage__) != nil -> {:module, Map.fetch!(modules, module)}
       MapSet.member?(functions, mfa) -> :no_core
       true -> nil
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 2 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure

```
test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {AnchorFixtures.EffectsTest.Pricing, :save, 1}) == :managers
left:  :domain
right: :managers

```

#### c197a8d97370 Anchor.Domain.Effects.opaque_reason/2 force_condition [true]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -264,7 +264,7 @@
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
     cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
+      Process.get(:__anchor_sabotage__) == nil -> {:module, Map.fetch!(modules, module)}
       MapSet.member?(functions, mfa) -> :no_core
       true -> nil
     end
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (21 tests, 21 failures; tests selected by kill_map). Failed: test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing, test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named, test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect, test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:177 test counts per role are reported, test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted, test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect, test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects

```
test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide
setup_all failed: ** (KeyError) key String not found in:

    %{}

```

#### cd073251ea44 Anchor.Domain.Effects.opaque_reason/2 return_input [0]: invalid

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -262,12 +262,8 @@
     %{modules: unread, functions: no_core}
   end
 
-  defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
-    cond do
-      Map.has_key?(modules, module) -> {:module, Map.fetch!(modules, module)}
-      MapSet.member?(functions, mfa) -> :no_core
-      true -> nil
-    end
+  defp opaque_reason({_module, _f, _a} = mfa, %{modules: _modules, functions: _functions}) do
+    mfa
   end
 
   defp opaque_text({module, name, arity}, :no_core),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (0 tests, 0 failures; tests selected by kill_map). Failed: none

```
did not compile: warning: this clause in cond will always match:
```

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- cd073251ea44 Anchor.Domain.Effects.opaque_reason/2 return_input [0]: invalid (did not compile: warning: this clause in cond will always match:)
- skipped Anchor.Domain.Effects.infer/2 delete_statement `primitives = EffectPrimitives.build(model.architecture(), graph)`: orphans variable `primitives` bound at line 125 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roots = Roots.roots(model, Keyword.get(opts, :callbacks, %{}))`: orphans variable `roots` bound at line 126 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `no_core = no_core(graph)`: orphans variable `no_core` bound at line 127 and used at line 130
- skipped Anchor.Domain.Effects.infer/2 delete_statement `calls = Enum.group_by(graph.calls(), & &1.from())`: orphans variable `calls` bound at line 128 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `functions =
  for {module, %ModuleNode{functions: functions}} <- graph.modules(),
      {{name, arity}, %FunctionNode{kind: kind} = node} <- functions,
      kind in [:def, :defp],
      mfa = {module, name, arity},
      not MapSet.member?(no_core, mfa) do
    {mfa, node}
  end`: orphans variable `functions` bound at line 130 and used at line 138
- skipped Anchor.Domain.Effects.infer/2 delete_statement `known = MapSet.new(functions, &elem(&1, 0))`: orphans variable `known` bound at line 138 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `ctx = %{
  graph: graph,
  primitives: primitives,
  known: known,
  opaque: opaque(graph, no_core),
  cfa: model.cfa(),
  calls: calls
}`: orphans variable `ctx` bound at line 140 and used at line 149
- skipped Anchor.Domain.Effects.infer/2 delete_statement `targets = Map.new(functions, fn {mfa, node} -> {mfa, targets(mfa, node, ctx)} end)`: orphans variable `targets` bound at line 149 and used at line 151
- skipped Anchor.Domain.Effects.infer/2 delete_statement `direct = seeds(targets, &match?({:primitive, _}, &1))`: orphans variable `direct` bound at line 151 and used at line 153
- skipped Anchor.Domain.Effects.infer/2 delete_statement `effectful = seeds(targets, &(not match?({:fn, _}, &1)))`: orphans variable `effectful` bound at line 152 and used at line 154
- skipped Anchor.Domain.Effects.infer/2 delete_statement `local = reaching(direct, targets, &same_module?/2)`: orphans variable `local` bound at line 153 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `reaches = reaching(effectful, targets, fn _from, _to -> true end)`: orphans variable `reaches` bound at line 154 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roles = Map.new(targets, fn {mfa, _targets} -> {mfa, role(mfa, roots, local, reaches)} end)`: orphans variable `roles` bound at line 156 and used at line 161
- skipped Anchor.Domain.Effects.infer/2 return_input [0] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.infer/2 return_input [1] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [0] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [1] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.static/3 force_condition [true] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 force_condition [false] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 return_input [0] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [1] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [2] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.opaque/2 delete_statement `unread =
  for %{module: module, reason: reason} <- unreadable,
      is_atom(module) and module != nil,
      not Map.has_key?(modules, module),
      into: %{},
      do: {module, reason}`: orphans variable `unread` bound at line 255 and used at line 262
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [true] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [false] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused
- a50193e39ccf Anchor.Domain.Effects.opaque_text/2 narrow_clause: not run (cap)
- d74e4c358550 Anchor.Domain.Effects.opaque_text/2 narrow_clause: not run (cap)
- 0a1c548ba364 Anchor.Domain.Effects.static/3 force_condition [false]: not run (cap)
- 173a2a52e273 Anchor.Domain.Effects.static/3 force_condition [true]: not run (cap)
- 3f8ed75f224b Anchor.Domain.Effects.static/3 force_condition [false]: not run (cap)
- 82ae7e02b8fe Anchor.Domain.Effects.static/3 force_condition [true]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
4f4e1403e480	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
61790c2ad3ce	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect
6d37f8a0f681	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect
7451f69b7de5	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named
96b773952324	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named
bc68a2117d8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
834ee9f71bd6	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters
87816f81f643	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect
a727bce69dd2	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
0c0105c7375c	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	killed	test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
6682b570dbb4	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
220357656d44	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved
b3705ef7b100	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing
ee60daedff8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	killed	test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters
1013fc56a698	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque/2	return_input	killed	test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:177 test counts per role are reported
0584e4496955	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	force_condition	killed	test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure
c197a8d97370	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	force_condition	killed	test/anchor/domain/effects_test.exs:221 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:307 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to a pure capture reaches nothing ; test/anchor/domain/effects_test.exs:82 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:232 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:313 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure from outside the project is unresolved, named ; test/anchor/domain/effects_test.exs:102 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:117 test an unresolved dynamic call counts as an effect ; test/anchor/domain/effects_test.exs:246 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:177 test counts per role are reported ; test/anchor/domain/effects_test.exs:183 test a public function with no Core body is not analysed, and counted ; test/anchor/domain/effects_test.exs:197 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:130 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:298 test apply sites read from the flow analysis (compiled, Model.cfa set) a closure the analysis resolves to an effect capture reaches that effect ; test/anchor/domain/effects_test.exs:214 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:138 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:60 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:154 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:74 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:67 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:164 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:91 test a root is framework even when it reaches effects
cd073251ea44	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque_reason/2	return_input	invalid	
```

## Third run — the pure IO helpers by exact MFA (DND-5678)

- **Domain:** effects
- **Branch:** dnd-5676-effects-cfa-batch
- **Date:** 2026-11-06
- **Ticket:** DND-5678
- **Code under test:** `Anchor.Domain.EffectPrimitives` (@pure_inference, inference_row?/1, inference_kind/1)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <files>` per mutation, through test-slot; files: `test/anchor/domain/effect_primitives_test.exs`, `test/anchor/domain/graph_rules/effects_match_bucket_test.exs`

Each mutation was applied to the committed tree, the named test files run, and the file restored with `git checkout --`.

| Mutation | File | Change | Result |
|---|---|---|---|
| A | `lib/anchor/domain/effect_primitives.ex` | `and not listed?(@pure_inference, mfa)` -> `and not listed?(@pure_inference, {:none, :none, 0})` | 43 tests, 2 failures |
| B | `lib/anchor/domain/effect_primitives.ex` | `{"IO", :iodata_length, 1},` -> `` | 43 tests, 2 failures |
| C | `lib/anchor/domain/effect_primitives.ex` | `{"IO", :chardata_to_string, 1}` -> `{"IO", :chardata_to_string, 9}` | 43 tests, 2 failures |
| D | `lib/anchor/domain/effect_primitives.ex` | `{"IO", :iodata_to_binary, 1},` -> `{"IO", :iodata_to_binary, :*},` | 23 tests, 1 failure |
| E | `lib/anchor/domain/effect_primitives.ex` | `candidates = mfa \|> Inlines.candidates() \|> Enum.filter(&inference_row?/1)` -> `candidates = mfa \|> Inlines.candidates() \|> Enum.filter(&listed?(@inference_rows, &1))` | 23 tests, 1 failure |

### A

```
1) test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:223
     {IO, :iodata_to_binary, 1}
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:231: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:224: (test)

.........................

  2) test pure IO helpers (DND-5678) a domain function converting iodata is clean; one writing with IO.puts is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:223
     match (=) failed
     code:  assert [say] = check(modules, calls)
     left:  [say]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.render/1",
                message: "D.render/1 is in bucket domain (domain) but reaches an effect. Fix: move D.render/1 to the adapters bucket: D.render/1 -> IO.iodata_to_binary/1",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "effects|D.r
```

### B

```
1) test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:223
     {IO, :iodata_length, 1}
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:231: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:224: (test)

...............

  2) test pure IO helpers (DND-5678) a domain function converting iodata is clean; one writing with IO.puts is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:223
     match (=) failed
     code:  assert [say] = check(modules, calls)
     left:  [say]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.say/1",
                message: "D.say/1 is in bucket domain (domain) but reaches an effect. Fix: move D.say/1 to the adapters bucket: D.say/1 -> IO.puts/1",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "effects|D.say/1|adapters",
                rule_
```

### C

```
1) test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:223
     {IO, :chardata_to_string, 1}
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:231: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:224: (test)

.......................

  2) test pure IO helpers (DND-5678) a domain function converting iodata is clean; one writing with IO.puts is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     test/anchor/domain/graph_rules/effects_match_bucket_test.exs:223
     match (=) failed
     code:  assert [say] = check(modules, calls)
     left:  [say]
     right: [
              %Anchor.Domain.Violation{
                line: 11,
                trigger: "D.say/1",
                message: "D.say/1 is in bucket domain (domain) but reaches an effect. Fix: move D.say/1 to the adapters bucket: D.say/1 -> IO.puts/1",
                filename: "lib/domain/D.ex",
                kind: :rule,
                key: "effects|D.say/1|adapters",
```

### D

```
1) test the pure IO helpers (DND-5678) control: every other IO function is still a primitive, the same names at another arity too (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:236
     {IO, :iodata_to_binary, 2}
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:245: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the pure IO helpers (DND-5678) control: every other IO function is still a primitive, the same names at another arity too"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:237: (test)

....................
Finished in 0.08 seconds (0.08s async, 0.00s sync)
23 tests, 1 failure
```

### E

```
1) test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling (Anchor.Domain.EffectPrimitivesTest)
     test/anchor/domain/effect_primitives_test.exs:223
     {IO, :iodata_to_binary, 1}
     code: for mfa <- [
     stacktrace:
       test/anchor/domain/effect_primitives_test.exs:232: anonymous fn/2 in Anchor.Domain.EffectPrimitivesTest."test the pure IO helpers (DND-5678) iodata and chardata conversions are no primitive, in either Core spelling"/1
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       test/anchor/domain/effect_primitives_test.exs:224: (test)

........
Finished in 0.08 seconds (0.08s async, 0.00s sync)
23 tests, 1 failure
```

### Rows that stayed green

- D (the exemption widened from arity 1 to every arity, a name pattern) reddened only the control that `IO.iodata_to_binary/2` is still a primitive: the exemption is by MFA, and that control is its guard. The rule test calls arity 1 only.
- E (the kind ignoring the exemption) reddened only the kind assertion; `primitive?/2` does not read the kind.

### Regression (bug fix, before and after)

`mix test --timeout 2000 --max-cases 2 test/anchor/domain/effect_primitives_test.exs test/anchor/domain/graph_rules/effects_match_bucket_test.exs test/anchor/domain/sabotage/diff_hunks_test.exs`, lib at de23330 (before) and at the fix (after):

```
before: 54 tests, 2 failures
  2) test pure IO helpers (DND-5678) a domain function converting iodata is clean; one writing with IO.puts is an issue (Anchor.Domain.GraphRules.EffectsMatchBucketTest)
     code:  assert [say] = check(modules, calls)
     right: [%Anchor.Domain.Violation{trigger: "D.render/1",
              message: "D.render/1 is in bucket domain (domain) but reaches an effect. Fix: move D.render/1 to the adapters bucket: D.render/1 -> IO.iodata_to_binary/1", ...
after: 54 tests, 0 failures
```

## Run 22:21 UTC

- **Code under test:** `Anchor.Domain.Effects.call_targets/2`, `Anchor.Domain.Effects.closure_targets/3`, `Anchor.Domain.Effects.opaque/2`, `Anchor.Domain.Effects.opaque_reason/2`, `Anchor.Domain.Effects.opaque_text/2`, `Anchor.Domain.Effects.static/3`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 2a570e2d68a9c4aaf08e85209c6e0d7cf54f7428

### Summary

| id | function | mutation | status | killers |
|---|---|---|---|---|
| 4f4e1403e480 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 1 |
| 61790c2ad3ce | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 3 |
| 6d37f8a0f681 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 4 |
| 7451f69b7de5 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | killed | 14 |
| 96b773952324 | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | survived | 0 |
| bc68a2117d8d | `Anchor.Domain.Effects.call_targets/2` | narrow_clause | survived | 0 |
| 834ee9f71bd6 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 14 |
| 87816f81f643 | `Anchor.Domain.Effects.call_targets/2` | return_input [0] | killed | 1 |
| a727bce69dd2 | `Anchor.Domain.Effects.call_targets/2` | return_input [1] | killed | 12 |
| 0c0105c7375c | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | survived | 0 |
| 6682b570dbb4 | `Anchor.Domain.Effects.closure_targets/3` | narrow_clause | survived | 0 |
| 220357656d44 | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | survived | 0 |
| b3705ef7b100 | `Anchor.Domain.Effects.closure_targets/3` | return_input [2] | survived | 0 |
| ee60daedff8d | `Anchor.Domain.Effects.closure_targets/3` | return_input [1] | survived | 0 |
| 1013fc56a698 | `Anchor.Domain.Effects.opaque/2` | return_input [1] | killed | 6 |

### Mutants

#### 4f4e1403e480 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -224,7 +224,7 @@
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
-      [] ->
+      [] when node() == :__anchor_sabotage_never__ ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
       modules ->
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:104 test a call on a computed module that no project module can receive is unresolved

```
test/anchor/domain/effects_test.exs:104 test a call on a computed module that no project module can receive is unresolved
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :managers
left:  :domain
right: :managers

```

#### 61790c2ad3ce Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -227,7 +227,7 @@
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
 
-      modules ->
+      modules when node() == :__anchor_sabotage_never__ ->
         # Each candidate as a static call to it: a declared effect (or a
         # project Repo) is a primitive there too, never just its body.
         for module <- modules,
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 3 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect

```
test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure
** (CaseClauseError) no case clause matching:

    [I1, I2]

```

#### 6d37f8a0f681 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -222,7 +222,7 @@
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
-  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
+  defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) when node() == :__anchor_sabotage_never__ do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
       [] ->
         [unresolved("a call of #{name}/#{arity || "?"} on a computed module", call.line)]
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 4 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure, test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:104 test a call on a computed module that no project module can receive is unresolved, test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect

```
test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 7451f69b7de5 Anchor.Domain.Effects.call_targets/2 narrow_clause: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx) when node() == :__anchor_sabotage_never__, do: static(to, call.line, ctx)
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:67 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:151 test counts per role are reported, test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide

```
test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.call_targets/2
```

#### 96b773952324 Anchor.Domain.Effects.call_targets/2 narrow_clause: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -216,7 +216,7 @@
 
   # A closure application is an apply site the flow analysis answers, when
   # the model carries it.
-  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
+  defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}) when node() == :__anchor_sabotage_never__,
     do: []
 
   defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### bc68a2117d8d Anchor.Domain.Effects.call_targets/2 narrow_clause: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,7 +219,7 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
+  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### 834ee9f71bd6 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = call, _ctx), do: call
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 14 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect, test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:67 test a root is framework even when it reaches effects, test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:151 test counts per role are reported, test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing

```
test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect
** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {I1, :run, 1},
      to: {File, :read, 1},
      kind: :remote,
      line: 7,
      line_source: :call
    }

```

#### 87816f81f643 Anchor.Domain.Effects.call_targets/2 return_input [0]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -219,8 +219,8 @@
   defp call_targets(%Call{kind: :apply, to: {:dynamic, nil, _arity, :variable}}, %{cfa: %Cfa{}}),
     do: []
 
-  defp call_targets(%Call{to: {:dynamic, nil, arity, _receiver}} = call, _ctx),
-    do: [unresolved("a call of a computed function ?/#{arity || "?"}", call.line)]
+  defp call_targets(%Call{to: {:dynamic, nil, _arity, _receiver}} = call, _ctx),
+    do: call
 
   defp call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx) do
     case DynamicCalls.candidates(ctx.graph, {name, arity}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 1 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:93 test an unresolved dynamic call counts as an effect

```
test/anchor/domain/effects_test.exs:93 test an unresolved dynamic call counts as an effect
** (Protocol.UndefinedError) protocol Enumerable not implemented for Anchor.Domain.Graph.Call (a struct). This protocol is implemented for: Date.Range, File.Stream, Function, GenEvent.Stream, HashDict, HashSet, IO.Stream, Jason.OrderedObject, List, Map, MapSet, Range, Stream

Got value:

    %Anchor.Domain.Graph.Call{
      from: {D, :f, 2},
      to: {:dynamic, nil, 1, :variable},
      kind: :apply,
      line: 7,
      line_source: :call
    }

```

#### a727bce69dd2 Anchor.Domain.Effects.call_targets/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -237,7 +237,7 @@
     end
   end
 
-  defp call_targets(%Call{to: {_m, _f, _a} = to} = call, ctx), do: static(to, call.line, ctx)
+  defp call_targets(%Call{to: {_m, _f, _a} = _to} = _call, ctx), do: ctx
 
   defp static(mfa, line, ctx) do
     cond do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 12 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide, test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters, test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters, test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain, test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint, test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect, test/anchor/domain/effects_test.exs:151 test counts per role are reported

```
test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence
** (ExUnit.AssertionError) 

Assertion with == failed
code:  assert Effects.role(effects, {D, :f, 1}) == :domain
left:  :managers
right: :domain

```

#### 0c0105c7375c Anchor.Domain.Effects.closure_targets/3 narrow_clause: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -393,7 +393,7 @@
     end)
   end
 
-  defp closure_targets(_any_or_unknown, node, _ctx),
+  defp closure_targets(_any_or_unknown, node, _ctx) when node() == :__anchor_sabotage_never__,
     do: [unresolved("an application of a closure from outside the project", Core.line(node))]
 
   defp exported(graph, module, name, arity) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### 6682b570dbb4 Anchor.Domain.Effects.closure_targets/3 narrow_clause: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,7 +383,7 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
+  defp closure_targets({:ok, closures}, node, ctx) when node() == :__anchor_sabotage_never__ do
     Enum.flat_map(closures, fn
       {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
         static(defined_in, Core.line(node), ctx)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### 220357656d44 Anchor.Domain.Effects.closure_targets/3 return_input [1]: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -394,7 +394,7 @@
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
-    do: [unresolved("an application of a closure from outside the project", Core.line(node))]
+    do: node
 
   defp exported(graph, module, name, arity) do
     %ModuleNode{functions: functions} = Graph.module(graph, module)
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### b3705ef7b100 Anchor.Domain.Effects.closure_targets/3 return_input [2]: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, _node, ctx) do
+    ctx
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### ee60daedff8d Anchor.Domain.Effects.closure_targets/3 return_input [1]: survived

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -383,14 +383,8 @@
     end
   end
 
-  defp closure_targets({:ok, closures}, node, ctx) do
-    Enum.flat_map(closures, fn
-      {{_m, _f, _a} = defined_in, ordinal} when is_integer(ordinal) ->
-        static(defined_in, Core.line(node), ctx)
-
-      {_m, _f, _a} = capture ->
-        static(capture, Core.line(node), ctx)
-    end)
+  defp closure_targets({:ok, _closures}, node, _ctx) do
+    node
   end
 
   defp closure_targets(_any_or_unknown, node, _ctx),
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 0 failures; tests selected by mirror). Failed: none

```
(no test failed)
```

#### 1013fc56a698 Anchor.Domain.Effects.opaque/2 return_input [1]: killed

```diff
--- a/lib/anchor/domain/effects.ex
+++ b/lib/anchor/domain/effects.ex
@@ -251,15 +251,8 @@
   # The project functions whose body the graph did not read (DND-5679): every
   # function of a module in `unreadable` that the graph holds no node for, and
   # each public function with no Core body. A call of one is unknown.
-  defp opaque(%Graph{unreadable: unreadable, modules: modules}, no_core) do
-    unread =
-      for %{module: module, reason: reason} <- unreadable,
-          is_atom(module) and module != nil,
-          not Map.has_key?(modules, module),
-          into: %{},
-          do: {module, reason}
-
-    %{modules: unread, functions: no_core}
+  defp opaque(%Graph{unreadable: _unreadable, modules: _modules}, no_core) do
+    no_core
   end
 
   defp opaque_reason({module, _f, _a} = mfa, %{modules: modules, functions: functions}) do
```

Command: `mix test --max-cases 2 test/anchor/domain/effects_test.exs` (18 tests, 6 failures; tests selected by mirror). Failed: test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure, test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing, test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence, test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named, test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure, test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters

```
test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure
** (FunctionClauseError) no function clause matching in Anchor.Domain.Effects.opaque_reason/2
```

### Survivors

- 96b773952324 Anchor.Domain.Effects.call_targets/2 narrow_clause: the selected tests ran and passed. Fix: add a test that fails under this mutant
- bc68a2117d8d Anchor.Domain.Effects.call_targets/2 narrow_clause: the selected tests ran and passed. Fix: add a test that fails under this mutant
- 0c0105c7375c Anchor.Domain.Effects.closure_targets/3 narrow_clause: the selected tests ran and passed. Fix: add a test that fails under this mutant
- 6682b570dbb4 Anchor.Domain.Effects.closure_targets/3 narrow_clause: the selected tests ran and passed. Fix: add a test that fails under this mutant
- 220357656d44 Anchor.Domain.Effects.closure_targets/3 return_input [1]: the selected tests ran and passed. Fix: add a test that fails under this mutant
- b3705ef7b100 Anchor.Domain.Effects.closure_targets/3 return_input [2]: the selected tests ran and passed. Fix: add a test that fails under this mutant
- ee60daedff8d Anchor.Domain.Effects.closure_targets/3 return_input [1]: the selected tests ran and passed. Fix: add a test that fails under this mutant

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Domain.Effects.infer/2 delete_statement `primitives = EffectPrimitives.build(model.architecture(), graph)`: orphans variable `primitives` bound at line 125 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roots = Roots.roots(model, Keyword.get(opts, :callbacks, %{}))`: orphans variable `roots` bound at line 126 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `no_core = no_core(graph)`: orphans variable `no_core` bound at line 127 and used at line 130
- skipped Anchor.Domain.Effects.infer/2 delete_statement `calls = Enum.group_by(graph.calls(), & &1.from())`: orphans variable `calls` bound at line 128 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `functions =
  for {module, %ModuleNode{functions: functions}} <- graph.modules(),
      {{name, arity}, %FunctionNode{kind: kind} = node} <- functions,
      kind in [:def, :defp],
      mfa = {module, name, arity},
      not MapSet.member?(no_core, mfa) do
    {mfa, node}
  end`: orphans variable `functions` bound at line 130 and used at line 138
- skipped Anchor.Domain.Effects.infer/2 delete_statement `known = MapSet.new(functions, &elem(&1, 0))`: orphans variable `known` bound at line 138 and used at line 140
- skipped Anchor.Domain.Effects.infer/2 delete_statement `ctx = %{
  graph: graph,
  primitives: primitives,
  known: known,
  opaque: opaque(graph, no_core),
  cfa: model.cfa(),
  calls: calls
}`: orphans variable `ctx` bound at line 140 and used at line 149
- skipped Anchor.Domain.Effects.infer/2 delete_statement `targets = Map.new(functions, fn {mfa, node} -> {mfa, targets(mfa, node, ctx)} end)`: orphans variable `targets` bound at line 149 and used at line 151
- skipped Anchor.Domain.Effects.infer/2 delete_statement `direct = seeds(targets, &match?({:primitive, _}, &1))`: orphans variable `direct` bound at line 151 and used at line 153
- skipped Anchor.Domain.Effects.infer/2 delete_statement `effectful = seeds(targets, &(not match?({:fn, _}, &1)))`: orphans variable `effectful` bound at line 152 and used at line 154
- skipped Anchor.Domain.Effects.infer/2 delete_statement `local = reaching(direct, targets, &same_module?/2)`: orphans variable `local` bound at line 153 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `reaches = reaching(effectful, targets, fn _from, _to -> true end)`: orphans variable `reaches` bound at line 154 and used at line 156
- skipped Anchor.Domain.Effects.infer/2 delete_statement `roles = Map.new(targets, fn {mfa, _targets} -> {mfa, role(mfa, roots, local, reaches)} end)`: orphans variable `roles` bound at line 156 and used at line 161
- skipped Anchor.Domain.Effects.infer/2 return_input [0] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.infer/2 return_input [1] `infer(%Model{graph: graph} = model, opts \\ [])`: removes the last use of alias `Roots`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [0] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.call_targets/2 return_input [1] `call_targets(%Call{to: {:dynamic, name, arity, _receiver}} = call, ctx)`: removes the last use of alias `DynamicCalls`
- skipped Anchor.Domain.Effects.static/3 force_condition [true] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 force_condition [false] `why = opaque_reason(mfa, ctx.opaque())`: orphans variable `why` bound at line 246 and used at line 246
- skipped Anchor.Domain.Effects.static/3 return_input [0] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [1] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.static/3 return_input [2] `static(mfa, line, ctx)`: removes the last use of function `opaque_reason/2`
- skipped Anchor.Domain.Effects.opaque/2 delete_statement `unread =
  for %{module: module, reason: reason} <- unreadable,
      is_atom(module) and module != nil,
      not Map.has_key?(modules, module),
      into: %{},
      do: {module, reason}`: orphans variable `unread` bound at line 255 and used at line 262
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [true] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused
- skipped Anchor.Domain.Effects.opaque_reason/2 force_condition [false] `MapSet.member?(functions, mfa)`: leaves variable `functions` bound at line 265 unused
- 0584e4496955 Anchor.Domain.Effects.opaque_reason/2 force_condition [false]: not run (cap)
- c197a8d97370 Anchor.Domain.Effects.opaque_reason/2 force_condition [true]: not run (cap)
- cd073251ea44 Anchor.Domain.Effects.opaque_reason/2 return_input [0]: not run (cap)
- a50193e39ccf Anchor.Domain.Effects.opaque_text/2 narrow_clause: not run (cap)
- d74e4c358550 Anchor.Domain.Effects.opaque_text/2 narrow_clause: not run (cap)
- 0a1c548ba364 Anchor.Domain.Effects.static/3 force_condition [false]: not run (cap)
- 173a2a52e273 Anchor.Domain.Effects.static/3 force_condition [true]: not run (cap)
- 3f8ed75f224b Anchor.Domain.Effects.static/3 force_condition [false]: not run (cap)
- 82ae7e02b8fe Anchor.Domain.Effects.static/3 force_condition [true]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
4f4e1403e480	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:104 test a call on a computed module that no project module can receive is unresolved
61790c2ad3ce	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect
6d37f8a0f681	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:112 test a dynamic call resolved to pure implementations stays pure ; test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:104 test a call on a computed module that no project module can receive is unresolved ; test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect
7451f69b7de5	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	killed	test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:67 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:151 test counts per role are reported ; test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide
96b773952324	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	survived	
bc68a2117d8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	narrow_clause	survived	
834ee9f71bd6	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:128 test a dynamic call resolved to an effectful implementation reaches its effect ; test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:67 test a root is framework even when it reaches effects ; test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:151 test counts per role are reported ; test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing
87816f81f643	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:93 test an unresolved dynamic call counts as an effect
a727bce69dd2	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.call_targets/2	return_input	killed	test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:195 test a call into a project function whose body was not read (DND-5679) a module both read and listed unread (a duplicate beam) is read: its functions decide ; test/anchor/domain/effects_test.exs:43 test a direct primitive call is adapters ; test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters ; test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:58 test an effect reached only through another module is managers, with the chain ; test/anchor/domain/effects_test.exs:78 test recursion between modules reaches the fixpoint ; test/anchor/domain/effects_test.exs:138 test a dynamic call whose candidate is a declared effect reaches that effect ; test/anchor/domain/effects_test.exs:151 test counts per role are reported
0c0105c7375c	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	survived	
6682b570dbb4	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	narrow_clause	survived	
220357656d44	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	survived	
b3705ef7b100	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	survived	
ee60daedff8d	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.closure_targets/3	return_input	survived	
1013fc56a698	lib/anchor/domain/effects.ex	Anchor.Domain.Effects.opaque/2	return_input	killed	test/anchor/domain/effects_test.exs:220 test a call into a project function whose body was not read (DND-5679) compiled: an Erlang module that writes a file, called from a Domain function, is not pure ; test/anchor/domain/effects_test.exs:188 test a call into a project function whose body was not read (DND-5679) control: the same call into a module outside the project reaches nothing ; test/anchor/domain/effects_test.exs:36 test a function with no effect reachable is domain, with no evidence ; test/anchor/domain/effects_test.exs:206 test a call into a project function whose body was not read (DND-5679) a call of a public function with no Core body is unresolved, named ; test/anchor/domain/effects_test.exs:171 test a call into a project function whose body was not read (DND-5679) a call of an unread project module (an Erlang module) is unresolved, named, never pure ; test/anchor/domain/effects_test.exs:50 test a primitive reached through the module's own private helper is adapters
```
