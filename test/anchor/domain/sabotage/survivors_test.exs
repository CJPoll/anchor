defmodule Anchor.Domain.Sabotage.SurvivorsTest do
  # DND-5483: the survivors list, parsed and judged against a run.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5483_survivors_replay.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ChangedFunction
  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Run
  alias Anchor.Domain.Sabotage.Survivors
  alias Anchor.Domain.Sabotage.Survivors.Entry

  @a "aaaaaaaaaaaa"
  @b "bbbbbbbbbbbb"
  @c "cccccccccccc"
  @d "dddddddddddd"
  @e "eeeeeeeeeeee"

  defp mutant(id, function \\ {:add, 2}, operator \\ :return_input, file \\ "lib/calc.ex") do
    %Mutant{
      id: id,
      file: file,
      module: Calc,
      function: function,
      operator: operator,
      variant: 0,
      target: "",
      range: {{1, 1}, {1, 2}},
      original: "",
      replacement: "",
      patch: ""
    }
  end

  defp outcome(id, status, killers \\ []),
    do: %{
      mutant: mutant(id),
      status: status,
      killers: killers,
      selection: {:mirror, ["test/calc_test.exs"]},
      reason: nil
    }

  defp entry(id, mfa \\ "Calc.add/2", file \\ "lib/calc.ex", operator \\ "return_input"),
    do: %Entry{
      id: id,
      file: file,
      mfa: mfa,
      operator: operator,
      reason: "logging only",
      line_no: 1
    }

  defp run(outcomes, opts \\ []) do
    %Run{
      outcomes: outcomes,
      not_run: Keyword.get(opts, :not_run, []),
      not_selected: Keyword.get(opts, :not_selected, []),
      scope_functions: Keyword.get(opts, :scope, ["Calc.add/2"]),
      errors: Keyword.get(opts, :errors, [])
    }
  end

  describe "parse/1" do
    test "1: two valid lines, a blank line and a # comment: two entries with every field" do
      lines = [
        "# survivors",
        "#{@a} lib/calc.ex Calc.add/2 return_input  # logging only",
        "",
        "#{@b} lib/calc.ex Calc.valid?/1 delete_statement # defensive fallback"
      ]

      assert {:ok, [first, second]} = Survivors.parse(lines)

      assert first == %Entry{
               id: @a,
               file: "lib/calc.ex",
               mfa: "Calc.add/2",
               operator: "return_input",
               reason: "logging only",
               line_no: 2
             }

      assert %Entry{id: @b, mfa: "Calc.valid?/1", line_no: 4, reason: "defensive fallback"} =
               second
    end

    test "2: a TODO, an empty and a fixme reason are refused, naming lines 1-3" do
      lines = [
        "#{@a} lib/calc.ex Calc.add/2 return_input  # TODO",
        "#{@b} lib/calc.ex Calc.add/2 return_input  #  ",
        "#{@c} lib/calc.ex Calc.add/2 return_input  # fixme: later"
      ]

      assert {:error, errors} = Survivors.parse(lines)
      assert Enum.map(errors, &elem(&1, 0)) == [1, 2, 3]
      assert {1, "the reason is a placeholder" <> _} = Enum.at(errors, 0)
      assert {2, "the reason is empty" <> _} = Enum.at(errors, 1)
      assert {3, "the reason is a placeholder" <> _} = Enum.at(errors, 2)
    end

    test "2b: TBD, a missing reason and the printed placeholder are refused too" do
      lines = [
        "#{@a} lib/calc.ex Calc.add/2 return_input  # tbd",
        "#{@b} lib/calc.ex Calc.add/2 return_input",
        "#{@c} lib/calc.ex Calc.add/2 return_input  # <why no test can kill it>"
      ]

      assert {:error, [{1, one}, {2, two}, {3, three}]} = Survivors.parse(lines)
      assert one =~ "placeholder"
      assert two =~ "no reason"
      assert three =~ "placeholder"
    end

    test "3: a duplicate id names both lines" do
      lines = [
        "#{@a} lib/calc.ex Calc.add/2 return_input  # one",
        "#{@b} lib/calc.ex Calc.add/2 return_input  # two",
        "#{@a} lib/calc.ex Calc.add/2 return_input  # three"
      ]

      assert {:error, [{3, message}]} = Survivors.parse(lines)
      assert message =~ "duplicate id #{@a}: lines 1 and 3"
    end

    test "4: three fields, or an id that is not 12 hex characters, names the line" do
      lines = [
        "#{@a} lib/calc.ex return_input  # three fields",
        "AAAAAAAAAAAA lib/calc.ex Calc.add/2 return_input  # upper case",
        "abc lib/calc.ex Calc.add/2 return_input  # short",
        "#{@d} lib/calc.ex Calc.add return_input  # no arity",
        "#{@e} lib/calc.ex Calc.add/2 no_such_operator  # unknown operator"
      ]

      assert {:error, errors} = Survivors.parse(lines)
      assert Enum.map(errors, &elem(&1, 0)) == [1, 2, 3, 4, 5]
      assert {1, "expected <id> <file> <Module.fun/arity> <operator>" <> _} = Enum.at(errors, 0)
      assert {2, "the id is not 12 lowercase hex characters" <> _} = Enum.at(errors, 1)
      assert {4, "the function is not Module.fun/arity" <> _} = Enum.at(errors, 3)
      assert {5, "unknown operator" <> _} = Enum.at(errors, 4)
    end

    test "an empty list (an empty file) is no entries" do
      assert Survivors.parse([]) == {:ok, []}
    end
  end

  describe "judge/2" do
    test "1: an unlisted survivor is new" do
      j = Survivors.judge(run([outcome(@a, :survived)]), [])
      assert Enum.map(j.new, & &1.mutant.id) == [@a]
      assert j.held == [] and j.stale == []
    end

    test "2: a listed survivor is held, not new" do
      j = Survivors.judge(run([outcome(@a, :survived)]), [entry(@a)])
      assert j.new == []
      assert Enum.map(j.held, & &1.id) == [@a]
    end

    test "3: a listed mutant now killed is stale, naming its killers" do
      killed = outcome(@a, :killed, [{"test/calc_test.exs", 12, "test add/2 sums"}])
      j = Survivors.judge(run([killed]), [entry(@a)])

      assert [{%Entry{id: @a}, "now killed by test/calc_test.exs:12 test add/2 sums"}] =
               j.stale
    end

    test "4: a listed mutant of an in-scope function that is no longer generated is stale" do
      j = Survivors.judge(run([]), [entry(@b)])
      assert [{%Entry{id: @b}, "no longer generated"}] = j.stale
      assert j.unjudged == []
    end

    test "5: a listed mutant the cap left unrun is not judged (positive control for 4)" do
      j = Survivors.judge(run([], not_run: [mutant(@b)]), [entry(@b)])
      assert j.stale == []
      assert [{%Entry{id: @b}, :not_run}] = j.unjudged
    end

    test "5b: a listed mutant --only left out is not judged" do
      j = Survivors.judge(run([], not_selected: [mutant(@b)]), [entry(@b)])
      assert [{%Entry{id: @b}, :not_run}] = j.unjudged
    end

    test "6: an entry for a function outside the scope is not judged at all" do
      j = Survivors.judge(run([]), [entry(@c, "Other.f/1", "lib/other.ex")])
      assert j.new == [] and j.stale == [] and j.unjudged == [] and j.held == []
    end

    test "7: an unlisted no_tests mutant is new" do
      j = Survivors.judge(run([outcome(@d, :no_tests)]), [])
      assert Enum.map(j.new, & &1.mutant.id) == [@d]
    end

    test "8: a listed invalid mutant is stale" do
      j = Survivors.judge(run([outcome(@e, :invalid)]), [entry(@e)])

      assert [{%Entry{id: @e}, "now invalid: it does not compile, so it needs no entry"}] =
               j.stale
    end

    test "8b: a listed timeout is stale, a listed crash is not judged" do
      j =
        Survivors.judge(
          run([outcome(@a, :timeout, ["(timeout)"]), outcome(@b, :crashed)]),
          [entry(@a), entry(@b)]
        )

      assert [{%Entry{id: @a}, "now killed by (timeout)"}] = j.stale
      assert [{%Entry{id: @b}, :crashed}] = j.unjudged
    end

    test "9: an entry whose file differs from its outcome's is malformed, never held" do
      j = Survivors.judge(run([outcome(@a, :survived)]), [entry(@a, "Calc.add/2", "lib/x.ex")])
      assert j.held == []
      assert Enum.map(j.new, & &1.mutant.id) == [@a]
      assert [{%Entry{id: @a}, message}] = j.malformed
      assert message =~ "belongs to Calc.add/2 return_input in lib/calc.ex"
    end

    test "9b: an operator mismatch is malformed too" do
      j =
        Survivors.judge(run([outcome(@a, :survived)]), [
          entry(@a, "Calc.add/2", "lib/calc.ex", "narrow_clause")
        ])

      assert [{%Entry{id: @a}, _message}] = j.malformed
    end

    test "an entry of a function no mutant could be made of this run is not judged" do
      function = %ChangedFunction{
        file: "lib/calc.ex",
        module: Calc,
        name: :add,
        arity: 2,
        kind: :def,
        changed_lines: [3]
      }

      j = Survivors.judge(run([], errors: [{function, {:parse_error, 3, "oops"}}]), [entry(@b)])
      assert [{%Entry{id: @b}, :no_mutant_made}] = j.unjudged
      assert j.stale == []
    end

    test "a held survivor counts once; a killed unlisted mutant is nothing" do
      j = Survivors.judge(run([outcome(@a, :survived), outcome(@b, :killed)]), [entry(@a)])
      assert j.new == [] and j.stale == []
      assert Enum.map(j.held, & &1.id) == [@a]
    end

    test "violation?/1 is true for new, stale or malformed, false for held or unjudged" do
      refute Survivors.violation?(Survivors.judge(run([outcome(@a, :survived)]), [entry(@a)]))
      assert Survivors.violation?(Survivors.judge(run([outcome(@a, :survived)]), []))
      assert Survivors.violation?(Survivors.judge(run([]), [entry(@b)]))
      refute Survivors.violation?(Survivors.judge(run([], not_run: [mutant(@b)]), [entry(@b)]))
    end
  end

  describe "grew/2" do
    test "1: working [A, B], base [A]: B" do
      base = ["#{@a} lib/calc.ex Calc.add/2 return_input  # one"]
      assert Survivors.grew([entry(@a), entry(@b)], base) == {:added, [entry(@b)]}
    end

    test "2: base absent: every entry, flagged first landing" do
      assert Survivors.grew([entry(@a), entry(@b)], :absent) ==
               {:first_landing, [entry(@a), entry(@b)]}
    end

    test "3: working [A], base [A, B] (shrunk): nothing" do
      base = [
        "#{@a} lib/calc.ex Calc.add/2 return_input  # one",
        "#{@b} lib/calc.ex Calc.add/2 return_input  # two"
      ]

      assert Survivors.grew([entry(@a)], base) == {:added, []}
    end

    test "a reason changed on the branch is not growth: entries are keyed by id" do
      base = ["#{@a} lib/calc.ex Calc.add/2 return_input  # an older reason"]
      assert Survivors.grew([entry(@a)], base) == {:added, []}
    end
  end

  describe "line_for/1" do
    test "1: a survived outcome: exactly <id> <file> <M.f/a> <operator>  # <reason>" do
      assert Survivors.line_for(outcome(@a, :survived)) ==
               "#{@a} lib/calc.ex Calc.add/2 return_input  # <why no test can kill it>"
    end

    test "the printed line, once its reason is filled in, parses back to the same mutant" do
      line =
        outcome(@a, :survived)
        |> Survivors.line_for()
        |> String.replace("<why no test can kill it>", "logging only")

      assert {:ok, [%Entry{id: @a, file: "lib/calc.ex", mfa: "Calc.add/2"}]} =
               Survivors.parse([line])
    end
  end
end
