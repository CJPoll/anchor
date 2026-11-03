defmodule Anchor.Domain.Sabotage.OperatorsTest do
  # DND-5471: each operator's edits on a table of functions. Each row is a
  # function's source; an edit is checked by the text it leaves behind, and,
  # where the QA plan's row names a "none", by the generator's verdict on it.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  # DND-5564 (drop_effect_call keeps its arguments):
  # ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Operators
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.SourceTree

  @never "node() == :__anchor_sabotage_never__"

  defp module_source(body) do
    indented = body |> String.split("\n") |> Enum.map_join("\n", &indent/1)
    "defmodule M do\n  require Logger\n\n" <> indented <> "\nend\n"
  end

  defp indent(""), do: ""
  defp indent(line), do: "  " <> line

  # The edits `operator` makes of every clause of M.name/arity.
  defp edits(body, operator, {name, arity}, tokens \\ []) do
    source = module_source(body)
    {:ok, ast} = SourceTree.parse(source)
    {:ok, clauses} = SourceTree.function_clauses(ast, M, name, arity)

    edits =
      Enum.flat_map(clauses, fn clause ->
        apply(Operators, operator, [
          %{source: source, clause: clause, clause_count: length(clauses), effect_calls: tokens}
        ])
      end)

    {source, edits}
  end

  defp applied(source, edit), do: Patch.apply_range(source, edit.range, edit.replacement)

  defp generated(body, operator, {name, arity}) do
    {:ok, result} =
      Mutator.generate(module_source(body), "lib/m.ex", {M, name, arity}, operators: [operator])

    result
  end

  @effects_body "def f(x) do\n  y = g(x)\n  Logger.info(y)\n  h(x)\nend\n\ndefp g(x), do: x\ndefp h(x), do: x"

  describe "delete_statement/1 and drop_effect_call/1" do
    test "1: delete_statement targets the pure `y = g(x)` only; y is used later, so no mutant" do
      {_source, edits} = edits(@effects_body, :delete_statement, {:f, 1})

      assert Enum.map(edits, & &1.target) == ["y = g(x)"]
      assert generated(@effects_body, :delete_statement, {:f, 1}).mutants == []

      assert [%{reason: "orphans variable `y` bound at line 5 and used at line 6"}] =
               generated(@effects_body, :delete_statement, {:f, 1}).skipped
    end

    # DND-5564: the dropped call keeps its arguments evaluated (`_ = {y}`), so
    # `y` stays used and the mutant compiles; the effect is still gone.
    test "2: drop_effect_call replaces the Logger call with `_ = {y}`, and that is a mutant" do
      {source, [edit]} = edits(@effects_body, :drop_effect_call, {:f, 1})

      assert edit.target == "Logger.info(y)"
      assert edit.range == {{6, 5}, {6, 19}}
      assert edit.replacement == "_ = {y}"
      refute applied(source, edit) =~ "Logger.info"
      assert applied(source, edit) =~ "    y = g(x)\n    _ = {y}\n    h(x)\n"

      assert %{mutants: [mutant], skipped: []} =
               generated(@effects_body, :drop_effect_call, {:f, 1})

      assert {mutant.original, mutant.replacement} == {"Logger.info(y)", "_ = {y}"}
    end

    test "2: every argument is kept, a piped one and a trailing keyword list included" do
      body =
        "def f(pid, x) do\n  send(pid, {:value, x})\n  x |> Logger.info(meta: 1)\n  Logger.flush()\n  x\nend"

      {source, edits} = edits(body, :drop_effect_call, {:f, 2})

      assert Enum.map(edits, &{&1.target, &1.replacement}) == [
               {"send(pid, {:value, x})", "_ = {pid, {:value, x}}"},
               {"x |> Logger.info(meta: 1)", "_ = {x, meta: 1}"},
               {"Logger.flush()", ""}
             ]

      # A call with no argument has nothing to keep: its whole line goes.
      refute applied(source, List.last(edits)) =~ "Logger.flush"
      assert applied(source, List.last(edits)) =~ "Logger.info(meta: 1)\n    x\n"
    end

    test "2: a call with a do block keeps nothing: its whole lines are deleted" do
      body = "def f(x) do\n  Logger.info do\n    x\n  end\n  x\nend"

      {source, [edit]} = edits(body, :drop_effect_call, {:f, 1})

      assert edit.replacement == ""
      assert applied(source, edit) =~ "  def f(x) do\n    x\n  end\n"
    end

    test "2: positive control: a drop that orphans something else is still refused" do
      bound = "def f(x) do\n  old = Process.put(:k, x)\n  {x, old}\nend"

      assert %{mutants: [], skipped: [%{reason: reason}]} =
               generated(bound, :drop_effect_call, {:f, 1})

      assert reason =~ "orphans variable `old`"

      aliased = "alias Notifier.Push\n\ndef f(x) do\n  Push.send(x)\n  x\nend"

      {:ok, result} =
        Mutator.generate(module_source(aliased), "lib/m.ex", {M, :f, 1},
          operators: [:drop_effect_call],
          effect_calls: ["Push.send/1"]
        )

      assert %{mutants: [], skipped: [%{reason: "removes the last use of alias `Push`"}]} =
               result
    end

    test "3: delete_statement removes `validate(x)`, and that is a mutant" do
      body =
        "def f(x) do\n  validate(x)\n  save(x)\nend\n\ndef validate(x), do: x\ndef save(x), do: x"

      {source, [edit]} = edits(body, :delete_statement, {:f, 1})

      assert edit.target == "validate(x)"
      assert applied(source, edit) =~ "  def f(x) do\n    save(x)\n  end"

      assert [%{operator: :delete_statement}] =
               generated(body, :delete_statement, {:f, 1}).mutants
    end

    test "a statement that shares a line with another is not deleted" do
      body =
        "def f(x) do\n  a(x); b(x)\n  c(x)\nend\n\ndef a(x), do: x\ndef b(x), do: x\ndef c(x), do: x"

      {_source, edits} = edits(body, :delete_statement, {:f, 1})

      assert Enum.map(edits, &{&1.target, &1.skip}) == [
               {"a(x)", "it shares line 5 with another expression"},
               {"b(x)", "it shares line 5 with another expression"}
             ]
    end

    test "every non-final statement gets exactly one of the two operators" do
      body =
        "def f(x) do\n  a = g(x)\n  send(self(), a)\n  Repo.insert(a)\n  _ = g(a)\n  a\nend\n\ndefp g(x), do: x"

      {_s, deletes} = edits(body, :delete_statement, {:f, 1})
      {_s, drops} = edits(body, :drop_effect_call, {:f, 1})

      assert Enum.map(deletes, & &1.target) == ["a = g(x)", "_ = g(a)"]
      assert Enum.map(drops, & &1.target) == ["send(self(), a)", "Repo.insert(a)"]
    end

    test "an extra effect token moves a statement to drop_effect_call" do
      body = "def f(x) do\n  Notifier.push(x)\n  x\nend"

      assert {_s, [%{target: "Notifier.push(x)"}]} = edits(body, :delete_statement, {:f, 1})

      assert {_s, [%{target: "Notifier.push(x)"}]} =
               edits(body, :drop_effect_call, {:f, 1}, ["Notifier.push/1"])

      assert {_s, []} = edits(body, :delete_statement, {:f, 1}, ["Notifier.push/1"])
    end
  end

  describe "narrow_clause/1" do
    test "4: each function clause gains the never guard" do
      {source, [first, second]} =
        edits("def f(:a), do: 1\ndef f(:b), do: 2", :narrow_clause, {:f, 1})

      assert applied(source, first) =~ "def f(:a) when #{@never}, do: 1"
      assert applied(source, second) =~ "def f(:b) when #{@never}, do: 2"
    end

    test "5: an existing guard is wrapped and anded" do
      body = "def f(x) when is_integer(x), do: x\ndef f(y), do: y"
      {source, [first, _second]} = edits(body, :narrow_clause, {:f, 1})

      assert applied(source, first) =~ "def f(x) when (is_integer(x)) and #{@never}, do: x"
    end

    test "a head with two `when`s is not narrowed" do
      body = "def f(x) when is_atom(x) when is_nil(x), do: x\ndef f(y), do: y"

      assert {_s, [%{skip: "the head has more than one `when`"}, %{skip: nil}]} =
               edits(body, :narrow_clause, {:f, 1})
    end

    test "a function with one clause is not narrowed" do
      assert {_s, []} = edits("def f(x) when is_integer(x), do: x", :narrow_clause, {:f, 1})
    end

    test "6: each case clause gains the never guard" do
      body = "def f(r) do\n  case r do\n    {:ok, v} -> v\n    {:error, _} -> nil\n  end\nend"
      {source, [first, second]} = edits(body, :narrow_clause, {:f, 1})

      assert applied(source, first) =~ "{:ok, v} when #{@never} -> v"
      assert applied(source, second) =~ "{:error, _} when #{@never} -> nil"
    end
  end

  describe "with_passthrough/1" do
    test "7: literals become `_` and a struct pattern a map pattern" do
      body =
        "def f(id) do\n  with {:ok, u} <- fetch(id),\n       %User{} = u2 <- load(u) do\n    u2\n  end\nend"

      {source, [first, second]} = edits(body, :with_passthrough, {:f, 1})

      assert applied(source, first) =~ "with {_, u} <- fetch(id),\n"
      assert applied(source, second) =~ "%{} = u2 <- load(u) do"
    end

    test "a step guard is dropped" do
      body = "def f(id) do\n  with x when is_integer(x) <- fetch(id) do\n    x\n  end\nend"
      {source, [edit]} = edits(body, :with_passthrough, {:f, 1})

      assert applied(source, edit) =~ "with x <- fetch(id) do"
    end

    test "8: a bare variable step has nothing to relax" do
      body = "def f(id) do\n  with u <- fetch(id) do\n    u\n  end\nend"

      assert {_s, [%{skip: "the pattern has nothing to relax"}]} =
               edits(body, :with_passthrough, {:f, 1})
    end
  end

  describe "force_condition/1" do
    test "9: an if condition, forced true and forced false" do
      body = "def f(x) do\n  if valid?(x), do: a(x), else: b()\nend"
      {source, [forced_true, forced_false]} = edits(body, :force_condition, {:f, 1})

      assert {forced_true.variant, forced_false.variant} == {true, false}

      assert applied(source, forced_true) =~
               "if Process.get(:__anchor_sabotage__) == nil, do: a(x), else: b()"

      assert applied(source, forced_false) =~
               "if Process.get(:__anchor_sabotage__) != nil, do: a(x), else: b()"
    end

    test "10: each cond condition but a final literal true" do
      body = "def f(x) do\n  cond do\n    x > 1 -> :a\n    true -> :b\n  end\nend"
      {_source, edits} = edits(body, :force_condition, {:f, 1})

      assert Enum.map(edits, &{&1.target, &1.variant}) == [{"x > 1", true}, {"x > 1", false}]
    end

    test "an unless condition is forced too" do
      body = "def f(x) do\n  unless x, do: :a\nend"

      assert {_s, [%{target: "x"}, %{target: "x"}]} = edits(body, :force_condition, {:f, 1})
    end
  end

  describe "return_input/1" do
    test "11: each bare-variable parameter, the others renamed `_name`" do
      {source, [first, second]} = edits("def f(a, b), do: a + b", :return_input, {:f, 2})

      assert {first.variant, second.variant} == {0, 1}
      assert applied(source, first) =~ "def f(a, _b), do: a\n"
      assert applied(source, second) =~ "def f(_a, b), do: b\n"
    end

    test "12: a parameter the guard reads cannot be renamed" do
      {_source, [first, second]} =
        edits("def f(a, b) when b > 0, do: a + b", :return_input, {:f, 2})

      assert first.skip == "the guard reads `b`, which the mutant renames `_b`"
      assert second.skip == nil
    end

    test "13: `pattern = var` returns var; the pattern's variables are renamed" do
      {source, [edit]} = edits("def f(%{k: v} = m), do: v", :return_input, {:f, 1})

      assert applied(source, edit) =~ "def f(%{k: _v} = m), do: m\n"
    end

    test "a do-block body is replaced whole; a body that already returns the input is skipped" do
      body = "def f(x, y) do\n  z = x + y\n  z * 2\nend\n\ndef g(x), do: x"
      {source, [first, _second]} = edits(body, :return_input, {:f, 2})

      assert applied(source, first) =~ "  def f(x, _y) do\n    x\n  end\n"
      assert {_s, [%{skip: "the body already returns `x`"}]} = edits(body, :return_input, {:g, 1})
    end
  end
end
