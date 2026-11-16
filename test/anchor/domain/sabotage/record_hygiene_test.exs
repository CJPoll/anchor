defmodule Anchor.Domain.Sabotage.RecordHygieneTest do
  # A sabotage record is committed, often to a public repo, so it must not carry
  # what only the machine that ran it knows: a test scheduler's status lines
  # (they name other runs and their checkouts) or an absolute path under a home
  # directory (it names the user and the checkout's branch). Pure.
  # Sabotage record: ../../../sabotage_records/record_hygiene-20261116-sabotage_record_redaction.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.RecordHygiene

  @root "/home/alice/.local/worktrees/repo/branch-x"

  describe "redact/2: scheduler status lines" do
    test "drops every test-slot status line, keeping the test output around it" do
      text =
        Enum.join(
          [
            "Finished in 0.4 seconds",
            "47 tests, 5 failures",
            "test-slot: HELD before queuing (ticket-1234): heavy-go: HOLD repo=repo step=gate",
            "test-slot: heavy-go: GO after 30s held; queuing for 8 unit(s)",
            "done"
          ],
          "\n"
        )

      assert RecordHygiene.redact(text, nil) ==
               "Finished in 0.4 seconds\n47 tests, 5 failures\ndone"
    end

    test "drops a WAITING block's holder and waiting lines, which name other runs' checkouts" do
      text =
        Enum.join(
          [
            "before",
            "test-slot: WAITING for 2 unit(s) -- cpu pool /tmp/pool, budget=8, 8 held:",
            "  units 1-4 (4 of weight 4): ticket-1234 gate in /home/bob/.local/worktrees/repo/ticket-1234 since 06:00 (pid 42, diagnostic)",
            "  1 waiting (this run: ticket-99, weight 2)",
            "  this run is --exclusive (bench only): it needs all 8 units",
            "after",
            ""
          ],
          "\n"
        )

      assert RecordHygiene.redact(text, nil) == "before\nafter\n"
    end

    test "keeps a line that only mentions test-slot mid-sentence" do
      text = "the run used test-slot: once\nassert x == 1"
      assert RecordHygiene.redact(text, nil) == text
    end
  end

  describe "redact/2: local absolute paths" do
    test "a path under the run's root becomes relative to it, and the root itself becomes ." do
      text =
        ~s(left: "#{@root}/_build/test/anchor"\nin #{@root}\nfile: "#{@root}/test/x_test.exs")

      assert RecordHygiene.redact(text, @root) ==
               ~s(left: "_build/test/anchor"\nin .\nfile: "test/x_test.exs")
    end

    test "a root given with a trailing slash strips the same way" do
      assert RecordHygiene.redact("#{@root}/lib/a.ex", @root <> "/") == "lib/a.ex"
    end

    test "a root of / or a relative root strips nothing" do
      assert RecordHygiene.redact("/tmp/a /usr/b", "/") == "/tmp/a /usr/b"
      assert RecordHygiene.redact("/tmp/a and tmp/a", "tmp") == "/tmp/a and tmp/a"
    end

    test "another checkout under .local/worktrees becomes <worktree>/, keeping the project path" do
      text = ~s(path: "/home/bob/.local/worktrees/repo/feature/ticket-1234/tmp/ATest/t-1/x.beam")

      assert RecordHygiene.redact(text, @root) == ~s(path: "<worktree>/tmp/ATest/t-1/x.beam")
    end

    test "a checkout path with no project directory in it is <worktree> alone" do
      assert RecordHygiene.redact("cd /home/bob/.local/worktrees/repo/branch-y now", nil) ==
               "cd <worktree> now"
    end

    test "any other home path loses the user name, macOS or Linux" do
      assert RecordHygiene.redact("/Users/carol/src/app/lib/a.ex and /home/dave/notes", nil) ==
               "~/src/app/lib/a.ex and ~/notes"
    end

    test "a charlist, a list and a quoted path are each rewritten up to the quote" do
      text = ~s(~c"#{@root}/a", ["/home/bob/x/y"], '/home/bob/z')
      assert RecordHygiene.redact(text, @root) == ~s(~c"a", ["~/x/y"], '~/z')
    end

    test "paths that are not under a home directory are kept" do
      text = "/tmp/a /usr/lib/erlang /homework/x lib/home/y"
      assert RecordHygiene.redact(text, @root) == text
    end

    test "a redacted text has no leaks left" do
      text =
        "test-slot: queued\n#{@root}/a\n/home/bob/.local/worktrees/r/b/test/c\n/Users/carol/d\n"

      assert RecordHygiene.leaks(RecordHygiene.redact(text, @root)) == []
    end
  end

  describe "leaks/1" do
    test "names each leaking line by number and kind, never the text" do
      text =
        Enum.join(
          [
            "fine",
            "test-slot: WAITING for 1 unit(s)",
            ~s(left: "/home/alice/x"),
            "  units 1 (1 of weight 1): a in b since c (pid 1, diagnostic)",
            "/Users/carol/y",
            "~/z and <worktree>/q are fine"
          ],
          "\n"
        )

      assert RecordHygiene.leaks(text) == [
               {2, :scheduler_line},
               {3, :local_path},
               {4, :scheduler_line},
               {5, :local_path}
             ]
    end

    test "a worktree path without the home prefix is still a leak" do
      assert RecordHygiene.leaks("x ~/.local/worktrees/repo/b/y") == [{1, :local_path}]
    end

    test "a clean text has none" do
      assert RecordHygiene.leaks("# Sabotage record\n\n- **Branch:** branch-x\n") == []
    end
  end

  describe "judge/3: committed records against the shrink-only list" do
    @newest ~D[2026-01-10]
    @old "test/sabotage_records/x-20260105-branch_x.md"
    @new "test/sabotage_records/y-20260120-branch_y.md"
    @leaky "ok\n/home/alice/a\n"

    test "clean records and a listed record that still leaks: no findings" do
      records = %{@old => @leaky, @new => "clean\n"}
      assert RecordHygiene.judge(records, [@old], @newest) == []
    end

    test "a record not listed that leaks is a finding per leaking line" do
      records = %{@new => "test-slot: x\nfine\n/Users/bob/b\n"}

      assert RecordHygiene.judge(records, [], @newest) == [
               {:leak, @new, 1, :scheduler_line},
               {:leak, @new, 3, :local_path}
             ]
    end

    test "a listed record that leaks no more is stale, and a listed one that is gone is missing" do
      assert RecordHygiene.judge(%{@old => "clean\n"}, [@old], @newest) == [{:stale, @old}]
      assert RecordHygiene.judge(%{}, [@old], @newest) == [{:missing, @old}]
    end

    test "a listed record dated after newest, or with no date, is late: the list never grows" do
      undated = "test/sabotage_records/README.md"
      records = %{@new => @leaky, undated => @leaky}

      assert RecordHygiene.judge(records, [@new, undated], @newest) == [
               {:late, undated},
               {:late, @new}
             ]
    end

    test "a listed record whose date is no calendar date is late" do
      bad = "test/sabotage_records/w-20261399-branch_w.md"
      assert RecordHygiene.judge(%{bad => @leaky}, [bad], @newest) == [{:late, bad}]
    end

    test "a record dated on newest itself may be listed" do
      on = "test/sabotage_records/z-20260110-branch_z.md"
      assert RecordHygiene.judge(%{on => @leaky}, [on], @newest) == []
    end
  end
end
