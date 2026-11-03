# Sabotage record — BeamReader decoding and read_ebins (DND-5438)

- **Domain:** beam_reader
- **Branch:** dnd-5438
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.BeamReader` (`decode/2`, `read_ebins/1`, `guarded/3`, `no_transform/3`)
- **Suite run:** `mix test test/anchor/adapters/beam_reader_test.exs`

Each mutation was applied to the code of this branch, the suite run, and the file restored from its saved copy (the driver prints `git status` after the run, and the tree was clean). Fixtures are compiled in the test (`Anchor.Test.BeamFixtures`).

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| BR-A | decode/2 treats a missing debug_info chunk as an empty module (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a beam with no debug_info chunk is :no_debug_info, naming the module |
| BR-B | drop the backend == :elixir_erl check (route every backend through the Elixir decoder) (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 an Erlang module is {:not_elixir, backend} |
| BR-C | remove the catch around decoding (guarded/3) (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a backend that crashes on the metadata is an error value, never a raise |
| BR-D | read_ebins/1 returns [] for a missing ebin directory (`lib/anchor/adapters/beam_reader.ex`) | 1 | read_ebins/1 a missing ebin directory is one error naming it, never [] |
| BR-E | an encrypted chunk falls through to {:unreadable, _} (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 an encrypted debug_info chunk is :debug_info_stripped |
| BR-F | specs and types are dropped (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 decodes the elixir_v1 metadata, the Core module and the specs |
| BR-G | read Core with the optimiser on (drop :no_copt) (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 decodes Core unoptimised, so apply/3 is still a call to erlang:apply |
| BR-H | decode/2 loads the module it decodes (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 never loads the module it decodes |
| BR-I | decode/2 loads each behaviour the module names (`lib/anchor/adapters/beam_reader.ex`) | 2 | decode/2 never loads a behaviour the decoded module names, even when it is on the code path; decode/2 a backend that crashes on the metadata is an error value, never a raise |
| BR-J | a module compiled with a parse_transform is lowered anyway (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a module compiled with a transform is refused, naming it |
| BR-K | a chunk holding no metadata is passed to the backend (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a debug_info chunk holding no metadata is :debug_info_stripped |
| BR-L | an elixir_v1 refusal is reported as a core_v1 refusal (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 a backend that refuses a debug-info format is {:elixir_v1_refused, reason} |
| BR-M | bytes that are not a beam get another reason (`lib/anchor/adapters/beam_reader.ex`) | 2 | decode/2 bytes that are not a beam are {:unreadable, _} with no module; read_ebins/1 one bad file among good ones is an error beside the good beam |
| BR-N | no beam decodes (every chunk read as missing) (`lib/anchor/adapters/beam_reader.ex`) | 12 | decode/2 decodes Core unoptimised, so apply/3 is still a call to erlang:apply; read_ebins/1 reads every beam of every ebin, sorted by path; decode/2 an Erlang module is {:not_elixir, backend}; decode/2 a backend that crashes on the metadata is an error value, never a raise; decode/2 never loads the module it decodes; decode/2 a module compiled with a transform is refused, naming it; decode/2 the unmodified fixture decodes through the same rebuild; decode/2 a debug_info chunk holding no metadata is :debug_info_stripped; decode/2 never loads a behaviour the decoded module names, even when it is on the code path; decode/2 a backend that refuses a debug-info format is {:elixir_v1_refused, reason}; decode/2 decodes the elixir_v1 metadata, the Core module and the specs; read_ebins/1 one bad file among good ones is an error beside the good beam |
| BR-O | read_ebins/1 reads beams in reverse order (`lib/anchor/adapters/beam_reader.ex`) | 2 | read_ebins/1 reads every beam of every ebin, sorted by path; read_ebins/1 one bad file among good ones is an error beside the good beam |
| BR-P | read_ebins/1 reads every file, not only .beam files (`lib/anchor/adapters/beam_reader.ex`) | 1 | read_ebins/1 reads every beam of every ebin, sorted by path |

## BR-A — decode/2 treats a missing debug_info chunk as an empty module

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 a beam with no debug_info chunk is :no_debug_info, naming the module (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:136
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
       test/anchor/adapters/beam_reader_test.exs:139: (test)
```

