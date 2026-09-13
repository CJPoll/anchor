# ADR 002 -- Fast, Comprehensive, High-Signal Tests

## Status

Accepted. Ported from walt_ui `adrs/002-fast-comprehensive-high-signal-test-suites.md`
and `backend/adrs/018-fast-comprehensive-high-signal-tests.md` on 2026-09-12,
adapted for a single Mix library.

## Context

A test suite has three properties worth paying for, and they are usually
discussed as if they trade off against each other:

- **Fast** — it runs often enough that people run it before pushing. For Anchor
  that means a plain `mix test` completing quickly on a laptop.
- **Comprehensive** — it covers the behaviour that matters, including the
  refusals. For a linter, "the refusals" are the cases a check is supposed to
  *flag*, not only the clean code it is supposed to pass.
- **High-signal** — when it is green that means something, and when it is red it
  names what broke.

They mostly do not trade off. Most of what makes a suite slow is *arrangement*
that never needed to be exercised, and most of what makes a suite low-signal is
an assertion that cannot fail. This ADR is those two ideas written down as rules
Anchor's suite follows.

Anchor's stakes are specific: it is a tool that *flags other people's
architectural mistakes*. A check that passes when it should fail does not merely
lose coverage of its own behaviour — it silently green-lights a violation in
every downstream project that trusts it. So the sabotage discipline below is not
optional polish; it is the only thing that distinguishes "this check works" from
"this check has never been observed to reject anything."

## Decision

The suite is automated (`mix test`), lives in one `test/` tree, and is shaped
like the testing pyramid. The bucket vocabulary is ADR 001's.

### Per-bucket rules

- **Domain** — tested extremely thoroughly. This is the broad base. For Anchor,
  `Anchor.DependencyAnalyzer` is pure and cheap to test with hand-built or
  fixture ASTs; it should be exercised across direct dependencies, `use`
  detection, aliased and dotted references, and transitive-closure edge cases
  (cycles, missing nodes, self-reference).
- **Adapters (Side Effects)** — test only the conversions: the shape that comes
  off the boundary, and the Domain object that goes back. For
  `Anchor.Adapters.ConfigFile` that is: given YAML content, the parsed
  `%Anchor.Config{}` has the right rules; given a missing file, the documented
  default. The IO itself is not the subject. (The pure parsing that turns a
  decoded YAML map into `%Anchor.Config{}` lives in the Domain module
  `Anchor.Config` and is tested exhaustively there, per the Domain bullet
  above.)
- **Managers** — mock the adapters, assert the expected value comes back. Where
  Anchor's orchestration loads config and runs analysis, a Manager test stubs
  the config load and checks the analysis is driven correctly.
- **Framework** — for Anchor, the `Anchor.Check.*` modules. Test them through
  Credo's own test harness (`Credo.Test.Case`): given source text and rules,
  assert the check produces the expected issues (and, just as importantly, *no*
  issues on clean code).
- **UI Components** — **not applicable.** Anchor has no UI.
- **E2E** — rare. For Anchor, an end-to-end test is running the real checks
  against a real `.anchor.yml` over sample source; keep these to the few
  critical paths.

### Arrange with fixtures; assert through the real path

Decide what a test is **about**, and buy only that. A test *about* the analyzer
drives the real analyzer on a real AST. A test that merely *needs an AST to
exist* builds it by the cheapest faithful means. "It went through the real path"
is a cost, worth paying exactly where that path is the thing under test.

### Sabotage (mutation) testing is mandatory

**A test is not finished until you have watched it fail.** Once a test is green,
delete the thing it exists to prove, run it, confirm the failure names the right
criterion, and put the thing back.

"The thing it exists to prove" is broad. For a linter it is most often the
*detection itself*:

| Shape | What deleting it looks like |
|---|---|
| The condition that flags a violation | make the check emit no issue for the bad input |
| A pattern in a function head | drop the specific head, let a catch-all take it |
| A `with` clause | replace with `_ <- expr`, so the `else` is never reached |
| A cap, an ordering, an allowlist | remove the bound and let the input through |
| A `when` clause | delete the `when` |

