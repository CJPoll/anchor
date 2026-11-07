defmodule Anchor.Domain.Placement.DirectoriesTest do
  # Domain (ADR 002). DND-5462: the module dominator tree, bucket roots and directory
  # proposals, on hand-built models with an explicit source file per module
  # (Anchor.Test.DirectoryModels).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  # and ../../../sabotage_records/placement-20261107-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.DirectoryModels

  alias Anchor.Domain.Digraph
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Placement.Directories

  defp proposals(modules, calls, files, generated \\ []) do
    model = directory_model(modules, calls, files, generated)
    model |> Placement.build() |> Directories.proposals(model, nil)
  end

  @chain [{W, "framework", "b"}, {Inv, "domain", "b"}, {Rnd, "domain", "b"}]
  @chain_files %{
    W => "lib/b/web/w.ex",
    Inv => "lib/b/domain/invoice.ex",
    Rnd => "lib/b/domain/rounding.ex"
  }

  describe "module_dominators/1" do
    test "a chain: the dominated module's immediate dominator is the module above it" do
      model = directory_model(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files)
      idom = model |> Placement.build() |> Directories.module_dominators()

      assert idom[Rnd] == Inv
      assert idom[Inv] == W
      assert idom[W] == Digraph.virtual_root()
    end

    test "two root modules calling one module make the virtual root its dominator" do
      modules = [{W1, "framework", "b"}, {W2, "framework", "b"}, {K, "domain", "b"}]
      files = %{W1 => "lib/b/web/w1.ex", W2 => "lib/b/web/w2.ex", K => "lib/b/domain/k.ex"}
      model = directory_model(modules, [{W1, K}, {W2, K}], files)

      assert (model |> Placement.build() |> Directories.module_dominators())[K] ==
               Digraph.virtual_root()
    end
  end

  describe "bucket_root/3" do
    test "the deepest directory holding every module of the bucket in the context" do
      modules = [{A, "domain", "b"}, {C, "domain", "b"}, {Web, "framework", "b"}]
      files = %{A => "lib/b/domain/a.ex", C => "lib/b/domain/x/c.ex", Web => "lib/b/web/w.ex"}
      model = directory_model(modules, [], files)

      assert Directories.bucket_root(model, "domain", "b") == "lib/b/domain"

      # No module sits at the root itself: it is still their common directory.
      deeper = %{files | A => "lib/b/domain/y/a.ex"}

      assert Directories.bucket_root(directory_model(modules, [], deeper), "domain", "b") ==
               "lib/b/domain"
    end

    test "one module: its own directory" do
      model = directory_model([{A, "domain", "b"}], [], %{A => "lib/b/domain/a.ex"})
      assert Directories.bucket_root(model, "domain", "b") == "lib/b/domain"
    end

    test "no module of that bucket in that context" do
      model = directory_model([{A, "domain", "b"}], [], %{A => "lib/b/domain/a.ex"})
      assert Directories.bucket_root(model, "domain", "c") == nil
    end
  end

  describe "proposals/3" do
    test "a dominated module moves under its dominator's companion directory" do
      assert [proposal] = proposals(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files)

      assert {proposal.subject, proposal.current, proposal.proposed, proposal.reason} ==
               {Rnd, "lib/b/domain", "lib/b/domain/invoice", :dominator_subtree}

      assert proposal.key == "directory_placement|directory|Rnd|lib/b/domain/invoice"
      assert proposal.evidence == ["dominated by Inv"]
    end

    test "a module already in its dominator's directory gives nothing" do
      files = %{@chain_files | Rnd => "lib/b/domain/invoice/rounding.ex"}
      assert proposals(@chain, [{W, Inv}, {Inv, Rnd}], files) == []
    end

    test "a module defined in its dominator's own file gives nothing" do
      files = %{@chain_files | Rnd => "lib/b/domain/invoice.ex"}
      assert proposals(@chain, [{W, Inv}, {Inv, Rnd}], files) == []
    end

    test "a dominator in another bucket gives nothing" do
      modules = [{W, "framework", "b"}, {Mgr, "managers", "b"}, {Calc, "domain", "b"}]

      files = %{
        W => "lib/b/web/w.ex",
        Mgr => "lib/b/managers/mgr.ex",
        Calc => "lib/b/domain/calc.ex"
      }

      assert proposals(modules, [{W, Mgr}, {Mgr, Calc}], files) == []
    end

    test "a dominator in another context gives nothing" do
      modules = [{W, "framework", "b"}, {Inv, "domain", "b"}, {Rnd, "domain", "c"}]
      files = %{@chain_files | Rnd => "lib/c/domain/rounding.ex"}

      assert proposals(modules, [{W, Inv}, {Inv, Rnd}], files) == []
    end

    test "a shared module within one context goes to the bucket root, with no tie-break" do
      modules = [
        {W1, "framework", "b"},
        {W2, "framework", "b"},
        {Inv, "domain", "b"},
        {K, "domain", "b"}
      ]

      files = %{
        W1 => "lib/b/web/w1.ex",
        W2 => "lib/b/web/w2.ex",
        Inv => "lib/b/domain/invoice.ex",
        K => "lib/b/domain/x/k.ex"
      }

      assert [proposal] = proposals(modules, [{W1, Inv}, {W1, K}, {W2, K}], files)

      assert {proposal.subject, proposal.reason, proposal.proposed} ==
               {K, :shared_module, "lib/b/domain"}

      assert proposal.evidence == [
               "reached from 2 unrelated callers: W1, W2",
               "no tie-break evidence"
             ]

      # Positive control: K already at the bucket root gives nothing.
      assert proposals(modules, [{W1, Inv}, {W1, K}, {W2, K}], %{files | K => "lib/b/domain/k.ex"}) ==
               []
    end

    test "a module shared across contexts goes to a library context naming them" do
      modules = [{W1, "framework", "b"}, {W2, "framework", "c"}, {K, "domain", "b"}]
      files = %{W1 => "lib/b/web/w1.ex", W2 => "lib/c/web/w2.ex", K => "lib/b/domain/k.ex"}

      assert [proposal] = proposals(modules, [{W1, K}, {W2, K}], files)
      assert proposal.proposed == {:library_context, ["b", "c"]}
      assert proposal.key == "directory_placement|directory|K|library:b,c"
    end

    test "a module shared by callers of one other context is the context rule's question" do
      modules = [{W1, "framework", "c"}, {W2, "framework", "c"}, {K, "domain", "b"}]
      files = %{W1 => "lib/c/web/w1.ex", W2 => "lib/c/web/w2.ex", K => "lib/b/domain/x/k.ex"}

      assert proposals(modules, [{W1, K}, {W2, K}], files) == []
    end

    test "an inert directory is flattened" do
      modules = [
        {W, "framework", "b"},
        {Inv, "domain", "b"},
        {U1, "domain", "b"},
        {U2, "domain", "b"}
      ]

      files = %{
        W => "lib/b/web/w.ex",
        Inv => "lib/b/domain/invoice.ex",
        U1 => "lib/b/domain/util/u1.ex",
        U2 => "lib/b/domain/util/u2.ex"
      }

      assert [proposal] = proposals(modules, [{W, Inv}, {W, U1}, {W, U2}], files)

      assert {proposal.subject, proposal.reason, proposal.proposed, proposal.level} ==
               {"lib/b/domain/util", :inert_directory, "lib/b/domain", :directory}
    end

    test "a directory of one file, however many modules it defines, is not inert" do
      modules = [
        {W, "framework", "b"},
        {Inv, "domain", "b"},
        {U1, "domain", "b"},
        {U2, "domain", "b"}
      ]

      files = %{
        W => "lib/b/web/w.ex",
        Inv => "lib/b/domain/invoice.ex",
        U1 => "lib/b/domain/util/u.ex",
        U2 => "lib/b/domain/util/u.ex"
      }

      assert proposals(modules, [{W, Inv}, {W, U1}, {W, U2}], files) == []
    end

    test "a directory with a member dominated by another is not inert" do
      modules = [
        {W, "framework", "b"},
        {Inv, "domain", "b"},
        {U1, "domain", "b"},
        {U2, "domain", "b"}
      ]

      files = %{
        W => "lib/b/web/w.ex",
        Inv => "lib/b/domain/invoice.ex",
        U1 => "lib/b/domain/util/u1.ex",
        U2 => "lib/b/domain/util/u2.ex"
      }

      # U2 moves under U1 (its own proposal); util/ itself is not flattened.
      assert proposals(modules, [{W, Inv}, {W, U1}, {U1, U2}], files) |> Enum.map(& &1.reason) ==
               [:dominator_subtree]
    end

    test "a directory whose companion module dominates its members is not inert" do
      modules = [
        {W, "framework", "b"},
        {Util, "domain", "b"},
        {U1, "domain", "b"},
        {U2, "domain", "b"}
      ]

      files = %{
        W => "lib/b/web/w.ex",
        Util => "lib/b/domain/util.ex",
        U1 => "lib/b/domain/util/u1.ex",
        U2 => "lib/b/domain/util/u2.ex"
      }

      assert proposals(modules, [{W, Util}, {Util, U1}, {Util, U2}], files) == []
    end

    test "a directory whose modules no root reaches is not judged" do
      modules = [
        {W, "framework", "b"},
        {Inv, "domain", "b"},
        {U1, "domain", "b"},
        {U2, "domain", "b"}
      ]

      files = %{
        W => "lib/b/web/w.ex",
        Inv => "lib/b/domain/invoice.ex",
        U1 => "lib/b/domain/util/u1.ex",
        U2 => "lib/b/domain/util/u2.ex"
      }

      assert proposals(modules, [{W, Inv}], files) == []
    end

    test "a generated dominator has no companion directory to move into" do
      assert proposals(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files, [Inv]) == []
    end

    test "the bucket root itself is never flattened" do
      modules = [{W, "framework", "b"}, {U1, "domain", "b"}, {U2, "domain", "b"}]
      files = %{W => "lib/b/web/w.ex", U1 => "lib/b/domain/u1.ex", U2 => "lib/b/domain/u2.ex"}

      assert proposals(modules, [{W, U1}, {W, U2}], files) == []
    end

    test "a generated module is not placed, and is counted" do
      calls = [{W, Inv}, {Inv, Rnd}]
      assert proposals(@chain, calls, @chain_files, [Rnd]) == []

      model = directory_model(@chain, calls, @chain_files, [Rnd])
      assert Directories.not_placed(model) == 1
      assert Placement.build(model).precision.modules_not_placed == 1
      assert Directories.not_placed(directory_model(@chain, calls, @chain_files)) == 0
    end

    test "length never triggers anything: a dominated module already in place stays" do
      many = for i <- 1..40, do: {Module.concat(Inv, "M#{i}"), "domain", "b"}
      files = Map.new(many, fn {m, _b, _c} -> {m, "lib/b/domain/invoice/#{inspect(m)}.ex"} end)
      calls = [{W, Inv} | Enum.map(many, fn {m, _b, _c} -> {Inv, m} end)]

      assert proposals(@chain ++ many, [{Inv, Rnd} | calls], Map.merge(@chain_files, files)) ==
               proposals(@chain, [{W, Inv}, {Inv, Rnd}], @chain_files)
    end
  end
end
