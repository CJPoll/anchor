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

    test "keeps a line shaped like a waiting line whose count is not a number" do
      text = "many waiting (this run: none)\n waiting (this run: none)"
      assert RecordHygiene.redact(text, nil) == text
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

    test "any other home path becomes <home> and its project path, macOS or Linux" do
      assert RecordHygiene.redact("/Users/carol/src/app/lib/a.ex and /home/dave/notes", nil) ==
               "<home>/lib/a.ex and <home>"
    end

    test "a home path with something before it is rewritten too" do
      text = "file:///home/bob/x -I/home/bob/inc /var/home/bob/dev/p/test/t.exs"

      assert RecordHygiene.redact(text, nil) ==
               "file://<home> -I<home> /var<home>/test/t.exs"
    end

    test "the user name ends at closing punctuation, which is kept" do
      text = "(/home/bob) PATH=/home/bob,x /home/bob:/usr/bin [/home/bob]"

      assert RecordHygiene.redact(text, nil) ==
               "(<home>) PATH=<home>,x <home>:/usr/bin [<home>]"
    end

    test "a kept project path that holds a home path of its own is rewritten as well" do
      assert RecordHygiene.redact("/home/u/x/lib/home/y/z", nil) == "<home>/lib<home>"
    end

    test "a charlist, a list and a quoted path are each rewritten up to the quote" do
      text = ~s(~c"#{@root}/a", ["/home/bob/x/y"], '/home/bob/z')
      assert RecordHygiene.redact(text, @root) == ~s(~c"a", ["<home>"], '<home>')
    end

    test "paths that are not under a home directory are kept" do
      text = "/tmp/a /usr/lib/erlang /homework/x lib/homey/y /home/ alone"
      assert RecordHygiene.redact(text, @root) == text
    end

    test "a sibling of the root is not the root" do
      assert RecordHygiene.redact("#{@root}2/lib/a.ex", @root) == "<worktree>/lib/a.ex"
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
            "~/z, <home>/a and <worktree>/q are fine"
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

    test "a home path anywhere in a line is a leak" do
      text = "file:///home/bob/x\n-I/home/bob/inc\n/var/home/bob/p\n/usr/home/bob/p"

      assert RecordHygiene.leaks(text) == [
               {1, :local_path},
               {2, :local_path},
               {3, :local_path},
               {4, :local_path}
             ]
    end

    test "a clean text has none" do
      assert RecordHygiene.leaks("# Sabotage record\n\n- **Branch:** branch-x\n") == []
    end
  end

  describe "redact_record/2 and record_leaks/1: a record's source blocks are kept" do
    @record Enum.join(
              [
                "left: \"/home/alice/x\"",
                "test-slot: queued",
                "```diff",
                "-    \"/home/alice/x\"",
                "test-slot: a source line",
                "```",
                "```",
                "right: \"/home/alice/y\"",
                "```",
                "```anchor-kills",
                "id\tfile\ttest reads /home/alice/z",
                "```",
                "after /Users/bob/q"
              ],
              "\n"
            )

    test "only text outside the diff and kill-map blocks is redacted" do
      assert RecordHygiene.redact_record(@record, nil) ==
               Enum.join(
                 [
                   "left: \"<home>\"",
                   "```diff",
                   "-    \"/home/alice/x\"",
                   "test-slot: a source line",
                   "```",
                   "```",
                   "right: \"<home>\"",
                   "```",
                   "```anchor-kills",
                   "id\tfile\ttest reads /home/alice/z",
                   "```",
                   "after <home>"
                 ],
                 "\n"
               )
    end

    test "record_leaks/1 reports only lines outside those blocks, by the record's line number" do
      assert RecordHygiene.record_leaks(@record) == [
               {1, :local_path},
               {2, :scheduler_line},
               {8, :local_path},
               {13, :local_path}
             ]
    end

    test "a redacted record has no record leaks, though its blocks still hold home paths" do
      redacted = RecordHygiene.redact_record(@record, nil)
      assert RecordHygiene.record_leaks(redacted) == []
      assert RecordHygiene.leaks(redacted) != []
    end
  end
end
