defmodule Anchor.Domain.Aggregates.WriteSourceTest do
  # DND-5459: what each write writes, traced through Core by rules 1-9.
  # Fixtures are compiled in the test and read through the real BeamReader and
  # Graph.Builder (`Anchor.Test.WriteFixtures`); nothing is loaded.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261103-dnd_5459_write_sets.md
  use ExUnit.Case, async: true

  import Anchor.Test.WriteFixtures

  alias Anchor.Domain.Aggregates.Config
  alias Anchor.Domain.Aggregates.WriteSites
  alias Anchor.Domain.Aggregates.WriteSource

  @ns AnchorFixtures.WriteSourceTest
  @s Module.concat(@ns, S)
  @t Module.concat(@ns, T)
  @repo Module.concat(@ns, Repo)
  @x Module.concat(@ns, X)
  @c Module.concat(@ns, C)

  @source schema(@s, "s") <>
            schema(@t, "t") <>
            repo(@repo) <>
            """
            defmodule #{inspect(@x)} do
              alias #{inspect(@repo)}
              alias #{inspect(@s)}
              alias #{inspect(@t)}

              def r1, do: Repo.insert(%S{id: 1})
              def r2(rows), do: Repo.insert_all(S, rows)
              def r3(rows), do: Repo.insert_all("t", rows)
              def r4(rows), do: Repo.insert_all({"t", S}, rows)

              def r5 do
                cs = Ecto.Changeset.change(%S{}, id: 1)
                Repo.insert(cs)
              end

              def r6(record, attrs), do: Repo.update(S.changeset(record, attrs))

              def r7(flag) do
                x = if flag, do: %S{}, else: %T{}
                Repo.insert(x)
              end

              def r8(flag) do
                x = if flag, do: %S{}, else: opaque()
                Repo.insert(x)
              end

              @spec r9(S.t()) :: term()
              def r9(r), do: Repo.update(Ecto.Changeset.change(r))

              def r10(r), do: Repo.insert(r)
              def r11(r), do: Repo.insert(r)

              def r12a(r, 0), do: Repo.insert(r)
              def r12a(r, n), do: r12b(r, n - 1)
              def r12b(r, n), do: r12a(r, n)

              def r13, do: Repo.insert(build())
              def r14, do: Repo.insert(Map.new())

              defp opaque, do: Map.new()
              defp build, do: %S{}
            end

            defmodule #{inspect(@c)} do
              def c1, do: #{inspect(@x)}.r10(%#{inspect(@s)}{})
              def c2, do: #{inspect(@x)}.r10(%#{inspect(@t)}{})
            end
            """

  setup_all do
    graph = graph!(@source)
    {:ok, sites} = WriteSites.find(graph, %Config{repos: [@repo]})
    %{sites: sites, graph: graph}
  end

  defp site(sites, name) do
    case Enum.filter(sites, fn site -> elem(site.mfa, 1) == name end) do
      [site] -> site
      other -> flunk("expected one write in #{name}, got #{inspect(other)}")
    end
  end

  describe "resolve/3 (through WriteSites.find/2)" do
    test "R1: a struct literal is its schema", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r1)
    end

    test "R2: a schema module is its schema", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r2)
    end

    test "R3: a literal table is a table", %{sites: sites} do
      assert %{sources: [{:table, "t"}], unresolved: nil} = site(sites, :r3)
    end

    test "R4: {table, schema} is the table", %{sites: sites} do
      assert %{sources: [{:table, "t"}], unresolved: nil} = site(sites, :r4)
    end

    test "R5: a changeset built from a struct is the struct's schema", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r5)
    end

    test "R6: a call on a schema module is the schema (rule 4)", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r6)
    end

    test "R7: branches union", %{sites: sites} do
      assert %{sources: [{:schema, @s}, {:schema, @t}], unresolved: nil} = site(sites, :r7)
    end

    test "R8: one unresolvable branch makes the value unresolved", %{sites: sites} do
      assert %{sources: [], unresolved: seen} = site(sites, :r8)
      assert seen =~ "Map.new/0"
    end

    test "R9: a parameter whose @spec is S.t() is S (rule 7a)", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r9)
    end

    test "R10: a parameter with no spec is the union of its callers' arguments (rule 7b)", %{
      sites: sites
    } do
      assert %{sources: [{:schema, @s}, {:schema, @t}], unresolved: nil} = site(sites, :r10)
    end

    test "R11: a parameter with no spec and no caller is unresolved, saying so", %{sites: sites} do
      assert %{sources: [], unresolved: seen} = site(sites, :r11)
      assert seen == "parameter 1 of #{inspect(@x)}.r11/1 has no @spec and no project caller"
    end

    test "R12: a parameter passed round a recursion is a parameter cycle, and terminates", %{
      sites: sites
    } do
      assert %{sources: [], unresolved: "parameter cycle"} = site(sites, :r12a)
    end

    test "R13: a call into a project function is what it returns (rule 8)", %{sites: sites} do
      assert %{sources: [{:schema, @s}], unresolved: nil} = site(sites, :r13)
    end

    test "R14: anything else is unresolved, naming what was seen and no line", %{sites: sites} do
      assert %{sources: [], unresolved: seen} = site(sites, :r14)
      assert seen == "the result of Map.new/0"
      refute seen =~ "line"
    end
  end

  describe "key/2" do
    test "a table exactly one schema derives is that schema; two keep the table", %{graph: graph} do
      tables = WriteSource.tables(graph)
      assert WriteSource.key({:table, "t"}, tables) == {:schema, @t}
      assert WriteSource.key({:table, "nope"}, tables) == {:table, "nope"}
      assert WriteSource.key({:table, "s"}, Map.put(tables, "s", [@s, @t])) == {:table, "s"}
      assert WriteSource.key({:schema, @s}, tables) == {:schema, @s}
    end
  end
end