Green only proves the test *can* pass. Red under sabotage is the only thing that
proves the test is about the thing it says it is about — and a test that passes
either way is worse than no test, because it is read as evidence.

#### Sabotage a match so the case walks through

For anything match-shaped — a `when` clause, a function-head pattern, a `case`
branch, a `with` chain — sabotage it so the case **gets through**, not so
everything fails:

```elixir
# The original
def flag?(%{type: :no_direct_dependency} = rule, deps) when rule.forbidden != []

# ✅ sabotage — the case walks through (a forbidden dep is no longer flagged)
def flag?(%{type: :no_direct_dependency} = rule, deps)

# ❌ sabotage — takes a branch the error tests already cover
def flag?(%{type: :no_direct_dependency} = rule, deps) when false
```

A check like this exists to catch a case, so the bug is "the case walks
through", not "everything fails."

#### A refactor that removes a hazard needs a *paired* mutation

When the change under review is a refactor claiming a class of failure is now
impossible, the outcome you want is **green** — and a green run is exactly what
a no-op change also produces. Run the mutation twice: once against the
refactored code, once against the pre-refactor version reconstructed from git,
and record both. Neither half is evidence alone.

#### Ways a run lies about this

These are the general traps that apply to any ExUnit suite, Anchor's included:

- **`--warnings-as-errors` fails the compile, not the test.** If the suite is
  run with warnings-as-errors, a sabotage that leaves an unused variable or an
  unreachable clause stops the *build* — the tests never ran, and the red reads
  as the check being load-bearing when it is not. Confirm that what failed was
  an assertion. Prefer a mutation that keeps the code well-formed (pass a wrong
  value rather than deleting a parameter), or delete the now-orphaned alias in
  the same edit.
- **Deleting a function clause outright often fails the compile, not the test.**
  If the clause's body is the only caller of a private helper, deleting it
  orphans the helper and warnings-as-errors stops the build. Narrow the clause's
  **head** to a value the input can never produce instead: the case falls
  through to the catch-all, every helper stays referenced, and the red lands on
  the assertion.
- **A compile error is not a test failure.** More generally, any sabotage that
  makes the code fail to compile has told you nothing about test coverage.
  Read *which* thing went red before believing it.
