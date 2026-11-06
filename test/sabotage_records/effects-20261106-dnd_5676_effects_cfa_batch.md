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
