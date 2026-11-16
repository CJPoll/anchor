# ADR 004 -- Sabotage Records Carry No Local-Only Text

## Status

Accepted (2026-11-16). Narrows ADR 003's *Failure strings verbatim* for the two
kinds of text below; ADR 003 stays in force for everything else.

## Context

ADR 003 commits a sabotage record beside the suite it describes, with failure
strings copied verbatim. This repository is public, so every record is public
too.

`mix anchor.sabotage run` writes a record from a run's own output. That output
can pick up text that only the machine that ran it knows:

- **Test-scheduler status lines.** A run queued behind a scheduler such as
  `test-slot` prints `test-slot: ...` lines and, while it waits, a block naming
  every run holding the machine: their labels and the paths of their checkouts.
  A record that quotes them names other people's work.
- **Absolute paths under a home or worktree directory.** An ExUnit failure
  often prints a temporary directory or a build path, such as
  `/home/<user>/.local/worktrees/<repo>/<branch>/tmp/<Test>/...`. That names
  the user and the branch the run was on.

Neither tells a later reader anything they need to replay the mutation. Both
were found in records already committed here.

## Decision

### A record never carries a scheduler line or a local path

- A **scheduler line** is a line that starts (after its indent) with
  `test-slot: `, or is one of a WAITING block's holder lines
  (`units ... (N of weight W): ...`, `unit N: held (holder diagnostics ...`),
  its waiting line (`N waiting (this run: ...`) or its `this run is --exclusive`
  line.
- A **local path** is any text from `/home/<user>` or `/Users/<user>` onward,
  wherever it appears in a line, or from `~/.local/worktrees` onward.

### Generated records are redacted when they are written

`Anchor.Domain.Sabotage.Record.render/2` runs every file's content through
`Anchor.Domain.Sabotage.RecordHygiene.redact_record/2`. A mutant's ` ```diff `
block and the ` ```anchor-kills ` block are the project's own source and test
names, in every checkout, so they are kept as written. Everywhere else:

- a scheduler line is dropped;
- a path under the run's root is written relative to the root, and the root
  itself as `.`;
- any other path under `.local/worktrees/` becomes `<worktree>` plus its path
  from the first project directory (`_build`, `deps`, `lib`, `test`, `tmp`,
  `apps`, `priv`, `config`) on;
- any other home path becomes `<home>` plus the same tail.

This is the one exception to ADR 003's *Failure strings verbatim*. A failure
string is copied verbatim except for those lines and paths.

### Hand-written records follow the same rule

Write a path relative to the project root, and leave scheduler output out.

### The gate

`test/anchor/sabotage_record_hygiene_test.exs`, part of `mix test`, fails on any
record under `test/sabotage_records/` that carries either kind of text outside
those two blocks (`RecordHygiene.record_leaks/1`).

Records committed before the redaction are listed in
`.anchor/sabotage/record_leaks.txt`, and the list only shrinks. The test also
fails on:

- an entry whose file no longer leaks, or is gone;
- an entry dated after the newest file on the list when the list landed;
- an entry its own pinned copy of the list does not hold.

Growing the list therefore means editing the test, which is loosening the
check.

## Examples

### Correct

```
test/anchor/adapters/beam_reader_test.exs:42 test reads a beam
** (ExUnit.AssertionError)
left:  "tmp/Anchor.Adapters.BeamReaderTest/test-reads-a-beam/Elixir.X.beam"
right: "<worktree>/tmp/Anchor.Adapters.BeamReaderTest/test-reads-a-beam/Elixir.Y.beam"
47 tests, 1 failure
```

### Incorrect

```
left:  "/home/alice/.local/worktrees/repo/branch-x/tmp/Anchor.Adapters.BeamReaderTest/..."
47 tests, 1 failure
test-slot: WAITING for 8 unit(s) -- cpu pool ..., 8 held:
  units 1-8 (8 of weight 8): ticket-1234 gate in /home/bob/.local/worktrees/repo/ticket-1234 since ...
```

## Consequences

### Benefits

- A record names no user, no checkout and no other run, wherever it was
  generated.
- A leak is caught by `mix test` in CI, not by a reader of a public repository.
- The redaction is in the one writer, so no caller can forget it.

### Tradeoffs

- Failure strings are no longer byte-for-byte what the run printed. A path is
  relative, or shortened to `<worktree>/...` or `<home>/...`, so a reader
  replaying a record compares the project path, not the absolute one.
- Shortening keeps the path from the first project directory on. A branch
  whose name contains a project directory's name past its first segment keeps
  those later segments.
- Failure output can quote a test's own code. A home path written as a literal
  in a failing assertion is rewritten like one the run printed, because nothing
  tells them apart; the test file holds the original.
- A scheduler line glued to the end of another line, with no newline between
  them, is not recognised. Neither is a home directory outside `/home/` and
  `/Users/` (such as `/root`), and a user name with a space in it keeps the
  text after the space.
- The records listed in `.anchor/sabotage/record_leaks.txt` still hold their
  leaks, and so does git history. Removing them is a separate decision.

## Enforcement

- `test/anchor/sabotage_record_hygiene_test.exs`, in `mix test` (CI's Test
  step).
- `RecordHygiene.redact/2`, in `Record.render/2`, for every generated record.

## References

- ADR 003 (`003-sabotage-records-one-file-per-run.md`): the records and their
  required content, narrowed here.
- ADR 002 (`002-fast-comprehensive-high-signal-tests.md`): the sabotage rule
  the records serve.
- `lib/anchor/domain/sabotage/record_hygiene.ex`: the rules.
