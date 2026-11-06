defmodule Anchor.Domain.PlacementTest do
  # Domain (ADR 002). DND-5448: the placement model and the rule order, on hand-built
  # models (Anchor.Test.PlacementModels). No beams.
  #
  # Sabotage record: ../../sabotage_records/placement-20261106-dnd_5448_placement_core.md
  # DND-5461 (render/1 joins this file, the mirror the generated sabotage runs):
  # ../../sabotage_records/placement-20261106-dnd_5461_placement_rules.md
  use ExUnit.Case, async: true

  import Anchor.Test.PlacementModels

  alias Anchor.Domain.Digraph
  alias Anchor.Domain.Placement
  alias Anchor.Domain.Proposal

  @line_struct {Inv.Line, "domain", [], struct: [:x]}
  @root {W, "framework", [{:a, 0}, {:b, 0}], []}

  defp facts(modules, calls, mfa, opts \\ []) do
    modules |> model(calls, opts) |> Placement.build() |> Placement.facts(mfa)
  end

  defp proposals(modules, calls, selection \\ :function, opts \\ []) do
    model = model(modules, calls, opts)
    model |> Placement.build() |> Placement.proposals(model, selection)
  end

  describe "build/1" do
    test "an immediate dominator inside a chain" do
      modules = [@root, {M, "domain", [{:b, 0}], []}, {N, "domain", [{:c, 0}], []}]
      calls = [{{W, :a, 0}, {M, :b, 0}}, {{M, :b, 0}, {N, :c, 0}}]
      facts = facts(modules, calls, {N, :c, 0})

      assert facts.idom == {M, :b, 0}
      assert facts.reachable?
      refute facts.shared?
      assert facts.callers == [{M, :b, 0}]
    end

    test "a function two roots reach by unrelated paths is shared" do
      calls = [{{W, :a, 0}, {K, :c, 0}}, {{W, :b, 0}, {K, :c, 0}}]
      facts = facts([@root, {K, "domain", [{:c, 0}], []}], calls, {K, :c, 0})

      assert facts.idom == Digraph.virtual_root()
      assert facts.shared?
    end

    test "a root is not shared" do
      facts = facts([@root], [], {W, :a, 0})

      assert facts.idom == Digraph.virtual_root()
      assert facts.reachable?
      refute facts.shared?
    end

    test "a capture makes its target reachable" do
      calls = [{{W, :a, 0}, {M, :f, 1}, :capture}]
      assert facts([@root, {M, "domain", [{:f, 1}], []}], calls, {M, :f, 1}).reachable?
      # Positive control: no capture, no path.
      refute facts([@root, {M, "domain", [{:f, 1}], []}], [], {M, :f, 1}).reachable?
    end

    test "a dynamic call reaches the implementations, and marks them named" do
      modules = [@root, {B, "domain", [], callbacks: [run: 1]}, {I, "domain", [{:run, 1}], []}]
      calls = [{{W, :a, 0}, {:dynamic, :run, 1, :variable}}]
      facts = facts(modules, calls, {I, :run, 1})

      assert facts.reachable?
      assert facts.named?
    end

    test "a macro counts as a root" do
      modules = [
        @root,
        {M, "domain", [{:m, 1, :defmacro}], []},
        {H, "domain", [{:help, 0}], []}
      ]

      assert facts(modules, [{{M, :m, 1}, {H, :help, 0}}], {H, :help, 0}).reachable?
    end

    test "a computed name in a reachable function loses reachability, naming the site" do
      model = model([@root], [{{W, :a, 0}, {:dynamic, nil, 2, :call}, :apply}])
      precision = Placement.build(model).precision

      assert precision.reachability == :lost
      assert precision.computed_calls == 1

      assert precision.lost_sites == [
               %{from: {W, :a, 0}, file: "lib/framework/W.ex", line: 7}
             ]
    end

    test "a computed name in an unreachable function is counted, and loses nothing" do
      model =
        model([@root, {M, "domain", [{:f, 0}], []}], [{{M, :f, 0}, {:dynamic, nil, 2, :call}}])

      precision = Placement.build(model).precision

      assert precision.reachability == :precise
      assert precision.computed_calls == 1
      assert precision.lost_sites == []
    end

    test "a variable application is the closure form: it loses nothing" do
      model = model([@root], [{{W, :a, 0}, {:dynamic, nil, 1, :variable}, :apply}])

      assert Placement.build(model).precision.reachability == :precise
    end

    test "no roots" do
      precision = Placement.build(model([{M, "domain", [{:f, 0}], []}], [])).precision
      assert precision.reachability == :no_roots
    end

    test "a macro alone is no root the inference found: still no roots" do
      modules = [{M, "domain", [{:f, 0}, {:m, 1, :defmacro}], []}]

      assert Placement.build(model(modules, [])).precision.reachability == :no_roots
    end

    test "generated modules and macro clauses are flagged generated; unknown reads as generated" do
      assert facts([{M, "domain", [{:f, 0}], generated: true}], [], {M, :f, 0}).generated?
      assert facts([{M, "domain", [{:f, 0}], generated: :unknown}], [], {M, :f, 0}).generated?
      refute facts([{M, "domain", [{:f, 0}], []}], [], {M, :f, 0}).generated?

      model = model([{M, "domain", [{:f, 0}], []}], [])
      node = model.graph.modules[M].functions[{:f, 0}]
      node = %{node | clauses: [{[context: Some], [], [], :ok}]}
      model = put_in(model.graph.modules[M].functions[{:f, 0}], node)

      assert Placement.build(model) |> Placement.facts({M, :f, 0}) |> Map.fetch!(:generated?)
    end

    test "precision counts the public functions whose ownership is unknown" do
      modules = [
        {M, "domain", [{:f, 0}, {:g, 0}, {:h, 0, :defp}], specs: %{{:g, 0} => "g() :: integer()"}}
      ]

      precision = Placement.build(model(modules, [])).precision

      assert precision.functions == 3
      assert precision.no_spec == 1
    end
  end

  describe "build/1 precision of ownership" do
    test "two structs are ambiguous, and a primitive with no clause is unjoined: both counted" do
      modules = [
        {Inv, "domain", [], struct: [:x]},
        {Pay, "domain", [], struct: [:y]},
        {M, "domain", [{:f, 0}, {:g, 1}],
         specs: %{
           {:f, 0} => "f() :: %Inv{} | %Pay{}",
           {:g, 1} => "g(%Inv{}) :: boolean()"
         }}
      ]

      precision = Placement.build(model(modules, [])).precision

      assert precision.ambiguous_owner == 1
      assert precision.unjoined == 1
      assert precision.no_spec == 0
    end
  end

  describe "proposals/3" do
    test "rule 1 wins over rule 2" do
      modules = [
        @line_struct,
        {Fmt, "domain", [{:line, 1}], specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}}
      ]

      assert [proposal] = proposals(modules, [{{Fmt, :line, 1}, {File, :read, 1}}])
      assert proposal.reason == :bucket_from_effects
      assert proposal.rule == :effects_match_bucket
    end

    test "rule 1's target names the context, and the one module with the subject's tail name" do
      modules = [
        {App.Managers.Inv, "managers", [{:f, 0}], []},
        {App.Domain.Inv, "domain", [{:g, 0}], []},
        {App.Domain.Other, "domain", [{:h, 0}], []}
      ]

      assert [%{reason: :bucket_from_effects, proposed: proposed} | _rest] =
               proposals(modules, [{{App.Domain.Inv, :g, 0}, {App.Domain.Other, :h, 0}}])

      assert proposed == {:bucket, :domain, "ctx", App.Domain.Inv}
    end

    test "rule 1 names no module when two have the subject's tail name, or none has" do
      two = [
        {App.Managers.Inv, "managers", [{:f, 0}], []},
        {App.Domain.Inv, "domain", [], []},
        {App.Domain.Sub.Inv, "domain", [], []}
      ]

      assert [%{proposed: {:bucket, :domain, "ctx", nil}}] = proposals(two, [])

      none = [{App.Managers.Inv, "managers", [{:f, 0}], []}]
      assert [%{proposed: {:bucket, :domain, "ctx", nil}}] = proposals(none, [])
    end

    test "rule 1: a pure function in a Manager whose input owner is known goes there" do
      modules = [
        {Inv, "domain", [], struct: [:x]},
        {Mgr, "managers", [{:total, 1}],
         specs: %{{:total, 1} => "total(%Inv{}) :: integer()"},
         clauses: %{{:total, 1} => ["def total(%Inv{} = i), do: i.x"]}}
      ]

      assert [proposal] = proposals(modules, [])
      assert proposal.reason == :input_type_owner
      assert proposal.proposed == Inv
      assert proposal.rule == :effects_match_bucket
      assert proposal.key == "effects_match_bucket|Mgr.total/1|domain"
    end

    test "output owner in a Domain bucket" do
      modules = [
        @line_struct,
        {Fmt, "domain", [{:line, 1}], specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}}
      ]

      assert [proposal] = proposals(modules, [])
      assert proposal.reason == :output_type_owner
      assert proposal.proposed == Inv.Line
      assert proposal.current == Fmt
      assert proposal.rule == :function_placement
      assert proposal.key == "function_placement|function|Fmt.line/1|Inv.Line"
    end

    test "an owner in another bucket gives no proposal" do
      modules = [
        {Inv.Line, "adapters", [], struct: [:x]},
        {Fmt, "domain", [{:line, 1}], specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}}
      ]

      assert proposals(modules, []) == []
    end

    test "input owner, from a clause's slice" do
      modules = [
        {Lease, "domain", [], struct: [:ends_at]},
        {Calc, "domain", [{:expired?, 2}],
         specs: %{{:expired?, 2} => "expired?(%Lease{}, integer()) :: boolean()"},
         clauses: %{{:expired?, 2} => ["def expired?(%Lease{} = l, now), do: l.ends_at < now"]}}
      ]

      assert [proposal] = proposals(modules, [])
      assert proposal.reason == :input_type_owner
      assert proposal.proposed == Lease
    end

    test "an input owner in another bucket gives no proposal" do
      modules = [
        {Lease, "adapters", [], struct: [:ends_at]},
        {Calc, "domain", [{:expired?, 1}],
         specs: %{{:expired?, 1} => "expired?(%Lease{}) :: boolean()"},
         clauses: %{{:expired?, 1} => ["def expired?(l), do: l.ends_at"]}}
      ]

      assert proposals(modules, []) == []
    end

    test "dominated by one module" do
      modules = [
        @root,
        {Inv, "domain", [{:total, 1}], []},
        {Round, "domain", [{:r, 1}], []}
      ]

      calls = [{{W, :a, 0}, {Inv, :total, 1}}, {{Inv, :total, 1}, {Round, :r, 1}}]

      assert [proposal] = proposals(modules, calls, :function_placement)
      assert proposal.reason == :dominated_by
      assert proposal.proposed == Inv
    end

    test "dominated across buckets is not moved" do
      modules = [@root, {Mgr, "managers", [{:run, 1}], []}, {Calc, "domain", [{:f, 1}], []}]
      calls = [{{W, :a, 0}, {Mgr, :run, 1}}, {{Mgr, :run, 1}, {Calc, :f, 1}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "dominated across contexts is not moved" do
      modules = [
        @root,
        {Inv, "domain", [{:total, 1}], context: "a"},
        {Round, "domain", [{:r, 1}], context: "b"}
      ]

      calls = [{{W, :a, 0}, {Inv, :total, 1}}, {{Inv, :total, 1}, {Round, :r, 1}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "dominated but called from two modules is not moved" do
      modules = [
        @root,
        {Inv, "domain", [{:total, 1}], []},
        {Pay, "domain", [{:sum, 1}], []},
        {Round, "domain", [{:r, 1}], []}
      ]

      calls = [
        {{W, :a, 0}, {Inv, :total, 1}},
        {{Inv, :total, 1}, {Pay, :sum, 1}},
        {{Inv, :total, 1}, {Round, :r, 1}},
        {{Pay, :sum, 1}, {Round, :r, 1}}
      ]

      assert Enum.filter(
               proposals(modules, calls, :function_placement),
               &(&1.subject == {Round, :r, 1})
             ) == []
    end

    test "a function its own module also calls is not moved" do
      modules = [
        @root,
        {Inv, "domain", [{:total, 1}], []},
        {Round, "domain", [{:r, 1}, {:s, 1}], []}
      ]

      calls = [
        {{W, :a, 0}, {Inv, :total, 1}},
        {{W, :a, 0}, {Round, :s, 1}},
        {{Inv, :total, 1}, {Round, :r, 1}},
        {{Round, :s, 1}, {Round, :r, 1}}
      ]

      assert Enum.filter(
               proposals(modules, calls, :function_placement),
               &(&1.subject == {Round, :r, 1})
             ) == []
    end

    test "a function a dynamic call can reach cannot go private" do
      modules = [
        @root,
        {Inv, "domain", [{:total, 1}], []},
        {Round, "domain", [{:r, 1}], []}
      ]

      calls = [{{W, :a, 0}, {Inv, :total, 1}}, {{Inv, :total, 1}, {:dynamic, :r, 1, :variable}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "a project behaviour's callback is not moved" do
      modules = [
        @root,
        {B, "domain", [], callbacks: [r: 1]},
        {Inv, "domain", [{:total, 1}], []},
        {Round, "domain", [{:r, 1}], behaviours: [B]}
      ]

      calls = [{{W, :a, 0}, {Inv, :total, 1}}, {{Inv, :total, 1}, {Round, :r, 1}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "a shared function gets no move from rules 2 or 3" do
      spec = %{{:line, 0} => "line() :: %Inv.Line{}"}
      modules = [@root, @line_struct, {Fmt, "domain", [{:line, 0}], specs: spec}]
      shared = [{{W, :a, 0}, {Fmt, :line, 0}}, {{W, :b, 0}, {Fmt, :line, 0}}]

      assert proposals(modules, shared, :function_placement) == []

      # Positive control: the same spec, one root.
      assert [%{reason: :output_type_owner}] =
               proposals(modules, [{{W, :a, 0}, {Fmt, :line, 0}}], :function_placement)
    end

    test "a shared function gets no move from rule 4" do
      # Two roots of one domain module: the idom is the virtual root, and every caller is
      # in one other module of the same bucket and context.
      modules = [{Dm, "domain", [{:a, 0}, {:b, 0}], []}, {K, "domain", [{:c, 0}], []}]
      calls = [{{Dm, :a, 0}, {K, :c, 0}}, {{Dm, :b, 0}, {K, :c, 0}}]

      assert proposals(modules, calls, :function_placement, roots: [%{"pattern" => "Dm"}]) == []
    end

    test "rule 1 of a shared pure function names its bucket, not an owner" do
      spec = %{{:line, 0} => "line() :: %Inv.Line{}"}
      modules = [@root, @line_struct, {Mgr, "managers", [{:line, 0}], specs: spec}]
      calls = [{{W, :a, 0}, {Mgr, :line, 0}}, {{W, :b, 0}, {Mgr, :line, 0}}]

      assert [%{reason: :bucket_from_effects}] = proposals(modules, calls)
    end

    test "a move into an interface module is not proposed" do
      modules = [
        @root,
        {Foo, "domain", [{:f, 0}], interface: true},
        {Impl, "domain", [{:g, 0}], []}
      ]

      calls = [{{W, :a, 0}, {Foo, :f, 0}}, {{Foo, :f, 0}, {Impl, :g, 0}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "an interface module's functions are exempt from rules 2 to 4" do
      modules = [
        @line_struct,
        {Fmt, "domain", [{:line, 1}],
         interface: true, specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}}
      ]

      assert proposals(modules, []) == []

      # Positive control: the same module, no interface.
      assert [%{reason: :output_type_owner}] =
               proposals(
                 [
                   @line_struct,
                   {Fmt, "domain", [{:line, 1}],
                    specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}}
                 ],
                 []
               )
    end

    test "a function already in its owner gives no proposal" do
      modules = [
        {Inv, "domain", [{:total, 1}],
         struct: [:x], specs: %{{:total, 1} => "total(term()) :: %Inv{}"}}
      ]

      assert proposals(modules, []) == []
    end

    test "a function in its owner stays, though only another module of its bucket calls it" do
      modules = [
        @root,
        {Inv, "domain", [{:add, 0}], []},
        {Inv.Line, "domain", [{:new, 0}],
         struct: [:x], specs: %{{:new, 0} => "new() :: %Inv.Line{}"}}
      ]

      calls = [{{W, :a, 0}, {Inv, :add, 0}}, {{Inv, :add, 0}, {Inv.Line, :new, 0}}]

      assert proposals(modules, calls, :function_placement) == []
    end

    test "a pure function in a Manager that owns its own struct gets its bucket" do
      modules = [
        {Mgr, "managers", [{:new, 0}], struct: [:x], specs: %{{:new, 0} => "new() :: %Mgr{}"}}
      ]

      assert [%{reason: :bucket_from_effects}] = proposals(modules, [])
    end

    test "generated functions, roots and compiler names are not judged by rules 2 to 4" do
      spec = %{{:line, 1} => "line(term()) :: %Inv.Line{}"}

      assert proposals(
               [@line_struct, {Fmt, "domain", [{:line, 1}], specs: spec, generated: true}],
               []
             ) ==
               []

      assert proposals(
               [@line_struct, {Fmt, "domain", [{:line, 1}], specs: spec}],
               [],
               :function,
               roots: [%{"pattern" => "Fmt"}]
             ) == []
    end

    test "a long, well-placed function gets no proposal" do
      body = Enum.map_join(1..200, "\n", &"  _ = i.x + #{&1}")

      modules = [
        @root,
        {Inv, "domain", [{:total, 1}],
         struct: [:x],
         specs: %{{:total, 1} => "total(%Inv{}) :: integer()"},
         clauses: %{{:total, 1} => ["def total(%Inv{} = i) do\n#{body}\n  i.x\nend"]}}
      ]

      assert proposals(modules, [{{W, :a, 0}, {Inv, :total, 1}}]) == []
    end

    test "unreachable: a public function, with delete; a private one is not judged" do
      modules = [@root, {M, "domain", [{:dead, 0}, {:hid, 0, :defp}], []}]

      assert [proposal] = proposals(modules, [], :reachable_from_root)
      assert proposal.subject == {M, :dead, 0}
      assert proposal.proposed == :delete
      assert proposal.reason == :unreachable
    end

    test "unreachable lists none under lost precision" do
      modules = [@root, {M, "domain", [{:dead, 0}], []}]
      calls = [{{W, :a, 0}, {:dynamic, nil, 2, :call}, :apply}]

      assert proposals(modules, calls, :reachable_from_root) == []
    end

    test "child_spec/1 and compiler names are not unreachable" do
      modules = [
        @root,
        {M, "domain",
         [{:child_spec, 1}, {:__struct__, 0}, {:module_info, 1}, {:behaviour_info, 1}], []}
      ]

      assert proposals(modules, [], :reachable_from_root) == []
    end

    test "the selection lists one rule's own; :function lists every one, sorted by key" do
      modules = [
        @root,
        @line_struct,
        {Fmt, "domain", [{:line, 1}], specs: %{{:line, 1} => "line(term()) :: %Inv.Line{}"}},
        {D, "domain", [{:read, 1}], []}
      ]

      calls = [
        {{D, :read, 1}, {File, :read, 1}},
        {{W, :a, 0}, {D, :read, 1}},
        {{W, :a, 0}, {Fmt, :line, 1}}
      ]

      model = model(modules, calls)
      placement = Placement.build(model)
      keys = placement |> Placement.proposals(model, :function) |> Enum.map(& &1.key)

      assert keys == Enum.sort(keys)
      assert length(keys) == 2

      assert [%{reason: :output_type_owner}] =
               Placement.proposals(placement, model, :function_placement)

      assert [%{reason: :bucket_from_effects}] =
               Placement.proposals(placement, model, :effects_match_bucket)
    end
  end

  describe "facts/2" do
    test "nil for a function the model does not hold" do
      assert facts([@root], [], {Nope, :f, 0}) == nil
    end
  end

  defp render_proposal(reason, proposed, evidence \\ []) do
    %Proposal{
      level: :function,
      subject: {F, :line, 1},
      current: F,
      proposed: proposed,
      rule: :function_placement,
      reason: reason,
      evidence: evidence
    }
  end

  describe "render/1" do
    test "output owner text" do
      assert Placement.render(render_proposal(:output_type_owner, Inv.Line)) ==
               "move F.line/1 to Inv.Line (it returns %Inv.Line{}; the owner of a type holds its " <>
                 "transitions)"
    end

    test "input owner text" do
      assert Placement.render(render_proposal(:input_type_owner, Lease)) ==
               "move F.line/1 to Lease (its result is computed from %Lease{})"
    end

    test "dominated text" do
      assert Placement.render(render_proposal(:dominated_by, Inv)) ==
               "move F.line/1 into Inv as a private function (only Inv calls it)"
    end

    test "unreachable text starts delete and names the alternative" do
      assert Placement.render(render_proposal(:unreachable, :delete)) ==
               "delete F.line/1 (no root reaches it), or add the root that should call it"
    end

    test "bucket text names the context and module when known, and the evidence" do
      assert Placement.render(
               render_proposal(:bucket_from_effects, {:bucket, :managers, "App.B", App.B.Inv}, [
                 "a -> b"
               ])
             ) == "move F.line/1 to the managers bucket of App.B (App.B.Inv): a -> b"

      assert Placement.render(
               render_proposal(:bucket_from_effects, {:bucket, :domain, nil, nil}, ["x"])
             ) ==
               "move F.line/1 to the domain bucket: x"
    end

    test "inert hop text names the callers and the target (DND-5461)" do
      hop = fn callers ->
        %Proposal{
          render_proposal(:inert_hop, {:inline, {N, :g, 1}}, ["forwards to N.g/1", callers])
          | rule: :no_inert_hop
        }
      end

      assert Placement.render(hop.("callers: A.x/1, B.y/2")) ==
               "inline F.line/1: its callers (A.x/1, B.y/2) call N.g/1 directly (it forwards " <>
                 "without crossing a bucket, context, app, aggregate, interface or callback boundary)"

      assert Placement.render(hop.("dynamic callers only")) =~
               "inline F.line/1: its callers (dynamic callers only) call N.g/1 directly"
    end

    test "directory texts (DND-5462)" do
      dir = fn reason, subject, proposed, evidence ->
        %Proposal{
          level: :directory,
          subject: subject,
          current: "lib/b/domain",
          proposed: proposed,
          rule: :directory_placement,
          reason: reason,
          evidence: evidence
        }
      end

      assert Placement.render(
               dir.(:dominator_subtree, Rnd, "lib/b/domain/invoice", ["dominated by Inv"])
             ) ==
               "move Rnd from lib/b/domain to lib/b/domain/invoice (only Inv reaches it; Inv is " <>
                 "the directory's public module)"

      assert Placement.render(
               dir.(:shared_module, K, "lib/b/domain", [
                 "reached from 3 unrelated callers: A, B, C",
                 "no tie-break evidence"
               ])
             ) ==
               "move K to lib/b/domain (reached from 3 unrelated callers: shared, not a private " <>
                 "helper); no tie-break evidence"

      assert Placement.render(
               dir.(:shared_module, K, {:library_context, ["b", "c"]}, ["reached from 2"])
             ) == "move K to a library context used by b, c"

      assert Placement.render(dir.(:inert_directory, "lib/b/domain/util", "lib/b/domain", [])) ==
               "flatten lib/b/domain/util into lib/b/domain (no module in it is reached only " <>
                 "through it)"
    end

    test "an unknown reason raises: there is no default text" do
      assert_raise FunctionClauseError, fn -> Placement.render(render_proposal(:nope, F)) end
    end

    test "the key has no line number and is stable when lines shift" do
      build = fn line ->
        model =
          model(
            [
              {W, "framework", [{:run, 1}], []},
              {Round, "domain", [{:r, 1}], []},
              {Inv, "domain", [{:total, 1}], []}
            ],
            [{{W, :run, 1}, {Inv, :total, 1}}, {{Inv, :total, 1}, {Round, :r, 1}}]
          )

        model = put_in(model.graph.modules[Round].functions[{:r, 1}].line, line)
        model |> Placement.build() |> Placement.proposals(model, :function) |> Enum.map(& &1.key)
      end

      assert build.(10) == build.(500)
      assert build.(10) == ["function_placement|function|Round.r/1|Inv"]
    end
  end

  describe "to_violation/3" do
    @rule %{type: :function_placement, id: "r"}

    defp violation_message(reason, subject, proposed, opts \\ []) do
      model =
        model(
          [
            {F, "domain", [{:line, 1}], []},
            {Mgr, "managers", [{:run, 1}], []},
            {Ad, "adapters", [{:get, 1}], []}
          ],
          []
        )

      proposal = %Proposal{
        level: :function,
        subject: subject,
        current: elem(subject, 0),
        proposed: proposed,
        rule: Keyword.get(opts, :rule, :function_placement),
        reason: reason,
        evidence: Keyword.get(opts, :evidence, []),
        key: Keyword.get(opts, :key, "function_placement|function|x|y")
      }

      Placement.to_violation(proposal, model, @rule).message
    end

    defp effects_message(subject, role, evidence) do
      violation_message(:bucket_from_effects, subject, {:bucket, role, nil, nil},
        rule: :effects_match_bucket,
        evidence: evidence,
        key: "effects_match_bucket|x|#{role}"
      )
    end

    test "each owner reason says why before the Fix" do
      assert violation_message(:output_type_owner, {F, :line, 1}, Inv) ==
               "F.line/1 is in F (bucket domain), but it returns %Inv{}. Fix: " <>
                 Placement.render(render_proposal(:output_type_owner, Inv))

      assert violation_message(:input_type_owner, {F, :line, 1}, Inv) =~
               "F.line/1 is in F (bucket domain), but its result is computed from %Inv{}. Fix: "

      assert violation_message(:dominated_by, {F, :line, 1}, Inv) =~
               "F.line/1 is in F (bucket domain), but only Inv calls it. Fix: "
    end

    test "an unreachable function's sentence" do
      assert violation_message(:unreachable, {F, :line, 1}, :delete) =~
               ~r/^F.line\/1 is public and no root reaches it. Fix: delete/
    end

    test "an inert hop's sentence names the target (DND-5461)" do
      message =
        violation_message(:inert_hop, {F, :line, 1}, {:inline, {N, :g, 1}},
          evidence: ["forwards to N.g/1", "callers: A.x/1"]
        )

      assert message ==
               "F.line/1 only forwards to N.g/1, and the hop crosses no boundary. Fix: inline " <>
                 "F.line/1: its callers (A.x/1) call N.g/1 directly (it forwards without crossing " <>
                 "a bucket, context, app, aggregate, interface or callback boundary)"
    end

    test "a module subject sits at its defmodule; a directory's on its first file (DND-5462)" do
      model =
        Anchor.Test.DirectoryModels.directory_model(
          [{W, "framework", "b"}, {U1, "domain", "b"}, {U2, "domain", "b"}],
          [],
          %{
            W => "lib/b/web/w.ex",
            U1 => "lib/b/domain/util/u1.ex",
            U2 => "lib/b/domain/util/u2.ex"
          }
        )

      base = %Proposal{
        level: :directory,
        subject: U2,
        current: "lib/b/domain/util",
        proposed: "lib/b/domain/util/u1",
        rule: :directory_placement,
        reason: :dominator_subtree,
        evidence: ["dominated by U1"],
        key: "directory_placement|directory|U2|lib/b/domain/util/u1"
      }

      module = Placement.to_violation(base, model, %{id: "d"})

      assert {module.filename, module.line, module.trigger, module.key} ==
               {"lib/b/domain/util/u2.ex", 3, "U2", "d|directory|U2|lib/b/domain/util/u1"}

      assert module.message =~ ~r/^U2 sits in lib\/b\/domain\/util, but only U1 reaches it. Fix: /

      dir = %Proposal{
        base
        | subject: "lib/b/domain/util",
          proposed: "lib/b/domain",
          reason: :inert_directory,
          key: "directory_placement|directory|lib/b/domain/util|lib/b/domain"
      }

      violation = Placement.to_violation(dir, model, %{id: "d"})

      assert {violation.filename, violation.trigger} ==
               {"lib/b/domain/util/u1.ex", "lib/b/domain/util"}

      assert violation.message =~ ~r/^lib\/b\/domain\/util encapsulates nothing: /
      assert Placement.subject_modules(dir, model) == [U1, U2]

      shared = %Proposal{
        base
        | subject: U1,
          reason: :shared_module,
          evidence: ["reached from 2 x"]
      }

      assert Placement.to_violation(shared, model, %{id: "d"}).message =~
               ~r/^U1 is shared: no one module reaches it. Fix: /
    end

    test "each effects sentence names the bucket and what the inference found" do
      assert effects_message({F, :line, 1}, :adapters, ["F.line/1 -> File.read/1"]) =~
               ~r/^F.line\/1 is in bucket domain \(domain\) but reaches an effect. Fix: /

      assert effects_message({Mgr, :run, 1}, :adapters, ["x"]) =~
               ~r/^Mgr.run\/1 is in bucket managers \(managers\) but calls an effect itself. Fix: /

      assert effects_message({Mgr, :run, 1}, :domain, ["x"]) =~
               ~r/^Mgr.run\/1 is in bucket managers but reaches no effect. Fix: /

      assert effects_message({Ad, :get, 1}, :managers, ["Ad.get/1 -> B.c/1 -> File.read/1"]) =~
               ~r/^Ad.get\/1 is in bucket adapters \(adapters\) but reaches effects only through B.c\/1. Fix: /

      assert effects_message({Ad, :get, 1}, :managers, ["Ad.get/1"]) =~
               "reaches effects only through Ad.get/1."

      assert effects_message({Ad, :get, 1}, :framework, ["x"]) =~
               ~r/^Ad.get\/1 is in bucket adapters \(adapters\) but infers framework. Fix: /
    end
  end
end
