# Sabotage record — compile options allowlisted, deny by default (DND-5552)

- **Domain:** beam_reader
- **Branch:** dnd-5551-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Adapters.BeamReader` (`safe_compile_options/3`, `safe_option?/1`, `warning_option?/1`, `@safe_atoms`, `@safe_keys`)
- **Suite run:** `mix test --timeout 2000 --max-cases 2 test/anchor/adapters/beam_reader_test.exs`

Each mutation replaced one exact text in the named file, the suite ran, and the file was restored from its saved copy (the driver prints `git status` after the run; only this branch's own edits were listed).

Traps seen: CO-E's first form compared a string with an atom, a typing warning that does not compile under warnings-as-errors; the row is the second form. A first CO-E rerun piped through `head -1`, which closed the pipe early; the tree was checked clean (no mutation left) and the run repeated without the pipe.

Found while writing the tests: `:warnings_as_errors` is not on the allowlist. It runs no code, but on a module with any warning the backend's lowering fails (`{:core_v1_refused, :failed_conversion}`), which would name the wrong cause, so it is refused by name instead.

| # | Mutation | Tests failed | Failing test |
|---|---|---|---|
| CO-A | back to a denylist: every non-transform option is safe (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 any other compile option is refused, naming it |
| CO-B | any atom option is safe (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 any other compile option is refused, naming it |
| CO-C | debug_info with any value (a backend tuple) is safe (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 any other compile option is refused, naming it |
| CO-D | the transform check runs after the option check, so a transform reads as an unknown option (`lib/anchor/adapters/beam_reader.ex`) | 2 | decode/2 a transform is named as one even after an unknown option; decode/2 a module compiled with a transform is refused, naming it |
| CO-E | warning options are not recognised (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 every known-safe compile option decodes |
| CO-F | the allowlist forgets no_warn_undefined (`lib/anchor/adapters/beam_reader.ex`) | 1 | decode/2 every known-safe compile option decodes |

## CO-A — back to a denylist: every non-transform option is safe

Run summary: `20 tests, 1 failure`

```

  1) test decode/2 any other compile option is refused, naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:151
     match (=) failed
     The following variables were pinned:
       option = {:nowarn_unused_vars, :extra, :arity}
     code:  assert {:error, %{reason: {:core_v1_refused, {:option, ^option}}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{reason: {:core_v1_refused, {:option, ^option}}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: %Anchor.Domain.Graph.Beam{
              module: AnchorFixtures.BeamReaderTest.Plain,
              app: :demo,
              path: "x.beam",
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
                      [{:x, [version: 0, line: 8, column: 11], nil}],
                      [],
                      {:helper, [line: 8, column: 19],
                       [
                         {:x, [version: 0, line: 8, column: 26],
                          nil}
```

## CO-B — any atom option is safe

Run summary: `20 tests, 1 failure`

```

  1) test decode/2 any other compile option is refused, naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:151
     match (=) failed
     The following variables were pinned:
       option = :from_core
     code:  assert {:error, %{reason: {:core_v1_refused, {:option, ^option}}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{reason: {:core_v1_refused, {:option, ^option}}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: %Anchor.Domain.Graph.Beam{
              module: AnchorFixtures.BeamReaderTest.Plain,
              app: :demo,
              path: "x.beam",
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
                      [{:x, [version: 0, line: 8, column: 11], nil}],
                      [],
                      {:helper, [line: 8, column: 19],
                       [
                         {:x, [version: 0, line: 8, column: 26],
                          nil}
```

## CO-C — debug_info with any value (a backend tuple) is safe

Run summary: `20 tests, 1 failure`

```

  1) test decode/2 any other compile option is refused, naming it (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:151
     match (=) failed
     The following variables were pinned:
       option = {:debug_info, {AnchorFixtures.NoSuchBackend, :data}}
     code:  assert {:error, %{reason: {:core_v1_refused, {:option, ^option}}, module: Plain}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error,
             %{reason: {:core_v1_refused, {:option, ^option}}, module: AnchorFixtures.BeamReaderTest.Plain}}
     right: %Anchor.Domain.Graph.Beam{
              module: AnchorFixtures.BeamReaderTest.Plain,
              app: :demo,
              path: "x.beam",
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
                      [{:x, [version: 0, line: 8, column: 11], nil}],
                      [],
                      {:helper, [line: 8, column: 19],
                       [
                         {:x, [version: 0, line: 8, column: 26],
                          nil}
```

## CO-D — the transform check runs after the option check, so a transform reads as an unknown option

Run summary: `20 tests, 2 failures`

```



  1) test decode/2 a transform is named as one even after an unknown option (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:177
     match (=) failed
     The following variables were pinned:
       transform = {:parse_transform, :anchor_fixtures_no_such_transform}
     code:  assert {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}}} =
              BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
     left:  {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}}}
     right: {:error,
             %{
               module: AnchorFixtures.BeamReaderTest.Plain,
               reason: {:core_v1_refused, {:option, :something_new}},
               path: "x.beam"
             }}
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:185: (test)

....
```

## CO-E — warning options are not recognised

Run summary: `20 tests, 1 failure`

```

  1) test decode/2 every known-safe compile option decodes (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:123
     :nowarn_unused_vars: {:error, %{module: AnchorFixtures.BeamReaderTest.Plain, reason: {:core_v1_refused, {:option, :nowarn_unused_vars}}, path: "x.beam"}}
     code: for option <- options do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/adapters/beam_reader_test.exs:142: (test)

................
```

## CO-F — the allowlist forgets no_warn_undefined

Run summary: `20 tests, 1 failure`

```

  1) test decode/2 every known-safe compile option decodes (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:123
     {:no_warn_undefined, Foo}: {:error, %{module: AnchorFixtures.BeamReaderTest.Plain, reason: {:core_v1_refused, {:option, {:no_warn_undefined, Foo}}}, path: "x.beam"}}
     code: for option <- options do
     stacktrace:
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       (elixir 1.19.4) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
       test/anchor/adapters/beam_reader_test.exs:142: (test)

.........
```

