# ADR 003 -- One File Per Sabotage Run, Beside the Suite It Describes

## Status

Accepted. Ported from walt_ui `backend/adrs/017-sabotage-records-one-file-per-run.md`
on 2026-09-12, adapted for a single Mix library.

## Context

ADR 002 states the rule that produces these records: *a test is not finished
until you have watched it fail.* Delete the thing the test exists to prove, run
it, confirm the failure names the right criterion, put the thing back — and
**write the failure string down next to the claim it supports**. The reason for
writing it down is auditability: someone changing the check later can re-apply
the same mutation and compare. Without the record, "this was verified once" is
folk memory.

The record therefore has to be tracked in git, and it has to be findable at the
moment it matters — which is when someone is about to weaken a check and needs
to know what mutation last proved it. Two container shapes were considered and
rejected in the source project, for reasons that hold here too:

- A single append-only `SABOTAGE_RECORDS.md` grows without bound, has no unit of
  retrieval, is not addressable by subject, and conflicts on nearly every rebase
  because every branch appends at the same EOF line — where the autopilot "keep
  both sides" resolution silently drops sections.
- Records left in a gitignored scratch directory stop existing the moment the
  branch leaves the machine that produced them.

So records live in one file per run, in a directory beside the suite, named so
that a bare `ls` clusters them by subject.

## Decision

### Records live in `test/sabotage_records/`

Anchor is a single Mix app with one `test/` tree, so there is one
`sabotage_records/` directory:

```
test/sabotage_records/
```

It is created when the first record lands in it; there are no empty
placeholders. (The umbrella multiplicity of the source ADR — one
`sabotage_records/` per app — does not apply: Anchor has one test root.)

### Filename: `<domain>-YYYYMMDD-<sanitized-branch>.md`

Three parts, two hyphens, and no part may contain a hyphen — so the name always
splits cleanly.

- **`<domain>`** — the check or area the mutated code belongs to, lowercase
  `snake_case`. This is **derived, not invented**: it is the name of the check
  or module under test, with the `Anchor.Check.` / `Anchor.` prefix dropped and
  the rest lowercased. So `dependency_analyzer`, `config`,
  `no_transitive_dependency`, `no_dependency`, `must_use_module`,
  `single_control_flow`, `struct_getter_convention`, and so on. Code that maps
  to no single check takes the nearest honest concept (`config`, `analysis`),
  and the directory's `README.md` records it so the next run reuses the word
  instead of coining a synonym.
- **`YYYYMMDD`** — the date the sabotage run was *performed*, UTC, no
  separators. Not the commit date, not the merge date; the record describes a
  run, and the run has one date.
- **`<sanitized-branch>`** — the branch the run happened on, with every
  character outside `[A-Za-z0-9]` replaced by `_`, runs of `_` collapsed to one,
  and leading/trailing `_` trimmed. Case is preserved, so ticket keys stay
  readable.

| Domain | Branch | Filename |
|---|---|---|
| `dependency_analyzer` | `adrs/seed-from-walt-ui` | `dependency_analyzer-20260912-adrs_seed_from_walt_ui.md` |
| `no_transitive_dependency` | `fix/cycle-detection` | `no_transitive_dependency-20260912-fix_cycle_detection.md` |
| `config` | `feat/umbrella-paths` | `config-20260912-feat_umbrella_paths.md` |

Compute the last two parts rather than typing them:

```bash
printf '%s-%s.md\n' \
  "$(date -u +%Y%m%d)" \
  "$(git rev-parse --abbrev-ref HEAD | sed 's/[^A-Za-z0-9]\{1,\}/_/g; s/^_//; s/_$//')"
```

### Domain leads, because that is what the reader knows first

Whoever is about to change a check knows *which check* before they know any
date, ticket, or branch. Leading with the domain makes a bare `ls` cluster every
record for that check together, and makes the glob that finds them the most
obvious string in the task:

```bash
ls test/sabotage_records/no_transitive_dependency-*
```

Date second keeps the ordering that matters — within a domain, records read
newest-last, so the most recent measurement of a check is the last line of the
cluster. Branch last is the re-run handle, and the part most likely to go stale.

### One file per domain, per branch, per day

A second run on the same branch, same day, same domain appends a new `##`
section to the existing file. There is no numeric suffix and no collision rule,
because two branches cannot write the same path unless they are the same branch,
the same day, in the same domain. A run that spans two domains writes two files,
split by domain, so a reader arriving from one domain need not skip the other's
mutations to find theirs.

### Required content

Every record opens with a header block, so the run can be reconstructed and so
the domain is greppable from inside the file as well as from its name:

```markdown
# Sabotage record — NoTransitiveDependency cycle handling

- **Domain:** no_transitive_dependency
- **Branch:** fix/cycle-detection
- **Date:** 2026-09-12
- **Code under test:** `Anchor.Check.NoTransitiveDependency`, `Anchor.DependencyAnalyzer.find_transitive_dependencies/3`
- **Suite run:** `mix test test/anchor/check/no_transitive_dependency_test.exs`
```

The body:

- **A mutation table** — mutation, tests that failed, failure string. Label
  mutations (`A`, `B`, …) when the prose below refers back to them.
- **Failure strings verbatim**, copied from the run, including the `left:` /
  `right:` lines. A paraphrase ("the assertion failed") is not re-runnable and
  is not a record.
- **Measured zeros recorded as zeros.** A mutation that reddened nothing marks a
  claim no test protects. Those are the most valuable rows in the file and are
  never quietly deleted — if the gap is later closed, the zero stays and the fix
  is recorded beneath it.
