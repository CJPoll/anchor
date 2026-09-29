defmodule Anchor.Domain.FailuresTest do
  # Domain (DND-1265): the text of every fail-closed report. Each message says
  # what was searched or what failed, that nothing was checked because of it,
  # and carries a `Fix:` line.
  #
  # Sabotage record: ../../sabotage_records/failures-20260929-dnd_1265_anchor_fail_closed.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  describe "config_violation/1" do
    test "config not found names every searched path and sits on the first one" do
      searched = ["/p/apps/a/.anchor.yml", "/p/.anchor.yml"]

      assert %Violation{} = violation = Failures.config_violation({:config_not_found, searched})

      assert violation.filename == "/p/apps/a/.anchor.yml"
      assert violation.kind == :fail_closed
      assert violation.message =~ "Searched: /p/apps/a/.anchor.yml, /p/.anchor.yml."
      assert violation.message =~ "no Anchor rule was checked"
      assert violation.message =~ "Fix:"
    end

    test "an unreadable file names the path and the posix reason" do
      violation =
        Failures.config_violation({:config_load_failed, "/p/.anchor.yml", {:read, :eacces}})

      assert violation.filename == "/p/.anchor.yml"
      assert violation.message =~ "/p/.anchor.yml"
      assert violation.message =~ "eacces"
      assert violation.message =~ "Fix:"
    end

    test "invalid YAML carries the parser's message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml", {:yaml, "bad indent at line 3"}}
        )

      assert violation.message =~ "YAML"
      assert violation.message =~ "bad indent at line 3"
      assert violation.message =~ "Fix:"
    end

    test "an invalid rule carries the validation message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml",
           {:invalid_rule, ~s(rule 2: unknown rule type "x")}}
        )

      assert violation.message =~ ~s(rule 2: unknown rule type "x")
      assert violation.message =~ "Fix:"
    end

    test "an invalid document carries the validation message" do
      violation =
        Failures.config_violation(
          {:config_load_failed, "/p/.anchor.yml", {:invalid_config, "no `rules:` list"}}
        )

      assert violation.message =~ "no `rules:` list"
      assert violation.message =~ "Fix:"
    end

    # A loader is a behaviour, so a reason of a shape this module does not know
    # must still be reported, never dropped.
    test "an unrecognised reason is still reported" do
      violation = Failures.config_violation({:something_new, 1})

      assert violation.kind == :fail_closed
      assert violation.filename == ".anchor.yml"
      assert violation.message =~ "{:something_new, 1}"
      assert violation.message =~ "Fix:"
    end
  end

  describe "unparseable_violation/2" do
    test "names the parser message and line, on the checked file" do
      violation = Failures.unparseable_violation(3, "missing terminator: end")

      assert violation.line == 3
      assert violation.filename == nil
      assert violation.kind == :fail_closed
      assert violation.message =~ "could not parse"
      assert violation.message =~ "missing terminator: end"
      assert violation.message =~ "Fix:"
    end
  end
end
