defmodule Anchor.Domain.GraphRules.DirectoryPlacementTest do
  # Domain (ADR 002). DND-5462: directory proposals as violations, over hand-built
  # models (Anchor.Test.DirectoryModels).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.DirectoryModels

  alias Anchor.Domain.GraphRules.DirectoryPlacement
  alias Anchor.Domain.Placement

  @rule %{type: :directory_placement, id: "dirs", paths: ["lib/**/*.ex"]}

  @modules [
    {W, "framework", "b"},
    {Inv, "domain", "b"},
    {Rnd, "domain", "b"},
    {U1, "domain", "b"},
    {U2, "domain", "b"}
  ]

  @files %{
    W => "lib/b/web/w.ex",
    Inv => "lib/b/domain/invoice.ex",
    Rnd => "lib/b/domain/rounding.ex",
    U1 => "lib/b/domain/util/u1.ex",
    U2 => "lib/b/domain/util/u2.ex"
  }

  @calls [{W, Inv}, {Inv, Rnd}, {W, U1}, {W, U2}]

  test "one violation per proposal: a module's at its defmodule, a directory's on its first file" do
    model = directory_model(@modules, @calls, @files)
    violations = DirectoryPlacement.check(model, @rule)
    proposals = model |> Placement.build() |> Placement.proposals(model, :directory_placement)

    assert Enum.map(violations, &{&1.trigger, &1.filename, &1.line}) == [
             {"Rnd", "lib/b/domain/rounding.ex", 3},
             {"lib/b/domain/util", "lib/b/domain/util/u1.ex", 3}
           ]

    for {violation, proposal} <- Enum.zip(violations, proposals) do
      assert String.ends_with?(violation.message, "Fix: " <> Placement.render(proposal))
    end

    assert Enum.map(violations, & &1.message) == [
             "Rnd sits in lib/b/domain, but only Inv reaches it. Fix: move Rnd from " <>
               "lib/b/domain to lib/b/domain/invoice (only Inv reaches it; Inv is the " <>
               "directory's public module)",
             "lib/b/domain/util encapsulates nothing: no module in it is reached only through " <>
               "it. Fix: flatten lib/b/domain/util into lib/b/domain (no module in it is reached " <>
               "only through it)"
           ]

    assert Enum.map(violations, & &1.key) == [
             "dirs|directory|Rnd|lib/b/domain/invoice",
             "dirs|directory|lib/b/domain/util|lib/b/domain"
           ]
  end

  test "a shared module's message says it had no tie-break evidence" do
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

    model = directory_model(modules, [{W1, Inv}, {W1, K}, {W2, K}], files)

    assert [violation] = DirectoryPlacement.check(model, @rule)

    assert violation.message ==
             "K is shared: no one module reaches it. Fix: move K to lib/b/domain (reached from " <>
               "2 unrelated callers: shared, not a private helper); no tie-break evidence"
  end

  test "a library-context proposal names the contexts" do
    modules = [{W1, "framework", "b"}, {W2, "framework", "c"}, {K, "domain", "b"}]
    files = %{W1 => "lib/b/web/w1.ex", W2 => "lib/c/web/w2.ex", K => "lib/b/domain/k.ex"}

    assert [violation] =
             DirectoryPlacement.check(directory_model(modules, [{W1, K}, {W2, K}], files), @rule)

    assert violation.message =~ "Fix: move K to a library context used by b, c"
  end

  test "the selector limits the subjects, a directory by the modules in it" do
    model = directory_model(@modules, @calls, @files)

    assert [%{trigger: "lib/b/domain/util"}] =
             DirectoryPlacement.check(model, %{@rule | paths: ["lib/b/domain/util/u2.ex"]})

    assert DirectoryPlacement.check(model, %{@rule | paths: ["lib/b/web/*.ex"]}) == []
  end

  test "no roots: one fail-closed issue, and no finding" do
    modules = [{Inv, "domain", "b"}, {Rnd, "domain", "b"}]
    model = directory_model(modules, [{Inv, Rnd}], Map.take(@files, [Inv, Rnd]))

    assert [issue] = DirectoryPlacement.check(model, @rule)
    assert issue.kind == :fail_closed
    assert issue.message =~ "no roots"
  end

  test "shape/1, needs/0 and narrows?/2" do
    assert DirectoryPlacement.shape(@rule) =~ "dominator subtree"
    assert :placement in DirectoryPlacement.needs()
    refute DirectoryPlacement.narrows?("a", "b")
  end
end
