# Sabotage record — the test-time aggregate backstop (DND-5480)

- **Domain:** backstop
- **Branch:** dnd-5480-test-backstop
- **Date:** 2026-11-06
- **Code under test:** `Anchor.Domain.Aggregates.Backstop`, `Anchor.Domain.Aggregates.QueryStatement`,
  `Anchor.Adapters.TelemetryRecorder`, `Anchor.Adapters.EctoTransactionProbe`,
  `Anchor.Managers.Backstop`, `Anchor.Backstop`
- **Run at:** e2c4d65 (the ticket's implementation commit), with the D4 test "a write outside a
  transaction beside a transaction's write joins no transaction" removed first: no mutation of the
  code could tell it apart from D3 and D4, so it proved nothing of its own.
- **Suite run:** per row, one mutation applied by a script, then
  `mix test --force --timeout 2000 --max-cases 2` over the eight backstop test files
  (`test/anchor/domain/aggregates/backstop_test.exs`, `query_statement_test.exs`,
  `test/anchor/adapters/ecto_transaction_probe_test.exs`, `telemetry_recorder_test.exs`,
  `telemetry_recorder_session_test.exs`, `test/anchor/managers/backstop_test.exs`,
  `test/anchor/backstop_test.exs`, `test/anchor/integration/backstop_integration_test.exs`),
  through `test-slot`, and the file restored. 73 tests, green before and after every row.

Every one of the 73 tests failed under at least one row. The QA plan's six required sabotages
are S1 (D3), S2 (D4), S3 (R1), S4 (R3; R4 is S53), S5 (M4) and S6 (M2). One mutant first failed
to compile (S18: an unused alias under warnings-as-errors); it was rewritten so the alias stays
used, and the row below is the rewritten run.

| # | Mutation | Tests failed | First failure, verbatim |
|---|---|---|---|
| S1 | `Aggregates.Backstop`: every judged write of a test read as one transaction | 4 of 73: verdict/2 D2: one transaction writing A and B is one crossing, one table each; verdict/2 two crossing transactions are two crossings, in the order of their first write; verdict/2 D3: A and B written in two separate transactions are no crossing; I1: orders and invoices in two transactions pass, and the summary counts the test | `Assertion with == failed code:  assert crossing == %{tx: r1, aggregates: ["A", "B"], tables: %{"A" => "orders", "B" => "invoices"}}` |
| S2 | `Aggregates.Backstop`: writes outside a transaction judged as one transaction | 2 of 73: verdict/2 D4: A and B written outside any transaction are no crossing, and are counted; verdict/2 each event is read once, by the first row that matches | `Assertion with == failed code:  assert Backstop.verdict(events, @index) == %{` |
| S3 | `TelemetryRecorder`: the handler stores the whole metadata map | 1 of 73: R1: a watched test's write is recorded with its table and kind, and no parameter | `Refute with =~ failed code:  refute inspect(:ets.tab2list(recorder.table), limit: :infinity) =~ Meta.secret()` |
| S4 | `TelemetryRecorder`: an unwatched process's write recorded as its own test's | 4 of 73: R3: an unwatched process's write is not recorded, and is counted unattributed; R1: a transaction's writes carry its ref; take forgets them and the pid; R2: the first watched pid in $callers owns the write; R2: a write from a process with the test in $callers is recorded as another process's | `Assertion with == failed code:  assert Recorder.take_events(recorder, other) == []` |
| S5 | `Managers.Backstop`: a detached handler ignored | 1 of 73: verdict!/3 M4: a detached handler fails the test, whatever was recorded | `Expected exception ExUnit.AssertionError but got Mox.UnexpectedCallError (no expectation defined for Anchor.WriteRecorderMock.add_counts/2 in process #PID<0.2727.0> with args [%{table: :fake, handler: :fake, event: [:app` |
| S6 | `Managers.Backstop`: zero declared aggregates allowed | 2 of 73: start/2 M2: zero declared aggregates raises: the backstop checks nothing; start/2 M2: declare: none raises: the backstop checks nothing | `Expected exception ArgumentError but got Mox.UnexpectedCallError (no expectation defined for Anchor.WriteRecorderMock.attach_recorder/2 in process #PID<0.2714.0> with args [[:app, :repo, :query], Anchor.Adapters.EctoTran` |
| S7 | `TelemetryRecorder`: a $callers process's write recorded as the test's own | 2 of 73: R2: the first watched pid in $callers owns the write; R2: a write from a process with the test in $callers is recorded as another process's | `match (=) failed The following variables were pinned:` |
| S8 | `EctoTransactionProbe`: commit and rollback do not close the transaction | 2 of 73: P2: a write after commit or rollback is outside any transaction; R1: a transaction's writes carry its ref; take forgets them and the pid | `Assertion with == failed code:  assert observe(Meta.insert("orders")) == :no_tx` |
| S9 | `EctoTransactionProbe`: every transaction gets the same ref | 2 of 73: P3: two sequential transactions get two different refs; I1: orders and invoices in two transactions pass, and the summary counts the test | `Assertion with != failed, both sides are exactly equal code: assert first != second` |
| S10 | `Aggregates.QueryStatement`: a SELECT is not read as a read | 4 of 73: a read is a read, and is never a write; R1: a transaction's writes carry its ref; take forgets them and the pid; R3: an unwatched process's read is not counted; R5: a read is not recorded | `Assertion with == failed code:  assert QueryStatement.classify(Meta.select("orders")) == :read` |
| S11 | `Managers.Backstop`: installed! with no session does not refuse | 2 of 73: F1: watch/1 before attach!/1 raises: call attach!/1 in test_helper.exs; install/1, installed!/1, watch/2 F1: installed! before any attach raises: call attach!/1 in test_helper.exs | `Expected exception ArgumentError but got CaseClauseError (no case clause matching:` |
| S12 | `Anchor.Backstop`: a repo with no telemetry prefix accepted | 2 of 73: F2: a repo with no telemetry prefix raises, naming the repo; F2: a module that is not a repo at all raises, naming it | `Assertion with == failed code:  assert error.message ==` |
| S13 | `Managers.Backstop`: escapes: :fail ignored | 1 of 73: verdict!/3 M7: an escape fails the test under escapes: :fail | `Expected exception ExUnit.AssertionError but nothing was raised code: assert_raise ExUnit.AssertionError, fn ->` |
| S14 | `Aggregates.Backstop`: a write outside a transaction fails under escapes: :fail | 4 of 73: summary/1 is the summary line of the recorder's totals; failure/3 under :fail a write outside a transaction alone passes: it is counted, not an escape; counts/1 and summary_line/1 F3: the summary is one line with every documented field; I1: orders and invoices in two transactions pass, and the summary counts the test | `Assertion with == failed code:  assert Backstop.summary(session()) ==` |
| S15 | `Managers.Backstop`: the index built from the config alone (no @anchor_aggregate, no schema table) | 2 of 73: I1: a transaction writing orders then invoices fails with the crossing; I1: orders and invoices in two transactions pass, and the summary counts the test | `Expected exception ExUnit.AssertionError but nothing was raised code: assert_raise ExUnit.AssertionError, fn ->` |
| S16 | `TelemetryRecorder`: take_events does not forget a test's events | 1 of 73: R1: a transaction's writes carry its ref; take forgets them and the pid | `Assertion with == failed code:  assert Recorder.take_events(recorder, self()) == []` |
| S17 | `Aggregates.QueryStatement`: an unknown statement read as a read | 1 of 73: a statement read as neither a read nor a write is an unknown write, never a read | `Assertion with == failed code:  assert QueryStatement.classify(%{query: "WITH t AS (SELECT 1) UPDATE x SET y = 1", source: "x"}) ==` |
| S18 | `Managers.Backstop`: zero beams read accepted | 1 of 73: start/2 M3: zero beams read raises, naming the ebins | `Expected exception ArgumentError but got Mox.UnexpectedCallError (no expectation defined for Anchor.WriteRecorderMock.attach_recorder/2 in process #PID<0.2718.0> with args [[:app, :repo, :query], Anchor.Adapters.EctoTran` |
| S19 | `Aggregates.Backstop`: a crossing needs three aggregates | 7 of 73: verdict/2 D2: the table named per aggregate is the lexically first it wrote; verdict/2 two crossing transactions are two crossings, in the order of their first write; failure/3 a crossing fails, naming the test, both aggregates, a table each and the outbox Fix; counts/1 and summary_line/1 a test counts itself, its crossings and every counted kind; verdict/2 D2: one transaction writing A and B is one crossing, one table each; I1: a transaction writing orders then invoices fails with the crossing; verdict!/3 M5: a crossing fails the test, naming both aggregates, with the outbox Fix: | `match (=) failed code:  assert %{crossings: [%{tables: %{"A" => "order_lines"}}]} = Backstop.verdict(events, @index)` |
| S20 | `TelemetryRecorder`: the probe's transaction ignored by the recorder | 3 of 73: I1: a transaction writing orders then invoices fails with the crossing; I1: orders and invoices in two transactions pass, and the summary counts the test; R1: a transaction's writes carry its ref; take forgets them and the pid | `Expected exception ExUnit.AssertionError but nothing was raised code: assert_raise ExUnit.AssertionError, fn ->` |
| S21 | `Aggregates.QueryStatement`: ROLLBACK TO SAVEPOINT read as the transaction's rollback | 1 of 73: savepoint statements are neither boundaries nor writes | `Assertion with == failed code:  assert QueryStatement.classify(%{query: "ROLLBACK TO SAVEPOINT s1", source: nil}) == :savepoint` |
| S22 | `EctoTransactionProbe`: the probe closes the transaction on a savepoint statement | 1 of 73: a savepoint inside a transaction leaves it open | `Assertion with == failed code:  assert Probe.observe(:savepoint) == {:in_tx, ref}` |
| S23 | `EctoTransactionProbe`: the probe reads a transaction open in a process with no begin | 5 of 73: the open transaction is the emitting process's own; P2: a write with no begin before it is outside any transaction; P2: a write after commit or rollback is outside any transaction; R1: a watched test's write is recorded with its table and kind, and no parameter; R1: a transaction's writes carry its ref; take forgets them and the pid | `Assertion failed, no matching message after 0ms Showing 1 of 1 message in the mailbox` |
| S24 | `Aggregates.QueryStatement`: boundaries matched case-sensitively | 1 of 73: begin, commit and rollback are the boundaries, whatever their case or trailing ; | `Assertion with == failed code:  assert QueryStatement.classify(%{query: " BEGIN; ", source: nil}) == :begin` |
| S25 | `Aggregates.QueryStatement`: a trailing ; not dropped | 1 of 73: begin, commit and rollback are the boundaries, whatever their case or trailing ; | `Assertion with == failed code:  assert QueryStatement.classify(%{query: " BEGIN; ", source: nil}) == :begin` |
| S26 | `Aggregates.QueryStatement`: the first word not upper-cased | 1 of 73: the kind is read from the first word, in any case, after leading whitespace | `Assertion with == failed code:  assert QueryStatement.classify(%{query: "\n  insert into x values (1)", source: "x"}) ==` |
| S27 | `Aggregates.QueryStatement`: an empty source read as a table | 1 of 73: an empty source is no table | `Assertion with == failed code:  assert QueryStatement.classify(%{query: "DELETE FROM x", source: ""}) == {:write, :delete, nil}` |
| S28 | `Aggregates.QueryStatement`: a write with no source given a table name | 5 of 73: a statement read as neither a read nor a write is an unknown write, never a read; raw SQL is a write with no table; an empty source is no table; I1: orders and invoices in two transactions pass, and the summary counts the test; raw SQL is recorded with no table | `Assertion with == failed code:  assert QueryStatement.classify(%{query: "TRUNCATE x", source: nil}) == {:write, :unknown, nil}` |
| S29 | `Aggregates.QueryStatement`: metadata with no query text read as a statement | 2 of 73: metadata with no query text is not a query event: it raises; R6: a handler that raises on malformed metadata is detached, and says so | `Expected exception FunctionClauseError but nothing was raised code: assert_raise FunctionClauseError, fn ->` |
| S30 | `Aggregates.Backstop`: a write with no source not a no_source escape | 5 of 73: failure/3 under :fail an escape fails, naming each kind it saw; verdict/2 D5: a write with no source is a no_source escape, never judged; verdict/2 each event is read once, by the first row that matches; counts/1 and summary_line/1 a test counts itself, its crossings and every counted kind; I1: orders and invoices in two transactions pass, and the summary counts the test | `Assertion with == failed code:  assert Backstop.failure(Backstop.verdict(events, @index), @test_name, :fail) ==` |
| S31 | `Aggregates.Backstop`: another process's write not an other_process escape | 5 of 73: verdict!/3 M7: an escape fails the test under escapes: :fail; verdict!/3 M7: under escapes: :report the escape passes and is kept for the summary; verdict/2 each event is read once, by the first row that matches; verdict/2 D6: a write from another process is an other_process escape, never joined to the test's transaction; failure/3 under :fail an escape fails, naming each kind it saw | `Expected exception ExUnit.AssertionError but got FunctionClauseError (no function clause matching in anonymous fn/2 in Anchor.Managers.BackstopTest."test verdict!/3 M7: an escape fails the test under escapes: :fail"/1) c` |
| S32 | `Aggregates.Backstop`: an undeclared table counted as outside a transaction | 2 of 73: failure/3 under :fail an escape fails, naming each kind it saw; verdict/2 D7: a table in no aggregate is an undeclared_table escape and no crossing | `Assertion with == failed code:  assert Backstop.failure(Backstop.verdict(events, @index), @test_name, :fail) ==` |
| S33 | `Aggregates.Backstop`: an unknown statement judged | 3 of 73: verdict/2 each event is read once, by the first row that matches; verdict/2 a statement read as neither a read nor a write is an unclassified escape; failure/3 under :fail an unclassified statement fails too | `Assertion with == failed code:  assert Backstop.verdict(events, @index).escapes == %{` |
| S34 | `Aggregates.Backstop`: no crossing fails under :report | 5 of 73: failure/3 no crossing passes under :report, escapes or not; I1: the same transaction writing orders only passes; I1: orders and invoices in two transactions pass, and the summary counts the test; verdict!/3 M7: under escapes: :report the escape passes and is kept for the summary; verdict!/3 M6: one aggregate per transaction passes, and is counted | `Assertion with == failed code:  assert Backstop.failure(result, @test_name, :report) == :pass` |
| S35 | `Aggregates.Backstop`: the escape message lists kinds it did not see | 3 of 73: failure/3 under :fail an escape fails, naming each kind it saw; failure/3 under :fail an unclassified statement fails too; verdict!/3 M7: an escape fails the test under escapes: :fail | `Assertion with == failed code:  assert Backstop.failure(Backstop.verdict(events, @index), @test_name, :fail) ==` |
| S36 | `Aggregates.Backstop`: no escape fails under :fail | 2 of 73: failure/3 under :fail a write outside a transaction alone passes: it is counted, not an escape; failure/3 under :fail with no escape a test passes (positive control) | `Assertion with == failed code:  assert Backstop.failure(result, @test_name, :fail) == :pass` |
| S37 | `Aggregates.Backstop`: three aggregates listed with commas only | 4 of 73: failure/3 a crossing fails, naming the test, both aggregates, a table each and the outbox Fix; failure/3 a crossing of three aggregates names each, with one Fix; I1: a transaction writing orders then invoices fails with the crossing; verdict!/3 M5: a crossing fails the test, naming both aggregates, with the outbox Fix: | `Assertion with == failed code:  assert Backstop.failure(result, @test_name, :report) ==` |
| S38 | `TelemetryRecorder`: counts add 1 whatever the count | 1 of 73: counts add up per key; a key never counted is 0 | `Assertion with == failed code:  assert Recorder.read_totals(recorder) == %{` |
| S39 | `TelemetryRecorder`: a key never counted reads -1 | 3 of 73: I1: orders and invoices in two transactions pass, and the summary counts the test; R3: an unwatched process's read is not counted; counts add up per key; a key never counted is 0 | `Assertion with == failed code:  assert Backstop.summary(session) ==` |
| S40 | `TelemetryRecorder`: a detached handler still reads attached | 1 of 73: R6: a handler that raises on malformed metadata is detached, and says so | `Expected false or nil, got true code: refute Recorder.recorder_attached?(recorder)` |
| S41 | `TelemetryRecorder`: a recorder whose table is gone reads attached | 2 of 73: R6: a handler that raises on malformed metadata is detached, and says so; a recorder whose table is gone is not attached | `Expected false or nil, got true code: refute Recorder.recorder_attached?(recorder)` |
| S42 | `TelemetryRecorder`: install_session keeps nothing | 1 of 73: a session installed is the session installed_session returns | `Assertion with == failed code:  assert Recorder.installed_session() == {:ok, session}` |
| S43 | `Managers.Backstop`: start attaches with no probe | 4 of 73: I1: orders and invoices in two transactions pass, and the summary counts the test; I1: a transaction writing orders then invoices fails with the crossing; I1: the same transaction writing orders only passes; start/2 loads the config and beams, builds the index and attaches the recorder | `I1 test: the backstop handler was detached, so this test's writes were not all recorded. Fix: read the :telemetry error logged when it was detached; the handler raised on an event it could not read. code: assert Backstop` |
| S44 | `Managers.Backstop`: a config with no aggregates: section read as no declarations | 1 of 73: start/2 M1: a config with no aggregates: section raises with Fix:, attaching nothing | `Expected exception ArgumentError but got Mox.UnexpectedCallError (no expectation defined for Anchor.BeamSourceMock.read_ebins/1 in process #PID<0.2710.0> with args [[app: "/repo/_build/test/lib/app/ebin"]]) code: error =` |
| S45 | `Managers.Backstop`: a config that does not load not refused with its reason | 1 of 73: start/2 M1: a config that does not load raises with Fix:, naming the reason | `Expected exception ArgumentError but got FunctionClauseError (no function clause matching in Anchor.Managers.Backstop.aggregates!/2) code: error = assert_raise ArgumentError, fn -> Backstop.start(@request, @deps) end` |
| S46 | `Managers.Backstop`: an attach error not refused | 1 of 73: start/2 a recorder that cannot attach raises with Fix: | `Expected exception ArgumentError but got CaseClauseError (no case clause matching:` |
| S47 | `Managers.Backstop`: install keeps nothing | 1 of 73: install/1, installed!/1, watch/2 install keeps the session through the recorder | `** (Mox.VerificationError) error while verifying mocks for #PID<0.2724.0>:` |
| S48 | `Managers.Backstop`: installed! returns a changed session | 1 of 73: install/1, installed!/1, watch/2 installed! returns the kept session | `Assertion with == failed code:  assert Backstop.installed!(WriteRecorderMock) == session` |
| S49 | `Managers.Backstop`: watch marks no pid | 3 of 73: I1: a transaction writing orders then invoices fails with the crossing; I1: orders and invoices in two transactions pass, and the summary counts the test; install/1, installed!/1, watch/2 watch marks the pid | `Expected exception ExUnit.AssertionError but nothing was raised code: assert_raise ExUnit.AssertionError, fn ->` |
| S50 | `Anchor.Backstop`: any atom accepted as escapes: | 1 of 73: an escapes: mode other than :report or :fail raises with Fix: | `Assertion with =~ failed code:  assert error.message =~ "escapes: must be :report or :fail, got: :warn. Fix:"` |
| S51 | `Anchor.Backstop`: repo: not required | 1 of 73: repo: is required | `Expected exception KeyError but got ArgumentError (anchor backstop: nil has no telemetry prefix. Fix: pass repo: an Ecto repo (use Ecto.Repo), whose config/0 holds :telemetry_prefix.) code: assert_raise KeyError, fn -> A` |
| S52 | `Aggregates.Backstop`: a single aggregate is a crossing | 10 of 73: verdict/2 D5: a write with no source is a no_source escape, never judged; verdict/2 a statement read as neither a read nor a write is an unclassified escape; verdict/2 D6: a write from another process is an other_process escape, never joined to the test's transaction; verdict/2 D1: one transaction writing one aggregate twice is no crossing (positive control); verdict/2 D3: A and B written in two separate transactions are no crossing; failure/3 under :fail with no escape a test passes (positive control); verdict/2 D7: a table in no aggregate is an undeclared_table escape and no crossing; I1: the same transaction writing orders only passes; I1: orders and invoices in two transactions pass, and the summary counts the test; verdict!/3 M6: one aggregate per transaction passes, and is counted | `Assertion with == failed code:  assert Backstop.verdict(events, @index) == %{crossings: [], escapes: %{zero_escapes() \| no_source: 1}}` |
| S53 | `TelemetryRecorder`: take_events returns every test's events | 1 of 73: R4: two watched tests each see only their own writes | `match (=) failed The following variables were pinned:` |
| S54 | `Aggregates.QueryStatement`: an UPDATE read as an insert | 2 of 73: an insert, update and delete are writes of their source table; R1: a transaction's writes carry its ref; take forgets them and the pid | `Assertion with == failed code:  assert QueryStatement.classify(Meta.update("orders")) == {:write, :update, "orders"}` |
| S55 | `EctoTransactionProbe`: each write of a transaction gets a fresh ref | 5 of 73: P3: two sequential transactions get two different refs; P1: every write of one transaction gets the same ref, the one begin opened; a savepoint inside a transaction leaves it open; I1: a transaction writing orders then invoices fails with the crossing; R1: a transaction's writes carry its ref; take forgets them and the pid | `Assertion with == failed code:  assert observe(Meta.insert("orders")) == {:in_tx, second}` |

After every row, the restored tree: the eight files, `73 tests, 0 failures`.

## Run 22:29 UTC

- **Code under test:** `Anchor.Managers.Backstop.aggregates!/2`, `Anchor.Managers.Backstop.index!/2`, `Anchor.Managers.Backstop.install/1`, `Anchor.Managers.Backstop.installed!/1`, `Anchor.Managers.Backstop.start/2`, `Anchor.Managers.Backstop.verdict!/3`, `Anchor.Managers.Backstop.watch/2`, `Anchor.Backstop.attach!/1`, `Anchor.Backstop.escapes!/1`, `Anchor.Backstop.query_event!/1`, `Anchor.Backstop.watch/1`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 0f318804748699062285e0c7fe323ef8be146b80

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Managers.Backstop.start/2 delete_statement `config_loader = Keyword.get(deps, :config_loader, ConfigFile)`: orphans variable `config_loader` bound at line 75 and used at line 80
- skipped Anchor.Managers.Backstop.start/2 delete_statement `beam_source = Keyword.get(deps, :beam_source, BeamReader)`: orphans variable `beam_source` bound at line 76 and used at line 81
- skipped Anchor.Managers.Backstop.start/2 delete_statement `write_recorder = Keyword.get(deps, :write_recorder, TelemetryRecorder)`: orphans variable `write_recorder` bound at line 77 and used at line 84
- skipped Anchor.Managers.Backstop.start/2 delete_statement `probe = Keyword.get(deps, :probe, EctoTransactionProbe)`: orphans variable `probe` bound at line 78 and used at line 84
- skipped Anchor.Managers.Backstop.start/2 delete_statement `aggregates = aggregates!(config_loader.load_in(root), root)`: orphans variable `aggregates` bound at line 80 and used at line 82
- skipped Anchor.Managers.Backstop.start/2 delete_statement `beams = beams!(beam_source.read_ebins(apps), apps)`: orphans variable `beams` bound at line 81 and used at line 82
- skipped Anchor.Managers.Backstop.start/2 delete_statement `index = index!(aggregates, Builder.build(beams, %{}, root: root))`: orphans variable `index` bound at line 82 and used at line 86
- skipped Anchor.Managers.Backstop.start/2 return_input [1] `start(%{event: event, root: root, apps: apps, escapes: escapes}, deps \\ [])
when escapes in [:report, :fail]`: the guard reads `escapes`, which the mutant renames `_escapes`
- skipped Anchor.Managers.Backstop.verdict!/3 delete_statement `events = write_recorder.take_events(recorder, pid)`: orphans variable `events` bound at line 128 and used at line 138
- skipped Anchor.Managers.Backstop.verdict!/3 delete_statement `result = Backstop.verdict(events, session.index())`: orphans variable `result` bound at line 138 and used at line 139
- skipped Anchor.Managers.Backstop.beams!/2 force_condition [true] `Enum.any?(beams, &match?(%Beam{}, &1))`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 force_condition [false] `Enum.any?(beams, &match?(%Beam{}, &1))`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 return_input [0] `beams!(beams, apps)`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 return_input [1] `beams!(beams, apps)`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.index!/2 delete_statement `index = Index.build(aggregates, graph)`: orphans variable `index` bound at line 181 and used at line 183
- skipped Anchor.Backstop.attach!/1 delete_statement `repo = Keyword.fetch!(opts, :repo)`: orphans variable `repo` bound at line 50 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `escapes = escapes!(Keyword.get(opts, :escapes, :report))`: orphans variable `escapes` bound at line 51 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `app = Keyword.get(Mix.Project.config(), :app) || :project`: orphans variable `app` bound at line 52 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `ebins = Keyword.get_lazy(opts, :ebins, fn -> [Mix.Project.compile_path()] end)`: orphans variable `ebins` bound at line 53 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `session =
  Backstop.start(%{
    event: query_event!(repo),
    root: Keyword.get_lazy(opts, :root, &File.cwd!/0),
    apps: Enum.map(ebins, &{app, &1}),
    escapes: escapes
  })`: orphans variable `session` bound at line 55 and used at line 63
- skipped Anchor.Backstop.attach!/1 return_input [0] `attach!(opts) when is_list(opts)`: removes the last use of function `escapes!/1`
- skipped Anchor.Backstop.watch/1 delete_statement `session = Backstop.installed!()`: orphans variable `session` bound at line 75 and used at line 78
- skipped Anchor.Backstop.watch/1 delete_statement `test_pid = self()`: orphans variable `test_pid` bound at line 76 and used at line 78
- skipped Anchor.Backstop.watch/1 delete_statement `test = "#{inspect(Map.get(tags, :module))} #{Map.get(tags, :test)}"`: orphans variable `test` bound at line 77 and used at line 79
- skipped Anchor.Backstop.escapes!/1 return_input [0] `escapes!(mode) when mode in [:report, :fail]`: the body already returns `mode`
- skipped Anchor.Backstop.query_event!/1 delete_statement `prefix =
  if is_atom(repo) and Code.ensure_loaded?(repo) and function_exported?(repo, :config, 0) do
    Keyword.get(repo.config(), :telemetry_prefix)
  end`: orphans variable `prefix` bound at line 91 and used at line 95
- 0cae7bb87697 Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- 43783b78965f Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- 67937f8d30af Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- feb9cd53ec78 Anchor.Managers.Backstop.aggregates!/2 return_input [1]: not run (cap)
- d30262e2c511 Anchor.Managers.Backstop.index!/2 delete_statement: not run (cap)
- 13b203c676e6 Anchor.Managers.Backstop.index!/2 force_condition [false]: not run (cap)
- a6bdbe61cbb7 Anchor.Managers.Backstop.index!/2 force_condition [true]: not run (cap)
- 1857d433aa66 Anchor.Managers.Backstop.index!/2 return_input [0]: not run (cap)
- d15d4cd337ed Anchor.Managers.Backstop.index!/2 return_input [1]: not run (cap)
- 019ab30d59a8 Anchor.Managers.Backstop.install/1 return_input [0]: not run (cap)
- 0bf82062e7ce Anchor.Managers.Backstop.installed!/1 narrow_clause: not run (cap)
- 20e2f5a65484 Anchor.Managers.Backstop.installed!/1 narrow_clause: not run (cap)
- c270e1f922b6 Anchor.Managers.Backstop.installed!/1 return_input [0]: not run (cap)
- 911d6280b250 Anchor.Managers.Backstop.start/2 narrow_clause: not run (cap)
- e3ec787cea1e Anchor.Managers.Backstop.start/2 narrow_clause: not run (cap)
- 368696afa101 Anchor.Managers.Backstop.verdict!/3 delete_statement: not run (cap)
- 723e31778738 Anchor.Managers.Backstop.verdict!/3 delete_statement: not run (cap)
- a0b2fca436fa Anchor.Managers.Backstop.verdict!/3 force_condition [true]: not run (cap)
- dbd5586bce1c Anchor.Managers.Backstop.verdict!/3 force_condition [false]: not run (cap)
- 6dc8a7fe032d Anchor.Managers.Backstop.verdict!/3 narrow_clause: not run (cap)
- 8f93a4224fb0 Anchor.Managers.Backstop.verdict!/3 narrow_clause: not run (cap)
- 2c53fce7aae1 Anchor.Managers.Backstop.verdict!/3 return_input [0]: not run (cap)
- 88cc3595e311 Anchor.Managers.Backstop.verdict!/3 return_input [2]: not run (cap)
- 8dac7e504781 Anchor.Managers.Backstop.verdict!/3 return_input [1]: not run (cap)
- 801e6e80344a Anchor.Managers.Backstop.watch/2 return_input [1]: not run (cap)
- 01a38312229e Anchor.Backstop.attach!/1 delete_statement: not run (cap)
- f7faecff1cfd Anchor.Backstop.attach!/1 delete_statement: not run (cap)
- 20122bd7a124 Anchor.Backstop.escapes!/1 narrow_clause: not run (cap)
- a6dacdb5187d Anchor.Backstop.escapes!/1 narrow_clause: not run (cap)
- e9855b3cf5af Anchor.Backstop.escapes!/1 return_input [0]: not run (cap)
- 427e7b63e900 Anchor.Backstop.query_event!/1 force_condition [false]: not run (cap)
- 60c2d06f62e0 Anchor.Backstop.query_event!/1 force_condition [false]: not run (cap)
- 996dcea64533 Anchor.Backstop.query_event!/1 force_condition [true]: not run (cap)
- c5f9e5def15c Anchor.Backstop.query_event!/1 force_condition [true]: not run (cap)
- 1141b8e7dafe Anchor.Backstop.query_event!/1 return_input [0]: not run (cap)
- 3ea1d7a09074 Anchor.Backstop.watch/1 delete_statement: not run (cap)
- fe58334e4432 Anchor.Backstop.watch/1 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```

## Run 22:30 UTC

- **Code under test:** `Anchor.Managers.Backstop.aggregates!/2`, `Anchor.Managers.Backstop.index!/2`, `Anchor.Managers.Backstop.install/1`, `Anchor.Managers.Backstop.installed!/1`, `Anchor.Managers.Backstop.start/2`, `Anchor.Managers.Backstop.verdict!/3`, `Anchor.Managers.Backstop.watch/2`, `Anchor.Backstop.attach!/1`, `Anchor.Backstop.escapes!/1`, `Anchor.Backstop.query_event!/1`, `Anchor.Backstop.watch/1`
- **Generated by:** `mix anchor.sabotage run --base 85dd5c9c77fe57d69e939a5a89b1a00696d18599 --print-survivor-lines` (Anchor 0.1.0), base 85dd5c9c77fe57d69e939a5a89b1a00696d18599, head 0bf615c80b47e4810394fea0ac2b9ce1d37889d5

### Summary

None.

### Mutants

None.

### Survivors

None.

### Kills by timeout

None.

### Skipped, invalid, not run

- skipped Anchor.Managers.Backstop.start/2 delete_statement `config_loader = Keyword.get(deps, :config_loader, ConfigFile)`: orphans variable `config_loader` bound at line 75 and used at line 80
- skipped Anchor.Managers.Backstop.start/2 delete_statement `beam_source = Keyword.get(deps, :beam_source, BeamReader)`: orphans variable `beam_source` bound at line 76 and used at line 81
- skipped Anchor.Managers.Backstop.start/2 delete_statement `write_recorder = Keyword.get(deps, :write_recorder, TelemetryRecorder)`: orphans variable `write_recorder` bound at line 77 and used at line 84
- skipped Anchor.Managers.Backstop.start/2 delete_statement `probe = Keyword.get(deps, :probe, EctoTransactionProbe)`: orphans variable `probe` bound at line 78 and used at line 84
- skipped Anchor.Managers.Backstop.start/2 delete_statement `aggregates = aggregates!(config_loader.load_in(root), root)`: orphans variable `aggregates` bound at line 80 and used at line 82
- skipped Anchor.Managers.Backstop.start/2 delete_statement `beams = beams!(beam_source.read_ebins(apps), apps)`: orphans variable `beams` bound at line 81 and used at line 82
- skipped Anchor.Managers.Backstop.start/2 delete_statement `index = index!(aggregates, Builder.build(beams, %{}, root: root))`: orphans variable `index` bound at line 82 and used at line 86
- skipped Anchor.Managers.Backstop.start/2 return_input [1] `start(%{event: event, root: root, apps: apps, escapes: escapes}, deps \\ [])
when escapes in [:report, :fail]`: the guard reads `escapes`, which the mutant renames `_escapes`
- skipped Anchor.Managers.Backstop.verdict!/3 delete_statement `events = write_recorder.take_events(recorder, pid)`: orphans variable `events` bound at line 128 and used at line 138
- skipped Anchor.Managers.Backstop.verdict!/3 delete_statement `result = Backstop.verdict(events, session.index())`: orphans variable `result` bound at line 138 and used at line 139
- skipped Anchor.Managers.Backstop.beams!/2 force_condition [true] `Enum.any?(beams, &match?(%Beam{}, &1))`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 force_condition [false] `Enum.any?(beams, &match?(%Beam{}, &1))`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 return_input [0] `beams!(beams, apps)`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.beams!/2 return_input [1] `beams!(beams, apps)`: removes the last use of alias `Beam`
- skipped Anchor.Managers.Backstop.index!/2 delete_statement `index = Index.build(aggregates, graph)`: orphans variable `index` bound at line 181 and used at line 183
- skipped Anchor.Backstop.attach!/1 delete_statement `repo = Keyword.fetch!(opts, :repo)`: orphans variable `repo` bound at line 50 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `escapes = escapes!(Keyword.get(opts, :escapes, :report))`: orphans variable `escapes` bound at line 51 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `app = Keyword.get(Mix.Project.config(), :app) || :project`: orphans variable `app` bound at line 52 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `ebins = Keyword.get_lazy(opts, :ebins, fn -> [Mix.Project.compile_path()] end)`: orphans variable `ebins` bound at line 53 and used at line 55
- skipped Anchor.Backstop.attach!/1 delete_statement `session =
  Backstop.start(%{
    event: query_event!(repo),
    root: Keyword.get_lazy(opts, :root, &File.cwd!/0),
    apps: Enum.map(ebins, &{app, &1}),
    escapes: escapes
  })`: orphans variable `session` bound at line 55 and used at line 63
- skipped Anchor.Backstop.attach!/1 return_input [0] `attach!(opts) when is_list(opts)`: removes the last use of function `escapes!/1`
- skipped Anchor.Backstop.watch/1 delete_statement `session = Backstop.installed!()`: orphans variable `session` bound at line 75 and used at line 78
- skipped Anchor.Backstop.watch/1 delete_statement `test_pid = self()`: orphans variable `test_pid` bound at line 76 and used at line 78
- skipped Anchor.Backstop.watch/1 delete_statement `test = "#{inspect(Map.get(tags, :module))} #{Map.get(tags, :test)}"`: orphans variable `test` bound at line 77 and used at line 79
- skipped Anchor.Backstop.escapes!/1 return_input [0] `escapes!(mode) when mode in [:report, :fail]`: the body already returns `mode`
- skipped Anchor.Backstop.query_event!/1 delete_statement `prefix =
  if is_atom(repo) and Code.ensure_loaded?(repo) and function_exported?(repo, :config, 0) do
    Keyword.get(repo.config(), :telemetry_prefix)
  end`: orphans variable `prefix` bound at line 91 and used at line 95
- 0cae7bb87697 Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- 43783b78965f Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- 67937f8d30af Anchor.Managers.Backstop.aggregates!/2 narrow_clause: not run (cap)
- feb9cd53ec78 Anchor.Managers.Backstop.aggregates!/2 return_input [1]: not run (cap)
- d30262e2c511 Anchor.Managers.Backstop.index!/2 delete_statement: not run (cap)
- 13b203c676e6 Anchor.Managers.Backstop.index!/2 force_condition [false]: not run (cap)
- a6bdbe61cbb7 Anchor.Managers.Backstop.index!/2 force_condition [true]: not run (cap)
- 1857d433aa66 Anchor.Managers.Backstop.index!/2 return_input [0]: not run (cap)
- d15d4cd337ed Anchor.Managers.Backstop.index!/2 return_input [1]: not run (cap)
- 019ab30d59a8 Anchor.Managers.Backstop.install/1 return_input [0]: not run (cap)
- 0bf82062e7ce Anchor.Managers.Backstop.installed!/1 narrow_clause: not run (cap)
- 20e2f5a65484 Anchor.Managers.Backstop.installed!/1 narrow_clause: not run (cap)
- c270e1f922b6 Anchor.Managers.Backstop.installed!/1 return_input [0]: not run (cap)
- 911d6280b250 Anchor.Managers.Backstop.start/2 narrow_clause: not run (cap)
- e3ec787cea1e Anchor.Managers.Backstop.start/2 narrow_clause: not run (cap)
- 368696afa101 Anchor.Managers.Backstop.verdict!/3 delete_statement: not run (cap)
- 723e31778738 Anchor.Managers.Backstop.verdict!/3 delete_statement: not run (cap)
- a0b2fca436fa Anchor.Managers.Backstop.verdict!/3 force_condition [true]: not run (cap)
- dbd5586bce1c Anchor.Managers.Backstop.verdict!/3 force_condition [false]: not run (cap)
- 6dc8a7fe032d Anchor.Managers.Backstop.verdict!/3 narrow_clause: not run (cap)
- 8f93a4224fb0 Anchor.Managers.Backstop.verdict!/3 narrow_clause: not run (cap)
- 2c53fce7aae1 Anchor.Managers.Backstop.verdict!/3 return_input [0]: not run (cap)
- 88cc3595e311 Anchor.Managers.Backstop.verdict!/3 return_input [2]: not run (cap)
- 8dac7e504781 Anchor.Managers.Backstop.verdict!/3 return_input [1]: not run (cap)
- 801e6e80344a Anchor.Managers.Backstop.watch/2 return_input [1]: not run (cap)
- 01a38312229e Anchor.Backstop.attach!/1 delete_statement: not run (cap)
- f7faecff1cfd Anchor.Backstop.attach!/1 delete_statement: not run (cap)
- 20122bd7a124 Anchor.Backstop.escapes!/1 narrow_clause: not run (cap)
- a6dacdb5187d Anchor.Backstop.escapes!/1 narrow_clause: not run (cap)
- e9855b3cf5af Anchor.Backstop.escapes!/1 return_input [0]: not run (cap)
- 427e7b63e900 Anchor.Backstop.query_event!/1 force_condition [false]: not run (cap)
- 60c2d06f62e0 Anchor.Backstop.query_event!/1 force_condition [false]: not run (cap)
- 996dcea64533 Anchor.Backstop.query_event!/1 force_condition [true]: not run (cap)
- c5f9e5def15c Anchor.Backstop.query_event!/1 force_condition [true]: not run (cap)
- 1141b8e7dafe Anchor.Backstop.query_event!/1 return_input [0]: not run (cap)
- 3ea1d7a09074 Anchor.Backstop.watch/1 delete_statement: not run (cap)
- fe58334e4432 Anchor.Backstop.watch/1 return_input [0]: not run (cap)

### Tests still lacking a red

None.

### Kill map

```anchor-kills
# id	file	mfa	operator	status	killers
```