- **`stub` does not self-prove; `expect` does.** With a mocking library
  (Anchor's tests use Hammox; Mox/Hammox behave the same way here), an
  `expect/3` verifies on exit, so deleting the call under test makes
  verification fail — the test proves itself. A `stub/3` does not verify: a test
  built on `stub` passes with the call gone entirely. Check which one a
  mock-based test uses before trusting it.
- **`refute`-shaped assertions pass when the whole mechanism is broken.** A
  `refute`, a `refute_receive`, an `assert [] == …` is satisfied by a process
  or a check that never ran at all, not merely by the absence of the thing it
  guards against. For a linter this is the sharpest trap: a test asserting "no
  issues on clean code" (`assert [] == issues`) also passes when the check is
  completely broken and emits nothing on *anything*. Every such test needs a
  paired positive test proving the same check *does* flag the bad input — the
  positive control.
- **A positive control is mandatory where a test asserts an absence.** An
  assertion that a check finds nothing is worthless without a sibling asserting
  the check finds the violation it is supposed to. Three of four comparisons can
  survive the deletion of their own subject when the subject silently fails to
  exist; only a positive control catches it.
- **Assert on the payload, not merely that something arrived.** A loose
  predicate ("an issue was produced") still passes when the sabotage changes
  *what* is produced rather than *whether*. Assert on the issue's message, line,
  or trigger — the discriminating detail — not only on the count.
- **Restoring a backup can lie.** `git checkout -- path` restores the
  *committed* state, not your pre-sabotage working state — on a file with
  uncommitted work it silently deletes the change under test. And `cp file
  file.bak` → mutate → `mv file.bak file` rewinds the file's mtime, so the next
  `mix compile` skips it and keeps the sabotaged beam. Back up with `cp` (which
  stamps a fresh mtime on restore), commit new files before sabotaging them, and
  verify a restore by grepping for a function that belongs in the file rather
  than trusting a clean `git status`.

### Watch every test fail, and write the failure down — including the zeros

**A mutation that reds nothing is a finding, not a failure of the exercise.**
Record it as a measured zero with the reason. Either the check is not
load-bearing — and the row is now a bug report — or the value is genuinely
prospective, which is a real answer a deleted row would have hidden.

Records are kept per ADR 003 (`003-sabotage-records-one-file-per-run.md`), in
`test/sabotage_records/`, with the failure string copied verbatim.

### Never use `Process.sleep/1` for timing, and never `Application.put_env/3`

Absolute. A sleep is a guess that fails on a loaded machine and passes on a fast
one; `Application.put_env/3` (and its twin `Application.delete_env/2`) mutate
global state other tests read, and the mutation outlives the test that made it.
Anchor's tests are pure enough to need neither — nothing here should ever reach
for global config mutation or a timing guess.

## Examples

### Correct

A Domain test drives the real analyzer and asserts the discriminating value:

```elixir
test "extracts a dotted-call dependency" do
  ast = quote do: MyApp.Repo.insert(record)
  assert MyApp.Repo in Anchor.DependencyAnalyzer.extract_direct_dependencies(ast)
end
```

A check test carries both the positive case and the clean case:

```elixir
test "flags a forbidden direct dependency" do
  source
  |> to_source_file()
  |> run_check(Anchor.Check.NoDependency, forbidden_modules: [MyApp.Repo])
  |> assert_issue(fn issue -> issue.trigger == "MyApp.Repo" end)   # positive control
end

test "passes clean code" do
  clean_source
  |> to_source_file()
  |> run_check(Anchor.Check.NoDependency, forbidden_modules: [MyApp.Repo])
  |> refute_issues()   # meaningless WITHOUT the positive test above
end
```

### Incorrect

An absence assertion with no positive control — green when the check is
completely broken:

```elixir
test "the check is fine" do
  source |> to_source_file() |> run_check(Anchor.Check.NoDependency, []) |> refute_issues()
end
```

Asserting only the count, blind to what was actually flagged:

```elixir
assert length(issues) == 1   # passes even if it flagged the wrong module for the wrong reason
```

## Consequences

### Benefits

- **Green means something.** A positive control and an assertion on the
  discriminating payload are what stand between "this check works" and "this
  check has never rejected anything."
- **Speed stays cheap.** Anchor's Domain is pure and its fixtures are small
  ASTs; there is no database, no network, no framework boot to pay for.
- **A broken check becomes a red, not a silent pass** in every downstream
  project — which, for a linter, is the whole point.

### Tradeoffs

- **Positive controls and payload assertions are more code**, and some of it
  reds nothing today (the measured zeros). Prospective value is still value, but
  it is paid for now.
- **Judgement remains.** "What is this test about?" is not mechanical, and
  nothing here decides it for you.

## Enforcement

- **Code review.** The questions worth asking on a test diff: what is this test
  *about*? Could this assertion be satisfied by an absence (a broken check
  emitting nothing)? Is there a positive control beside every "passes clean
  code" test?
- **The sabotage requirement** above, and the per-run records under ADR 003,
  which make a claim auditable later rather than folk memory.
- There is no ADR review bot in this repository; enforcement is manual review
  plus Anchor's own test discipline.

## References

- walt_ui `adrs/002-fast-comprehensive-high-signal-test-suites.md` and
  `backend/adrs/018-fast-comprehensive-high-signal-tests.md` — the source ADRs.
- ADR 001 (`001-five-bucket-architecture.md`) — the buckets these testing rules
  are organized around.
- ADR 003 (`003-sabotage-records-one-file-per-run.md`) — where the sabotage
  records live and what they must contain.
- `test/anchor/dependency_analyzer_test.exs`, `test/anchor/config_test.exs`,
  `test/anchor/check/` — the suite these rules apply to.
