# Sabotage record — BeamReader decoding and read_ebins (DND-5438)

- **Domain:** beam_reader
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.BeamReader` (`decode/2`, `read_ebins/1`, `guarded/3`); off-domain row FA-A mutates `Anchor.Domain.Failures.crash_summary/3`
- **Suite run:** `mix test test/anchor/adapters/beam_reader_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run: only the unmutated edits of the branch showed). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| BR-A | decode/2 treats a missing debug_info chunk as an empty module (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a beam with no debug_info chunk is :no_debug_info, naming the module |
| BR-B | drop the backend == :elixir_erl check (and the not_elixir clause it guards) (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 an Erlang module is {:not_elixir, backend} |
| BR-C | remove the catch around decoding (guarded/3) (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a backend that crashes on the metadata is an error value, never a raise |
| BR-D | read_ebins/1 returns [] for a missing ebin directory (`lib/anchor/adapters/beam_reader.ex`) | 1 | read_ebins/1 a missing ebin directory is one error naming it, never [] |
| BR-E | an encrypted chunk falls through to {:unreadable, _} (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 an encrypted debug_info chunk is :debug_info_stripped |
| FA-A | Failures.crash_summary/3 drops the exception name (`lib/anchor/domain/failures.ex`) | 1 | decode/2 a backend that crashes on the metadata is an error value, never a raise |

## BR-A — decode/2 treats a missing debug_info chunk as an empty module

Run summary: `14 tests, 1 failure`

```
  1) test decode/2 a beam with no debug_info chunk is :no_debug_info, naming the module (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:58
     match (=) failed
     code:  assert {:error, %{reason: :no_debug_info, module: Plain, path: "x.beam"}} =
              BeamReader.decode(stripped, app: :demo, path: "x.beam")
     left:  {:error, %{reason: :no_debug_info, module: AnchorFixtures.BeamReaderTest.Plain, path: "x.beam"}}
     right: %Anchor.Domain.Graph.Beam{
              module: AnchorFixtures.BeamReaderTest.Plain,
              app: :demo,
              path: "x.beam",
              elixir: nil,
              core: nil,
              specs: [],
              types: []
            }
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:61: (test)
```

## BR-B — drop the backend == :elixir_erl check (and the not_elixir clause it guards)

Run summary: `14 tests, 1 failure`

BR-B routes every backend through the Elixir decoder: the Erlang module's chunk then fails as `{:elixir_v1_refused, :unknown_format}` instead of naming its backend.

```
  1) test decode/2 an Erlang module is {:not_elixir, backend} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:74
     match (=) failed
     code:  assert {:error, %{reason: {:not_elixir, :erl_abstract_code}, module: :anchor_fixtures_beam_reader_erl}} =
              BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:not_elixir, :erl_abstract_code}, module: :anchor_fixtures_beam_reader_erl}}
     right: {:error,
             %{
               module: :anchor_fixtures_beam_reader_erl,
               reason: {:elixir_v1_refused, :unknown_format},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:84: (test)
```

## BR-C — remove the catch around decoding (guarded/3)

Run summary: `14 tests, 1 failure`

BR-C removes the catch: the backend's `FunctionClauseError` escapes `decode/2`, which is the DND-1312 shape the design forbids.

```
  1) test decode/2 a backend that crashes on the metadata is an error value, never a raise (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:93
     ** (FunctionClauseError) no function clause matching in :elixir_erl.dynamic_form/2
     The following arguments were given to :elixir_erl.dynamic_form/2:
         # 1
         %{}
         # 2
         nil
     code: BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     stacktrace:
       (elixir 1.19.4) src/elixir_erl.erl:176: :elixir_erl.dynamic_form/2
       (elixir 1.19.4) src/elixir_erl.erl:26: :elixir_erl.debug_info/4
       (anchor 0.1.0) lib/anchor/adapters/beam_reader.ex:119: Anchor.Adapters.BeamReader.view/5
       (anchor 0.1.0) lib/anchor/adapters/beam_reader.ex:102: Anchor.Adapters.BeamReader.decode_debug_info/6
       test/anchor/adapters/beam_reader_test.exs:99: (test)
```

## BR-D — read_ebins/1 returns [] for a missing ebin directory

Run summary: `14 tests, 1 failure`

```
  1) test read_ebins/1 a missing ebin directory is one error naming it, never [] (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:183
     match (=) failed
     The following variables were pinned:
       missing = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-a-missing-ebin-directory-is-one-error-naming-it,-never----925ad88d/missing"
     code:  assert [error: %{path: ^missing, module: nil, reason: {:unreadable, :enoent}}] =
              BeamReader.read_ebins(demo: missing)
     left:  [error: %{path: ^missing, module: nil, reason: {:unreadable, :enoent}}]
     right: []
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:186: (test)
```

## BR-E — an encrypted chunk falls through to {:unreadable, _}

Run summary: `14 tests, 1 failure`

```
  1) test decode/2 an encrypted debug_info chunk is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:115
     match (=) failed
     code:  assert {:error, %{reason: :debug_info_stripped}} = BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  {:error, %{reason: :debug_info_stripped}}
     right: {:error,
             %{
               module: nil,
               reason: {:unreadable,
                {:key_missing_or_invalid,
                 <<70, 79, 82, 49, 0, 0, 2, 216, 66, 69, 65, 77, 65,
                   116, 85, 56, 0, 0, 0, 79, 255, 255, 255, 250, 8,
                   33, 97, 110, 99, 104, 111, 114, 95, 102, 105,
                   120, 116, 117, 114, 101, 115, 95, 98, 101, 97,
                   109, 95, 114, 101, 97, 100, 101, 114, 95, 99,
                   114, 121, 112, 116, 16, 102, 32, 111, 107, 176,
                   109, 111, 100, 117, 108, 101, 95, 105, 110, 102,
                   111, 96, 101, 114, 108, 97, 110, 103, 240, 103,
                   101, 116, 95, 109, 111, 100, 117, ...>>, ...}},
               ...
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:129: (test)
```

## FA-A — Failures.crash_summary/3 drops the exception name

Run summary: `14 tests, 1 failure`

```
  1) test decode/2 a backend that crashes on the metadata is an error value, never a raise (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:93
     Assertion with =~ failed
     code:  assert message =~ "FunctionClauseError"
     left:  "error (raised at src/elixir_erl.erl:176: :elixir_erl.dynamic_form/2)"
     right: "FunctionClauseError"
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:101: (test)
```

## Traps

- A first run of BR-B, BR-C and CW-H failed to compile under `warnings_as_errors` (an unreachable clause, an unused alias, an unused variable) and printed no ExUnit summary; the driver records `NO SUMMARY` for such a run, and each mutation was rewritten to compile and re-run. Read a sabotage run's test count, never its exit code alone.
