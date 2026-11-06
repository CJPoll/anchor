defmodule Anchor.Domain.Aggregates.RealEctoTest do
  # DND-5459: the shapes real Ecto macros produce (`use Ecto.Schema`,
  # `Ecto.Query.from/2`, `Ecto.Multi`), pinned by fixtures compiled against Ecto
  # as a test-only dependency. Nothing is loaded or run.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md,
  # ../../../sabotage_records/aggregates-20261106-dnd_5459_write_sets.md
  # and ../../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Analysis
  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.Index
  alias Anchor.Domain.Aggregates.WriteSites
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
    def e7, do: Repo.insert(Ecto.Changeset.get_change(Ecto.Changeset.change(%Thread{}), :x))
    def e8, do: Repo.insert(Ecto.Changeset.apply_changes(Ecto.Changeset.change(%Thread{})))
    def e6_scoped(q), do: e6_prefix(q, "tenant_a")
    defp e6_prefix(q, prefix), do: Repo.delete_all(put_query_prefix(q, prefix))
    def e6_table(v), do: Repo.delete_all(where(from(t in "threads"), [t], t.x == ^v))
    def e6_join(q), do: Repo.delete_all(join(q, :inner, [t], o in Post, on: true))
    def e6_where(q, v), do: Repo.delete_all(where(q, [t], t.x == ^v))
    def e6_prefixed, do: Repo.delete_all(put_query_prefix(from(t in "threads"), "tenant_a"))
    def e6_prefixed_pin(v) do
      Repo.delete_all(put_query_prefix(from(t in "threads", where: t.x == ^v), "tenant_a"))
    end

    def e9(v) do
      Repo.transaction(fn ->
        query =
          from t in Thread,
            join: p in Post,
            on: t.id == p.id,
            where: t.x == ^v and not is_nil(p.body),
            group_by: t.id,
            having: count(p.id) > 1,
            order_by: [desc: t.id],
            limit: 1,
            offset: 1,
            lock: "FOR UPDATE",
            preload: [],
            select: {t.id, count(p.id)}

        changeset = Ecto.Changeset.change(%Thread{})
        {Repo.all(query), Repo.update(Ecto.Changeset.validate_required(changeset, [:x]))}
      end)
    end

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

  test "E6: a string reaching a query call through a variable is never the table either", %{
    analysis: a
  } do
    assert %{sources: [], unresolved: seen} = site(a, :e6_prefix)
    refute seen =~ "tenant_a"
  end

  test "E6: a query that cannot be traced is never named by what it joins or filters on", %{
    analysis: a
  } do
    assert %{sources: [], unresolved: seen} = site(a, :e6_join)
    assert is_binary(seen)
    assert %{sources: [], unresolved: _seen} = site(a, :e6_where)
  end

  test "a value read out of a changeset is not the changeset's schema", %{analysis: a} do
    assert %{sources: [], unresolved: seen} = site(a, :e7)
    assert seen == "a value read out of a changeset (Ecto.Changeset.get_change/2)"
    assert %{sources: [{:schema, @thread}], unresolved: nil} = site(a, :e8)
  end

  test "E6: a table named by from/2 still reaches through a query call", %{analysis: a} do
    assert %{sources: [{:table, "threads"}], unresolved: nil} = site(a, :e6_table)
    assert %{sources: [{:table, "threads"}], unresolved: nil} = site(a, :e6_prefixed)
    assert %{sources: [{:table, "threads"}], unresolved: nil} = site(a, :e6_prefixed_pin)
  end

  test "every callback of Ecto.Repo is a write, raw SQL, or known to write nothing" do
    known =
      MapSet.union(MapSet.new(Map.keys(WriteSites.repo_writes())), WriteSites.repo_functions())

    assert Ecto.Repo.behaviour_info(:callbacks)
           |> Keyword.keys()
           |> Enum.reject(&MapSet.member?(known, &1)) == []
  end

  test "DND-5889: Ecto's own expansion, and what `use Ecto.Schema` generates, is no gap", %{
    analysis: a
  } do
    assert a.counts.unread_by_callee == %{}
    assert [%{no_gap_noticed?: true}] = Enum.filter(a.scopes, &(&1.mfa == {@e, :e9, 1}))
    assert a.counts.cleared > 0
  end

  test "E4: a real Multi pipeline's scope keys are exactly the written schemas", %{analysis: a} do
    assert [scope] = Enum.filter(a.scopes, &(&1.mfa == {@e, :e4, 0}))
    assert scope.kind == :multi
    assert scope.no_gap_noticed?
    assert scope.keys == MapSet.new([{:schema, @thread}, {:schema, @post}])
  end
end
