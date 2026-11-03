defmodule Anchor.Domain.Aggregates.WriteSitesTest do
  # DND-5459: every write found in Core, with its op, via and line.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.WriteSites
  alias Anchor.Domain.FunctionRef
  alias Anchor.Test.BeamFixtures

  @ns AnchorFixtures.WriteSitesTest
  @s Module.concat(@ns, S)
  @repo Module.concat(@ns, Repo)
  @w Module.concat(@ns, W)
  @declared Module.concat(@ns, DeclaredRepo)

  @writes """
  defmodule #{inspect(@w)} do
    alias #{inspect(@repo)}
    alias #{inspect(@repo)}, as: R
    alias #{inspect(@s)}
    alias Ecto.Multi
    @repo #{inspect(@repo)}

    def w1_insert, do: Repo.insert(%S{})
    def w1_insert!, do: Repo.insert!(%S{})
    def w1_update, do: Repo.update(%S{})
    def w1_update!, do: Repo.update!(%S{})
    def w1_delete, do: Repo.delete(%S{})
    def w1_delete!, do: Repo.delete!(%S{})
    def w1_insert_or_update, do: Repo.insert_or_update(%S{})
    def w1_insert_or_update!, do: Repo.insert_or_update!(%S{})
    def w1_insert_all, do: Repo.insert_all(S, [])
    def w1_update_all, do: Repo.update_all(S, set: [id: 1])
    def w1_delete_all, do: Repo.delete_all(S)

    def w2_alias(x), do: R.insert(x)
    def w2_pipe(x), do: x |> Repo.insert()
    def w2_attribute(x), do: @repo.insert(x)

    def w3(m) do
      m
      |> Multi.insert(:a, %S{})
      |> Multi.update(:b, %S{})
      |> Multi.delete(:c, %S{})
      |> Multi.insert_or_update(:d, %S{})
      |> Multi.insert_all(:e, S, [])
      |> Multi.update_all(:f, S, set: [id: 1])
      |> Multi.delete_all(:g, S)
    end

    def w4(m), do: Multi.run(m, :x, fn repo, _changes -> repo.insert(%S{}) end)

    def w5(m), do: Multi.run(m, :x, &__MODULE__.step/2)
    def step(repo, _changes), do: repo.update(%S{})

    def w6(at), do: Repo.soft_delete(%S{}, at)

    def w7(mod, x), do: mod.insert(x)

    def w8(id), do: {Repo.get(S, id), Repo.all(S)}
  end
  """

  @source schema(@s, "s") <> repo(@repo) <> @writes

  setup_all do
    graph = graph!(@source)

    config = %Config{
      repos: [@repo],
      write_functions: [ok!(FunctionRef.parse("#{inspect(@repo)}.soft_delete/2"))]
    }

    {:ok, sites} = WriteSites.find(graph, config)
    %{sites: sites, graph: graph, config: config}
  end

  defp ok!({:ok, value}), do: value

  defp in_function(sites, prefix) do
    Enum.filter(sites, &String.starts_with?(Atom.to_string(elem(&1.mfa, 1)), prefix))
  end

  describe "find/2" do
    test "W1: each Repo write name is a site via :repo, with its op and line", %{sites: sites} do
      w1 = in_function(sites, "w1_")
      assert length(w1) == 11

      for site <- w1 do
        "w1_" <> op = Atom.to_string(elem(site.mfa, 1))
        assert site.op == String.to_existing_atom(op)
        assert site.via == :repo
        assert site.sources == [{:schema, @s}]
        assert site.line == BeamFixtures.line_of(@source, "def #{elem(site.mfa, 1)},")
      end
    end

    test "W2: an alias, a pipe and an @repo attribute are all :repo sites", %{sites: sites} do
      assert [:w2_alias, :w2_attribute, :w2_pipe] ==
               sites |> in_function("w2_") |> Enum.map(&elem(&1.mfa, 1)) |> Enum.sort()

      assert sites |> in_function("w2_") |> Enum.all?(&(&1.via == :repo and &1.op == :insert))
    end

    test "W3: each Multi write is a site via :multi, its source argument 3", %{sites: sites} do
      w3 = in_function(sites, "w3")

      assert Enum.map(w3, & &1.op) ==
               [
                 :insert,
                 :update,
                 :delete,
                 :insert_or_update,
                 :insert_all,
                 :update_all,
                 :delete_all
               ]

      assert Enum.all?(w3, &(&1.via == :multi and &1.sources == [{:schema, @s}]))
    end

    test "W4: a Multi.run callback's repo argument writes via :run_callback_repo", %{sites: sites} do
      assert [%{via: :run_callback_repo, op: :insert, sources: [{:schema, @s}]}] =
               in_function(sites, "w4")
    end

    test "W5: a Multi.run capture's repo parameter writes via :run_callback_repo", %{sites: sites} do
      assert [%{via: :run_callback_repo, op: :update, sources: [{:schema, @s}]}] =
               in_function(sites, "step")
    end

    test "W6: a write_functions entry is a site via :write_function, its source argument 1", %{
      sites: sites
    } do
      assert [%{via: :write_function, op: :soft_delete, sources: [{:schema, @s}]}] =
               in_function(sites, "w6")
    end

    test "W7: a write on a module held in a variable is no site, and is a dynamic call", %{
      sites: sites,
      graph: graph,
      config: config
    } do
      assert in_function(sites, "w7") == []

      facts = WriteSites.facts(graph, config, WriteSites.repos(graph, config))

      assert [%{what: "a call of insert/1 on a module held in a variable"}] =
               facts.functions[{@w, :w7, 2}].dynamic
    end

    test "W8: reads are not writes (positive control for W1)", %{sites: sites} do
      assert in_function(sites, "w8") == []
    end

    test "W9: no repo at all is {:error, :no_repo}", %{graph: graph} do
      assert WriteSites.find(graph, %Config{repos: []}) == {:error, :no_repo}
    end
  end

  describe "repos/2" do
    test "a module declaring @behaviour Ecto.Repo is a repo, and so is each listed one" do
      graph =
        graph!("""
        defmodule #{inspect(@declared)} do
          @behaviour Ecto.Repo
        end
        """)

      assert WriteSites.repos(graph, %Config{}) == MapSet.new([@declared])

      assert WriteSites.repos(graph, %Config{repos: [Other.Repo]}) ==
               MapSet.new([@declared, Other.Repo])
    end
  end
end
