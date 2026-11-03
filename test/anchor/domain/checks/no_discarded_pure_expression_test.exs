defmodule Anchor.Domain.Checks.NoDiscardedPureExpressionTest do
  # DND-5451 (proposal F1): a discarded expression with no effect causes
  # nothing. Rows D1-D19 and S1 are the QA plan's. Pure Domain: sources are
  # parsed with columns, as `Credo.Code.ast/1` parses every file.
  #
  # Sabotage record: ../../../sabotage_records/no_discarded_pure_expression-20261103-dnd_5451_ast_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDiscardedPureExpression, as: Check

  @shape "use the value (bind it and use the binding, or make it the block's last " <>
           "expression), or delete it. A call kept for its effect must be to a module " <>
           "outside pure_patterns and the stdlib pure set."

  defp detect(source, rules \\ [%{}]) do
    source
    |> Code.string_to_quoted!(columns: true)
    |> Check.detect_violations(rules)
  end

  # One function body holding `expr` in a non-final position. The module also
  # defines `add/2`, so a pure_patterns module's own local call can be judged.
  defp discarded(expr, module \\ "App.X") do
    """
    defmodule #{module} do
      @handler &IO.puts/1

      def f(m, a, b, x, xs, s, pid, mod, fun) do
        #{expr}
        {m, a, b, x, xs, s, pid, mod, fun, @handler}
      end

      defp add(a, b), do: a + b
    end
    """
  end

  describe "detect_violations/2" do
    test "D1: a discarded Map.put is reported on its line, with the Fix shape" do
      source = """
      defmodule App.X do
        def f(m) do
          Map.put(m, :a, 1)
          m
        end
      end
      """

      assert [violation] = detect(source)
      assert violation.line == 3
      assert violation.trigger == "Map.put(m, :a, 1)"
      assert String.ends_with?(violation.message, "Fix: " <> @shape)
      assert violation.message =~ "value is discarded and it has no effect"
    end

    test "D2: each literal kind, non-final, is reported" do
      for literal <- [":ok", "1", ~s("s"), "nil", "1.5", "true"] do
        assert [_one] = detect(discarded(literal)), "literal #{literal}"
      end
    end

    test "D3: a bare variable and a module attribute read are reported" do
      assert [%{trigger: "m"}] = detect(discarded("m"))

      source = """
      defmodule App.X do
        @limit 3
        def f(m) do
          @limit
          m
        end
      end
      """

      assert [%{trigger: "@limit", line: 4}] = detect(source)
    end

    test "D4: operators, field reads and containers over pure parts are reported" do
      for expr <- [
            "a + b",
            "x.field",
            "x[:k]",
            "[a, b]",
            "%{a: x}",
            "{a, b}",
            "{a, b, x}",
            ~S("#{a}"),
            "%{m | a: 1}",
            "<<a, b>>",
            "not a",
            "a in xs",
            "[a | xs]"
          ] do
        assert [_one] = detect(discarded(expr)), "expression #{expr}"
      end
    end

    test "D5: an underscore binding of a pure expression is reported, in any body" do
      assert [%{trigger: "_ = Enum.map(xs, &(&1 * 2))"}] =
               detect(discarded("_ = Enum.map(xs, &(&1 * 2))"))

      assert [%{trigger: "_unused = String.trim(s)"}] =
               detect(discarded("_unused = String.trim(s)"))

      in_case = """
      defmodule App.X do
        def f(s) do
          case s do
            :a ->
              _ = String.trim(s)
              :ok
          end
        end
      end
      """

      assert [%{line: 5}] = detect(in_case)
    end

    test "D6: a real binding and a match assertion are not reported" do
      source = """
      defmodule App.X do
        def f(s, p, d, c) do
          x = String.trim(s)
          :ok = File.write(p, d)
          {:ok, _} = Repo.insert(c)
          x
        end
      end
      """

      assert detect(source) == []
      # Positive control: the same call, discarded, is reported.
      assert [_one] = detect(discarded("String.trim(s)"))
    end

    test "D7: an unknown or effectful call is not reported" do
      for expr <- [
            ~s|IO.puts("x")|,
            "send(pid, :m)",
            ~s|Logger.info("x")|,
            "foo(x)",
            "mod.f()",
            "apply(M, :f, [])",
            "fun.()",
            "raise ArgumentError",
            "throw(:x)",
            "exit(:normal)",
            "spawn(fun)",
            ":lists.reverse(xs)",
            "Process.put(:k, 1)"
          ] do
        assert detect(discarded(expr)) == [], "expression #{expr}"
      end
    end

    test "D8: a bang function is not reported" do
      assert detect(discarded("Map.fetch!(m, :k)")) == []
      assert [_one] = detect(discarded("Map.fetch(m, :k)"))
    end

    test "D9: a pure-module call whose function argument has an effect is not reported" do
      assert detect(discarded("Enum.each(xs, &IO.puts/1)")) == []
      assert detect(discarded("Enum.each(xs, fn x -> send(self(), x) end)")) == []
      assert detect(discarded("Enum.map(xs, &foo/1)")) == []
    end

    # Critic round 1 on d5db360: a function held in a variable, a field or an
    # attribute may be any function, so a stdlib call that calls it is not pure.
    test "D9: a stdlib call that calls a function held in a value is not reported" do
      for expr <- [
            "Enum.each(xs, fun)",
            "Enum.each(xs, x.callback)",
            "Enum.each(xs, @handler)",
            "xs |> Enum.map(fun)",
            "Enum.reduce(xs, a, fun)",
            "Map.update(m, :a, 1, fun)",
            "Enum.into(xs, s)",
            "Enum.sort(xs, fun)"
          ] do
        assert detect(discarded(expr)) == [], "expression #{expr}"
      end

      # Positive control: the same calls with data or a pure literal are reported.
      for expr <- [
            "Enum.each(xs, fn y -> y end)",
            "Enum.reduce(xs, a, &+/2)",
            "Enum.sort(xs, :desc)",
            "Map.update(m, :a, 1, &(&1 + 1))",
            "Enum.into(xs, %{})"
          ] do
        assert [_one] = detect(discarded(expr)), "expression #{expr}"
      end
    end

    test "D10: a pure-module call whose function argument is pure is reported" do
      assert [_one] = detect(discarded("Enum.each(xs, fn x -> x + 1 end)"))
      assert [_one] = detect(discarded("Enum.map(xs, &String.trim/1)"))
      assert [_one] = detect(discarded("Enum.map(xs, &(&1 * 2))"))
      assert [_one] = detect(discarded("xs |> Enum.map(&abs/1) |> Enum.sum()"))
    end

    test "D11: a clock or random read is not reported" do
      for expr <- [
            "DateTime.utc_now()",
            "Date.utc_today()",
            "NaiveDateTime.utc_now()",
            "Time.utc_now()",
            "Enum.random(xs)",
            "Enum.shuffle(xs)",
            "Stream.run(s)"
          ] do
        assert detect(discarded(expr)) == [], "expression #{expr}"
      end

      # Positive control: a pure function of the same modules is reported.
      assert [_one] = detect(discarded("Date.add(s, 1)"))
    end

    test "D12: the last expression of a body is never reported" do
      source = """
      defmodule App.X do
        def f(m), do: Map.put(m, :a, 1)

        def g(m) do
          m = Map.put(m, :b, 2)
          Map.put(m, :a, 1)
        end

        def h(xs) do
          Enum.map(xs, fn x ->
            y = x
            Map.put(y, :a, 1)
          end)
        end

        def i(m) do
          case m do
            %{} -> Map.put(m, :a, 1)
          end
        end

        def j(m, c) do
          if c do
            Map.put(m, :a, 1)
          else
            m
          end
        end

        def k(m) do
          _ = Map.put(m, :a, 1)
        end
      end
      """

      assert detect(source) == []
    end

    test "D13: an aliased pure_patterns module is reported; without pure_patterns, not" do
      source = """
      defmodule App.X do
        alias MyApp.Calc

        def f(a, b) do
          Calc.add(a, b)
          a
        end
      end
      """

      assert [%{trigger: "Calc.add(a, b)"}] =
               detect(source, [%{pure_patterns: ["MyApp.*"]}])

      assert detect(source, [%{pure_patterns: []}]) == []
      assert detect(source, [%{pure_patterns: ["Other.*"]}]) == []
    end

    test "D14: a local call in a pure_patterns module is reported; elsewhere, not" do
      assert [%{trigger: "add(a, b)"}] =
               detect(discarded("add(a, b)", "MyApp.Calc"), [%{pure_patterns: ["MyApp.*"]}])

      assert detect(discarded("add(a, b)", "Other.Calc"), [%{pure_patterns: ["MyApp.*"]}]) == []

      # A Kernel effect or a bang local is never pure, even in a pure module.
      assert detect(discarded("send(pid, a)", "MyApp.Calc"), [%{pure_patterns: ["MyApp.*"]}]) ==
               []

      assert detect(discarded("add!(a, b)", "MyApp.Calc"), [%{pure_patterns: ["MyApp.*"]}]) ==
               []
    end

    test "a call on a name the resolver cannot place is not reported" do
      source = """
      defmodule App.X do
        alias @calc, as: Calc

        def f(a) do
          Calc.add(a, 1)
          a
        end
      end
      """

      assert detect(source, [%{pure_patterns: ["*Calc*"]}]) == []
    end

    # Critic round 1 on d5db360: a local call in a pure_patterns module is
    # pure only when that module defines the function; an imported or
    # `use`-injected macro (`field/2`) is unknown.
    test "D14: a pure_patterns module's imported or injected calls are not reported" do
      source = """
      defmodule MyApp.Domain.Thing do
        use Ecto.Schema
        import MyApp.Helpers

        embedded_schema do
          field :a, :string
          field :b, :string
        end

        def f(a) do
          helper(a)
          a
        end
      end
      """

      assert detect(source, [%{pure_patterns: ["MyApp.*"]}]) == []
    end

    test "D15: an operator with an unknown operand is not reported" do
      assert detect(discarded("foo() + 1")) == []
      assert detect(discarded("[a, IO.gets(:x)]")) == []
    end

    test "D16: a pure expression inside quote is not reported" do
      source = """
      defmodule App.X do
        defmacro m(a) do
          quote do
            b = unquote(a)
            b + 1
            :ok
          end
        end
      end
      """

      assert detect(source) == []

      # Positive control: the same shape outside the quote is reported.
      assert [_one] = detect(discarded("a + 1"))
    end

    test "D17: a single-expression body has no discarded position" do
      assert detect("defmodule App.X do\n  def f(m) do\n    Map.put(m, :a, 1)\n  end\nend\n") ==
               []
    end

    test "D18: nested blocks report each discarded expression on its own line" do
      source = """
      defmodule App.X do
        def f(m, xs) do
          case m do
            %{} ->
              Map.put(m, :a, 1)
              :ok
          end

          Enum.map(xs, fn x ->
            x + 1
            x
          end)
        end
      end
      """

      assert [%{line: 5}, %{line: 10}] = detect(source)
    end

    test "D19: no rules, no violations" do
      assert detect(discarded("Map.put(m, :a, 1)"), []) == []
    end

    test "a control-flow expression is judged inside, not as a whole" do
      assert detect(discarded("if a, do: 1, else: 2")) == []
      assert detect(discarded("case a do\n _ -> 1\n end")) == []
    end

    test "every rule reports its own issues" do
      assert [_one, _two] = detect(discarded("Map.put(m, :a, 1)"), [%{}, %{}])
    end
  end

  describe "shape/1" do
    test "S1: the exact conforming shape" do
      assert Check.shape(%{}) == @shape
    end
  end
end
