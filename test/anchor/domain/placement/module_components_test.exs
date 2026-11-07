defmodule Anchor.Domain.Placement.ModuleComponentsTest do
  # Domain (ADR 002). DND-5463: a module's causal components (M1) and its shared private
  # helpers (M3), on hand-built models (Anchor.Test.PlacementModels).
  #
  # Sabotage record: ../../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Effects
  alias Anchor.Domain.Graph.StructUse
  alias Anchor.Domain.Placement.ModuleComponents

  # `uses`: `[{from_mfa, struct, op}]`.
  defp model_of(modules, calls, uses \\ [], opts \\ []) do
    model = model(modules, calls, opts)

    struct_uses =
      for {from, struct, op} <- uses,
          do: %StructUse{from: from, struct: struct, op: op, line: 1, line_source: :call}

    put_in(model.graph.struct_uses, struct_uses)
  end

  defp function_sets(model, module) do
    model |> ModuleComponents.components(module) |> Enum.map(& &1.functions)
  end

  @ledger_fns [{:new, 1}, {:get, 1}, {:fmt, 1}, {:parse, 1}]

  defp ledger(opts \\ []) do
    [{M, "domain", @ledger_fns, opts}, {W, "framework", [{:run, 0}], []}]
  end

  @ledger_calls [{{M, :fmt, 1}, {M, :parse, 1}, :local}, {{M, :parse, 1}, {M, :fmt, 1}, :local}]
  @ledger_uses [{{M, :new, 1}, M, :build}, {{M, :get, 1}, M, :match}]

  describe "components/2" do
    test "functions linked by a direct call are one component" do
      model =
        model_of([{M, "domain", [{:a, 0}, {:b, 0}], []}], [{{M, :a, 0}, {M, :b, 0}, :local}])

      assert function_sets(model, M) == [[{M, :a, 0}, {M, :b, 0}]]
    end

    test "a call through a private hop links" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}, {:p, 0, :defp}], []}]
      calls = [{{M, :a, 0}, {M, :p, 0}, :local}, {{M, :p, 0}, {M, :b, 0}, :local}]

      assert [%{functions: [{M, :a, 0}, {M, :b, 0}], privates: [{M, :p, 0}]}] =
               model_of(modules, calls) |> ModuleComponents.components(M)
    end

    test "a remote call into the same module links" do
      model = model_of([{M, "domain", [{:a, 0}, {:b, 0}], []}], [{{M, :a, 0}, {M, :b, 0}}])
      assert function_sets(model, M) == [[{M, :a, 0}, {M, :b, 0}]]
    end

    test "own-struct users are linked" do
      model = model_of([{M, "domain", [{:new, 1}, {:get, 1}], []}], [], @ledger_uses)
      assert function_sets(model, M) == [[{M, :get, 1}, {M, :new, 1}]]
    end

    test "another module's struct does not link" do
      uses = [{{M, :new, 1}, Other, :build}, {{M, :get, 1}, Other, :match}]
      model = model_of([{M, "domain", [{:new, 1}, {:get, 1}], []}], [], uses)
      assert length(function_sets(model, M)) == 2
    end

    test "unrelated groups are two components" do
      model = model_of(ledger(), @ledger_calls, @ledger_uses)

      assert function_sets(model, M) == [
               [{M, :fmt, 1}, {M, :parse, 1}],
               [{M, :get, 1}, {M, :new, 1}]
             ]
    end

    test "a shared private callee does not link; it is in both privates lists" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}, {:p, 0, :defp}], []}]
      calls = [{{M, :a, 0}, {M, :p, 0}, :local}, {{M, :b, 0}, {M, :p, 0}, :local}]

      assert [
               %{functions: [{M, :a, 0}], privates: [{M, :p, 0}]},
               %{functions: [{M, :b, 0}], privates: [{M, :p, 0}]}
             ] =
               model_of(modules, calls) |> ModuleComponents.components(M)
    end

    test "callbacks of one behaviour are linked" do
      modules = [{M, "domain", [{:init, 1}, {:handle_call, 3}], behaviours: [GenServer]}]
      model = model_of(modules, [])

      model = %{
        model
        | effects: %Effects{callbacks: %{GenServer => [{:init, 1}, {:handle_call, 3}]}}
      }

      assert function_sets(model, M) == [[{M, :handle_call, 3}, {M, :init, 1}]]
      # Positive control: with no callbacks known, they are two.
      assert length(function_sets(model_of(modules, []), M)) == 2
    end

    test "struct use in a private helper counts for its callers" do
      modules = [{M, "domain", [{:a, 0}, {:b, 1}, {:p, 0, :defp}], []}]
      calls = [{{M, :a, 0}, {M, :p, 0}, :local}]
      uses = [{{M, :p, 0}, M, :build}, {{M, :b, 1}, M, :match}]

      assert function_sets(model_of(modules, calls, uses), M) == [[{M, :a, 0}, {M, :b, 1}]]
    end
  end

  describe "proposals/1" do
    test "a split names the second part by the type it owns; the first keeps the name" do
      specs = %{{:fmt, 1} => "fmt(term()) :: %Money.Currency{}"}

      modules = [
        {M, "domain", @ledger_fns, specs: specs},
        {W, "framework", [{:run, 0}], []},
        {Money.Currency, "domain", [], struct: [:code]}
      ]

      model = model_of(modules, @ledger_calls, @ledger_uses)

      assert [proposal] = ModuleComponents.proposals(model)
      assert proposal.reason == :components
      assert proposal.subject == M

      assert proposal.proposed ==
               {:split,
                [{Currency, [{M, :fmt, 1}, {M, :parse, 1}]}, {M, [{M, :get, 1}, {M, :new, 1}]}]}

      assert proposal.key == "module_one_component|module|M|fmt/1,parse/1;get/1,new/1"
    end

    test "a part that owns no type is named by its first function, with a rename note" do
      assert [proposal] =
               model_of(ledger(), @ledger_calls, @ledger_uses) |> ModuleComponents.proposals()

      assert {:split, [{M.Fmt, _fns}, {M, _kept}]} = proposal.proposed
      assert Enum.any?(proposal.evidence, &(&1 =~ "rename M.Fmt"))
    end

    test "a shared private helper is one proposal naming both components" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}, {:p, 0, :defp}], []}]
      calls = [{{M, :a, 0}, {M, :p, 0}, :local}, {{M, :b, 0}, {M, :p, 0}, :local}]
      proposals = model_of(modules, calls) |> ModuleComponents.proposals()

      assert [helper] = Enum.filter(proposals, &(&1.reason == :shared_private_helper))
      assert helper.subject == {M, :p, 0}
      assert helper.proposed == {:extract, M.P}
      assert helper.evidence == ["component a/0", "component b/0"]
    end

    test "one component gives no proposal, however long the module" do
      functions = for i <- 1..40, do: {String.to_atom("f#{i}"), 0}

      calls =
        for [{a, 0}, {b, 0}] <- Enum.chunk_every(functions, 2, 1, :discard),
            do: {{M, a, 0}, {M, b, 0}, :local}

      assert model_of([{M, "domain", functions, []}], calls) |> ModuleComponents.proposals() == []
    end

    test "an interface module is exempt" do
      assert model_of(ledger(interface: true), @ledger_calls, @ledger_uses)
             |> ModuleComponents.proposals() == []
    end

    test "a generated module is exempt" do
      assert model_of(ledger(generated: true), @ledger_calls, @ledger_uses)
             |> ModuleComponents.proposals() == []
    end

    test "a name an existing module has makes the proposal merge into it" do
      specs = %{{:fmt, 1} => "fmt(term()) :: %Money.Currency{}"}

      modules = [
        {M, "domain", @ledger_fns, specs: specs},
        {Money.Currency, "domain", [], struct: [:code]},
        {Currency, "domain", [{:x, 0}], []}
      ]

      assert [proposal] =
               model_of(modules, @ledger_calls, @ledger_uses) |> ModuleComponents.proposals()

      assert {:split, [{Currency, _fns}, {M, _kept}]} = proposal.proposed
      assert Enum.any?(proposal.evidence, &(&1 =~ "merge into existing Currency"))
    end

    test "the component using the module's own struct keeps the name, even when smaller" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}, {:new, 1}], []}]
      calls = [{{M, :a, 0}, {M, :b, 0}, :local}]
      uses = [{{M, :new, 1}, M, :build}]

      assert [%{proposed: {:split, parts}}] =
               model_of(modules, calls, uses) |> ModuleComponents.proposals()

      assert {M, [{M, :new, 1}]} in parts
      assert {M.A, [{M, :a, 0}, {M, :b, 0}]} in parts
    end

    test "with no own struct, a tie keeps the name for the alphabetically first" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}], []}]

      assert [%{proposed: {:split, [{M, [{M, :a, 0}]}, {M.B, [{M, :b, 0}]}]}}] =
               model_of(modules, []) |> ModuleComponents.proposals()
    end

    test "the kept name goes to the larger component" do
      modules = [{M, "domain", [{:a, 0}, {:b, 0}, {:c, 0}], []}]
      calls = [{{M, :b, 0}, {M, :c, 0}, :local}]

      assert [%{proposed: {:split, parts}}] =
               model_of(modules, calls) |> ModuleComponents.proposals()

      assert {M, [{M, :b, 0}, {M, :c, 0}]} in parts
      assert {M.A, [{M, :a, 0}]} in parts
    end
  end
end