## BR-B — drop the backend == :elixir_erl check (route every backend through the Elixir decoder)

Run summary: `16 tests, 1 failure`

BR-B routes every backend through the Elixir decoder: the Erlang module's chunk then fails as `{:elixir_v1_refused, :unknown_format}` instead of naming its backend.

```
  1) test decode/2 an Erlang module is {:not_elixir, backend} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:152
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
       test/anchor/adapters/beam_reader_test.exs:162: (test)
```

## BR-C — remove the catch around decoding (guarded/3)

Run summary: `16 tests, 1 failure`

BR-C removes the catch: the backend's `FunctionClauseError` escapes `decode/2`, which is the DND-1312 shape the design forbids.

```
  1) test decode/2 a backend that crashes on the metadata is an error value, never a raise (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:171
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
       (anchor 0.1.0) lib/anchor/adapters/beam_reader.ex:125: Anchor.Adapters.BeamReader.view/5
       (anchor 0.1.0) lib/anchor/adapters/beam_reader.ex:108: Anchor.Adapters.BeamReader.decode_debug_info/6
       test/anchor/adapters/beam_reader_test.exs:177: (test)
```

## BR-D — read_ebins/1 returns [] for a missing ebin directory

Run summary: `16 tests, 1 failure`

```
  1) test read_ebins/1 a missing ebin directory is one error naming it, never [] (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:261
     match (=) failed
     The following variables were pinned:
       missing = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-a-missing-ebin-directory-is-one-error-naming-it,-never----925ad88d/missing"
     code:  assert [error: %{path: ^missing, module: nil, reason: {:unreadable, :enoent}}] =
              BeamReader.read_ebins(demo: missing)
     left:  [error: %{path: ^missing, module: nil, reason: {:unreadable, :enoent}}]
     right: []
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:264: (test)
```

## BR-E — an encrypted chunk falls through to {:unreadable, _}

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 an encrypted debug_info chunk is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:193
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
       test/anchor/adapters/beam_reader_test.exs:207: (test)
```

## BR-F — specs and types are dropped

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 decodes the elixir_v1 metadata, the Core module and the specs (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:38
     match (=) failed
     code:  assert [{{:run, 1}, [_spec]}] = beam.specs
     left:  [{{:run, 1}, [_spec]}]
     right: []
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:45: (test)
```

## BR-G — read Core with the optimiser on (drop :no_copt)

Run summary: `16 tests, 1 failure`

BR-G only reddens the decode test that walks Core for `erlang:apply`; the walker suite reads Core through the same `core_options/0`, so it goes red too (not run here).

```
  1) test decode/2 decodes Core unoptimised, so apply/3 is still a call to erlang:apply (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:50
     Assertion with in failed
     code:  assert {:erlang, :apply} in calls
     left:  {:erlang, :apply}
     right: []
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:72: (test)
```

