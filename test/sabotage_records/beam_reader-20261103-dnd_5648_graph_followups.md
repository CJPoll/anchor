# Sabotage records: beam_reader (branch dnd-5648-graph-followups)

- **Domain:** beam_reader
- **Branch:** dnd-5648-graph-followups
- **Date:** 2026-11-03
- Each section's rows were run with another record's suite run, which it names; they are filed here by the module they mutate (ADR 003).

## DND-5633: a dynamic call narrowed to a declared behaviour's implementers (DY-N)

**Run with:** the `## DND-5633: a dynamic call narrowed to a declared behaviour's implementers` section of `layering-20261103-dnd_5648_graph_followups.md`, which names the code under test and the suite run; filed here by the module mutated.

| ID | Mutation | Tests | Result | Failing tests |
|---|---|---|---|---|
| DY-N | the reader drops the callbacks (`lib/anchor/adapters/beam_reader.ex`) | `beam_reader_test.exs` | `21 tests, 1 failure` (red) | decode/2 reads the callbacks a behaviour declares, sorted; none is [] |

### DY-N: the reader drops the callbacks

Run summary: `21 tests, 1 failure`

```text


  1) test decode/2 reads the callbacks a behaviour declares, sorted; none is [] (Anchor.Adapters.BeamReaderTest)
     test/anchor/adapters/beam_reader_test.exs:52
     Assertion with == failed
     code:  assert callbacks == ["MACRO-expand": 2, check: 2, run: 1]
     left:  []
     right: ["MACRO-expand": 2, check: 2, run: 1]
     stacktrace:
       test/anchor/adapters/beam_reader_test.exs:63: (test)

...
```
