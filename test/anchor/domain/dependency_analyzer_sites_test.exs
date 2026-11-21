defmodule Anchor.Domain.DependencyAnalyzerSitesTest do
  # Every line a dependency is referenced on, not only its first, so a check can
  # report each site: `by_owner_sites` of `attributed_dependency_lines/2` and of
  # `attributed_function_references/1`.
  #
  # Sabotage record:
  #   ../../sabotage_records/dependency_analyzer-20261121-athena_no_dependency_report_every_site.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DependencyAnalyzer

  defp parse(source), do: Code.string_to_quoted!(source)

  # The same AST with every `:line` removed, as an AST built by hand has none.
  defp without_lines(ast) do
    Macro.prewalk(ast, fn
      {form, meta, args} when is_list(meta) -> {form, Keyword.delete(meta, :line), args}
      other -> other
    end)
  end

  @two_owners """
  defmodule A do
    def f, do: Sample.Repo.all(Q)
    def g, do: Sample.Repo.one(Q)
    def h, do: Sample.Repo.one(Sample.Repo.query())
  end

  defmodule B do
    def f, do: Sample.Repo.all(Q)
  end
  """

  defp repo_sites(ast, mode) do
    %{by_owner_sites: sites} = DependencyAnalyzer.attributed_dependency_lines(ast, mode)
    sites |> Enum.filter(&match?({_owner, Sample.Repo, _lines}, &1)) |> Enum.sort()
  end

  describe "attributed_dependency_lines/2 sites" do
    for mode <- [:reference, :call] do
      test "lists each distinct line a module is referenced on, per owner, ascending (#{mode})" do
        assert [{A, Sample.Repo, [2, 3, 4]}, {B, Sample.Repo, [8]}] =
                 repo_sites(parse(@two_owners), unquote(mode))
      end
    end

    test "the first site is the line the first-line list reports" do
      result = DependencyAnalyzer.attributed_dependency_lines(parse(@two_owners), :call)

      assert {A, Sample.Repo, 2} in result.by_owner
      assert {A, Sample.Repo, [2 | _rest]} = List.keyfind(result.by_owner_sites, A, 0)
    end

    test "an AST that carries no line has one site, `nil`" do
      ast = @two_owners |> parse() |> without_lines()

      assert [{A, Sample.Repo, [nil]}, {B, Sample.Repo, [nil]}] = repo_sites(ast, :call)
    end
  end

  describe "attributed_function_references/1 sites" do
    test "lists each distinct line a function is called on, per owner" do
      %{by_owner_sites: sites} =
        DependencyAnalyzer.attributed_function_references(parse(@two_owners))

      assert {A, {Sample.Repo, :one, 1}, [3, 4]} in sites
      assert {A, {Sample.Repo, :all, 1}, [2]} in sites
      assert {B, {Sample.Repo, :all, 1}, [8]} in sites
    end

    test "an AST that carries no line has one site, `nil`" do
      ast = @two_owners |> parse() |> without_lines()
      %{by_owner_sites: sites} = DependencyAnalyzer.attributed_function_references(ast)

      assert {A, {Sample.Repo, :one, 1}, [nil]} in sites
    end
  end
end
