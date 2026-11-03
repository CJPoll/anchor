defmodule Anchor.Domain.Sabotage.ScopeTest do
  # Domain tests for mapping changed lines onto function spans, the exclusion
  # counts, and the two renderings (DND-5472). Spans come from the real
  # `FunctionSpans` over literal source, so a line number in a test is a line of
  # the source beside it.
  # Sabotage record: ../../../sabotage_records/sabotage_scope-20261103-dnd_5472.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.ChangedFunction
  alias Anchor.Domain.Sabotage.FunctionSpans
  alias Anchor.Domain.Sabotage.Scope

  @source """
  defmodule M do
    @spec f(term()) :: term()
    def f(:a) do
      1
    end

    def f(_other) do
      2
    end

    def g(x) do
      x
      |> h()
    end

    defmacro m(x) do
      quote do: unquote(x)
    end

    defp h(x), do: x
  end
  """

  @zero %{test_files: 0, non_source_files: 0, deleted_files: 0, outside_hunks: 0, macros: 0}

  defp spans!(source) do
    {:ok, spans} = FunctionSpans.spans(source, "lib/m.ex")
    spans
  end

  defp build(hunks, source \\ @source, status \\ :modified) do
    Scope.build(%{"lib/m.ex" => %{status: status, hunks: hunks}}, %{"lib/m.ex" => spans!(source)})
  end

  defp build_with_base(hunks, old_hunks, source, base) do
    Scope.build(
      %{"lib/m.ex" => %{status: :modified, hunks: hunks, old_hunks: old_hunks}},
      %{"lib/m.ex" => spans!(source)},
      %{"lib/m.ex" => spans!(base)}
    )
  end

  defp identities(scope),
    do: Enum.map(scope.functions, &{&1.module, &1.name, &1.arity, &1.changed_lines})

  describe "build/2" do
    test "S1: a changed line inside f/1 puts f/1 in scope with that line" do
      scope = build([{4, 1}])
      assert identities(scope) == [{M, :f, 1, [4]}]
      assert scope.counts == @zero
    end

    test "S2: changed lines in two clauses of f/1 are one entry with the union of lines" do
      scope = build([{4, 1}, {8, 1}])

      assert [
               %ChangedFunction{
                 file: "lib/m.ex",
                 module: M,
                 name: :f,
                 arity: 1,
                 kind: :def,
                 changed_lines: [4, 8]
               }
             ] =
               scope.functions
    end

    test "S3: a deletion point between two lines of g/1 puts g/1 in scope" do
      # `@@ -13,1 +12,0 @@`: a line removed between new lines 12 and 13 of g/1 (11..14).
      assert identities(build([{12, 0}])) == [{M, :g, 1, [13]}]
    end

    test "S4: a deletion point between two functions is outside every function" do
      # Between line 9 (`end` of f's second clause) and line 10 (blank): no span holds both.
      scope = build([{9, 0}])
      assert scope.functions == []
      assert scope.counts == %{@zero | outside_hunks: 1}
    end

    test "S5: a change on the @spec line above f is outside a function, and f is not in scope" do
      scope = build([{2, 1}])
      assert scope.functions == []
      assert scope.counts == %{@zero | outside_hunks: 1}
    end

    test "S6: test files are counted, never read, never in scope" do
      files = %{
        "test/x_test.exs" => %{status: :modified, hunks: [{1, 1}]},
        "test/support/fixture.ex" => %{status: :modified, hunks: [{1, 1}]},
        "apps/a/test/b.ex" => %{status: :deleted, hunks: []}
      }

      scope = Scope.build(files, %{})
      assert scope.functions == []
      assert scope.counts == %{@zero | test_files: 3}
      assert Scope.source_files(files) == []
    end

    test "S7: config, docs and deps files are non-source" do
      files = %{
        "config/config.exs" => %{status: :modified, hunks: [{1, 1}]},
        "README.md" => %{status: :modified, hunks: [{1, 1}]},
        "deps/x/lib/x.ex" => %{status: :modified, hunks: [{1, 1}]},
        "_build/dev/lib/y.ex" => %{status: :added, hunks: [{1, 1}]}
      }

      assert Scope.build(files, %{}).counts == %{@zero | non_source_files: 4}
      assert Scope.source_files(files) == []
    end

    test "S8: a deleted .ex file is counted, and not read" do
      files = %{
        "lib/gone.ex" => %{status: :deleted, hunks: []},
        "lib/m.ex" => %{status: :modified, hunks: [{4, 1}]}
      }

      scope = Scope.build(files, %{"lib/m.ex" => spans!(@source)})
      assert scope.counts == %{@zero | deleted_files: 1}
      assert identities(scope) == [{M, :f, 1, [4]}]
      assert Scope.source_files(files) == ["lib/m.ex"]
    end

    test "S15: old_source_files names the modified source files with removed lines" do
      files = %{
        "lib/a.ex" => %{status: :modified, hunks: [{3, 1}], old_hunks: [{3, 1}]},
        "lib/b.ex" => %{status: :modified, hunks: [{3, 2}], old_hunks: [{2, 0}]},
        "lib/c.ex" => %{status: :added, hunks: [{1, 9}], old_hunks: [{0, 0}]},
        "test/d_test.exs" => %{status: :modified, hunks: [{1, 1}], old_hunks: [{1, 1}]}
      }

      assert Scope.old_source_files(files) == ["lib/a.ex"]
    end

    test "S9: an added file puts every function in scope, whatever its hunks say" do
      scope = build([], @source, :added)

      assert Enum.map(scope.functions, &{&1.name, &1.arity}) == [{:f, 1}, {:g, 1}, {:h, 1}]
      assert hd(scope.functions).changed_lines == [3, 4, 5, 7, 8, 9]
      assert scope.counts.macros == 1
      # The defmodule line is the added file's own, not a hunk outside a function.
      assert scope.counts.outside_hunks == 0
    end

    test "S10: a change inside a defmacro is counted as a macro, not scoped" do
      scope = build([{17, 1}])
      assert scope.functions == []
      assert scope.counts == %{@zero | macros: 1}
    end

    test "S11: identity does not depend on line numbers" do
      # Both clauses of f/1 change, before and after the file moves down 10
      # lines: one function each time, the same in all but its line numbers.
      moved = String.duplicate("\n", 10) <> @source
      before = build([{4, 1}, {8, 1}])
      later = build([{14, 1}, {18, 1}], moved)

      assert [%ChangedFunction{changed_lines: [4, 8]} = was] = before.functions
      assert [%ChangedFunction{changed_lines: [14, 18]} = now] = later.functions
      assert %{was | changed_lines: []} == %{now | changed_lines: []}
    end

    test "S13: a whole clause deleted first, in the middle or last keeps f/1 in scope" do
      base = """
      defmodule M do
        def e, do: :e
        def f(1), do: 1
        def f(2), do: 2
        def f(3), do: 3
        def g, do: :g
      end
      """

      # Each row: the source without one line of `base`, the hunk git prints
      # for it (new side, then base side), and the line now where it was.
      for {deleted, new_hunk, old_hunk, at} <- [
            {3, {2, 0}, {3, 1}, 3},
            {4, {3, 0}, {4, 1}, 4},
            {5, {4, 0}, {5, 1}, 5}
          ] do
        source = base |> String.split("\n") |> List.delete_at(deleted - 1) |> Enum.join("\n")
        scope = build_with_base([new_hunk], [old_hunk], source, base)

        assert identities(scope) == [{M, :f, 1, [at]}], "deleted line #{deleted}"
        assert scope.counts == @zero, "deleted line #{deleted}"
      end
    end

    test "S14: a function deleted whole is not scoped, and its hunk is outside a function" do
      base = """
      defmodule M do
        def e, do: :e
        def gone, do: :gone
        def g, do: :g
      end
      """

      source = base |> String.split("\n") |> List.delete_at(2) |> Enum.join("\n")
      scope = build_with_base([{2, 0}], [{3, 1}], source, base)

      assert scope.functions == []
      assert scope.counts == %{@zero | outside_hunks: 1}
    end

    test "S12: one hunk over two functions scopes both, in file then line order" do
      files = %{
        "lib/m.ex" => %{status: :modified, hunks: [{12, 9}]},
        "lib/a.ex" => %{status: :modified, hunks: [{2, 1}]}
      }

      a = "defmodule A do\n  def a, do: 1\nend\n"
      scope = Scope.build(files, %{"lib/m.ex" => spans!(@source), "lib/a.ex" => spans!(a)})

      assert Enum.map(scope.functions, &{&1.file, &1.name}) == [
               {"lib/a.ex", :a},
               {"lib/m.ex", :g},
               {"lib/m.ex", :h}
             ]

      # Lines 15, 16 and 19 are outside a function; lines 16..18 also cover the macro.
      assert scope.counts == %{@zero | outside_hunks: 1, macros: 1}
    end
  end

  describe "render/2" do
    setup do
      files = %{
        "lib/m.ex" => %{status: :modified, hunks: [{3, 3}, {8, 1}, {2, 1}]},
        "test/m_test.exs" => %{status: :modified, hunks: [{1, 1}]},
        "README.md" => %{status: :modified, hunks: [{1, 1}]}
      }

      {:ok, scope: Scope.build(files, %{"lib/m.ex" => spans!(@source)})}
    end

    test "R1: text is a TSV line per function, then the summary with every count", %{scope: scope} do
      assert Scope.render(scope, :text) ==
               "lib/m.ex\tM\tf/1\tdef\t3-5,8\n" <>
                 "anchor.sabotage scope: 1 functions in 1 files; excluded: 1 test files, " <>
                 "1 non-source files, 0 deleted files, 1 hunks outside a function, 0 macros"
    end

    test "R2: json decodes to the functions and the counts, the same values as text", %{
      scope: scope
    } do
      assert JSON.decode!(Scope.render(scope, :json)) == %{
               "functions" => [
                 %{
                   "file" => "lib/m.ex",
                   "module" => "M",
                   "name" => "f",
                   "arity" => 1,
                   "function" => "f/1",
                   "kind" => "def",
                   "changed_lines" => [3, 4, 5, 8],
                   "changed_line_ranges" => "3-5,8"
                 }
               ],
               "function_count" => 1,
               "file_count" => 1,
               "excluded" => %{
                 "test_files" => 1,
                 "non_source_files" => 1,
                 "deleted_files" => 0,
                 "outside_hunks" => 1,
                 "macros" => 0
               }
             }
    end

    test "R3: zero functions still prints the summary with every count" do
      scope = Scope.build(%{"README.md" => %{status: :modified, hunks: [{1, 1}]}}, %{})

      assert Scope.render(scope, :text) ==
               "anchor.sabotage scope: 0 functions in 0 files; excluded: 0 test files, " <>
                 "1 non-source files, 0 deleted files, 0 hunks outside a function, 0 macros"
    end
  end
end