- **Rows that stayed green, and why.** A test that does not move under a
  mutation is about a different property; saying so stops it being read as
  coverage it does not provide.
- **Traps** — any run that lied (a compile failure that read as a test failure,
  a restore that silently did not restore). ADR 002 catalogues the known ones; a
  record adds to that catalogue when it finds a new one.

Two header fields are easy to conflate, and the difference is what makes a
record replayable:

- **`Code under test`** is the production module or path the mutation is applied
  to — the thing you break. If a run mutates more than one, name them all.
- **`Suite run`** is the command run afterwards, which is often a *different*
  file: a mutation to `Anchor.DependencyAnalyzer` is frequently verified by a
  check's test file. Naming the suite here is what lets a later reader re-apply
  the mutation from the header alone.

### No index file

The directory gets a `README.md` describing the *convention* and listing the
domain words already in use — never a list of its contents. An index of the
records would be a shared, append-only file that every branch edits at the same
place, which is precisely the artifact this ADR removes. Discovery is the
filesystem:

```bash
ls test/sabotage_records/config-*                       # by domain
grep -rl 'find_transitive_dependencies' test/sabotage_records/   # by module
grep -rn 'measured zero' test/sabotage_records/          # by theme
```

### Read the matching records before weakening a check

That is the moment these records exist for. Before changing or relaxing a check,
`ls test/sabotage_records/<that-check>-*` and read what mutations last proved it
— and pay particular attention to the rows recording a **zero**, which tell you
a claim has no test behind it.

### Cite the record file, not the directory

Inline comments in tests name the specific record. From a test file the relative
path is short, because the records are in the same tree:

```elixir
# Sabotage record: ../sabotage_records/no_transitive_dependency-20260912-fix_cycle_detection.md
```

## Examples

### Correct

```
test/sabotage_records/dependency_analyzer-20260912-adrs_seed_from_walt_ui.md
```

```markdown
# Sabotage record — direct-dependency extraction

- **Domain:** dependency_analyzer
- **Branch:** adrs/seed-from-walt-ui
- **Date:** 2026-09-12
- **Code under test:** `Anchor.DependencyAnalyzer.extract_direct_dependencies/1`
- **Suite run:** `mix test test/anchor/dependency_analyzer_test.exs`

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| A | drop the dotted-call clause of `extract_module_references/2` | 3 | `Assertion with in failed ... left: MyApp.Repo, right: [MyApp]` |
| B | return `visited` before recursing in `find_transitive_dependencies/3` | **0** | — see below |

**B — a measured zero.** No test exercises a dependency chain deeper than one
hop, so cutting the recursion changes nothing observable. The transitive check
has no test protecting its depth; companion test added in this pass.
```

### Incorrect

```
20260912-seed.md                          # no domain: findable only by grep
sabotage-2026-09-12-config.md             # hyphens inside the parts; does not split
config_20260912_seed.md                   # parts no longer separable
Config-20260912-seed.md                   # domain must be lowercase snake_case
adrs/sabotage_records/…                   # outside the test tree it describes
```

```markdown
| Mutation | Tests failed | Failure string |
|---|---|---|
| Broke the check | some | the assertion failed |   <!-- not re-runnable -->
```

## Consequences

### Benefits

- **A record is findable from the code it protects.** The domain prefix is the
  word the reader already has, and the directory is inside the test tree they
  are already in. `ls test/sabotage_records/<check>-*` is the whole retrieval
  story.
- **The rebase conflict becomes structurally impossible.** Two branches cannot
  write the same path unless they are the same branch, the same day, the same
  domain.
- **Every record carries its own provenance.** Domain, date and branch are in
  the name; the header block adds the exact suite command, which is what
  re-running a mutation needs.
- **Writing a record gets cheaper.** A new file with a short header costs nothing
  to start, and nothing already in the directory has to be read first.

### Tradeoffs

- **The domain word has to be chosen, and can be chosen badly.** Deriving it from
  the check or module name removes most of the freedom, and the `README.md`
  vocabulary list absorbs the rest — but a genuinely cross-cutting run is a
  judgement call, and two runs can still land on synonyms. Reuse an existing word
  before coining one.
- **Cross-cutting reading becomes `grep`, not scrolling.** A theme that spans
  many passes no longer accumulates in one place; one `grep -rn` over
  `test/sabotage_records/` answers it.
- **A renamed branch leaves a filename pointing at nothing.** The domain, the
  date, and the header carry the record when the branch name stops resolving.

## Enforcement

- **Reviewers** treat a test-touching change with no matching record as
  incomplete. The record is part of the diff, not a follow-up: it is written
  while the failure strings are still on screen, and cannot be reconstructed
  afterwards.
- **Deliberately not a mechanical gate.** A "a file exists in
  `sabotage_records/`" check rewards an empty file, and the properties actually
  worth enforcing — verbatim failure strings, honest zeros, a mutation that made
  the case *walk through* rather than fail everything — are not lint-shaped.
- The **naming** rule is the one mechanically checkable part, should it ever need
  to be: `^[a-z0-9_]+-[0-9]{8}-[A-Za-z0-9_]+\.md$`.

## References

- ADR 002 (`002-fast-comprehensive-high-signal-tests.md`) — the sabotage rule
  this ADR gives a home to, and the catalogue of ways a sabotage run lies about
  its own result.
- walt_ui `backend/adrs/017-sabotage-records-one-file-per-run.md` — the source
  ADR this is ported from.
- `test/sabotage_records/README.md` — the working convention and the domain
  vocabulary already in use (created with the first record).