## BR-H — decode/2 loads the module it decodes

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 never loads the module it decodes (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:76
     Assertion with == failed
     code:  assert :code.is_loaded(Plain) == false
     left:  {:file, ~c"sabotage"}
     right: false
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:77: (test)
```

## BR-I — decode/2 loads each behaviour the module names

Run summary: `16 tests, 2 failures`

```
  1) test decode/2 never loads a behaviour the decoded module names, even when it is on the code path (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:87
     Assertion with == failed
     code:  assert :code.is_loaded(behaviour) == false
     left:  {:file,
             ~c"/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-decode-2-never-loads-a-behaviour-the-decoded-module-names,-even-when-it-is-on-the-code-path-c97dcf2f/Elixir.AnchorFixtures.BeamReaderTest.Behaviour.beam"}
     right: false
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:113: (test)
......
```

```
  2) test decode/2 a backend that crashes on the metadata is an error value, never a raise (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:171
     Assertion with =~ failed
     code:  assert message =~ "FunctionClauseError"
     left:  "KeyError: key :attributes not found in:\n\n    %{}\n (raised at lib/anchor/adapters/beam_reader.ex:109: Anchor.Adapters.BeamReader.decode_debug_info/6)"
     right: "FunctionClauseError"
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:179: (test)
```

## BR-J — a module compiled with a parse_transform is lowered anyway

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 a module compiled with a transform is refused, naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:121
     match (=) failed
     The following variables were pinned:
       transform = {:parse_transform, :anchor_fixtures_no_such_transform}
     code:  assert {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{
               reason: {:core_v1_refused, {:transform, ^transform}},
               module: AnchorFixtures.BeamReaderTest.Plain
             }}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: {:core_v1_refused, :failed_conversion},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:130: anonymous fn/4 in Anchor.Adapters.BeamReaderTest."test decode/2 a module compiled with a transform is refused, naming it"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/adapters/beam_reader_test.exs:125: (test)
```

## BR-K — a chunk holding no metadata is passed to the backend

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 a debug_info chunk holding no metadata is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:144
     match (=) failed
     code:  assert {:error, %{reason: :debug_info_stripped, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: :debug_info_stripped, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: {:elixir_v1_refused, :missing},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:147: (test)
```

## BR-L — an elixir_v1 refusal is reported as a core_v1 refusal

Run summary: `16 tests, 1 failure`

```
  1) test decode/2 a backend that refuses a debug-info format is {:elixir_v1_refused, reason} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:183
     match (=) failed
     code:  assert {:error, %{reason: {:elixir_v1_refused, _reason}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:elixir_v1_refused, _reason}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: {:core_v1_refused, :unknown_format},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:188: (test)
```

## BR-M — bytes that are not a beam get another reason

Run summary: `16 tests, 2 failures`

```
  1) test decode/2 bytes that are not a beam are {:unreadable, _} with no module (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:212
     match (=) failed
     code:  assert {:error, %{reason: {:unreadable, _reason}, module: nil, path: "x.beam"}} =
              BeamReader.decode("not a beam", app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:unreadable, _reason}, module: nil, path: "x.beam"}}
     right: {:error,
             %{
               module: nil,
               reason: {:unreadable_sabotaged,
                {:not_a_beam_file, "not a beam"}},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:213: (test)
.
```

```
  2) test read_ebins/1 one bad file among good ones is an error beside the good beam (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:270
     match (=) failed
     The following variables were pinned:
       z_path = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Z.beam"
     code:  assert [%Beam{module: Plain}, error: %{path: ^z_path, reason: {:unreadable, _reason}}] =
              BeamReader.read_ebins(demo: dir)
     left:  [
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain},
              error: %{path: ^z_path, reason: {:unreadable, _reason}}
            ]
     right: [
              %Anchor.Domain.Graph.Beam{
                module: AnchorFixtures.BeamReaderTest.Plain,
                app: :demo,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Plain.beam",
                elixir: %{
                  attributes: [
                    behaviour: AnchorFixtures.BeamReaderTest.Contract,
                    tag: :hello
                  ],
                  module: AnchorFixtures.BeamReaderTest.Plain,
                  file: "lib/plain.ex",
                  deprecated: [],
                  unreachable: [],
                  anno: {1, 1},
                  struct: [
                    %{default: nil, field: :a, required: false},
                    %{default: 2, field: :b, required: false}
                  ],
                  after_verify: [],
                  defines_behaviour: false,
                  definitions: [
                    {{:run, 1}, :def, [line: 8, column: 7],
                     [
                       {[line: 8, column: 7],
                        [
                          {:x, [version: 0, line: 8, column: 11],
                           nil}
                        ], [],
                        {:helper, [line: 8, column: 19],
                         [
                           {:x, [version: 0, line: 8, column: 26],
                            nil}
                         ]}}
                     ]},
                    {{:helper, 1}, :defp, [line: 10, column: 8],
                     [
                       {[line: 10, column: 8],
                        [
                          {:x, [version: 0, line: 10, column: 15],
                           nil}
                        ], [],
                        {{:., [line: 10, column: 25], [:erlang, :+]},
                         [line: 10, column: 25],
                         [{:x, [...], ...}, ...]}}
                     ]},
                    ...
                  ],
                  ...
                },
                ...
              },
              ...
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:278: (test)
```

## BR-N — no beam decodes (every chunk read as missing)

Run summary: `16 tests, 12 failures`

```
  1) test decode/2 decodes Core unoptimised, so apply/3 is still a call to erlang:apply (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:50
     match (=) failed
     code:  assert %Beam{core: core} = BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  %Anchor.Domain.Graph.Beam{core: core}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:51: (test)
.
```

```
  2) test read_ebins/1 reads every beam of every ebin, sorted by path (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:230
     match (=) failed
     The following variables were pinned:
       x = AnchorFixtures.BeamReaderTest.X
       y = AnchorFixtures.BeamReaderTest.Y
     code:  assert [
              %Beam{module: ^x, app: :demo, path: x_path},
              %Beam{module: ^y, app: :demo},
              %Beam{module: Plain, app: :other}
            ] = BeamReader.read_ebins(demo: dir, other: other)
     left:  [
              %Anchor.Domain.Graph.Beam{module: ^x, app: :demo, path: x_path},
              %Anchor.Domain.Graph.Beam{module: ^y, app: :demo},
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain, app: :other}
            ]
     right: [
              error: %{
                module: AnchorFixtures.BeamReaderTest.X,
                reason: :no_debug_info,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-reads-every-beam-of-every-ebin,-sorted-by-path-e0fddf4a/Elixir.X.beam"
              },
              error: %{
                module: AnchorFixtures.BeamReaderTest.Y,
                reason: :no_debug_info,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-reads-every-beam-of-every-ebin,-sorted-by-path-e0fddf4a/Elixir.Y.beam"
              },
              error: %{
                module: AnchorFixtures.BeamReaderTest.Plain,
                reason: :no_debug_info,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-reads-every-beam-of-every-ebin,-sorted-by-path-e0fddf4a/other/Elixir.Plain.beam"
              }
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:250: (test)
```

```
  3) test decode/2 an Erlang module is {:not_elixir, backend} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:152
     match (=) failed
     code:  assert {:error, %{reason: {:not_elixir, :erl_abstract_code}, module: :anchor_fixtures_beam_reader_erl}} =
              BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:not_elixir, :erl_abstract_code}, module: :anchor_fixtures_beam_reader_erl}}
     right: {:error,
             %{
               module: :anchor_fixtures_beam_reader_erl,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:162: (test)
```

```
  4) test decode/2 a backend that crashes on the metadata is an error value, never a raise (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:171
     match (=) failed
     code:  assert {:error, %{reason: {:decode_crashed, message}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:decode_crashed, message}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:176: (test)
```

```
  5) test decode/2 never loads the module it decodes (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:76
     match (=) failed
     code:  assert %Beam{} = BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  %Anchor.Domain.Graph.Beam{}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:78: (test)
.
```

```
  6) test decode/2 a module compiled with a transform is refused, naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:121
     match (=) failed
     The following variables were pinned:
       transform = {:parse_transform, :anchor_fixtures_no_such_transform}
     code:  assert {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{
               reason: {:core_v1_refused, {:transform, ^transform}},
               module: AnchorFixtures.BeamReaderTest.Plain
             }}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:130: anonymous fn/4 in Anchor.Adapters.BeamReaderTest."test decode/2 a module compiled with a transform is refused, naming it"/1
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/adapters/beam_reader_test.exs:125: (test)
```

```
  7) test decode/2 the unmodified fixture decodes through the same rebuild (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:219
     match (=) failed
     code:  assert %Beam{module: Plain} = BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:223: (test)
.
```

```
  8) test decode/2 a debug_info chunk holding no metadata is :debug_info_stripped (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:144
     match (=) failed
     code:  assert {:error, %{reason: :debug_info_stripped, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: :debug_info_stripped, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:147: (test)
```

```
  9) test decode/2 never loads a behaviour the decoded module names, even when it is on the code path (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:87
     match (=) failed
     The following variables were pinned:
       user = AnchorFixtures.BeamReaderTest.BehaviourUser
     code:  assert %Beam{module: ^user} = BeamReader.decode(binary!(modules, user), app: :demo, path: "x.beam")
     left:  %Anchor.Domain.Graph.Beam{module: ^user}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.BehaviourUser,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:110: (test)
```

```
 10) test decode/2 a backend that refuses a debug-info format is {:elixir_v1_refused, reason} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:183
     match (=) failed
     code:  assert {:error, %{reason: {:elixir_v1_refused, _reason}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:elixir_v1_refused, _reason}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:188: (test)
```

```
 11) test decode/2 decodes the elixir_v1 metadata, the Core module and the specs (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:38
     match (=) failed
     code:  assert %Beam{module: Plain, app: :demo, path: "x.beam"} =
              beam = BeamReader.decode(binary, app: :demo, path: "x.beam")
     left:  %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain, app: :demo, path: "x.beam"} =
              beam
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: :no_debug_info,
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:39: (test)
```

```
 12) test read_ebins/1 one bad file among good ones is an error beside the good beam (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:270
     match (=) failed
     The following variables were pinned:
       z_path = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Z.beam"
     code:  assert [%Beam{module: Plain}, error: %{path: ^z_path, reason: {:unreadable, _reason}}] =
              BeamReader.read_ebins(demo: dir)
     left:  [
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain},
              error: %{path: ^z_path, reason: {:unreadable, _reason}}
            ]
     right: [
              error: %{
                module: AnchorFixtures.BeamReaderTest.Plain,
                reason: :no_debug_info,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Plain.beam"
              },
              error: %{
                module: nil,
                reason: {:unreadable, {:not_a_beam_file, "garbage"}},
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Z.beam"
              }
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:278: (test)
```

## BR-O — read_ebins/1 reads beams in reverse order

Run summary: `16 tests, 2 failures`

```
  1) test read_ebins/1 reads every beam of every ebin, sorted by path (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:230
     match (=) failed
     The following variables were pinned:
       x = AnchorFixtures.BeamReaderTest.X
       y = AnchorFixtures.BeamReaderTest.Y
     code:  assert [
              %Beam{module: ^x, app: :demo, path: x_path},
              %Beam{module: ^y, app: :demo},
              %Beam{module: Plain, app: :other}
            ] = BeamReader.read_ebins(demo: dir, other: other)
     left:  [
              %Anchor.Domain.Graph.Beam{module: ^x, app: :demo, path: x_path},
              %Anchor.Domain.Graph.Beam{module: ^y, app: :demo},
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain, app: :other}
            ]
     right: [
              %Anchor.Domain.Graph.Beam{
                module: AnchorFixtures.BeamReaderTest.Y,
                app: :demo,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-reads-every-beam-of-every-ebin,-sorted-by-path-e0fddf4a/Elixir.Y.beam",
                elixir: %{
                  attributes: [],
                  module: AnchorFixtures.BeamReaderTest.Y,
                  file: "nofile",
                  deprecated: [],
                  unreachable: [],
                  anno: {1, 1},
                  struct: nil,
                  after_verify: [],
                  defines_behaviour: false,
                  definitions: [],
                  impls: [],
                  compile_opts: [debug_info: true],
                  relative_file: "nofile"
                },
                core: {:c_module, [],
                 {:c_literal, [], AnchorFixtures.BeamReaderTest.Y},
                 [
                   {:c_var, [], {:__info__, 1}},
                   {:c_var, [], {:module_info, 0}},
                   {:c_var, [], {:module_info, 1}}
                 ],
                 [
                   {{:c_literal, [1], :file},
                    {:c_literal, [1], [{~c"nofile", 1}]}},
                   {{:c_literal, [1], :compile},
                    {:c_literal, [1], [:no_auto_import]}},
                   {{:c_literal, [1], :spec},
                    {:c_literal, [1],
                     [
                       {{:__info__, 1},
                        [
                          {:type, 1, :fun,
                           [{:type, 1, :product, [...]}, ...]}
                        ]}
                     ]}}
                 ], ...},
                ...
              },
              ...
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:250: (test)
```

```
  2) test read_ebins/1 one bad file among good ones is an error beside the good beam (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:270
     match (=) failed
     The following variables were pinned:
       z_path = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Z.beam"
     code:  assert [%Beam{module: Plain}, error: %{path: ^z_path, reason: {:unreadable, _reason}}] =
              BeamReader.read_ebins(demo: dir)
     left:  [
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain},
              error: %{path: ^z_path, reason: {:unreadable, _reason}}
            ]
     right: [
              {:error,
               %{
                 module: nil,
                 reason: {:unreadable,
                  {:not_a_beam_file, "garbage"}},
                 path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Z.beam"
               }},
              %Anchor.Domain.Graph.Beam{
                module: AnchorFixtures.BeamReaderTest.Plain,
                app: :demo,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-one-bad-file-among-good-ones-is-an-error-beside-the-good-beam-12927c74/Elixir.Plain.beam",
                elixir: %{
                  attributes: [
                    behaviour: AnchorFixtures.BeamReaderTest.Contract,
                    tag: :hello
                  ],
                  module: AnchorFixtures.BeamReaderTest.Plain,
                  file: "lib/plain.ex",
                  deprecated: [],
                  unreachable: [],
                  anno: {1, 1},
                  struct: [
                    %{default: nil, field: :a, required: false},
                    %{default: 2, field: :b, required: false}
                  ],
                  after_verify: [],
                  defines_behaviour: false,
                  definitions: [
                    {{:run, 1}, :def, [line: 8, column: 7],
                     [
                       {[line: 8, column: 7],
                        [
                          {:x, [version: 0, line: 8, column: 11],
                           nil}
                        ], [],
                        {:helper, [line: 8, column: 19],
                         [
                           {:x, [version: 0, line: 8, column: 26],
                            nil}
                         ]}}
                     ]},
                    {{:helper, 1}, :defp, [line: 10, column: 8],
                     [
                       {[line: 10, column: 8],
                        [
                          {:x, [version: 0, line: 10, column: 15],
                           nil}
                        ], [],
                        {{:., [line: 10, column: 25], ...}, ...}}
                     ]},
                    ...
                  ],
                  ...
                },
                ...
              }
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:278: (test)
```

## BR-P — read_ebins/1 reads every file, not only .beam files

Run summary: `16 tests, 1 failure`

```
  1) test read_ebins/1 reads every beam of every ebin, sorted by path (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:230
     match (=) failed
     The following variables were pinned:
       x = AnchorFixtures.BeamReaderTest.X
       y = AnchorFixtures.BeamReaderTest.Y
     code:  assert [
              %Beam{module: ^x, app: :demo, path: x_path},
              %Beam{module: ^y, app: :demo},
              %Beam{module: Plain, app: :other}
            ] = BeamReader.read_ebins(demo: dir, other: other)
     left:  [
              %Anchor.Domain.Graph.Beam{module: ^x, app: :demo, path: x_path},
              %Anchor.Domain.Graph.Beam{module: ^y, app: :demo},
              %Anchor.Domain.Graph.Beam{module: AnchorFixtures.BeamReaderTest.Plain, app: :other}
            ]
     right: [
              %Anchor.Domain.Graph.Beam{
                module: AnchorFixtures.BeamReaderTest.X,
                app: :demo,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-reads-every-beam-of-every-ebin,-sorted-by-path-e0fddf4a/Elixir.X.beam",
                elixir: %{
                  attributes: [],
                  module: AnchorFixtures.BeamReaderTest.X,
                  file: "nofile",
                  deprecated: [],
                  unreachable: [],
                  anno: {4, 1},
                  struct: nil,
                  after_verify: [],
                  defines_behaviour: false,
                  definitions: [],
                  impls: [],
                  compile_opts: [debug_info: true],
                  relative_file: "nofile"
                },
                core: {:c_module, [],
                 {:c_literal, [], AnchorFixtures.BeamReaderTest.X},
                 [
                   {:c_var, [], {:__info__, 1}},
                   {:c_var, [], {:module_info, 0}},
                   {:c_var, [], {:module_info, 1}}
                 ],
                 [
                   {{:c_literal, [4], :file},
                    {:c_literal, [4], [{~c"nofile", 4}]}},
                   {{:c_literal, [4], :compile},
                    {:c_literal, [4], [:no_auto_import]}},
                   {{:c_literal, [4], :spec},
                    {:c_literal, [4],
                     [
                       {{:__info__, 1},
                        [
                          {:type, 4, :fun,
                           [{:type, 4, :product, [...]}, ...]}
                        ]}
                     ]}}
                 ], ...},
                ...
              },
              ...
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:250: (test)
```

## Traps

- A first run of BR-B, BR-C, CW-H and SF-B failed to compile under `warnings_as_errors` (an unreachable clause, an unused alias, unused variables) and printed no ExUnit summary; the driver records `NO SUMMARY` for such a run, and each mutation was rewritten to compile and re-run. Read a sabotage run's test count, never its exit code alone.

## Added after critic round 4 (merged head 6c9e06c): two error branches with no red

### BR-Q — a core_v1 refusal is reported as an elixir_v1 refusal

Run summary: `18 tests, 1 failure`

```
  1) test decode/2 a backend that refuses core_v1 is {:core_v1_refused, reason} (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:123
     match (=) failed
     code:  assert {:error, %{reason: {:core_v1_refused, :failed_conversion}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{reason: {:core_v1_refused, :failed_conversion}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: {:elixir_v1_refused, :failed_conversion},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:133: (test)
```

### BR-R — an unreadable beam file gets another reason

Run summary: `18 tests, 1 failure`

```
  1) test read_ebins/1 an unreadable beam file is {:unreadable, posix} naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:288
     match (=) failed
     The following variables were pinned:
       path = "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-an-unreadable-beam-file-is---unreadable,-posix--naming-it-1b1cdd76/Elixir.Plain.beam"
     code:  assert [error: %{path: ^path, module: nil, reason: {:unreadable, :eacces}}] =
              BeamReader.read_ebins(demo: dir)
     left:  [error: %{path: ^path, module: nil, reason: {:unreadable, :eacces}}]
     right: [
              error: %{
                module: nil,
                reason: :no_debug_info,
                path: "/home/cjpoll/.local/worktrees/anchor/dnd-5438/tmp/Anchor.Adapters.BeamReaderTest/test-read_ebins-1-an-unreadable-beam-file-is---unreadable,-posix--naming-it-1b1cdd76/Elixir.Plain.beam"
              }
            ]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:301: (test)
```


## Note (after c3c1558): row 7b moved to its own synchronous module

The test "never loads a behaviour the decoded module names, even when it is on the code path" moved from `beam_reader_test.exs` (async) to `beam_reader_code_path_test.exs` (`async: false`). It calls `Code.append_path/1`, which changes the code path for every concurrently running test. The test body is unchanged, so the BR-I and BR-N reds above still hold for it; its module name in those outputs is now `Anchor.Adapters.BeamReaderCodePathTest`.
