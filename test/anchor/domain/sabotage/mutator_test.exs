defmodule Anchor.Domain.Sabotage.MutatorTest do
  # DND-5471: the generator end to end over source text: the pinned mutants of
  # the canary, the orphan skips, stable ids, the errors and the patches.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5471.md
  # DND-5564 (drop_effect_call keeps its arguments):
  # ../../../sabotage_records/sabotage-20261103-dnd_5473_sabotage_run.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.Mutator
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.Skipped

  @canary_path "test/fixtures/sabotage/canary.ex"
  @canary AnchorFixtures.Sabotage.Canary
  @nested AnchorFixtures.Sabotage.Canary.Nested

  # Function => {mutants as {operator, variant, target}, skipped as {operator, variant, reason}}.
  @pinned [
    {{@canary, :statements, 1},
     {[{:drop_effect_call, nil, "Logger.info(\"doubled\")"}],
      [
        {:delete_statement, nil, "removes the last use of function `validate/1`"},
        {:delete_statement, nil, "orphans variable `y` bound at line 17 and used at line 19"},
        {:return_input, 0, "removes the last use of function `double/1`"}
      ]}},
    {{@canary, :checked, 1},
     {[{:delete_statement, nil, "true = is_integer(x)"}, {:return_input, 0, "checked(x)"}], []}},
    # DND-5564: dropping `send(pid, ...)` keeps `pid` used (`_ = {pid, ...}`).
    {{@canary, :effects, 2},
     {[
        {:drop_effect_call, nil, "send(pid, {:value, x})"},
        {:drop_effect_call, nil, "Logger.debug(\"sent\")"},
        {:return_input, 0, "effects(pid, x)"},
        {:return_input, 1, "effects(pid, x)"}
      ], []}},
    {{@canary, :classify, 1},
     {[
        {:narrow_clause, nil, "classify(:small)"},
        {:narrow_clause, nil, "classify(n) when is_integer(n) and n > @limit"},
        {:return_input, 0, "classify(n) when is_integer(n) and n > @limit"},
        {:narrow_clause, nil, "classify(_other)"}
      ], []}},
    {{@canary, :unwrap, 1},
     {[
        {:narrow_clause, nil, "{:ok, value}"},
        {:narrow_clause, nil, "{:error, reason}"},
        {:return_input, 0, "unwrap(result)"}
      ], []}},
    {{@canary, :pipeline, 2},
     {[
        {:with_passthrough, nil, "{:ok, user} <- lookup.(id)"},
        {:with_passthrough, nil, "%URI{host: host} <- URI.parse(user)"},
        {:return_input, 0, "pipeline(id, lookup)"},
        {:return_input, 1, "pipeline(id, lookup)"}
      ], []}},
    {{@canary, :decide, 2},
     {[
        {:force_condition, true, "x > @limit"},
        {:force_condition, false, "x > @limit"},
        {:return_input, 0, "decide(x, flag)"},
        {:return_input, 1, "decide(x, flag)"}
      ], []}},
    {{@canary, :grade, 1},
     {[
        {:force_condition, true, "score > 90"},
        {:force_condition, false, "score > 90"},
        {:force_condition, true, "score > 50"},
        {:force_condition, false, "score > 50"},
        {:return_input, 0, "grade(score)"}
      ], []}},
    {{@canary, :pick, 2},
     {[
        {:narrow_clause, nil, "pick(a, b) when is_integer(b)"},
        {:return_input, 1, "pick(a, b) when is_integer(b)"},
        {:narrow_clause, nil, "pick(a, _b)"}
      ],
      [
        {:return_input, 0, "the guard reads `b`, which the mutant renames `_b`"},
        {:return_input, 0, "the body already returns `a`"}
      ]}},
    {{@canary, :scaled, 1},
     {[
        {:return_input, 0, "scaled(x, factor \\\\ 2)"},
        {:return_input, 1, "scaled(x, factor \\\\ 2)"}
      ], []}},
    {{@canary, :scaled, 2},
     {[
        {:return_input, 0, "scaled(x, factor \\\\ 2)"},
        {:return_input, 1, "scaled(x, factor \\\\ 2)"}
      ], []}},
    {{@canary, :bits, 2},
     {[{:return_input, 1, "bits(<<head::binary-size(1), _rest::binary>>, y)"}], []}},
    {{@canary, :limited, 2}, {[{:return_input, 1, "limited(@limit, y)"}], []}},
    {{@canary, :counted, 1},
     {[],
      [
        {:delete_statement, nil, "removes the last use of function `loop/1`"},
        {:return_input, 0, "removes the last use of function `loop/1`"}
      ]}},
    {{@canary, :host, 1},
     {[
        {:delete_statement, nil, "_ = Link.to_string(link)"},
        {:return_input, 0, "host(%Link{} = link)"}
      ], []}},
    {{@canary, :logged, 1},
     {[{:drop_effect_call, nil, "Logger.info(y)"}, {:return_input, 0, "logged(x)"}],
      [{:delete_statement, nil, "orphans variable `y` bound at line 91 and used at line 92"}]}},
    {{@canary, :remembered, 1},
     {[{:return_input, 0, "remembered(x)"}],
      [
        {:drop_effect_call, nil,
         "orphans variable `previous` bound at line 97 and used at line 98"}
      ]}},
    {{@nested, :twice, 1},
     {[{:drop_effect_call, nil, "send(self(), :twice)"}, {:return_input, 0, "twice(x)"}],
      [{:delete_statement, nil, "orphans variable `y` bound at line 113 and used at line 115"}]}}
  ]

  setup_all do
    %{canary: File.read!(@canary_path)}
  end

  defp generate!(source, mfa, opts \\ []) do
    {:ok, result} = Mutator.generate(source, "lib/m.ex", mfa, opts)
    result
  end

  defp ids(source),
    do:
      Enum.flat_map(@pinned, fn {mfa, _expected} ->
        Enum.map(generate!(source, mfa).mutants, & &1.id)
      end)

  # Applies a one-hunk unified diff the way `patch -p1` would.
  defp apply_diff(source, diff) do
    [_old_header, _new_header, hunk | lines] = String.split(diff, "\n", trim: true)
    [_all, start] = Regex.run(~r/^@@ -(\d+),\d+ \+\d+,\d+ @@$/, hunk)
    start = String.to_integer(start)

    {old_lines, new_lines} =
      Enum.reduce(lines, {[], []}, fn
        " " <> text, {old, new} -> {[text | old], [text | new]}
        "-" <> text, {old, new} -> {[text | old], new}
        "+" <> text, {old, new} -> {old, [text | new]}
      end)

    source_lines = String.split(source, "\n")
    skip = if old_lines == [], do: start, else: start - 1
    {before, rest} = Enum.split(source_lines, skip)
    after_lines = Enum.drop(rest, length(old_lines))

    assert Enum.take(rest, length(old_lines)) == Enum.reverse(old_lines)
    Enum.join(before ++ Enum.reverse(new_lines) ++ after_lines, "\n")
  end

  defp module_source(body), do: "defmodule M do\n" <> body <> "\nend\n"

  describe "generate/4" do
    test "1: the canary's mutants and skips per function (pinned), each with range, original, replacement and patch",
         %{canary: canary} do
      for {mfa, {mutants, skipped}} <- @pinned do
        result = generate!(canary, mfa)

        assert Enum.map(result.mutants, &{&1.operator, &1.variant, &1.target}) == mutants,
               inspect(mfa)

        assert Enum.map(result.skipped, &{&1.operator, &1.variant, &1.reason}) == skipped,
               inspect(mfa)

        for %Mutant{} = m <- result.mutants do
          {start, stop} = m.range
          assert m.id =~ ~r/\A[0-9a-f]{12}\z/
          assert m.original == Patch.slice(canary, m.range)
          assert m.original != m.replacement
          assert m.patch =~ "--- a/lib/m.ex\n+++ b/lib/m.ex\n@@ -"
          assert m.function == {elem(mfa, 1), elem(mfa, 2)}

          # Formatting outside the range is untouched: Sourceror's ranges
          # splice, nothing is re-rendered.
          mutated = Patch.apply_range(canary, m.range, m.replacement)
          prefix = Patch.offset(canary, start)
          suffix = byte_size(canary) - Patch.offset(canary, stop)
          assert binary_part(mutated, 0, prefix) == binary_part(canary, 0, prefix)

          assert binary_part(mutated, byte_size(mutated) - suffix, suffix) ==
                   binary_part(canary, byte_size(canary) - suffix, suffix)
        end
      end
    end

    test "2: deleting the only reader of x leaves x unused: skipped; a sibling statement is a mutant" do
      source =
        module_source("""
          def f(a) do
            x = g(a)
            use_it(x)
            check(a)
            a
          end

          def g(a), do: a
          def use_it(x), do: x
          def check(a), do: a
        """)

      result = generate!(source, {M, :f, 1}, operators: [:delete_statement])

      assert [%Mutant{target: "check(a)"}] = result.mutants

      assert [%Skipped{target: "x = g(a)"} = orphan, %Skipped{target: "use_it(x)"} = unused] =
               result.skipped

      assert orphan.reason == "orphans variable `x` bound at line 3 and used at line 4"
      assert unused.reason =~ "`x`"
      assert unused.reason =~ "unused"
      assert unused.range == {{4, 1}, {5, 1}}
    end

    test "3: ids survive 10 blank lines and an unrelated function inserted above", %{
      canary: canary
    } do
      moved =
        String.replace(
          canary,
          "  @limit 10\n",
          "  @limit 10\n" <> String.duplicate("\n", 10) <> "  def unrelated(x), do: x\n",
          global: false
        )

      assert moved != canary
      assert ids(moved) == ids(canary)
      assert length(Enum.uniq(ids(canary))) == length(ids(canary))
    end

    test "4: two identical statements are two mutants with different ids (the occurrence index)" do
      source =
        module_source("""
          def f(x) do
            log(x)
            log(x)
            x
          end

          def log(x), do: x
        """)

      assert [first, second] =
               generate!(source, {M, :f, 1}, operators: [:delete_statement]).mutants

      assert first.target == second.target
      assert first.id != second.id
    end

    test "5: a source that does not parse is an error naming the line" do
      source = module_source("  def f(x) do\n    x\n  end\n\n  def g(y) do\n    y +\n  end")

      assert {:error, {:parse_error, 8, message}} = Mutator.generate(source, "m.ex", {M, :f, 1})
      assert message =~ "syntax error"
    end

    test "6: a function only a macro defines, or a module the file lacks, is not in source" do
      source =
        module_source("  use GenServer\n\n  def handle_call(_m, _f, s), do: {:reply, :ok, s}")

      assert Mutator.generate(source, "m.ex", {M, :init, 1}) == {:error, :not_in_source}

      assert Mutator.generate(source, "m.ex", {Other, :handle_call, 3}) ==
               {:error, :not_in_source}

      assert {:ok, _result} = Mutator.generate(source, "m.ex", {M, :handle_call, 3})
    end

    test "7: a function with no mutation target has no mutants and no skips" do
      assert Mutator.generate(module_source("  def f, do: :ok"), "m.ex", {M, :f, 0}) ==
               {:ok, %{mutants: [], skipped: []}}
    end

    test "an empty do-block body has no return_input target (no crash)" do
      source = module_source("  def f(x) when is_integer(x) do\n  end")

      assert Mutator.generate(source, "m.ex", {M, :f, 1}) == {:ok, %{mutants: [], skipped: []}}
    end

    test "8: a clause with a default argument covers both arities; a bodiless head's defaults too" do
      source = module_source("  def f(a, b \\\\ 1) do\n    a + b\n  end")

      assert [_, _] = generate!(source, {M, :f, 1}).mutants
      assert [_, _] = generate!(source, {M, :f, 2}).mutants
      assert Mutator.generate(source, "m.ex", {M, :f, 3}) == {:error, :not_in_source}

      headed = module_source("  def g(a, b \\\\ 1)\n  def g(a, b), do: a + b")
      assert [_, _] = generate!(headed, {M, :g, 1}).mutants
    end

    test "9: applying a mutant's replacement to its range equals applying its patch", %{
      canary: canary
    } do
      for {mfa, _expected} <- @pinned, m <- generate!(canary, mfa).mutants do
        assert apply_diff(canary, m.patch) == Patch.apply_range(canary, m.range, m.replacement),
               "#{m.operator} #{inspect(m.target)}"
      end
    end

    test "10: the same source and function give the same result in the same order", %{
      canary: canary
    } do
      for {mfa, _expected} <- @pinned,
          do: assert(generate!(canary, mfa) == generate!(canary, mfa))
    end

    test "11: `operators:` runs only the operators named", %{canary: canary} do
      result = generate!(canary, {@canary, :classify, 1}, operators: [:narrow_clause])

      assert Enum.map(result.mutants, & &1.operator) == List.duplicate(:narrow_clause, 3)
      assert result.skipped == []
    end

    test "a nested module's use of a same-named private function does not count for the outer one" do
      source =
        module_source("""
          def f(x) do
            g(x)
            x
          end

          defp g(x), do: x

          defmodule Inner do
            def h(x), do: g(x)
            defp g(x), do: x
          end
        """)

      assert %{mutants: [], skipped: [%{reason: "removes the last use of function `g/1`"}]} =
               generate!(source, {M, :f, 1}, operators: [:delete_statement])
    end

    test "a misspelt effect token is refused even with no statement to classify" do
      assert_raise ArgumentError,
                   ~r/sabotage effect_calls: "Notifier" is not a function reference/,
                   fn ->
                     Mutator.generate(module_source("  def f, do: :ok"), "m.ex", {M, :f, 0},
                       effect_calls: ["Notifier"]
                     )
                   end
    end

    test "an unknown operator is refused" do
      assert_raise ArgumentError, ~r/unknown operators \[:flip\]/, fn ->
        Mutator.generate(module_source("  def f, do: :ok"), "m.ex", {M, :f, 0},
          operators: [:flip]
        )
      end
    end

    test "a statement that removes the last read of a module attribute or an alias is skipped" do
      source =
        module_source("""
          alias Foo.Bar
          @limit 3

          def f(x) do
            check(x, @limit)
            Bar.go(x)
            x
          end

          def check(x, _limit), do: x
        """)

      assert [
               %{reason: "removes the last use of module attribute `@limit`"},
               %{reason: "removes the last use of alias `Bar`"}
             ] =
               generate!(source, {M, :f, 1}, operators: [:delete_statement]).skipped
    end
  end

  describe "purity" do
    @impure [File, IO, Process, System, Port, Node, :ets, :persistent_term]

    # The impure modules `source` calls, and whether it evaluates or compiles code.
    defp impurities(source) do
      modules =
        source
        |> Code.string_to_quoted!()
        |> Anchor.Domain.DependencyAnalyzer.extract_call_dependencies()

      {Enum.filter(modules, &(&1 in @impure)), source =~ ~r/Code\.(eval|compile|require|ensure)/}
    end

    test "the sabotage generator's modules call no IO, file, process or system module" do
      files =
        ~w(mutator operators orphan_check source_tree patch mutant_id effect_calls mutant skipped)
        |> Enum.map(&"lib/anchor/domain/sabotage/#{&1}.ex")

      for file <- files, do: assert(impurities(File.read!(file)) == {[], false}, file)
    end

    test "positive control: the scan flags a file call, an ETS call and an eval" do
      source = """
      defmodule Impure do
        def f(p, t), do: {File.read!(p), :ets.insert(t, {1}), Code.eval_string("1")}
      end
      """

      assert impurities(source) == {[File, :ets], true}
    end
  end
end
