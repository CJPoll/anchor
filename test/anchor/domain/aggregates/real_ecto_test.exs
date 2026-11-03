defmodule Anchor.Domain.Aggregates.RealEctoTest do
  # DND-5459: the shapes real Ecto macros produce (`use Ecto.Schema`,
  # `Ecto.Query.from/2`, `Ecto.Multi`), pinned by fixtures compiled against Ecto
  # as a test-only dependency. Nothing is loaded or run.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Aggregates.WriteSource

  @ns AnchorFixtures.RealEctoTest
  @thread Module.concat(@ns, Thread)
  @post Module.concat(@ns, Post)
  @repo Module.concat(@ns, Repo)
  @e Module.concat(@ns, E)

  @source """
  defmodule #{inspect(@thread)} do
    use Ecto.Schema
    schema "threads" do
      field :x, :string
    end
  end

  defmodule #{inspect(@post)} do
    use Ecto.Schema
    schema "posts" do
      field :body, :string
    end
  end

  defmodule #{inspect(@repo)} do
    @behaviour Ecto.Repo
  end

  defmodule #{inspect(@e)} do
    import Ecto.Query
    alias #{inspect(@repo)}
    alias #{inspect(@thread)}
    alias #{inspect(@post)}
    alias Ecto.Multi

    def e1, do: Repo.insert(%Thread{})
    def e2(v), do: Repo.update_all(from(t in Thread, where: t.x == ^v), set: [x: "1"])
    def e2_piped(v), do: from(t in Thread, where: t.x == ^v) |> Repo.update_all(set: [x: "1"])
    def e3, do: Repo.delete_all(from(t in "threads"))
    def e5(v), do: Repo.delete_all(where(Thread, [t], t.x == ^v))
    def e6(q), do: Repo.delete_all(put_query_prefix(q, "tenant_a"))
    def e6_known, do: Repo.delete_all(put_query_prefix(Thread, "tenant_a"))

    def e4 do
      Multi.new()
      |> Multi.insert(:thread, %Thread{})
      |> Multi.update_all(:posts, Post, set: [body: "x"])
      |> Multi.run(:more, fn repo, _ -> repo.insert(%Post{}) end)
      |> Repo.transaction()
    end
  end
  """

  setup_all do
    graph = graph!(@source)
    %{graph: graph, analysis: Analysis.build(graph, %Config{})}
  end

  defp site(analysis, name),
    do: Enum.find(analysis.sites, &(elem(&1.mfa, 1) == name)) || flunk("no write in #{name}")

  test "E1: a struct of a real schema is the schema, and its table is read from Core", %{
    analysis: a,
    graph: graph
  } do
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e1)
    assert Index.table_of(graph, @thread) == {:ok, "threads"}
  end

  test "E1: @behaviour Ecto.Repo makes the module a repo", %{analysis: a} do
    assert a.repos == [@repo]
  end

  test "E2: a from/2 query on a schema is the schema, written or piped", %{analysis: a} do
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e2)
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e2_piped)
  end

  test "E3: a from/2 query on a table is the table, keyed to its schema", %{analysis: a} do
    assert %{sources: [{:table, "threads"}], unresolved: nil} = site(a, :e3)
    assert WriteSource.key({:table, "threads"}, a.tables) == {:schema, @thread}
  end

  test "E5: a query built on a schema by Ecto.Query's builders is the schema (rule 6)", %{
    analysis: a
  } do
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e5)
  end

  test "E6: a query call's literal argument is never the table; an unknown query stays unknown",
       %{analysis: a} do
    assert %{sources: [], unresolved: seen} = site(a, :e6)
    refute seen =~ "tenant_a"
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e6_known)
  end

  test "E4: a real Multi pipeline's scope keys are exactly the written schemas", %{analysis: a} do
    assert [scope] = Enum.filter(a.scopes, &(&1.mfa == {@e, :e4, 0}))
    assert scope.kind == :multi
    assert scope.complete?
    assert scope.keys == MapSet.new([{:schema, @thread}, {:schema, @post}])
  end
end
