defmodule Anchor.Domain.DataFlowTest do
  # DND-5439: intra-function data flow over one clause's source AST.
  # Sabotage record: ../../sabotage_records/data_flow-20261103-dnd_5439.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.DataFlow
  alias Anchor.Domain.DependencyAnalyzer

  @no_effects &__MODULE__.never/1

  def never(_ast), do: false

  # `def`/`defp` source becomes {args, guards, body}; any other source is a bare
  # body with no parameters (its free variables read as `:free` keys).
  defp clause!(source) do
    case Code.string_to_quoted!(source) do
      {def, _meta, [head, [do: body]]} when def in [:def, :defp] -> head_clause(head, body)
      body -> {[], [], body}
    end
  end

  defp head_clause({:when, _meta, [call, guard]}, body),
    do: put_elem(head_clause(call, body), 1, [guard])

  defp head_clause({_name, _meta, args}, body), do: {List.wrap(args), [], body}

  defp flow!(source), do: source |> clause!() |> DataFlow.analyze()

  # The outermost node that starts on `line`.
  defp node_at(flow, line) do
    flow.nodes
    |> Map.values()
    |> Enum.filter(&(&1.line == line))
    |> Enum.min_by(&length(&1.id), fn ->
      flunk("no node on line #{line}: #{inspect(Map.keys(flow.nodes))}")
    end)
  end

  defp id_at(flow, line), do: node_at(flow, line).id

  defp calls?(ast, name) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        {^name, _meta, args} = node, _acc when is_list(args) -> {node, true}
        node, acc -> {node, acc}
      end)

    found?
  end

  defp k(name, version), do: {name, nil, version}

  describe "analyze/1 def-use" do
    test "1: a plain binding is defined by its node and used by the final node; a is a parameter" do
      flow = flow!("def f(a) do\n  b = a + 1\n  b * 2\nend")

      assert flow.params == [k(:a, 0)]
      assert flow.defs[k(:a, 0)] == :param
      assert flow.defs[k(:b, 0)] == id_at(flow, 2)
      assert node_at(flow, 2).kind == :bind
      assert node_at(flow, 2).uses == [k(:a, 0)]
      assert node_at(flow, 3).uses == [k(:b, 0)]
      assert flow.result == id_at(flow, 3)
    end

    test "2: rebinding makes a new key; the rebinding reads the old one" do
      flow = flow!("x = 1\nx = x + 1\nx")

      assert node_at(flow, 1).binds == [k(:x, 0)]
      assert node_at(flow, 2).uses == [k(:x, 0)]
      assert node_at(flow, 2).binds == [k(:x, 1)]
      assert node_at(flow, 3).uses == [k(:x, 1)]
    end

    test "3: a pin is a use, never a new binding" do
      flow = flow!("def f(x, y) do\n  case y do\n    ^x -> 1\n  end\nend")
      branch = node_at(flow, 2)

      assert branch.kind == :branch
      assert branch.uses == [k(:y, 0), k(:x, 0)]
      refute Map.has_key?(flow.defs, k(:x, 1))
    end

    test "4: _ and _-prefixed variables are neither defs nor uses" do
      flow = flow!("_ = f()\n_x = g()\n_x")

      assert flow.defs == %{}
      assert flow.uses == %{}
      assert node_at(flow, 2).binds == []
    end

    test "4 positive control: the same names without the underscore bind and use" do
      flow = flow!("y = f()\nx = g()\nx")

      assert Map.keys(flow.defs) |> Enum.sort() == [k(:x, 0), k(:y, 0)]
      assert flow.uses == %{k(:x, 0) => [id_at(flow, 3)]}
    end

    test "5: destructuring binds tuple, list, map, struct and binary variables in one node" do
      source = """
      def f(v) do
        {a, [b | _], %{k: c}, %S{f: d}, <<n::8, e::binary-size(n)>>} = v
        {a, b, c, d, e}
      end
      """

      flow = flow!(source)
      bind = node_at(flow, 2)

      assert bind.binds == [k(:a, 0), k(:b, 0), k(:c, 0), k(:d, 0), k(:n, 0), k(:e, 0)]
      for name <- [:a, :b, :c, :d, :n, :e], do: assert(flow.defs[k(name, 0)] == bind.id)
      # `binary` is a segment type, not a variable; size(n) reads the n this pattern binds.
      assert bind.uses == [k(:v, 0), k(:n, 0)]
      refute Map.has_key?(flow.uses, k(:binary, :free))
    end

    test "6: a case clause's bindings do not leak out of the clause" do
      source = """
      def f(v) do
        case v do
          {:ok, z} -> z
        end
        w = z
      end
      """

      flow = flow!(source)
      branch = node_at(flow, 2)
      clause_node = id_at(flow, 3)

      assert flow.defs[k(:z, 0)] == branch.id
      assert branch.binds == []
      assert flow.uses[k(:z, 0)] == [clause_node]
      assert node_at(flow, 5).uses == [k(:z, :free)]
    end

    test "7: with steps bind into later steps and the do block; else clauses get their own scope" do
      source = """
      with {:ok, a} <- f(),
           {:ok, b} <- g(a) do
        b
      else
        e -> e
      end
      """

      flow = flow!(source)
      with_node = node_at(flow, 1)

      assert with_node.kind == :branch
      assert flow.defs[k(:a, 0)] == with_node.id
      assert flow.uses[k(:a, 0)] == [with_node.id]
      assert flow.defs[k(:b, 0)] == with_node.id
      assert node_at(flow, 3).uses == [k(:b, 0)]
      assert node_at(flow, 3).block == with_node.id ++ [:clause, 0]
      assert flow.defs[k(:e, 0)] == with_node.id
      assert node_at(flow, 5).uses == [k(:e, 0)]
      assert node_at(flow, 5).block == with_node.id ++ [:clause, 1]
      assert with_node.binds == []
    end

    test "8: a fn uses the outer variables it closes over; its argument is scoped to it" do
      flow = flow!("y = 1\nEnum.map(xs, fn x -> x + y end)")
      call = node_at(flow, 2)

      assert k(:y, 0) in call.uses
      assert {:xs, nil, :free} in call.uses
      assert flow.defs[k(:x, 0)] == call.id
      assert call.binds == []
      assert flow.uses[k(:x, 0)] == [call.id]
    end

    test "8b: a fn that is a whole statement is a :fn node with a block per clause" do
      flow = flow!("def f(y) do\n  g = fn x ->\n    x + y\n  end\n  g\nend")
      fn_node = node_at(flow, 2)

      assert fn_node.kind == :fn
      assert fn_node.binds == [k(:g, 0)]
      assert flow.defs[k(:x, 0)] == fn_node.id
      assert node_at(flow, 3).uses == [k(:x, 0), k(:y, 0)]
      assert node_at(flow, 3).parent == fn_node.id
    end

    test "9: a for comprehension scopes its generators and filters" do
      flow = flow!("for x <- xs, y = x * 2, do: y\nx")
      for_node = node_at(flow, 1)

      assert for_node.kind == :for
      assert flow.defs[k(:x, 0)] == for_node.id
      assert flow.defs[k(:y, 0)] == for_node.id
      assert for_node.binds == []

      assert flow.blocks[for_node.id ++ [:clause, 0]] |> Enum.map(&flow.nodes[&1].uses) == [
               [k(:y, 0)]
             ]

      assert {:xs, nil, :free} in for_node.uses
      assert flow.nodes[[1]].uses == [{:x, nil, :free}]
    end

    test "10: try scopes the rescue variable; the after block is its own block" do
      source = """
      try do
        f()
      rescue
        e -> e
      after
        g()
      end
      """

      flow = flow!(source)
      try_node = node_at(flow, 1)

      assert flow.defs[k(:e, 0)] == try_node.id
      assert node_at(flow, 4).uses == [k(:e, 0)]
      assert flow.blocks[try_node.id ++ [:after]] == [id_at(flow, 6)]
      assert Macro.to_string(node_at(flow, 6).ast) == "g()"
    end

    test "10b: rescue e in X binds e only" do
      flow = flow!("try do\n  f()\nrescue\n  e in [ArgumentError] -> e\nend")

      assert Map.keys(flow.defs) == [k(:e, 0)]
    end

    test "11: a pipe is read as the call it desugars to" do
      flow = flow!("def f(x, y) do\n  x |> f() |> g(y)\nend")
      call = node_at(flow, 2)

      assert map_size(flow.nodes) == 1
      assert Macro.to_string(call.ast) == "g(f(x), y)"
      assert call.uses == [k(:x, 0), k(:y, 0)]
    end

    test "11b: a multi-line pipeline's node starts on its first line" do
      flow = flow!("def f(x) do\n  x\n  |> f()\n  |> g()\nend")
      [id] = flow.blocks[[]]

      assert flow.nodes[id].line == 2
      assert [%DataFlow.Region{lines: 2..4//1}] = DataFlow.regions(flow)
    end

    test "12: if is a branch with two blocks; unless with no else still has two" do
      flow = flow!("def f(c, a, b) do\n  if c, do: a, else: b\nend")
      branch = node_at(flow, 2)

      assert branch.kind == :branch
      assert branch.uses == [k(:c, 0)]

      assert flow.blocks[branch.id ++ [:clause, 0]] |> Enum.map(&flow.nodes[&1].uses) == [
               [k(:a, 0)]
             ]

      assert flow.blocks[branch.id ++ [:clause, 1]] |> Enum.map(&flow.nodes[&1].uses) == [
               [k(:b, 0)]
             ]

      unless_flow = flow!("def f(c, a) do\n  unless c, do: a\nend")
      unless_node = node_at(unless_flow, 2)
      assert unless_flow.blocks[unless_node.id ++ [:clause, 1]] == []
      assert length(unless_flow.blocks[unless_node.id ++ [:clause, 0]]) == 1
    end

    test "13: an unknown macro uses every variable in its arguments" do
      flow = flow!("def f(a, b) do\n  my_macro(a, b)\nend")

      assert node_at(flow, 2).uses == [k(:a, 0), k(:b, 0)]
    end

    test "cond: conditions are the branch's uses; each body is its own block" do
      flow = flow!("def f(a, b, c) do\n  cond do\n    a > 1 -> b\n    true -> c\n  end\nend")
      branch = node_at(flow, 2)

      assert branch.uses == [k(:a, 0)]
      assert flow.nodes[branch.id ++ [:clause, 0, 0]].uses == [k(:b, 0)]
      assert flow.nodes[branch.id ++ [:clause, 1, 0]].uses == [k(:c, 0)]
    end

    test "receive: a clause pattern binds in the clause; the after timeout is a use" do
      flow =
        flow!(
          "def f(t) do\n  receive do\n    {:msg, m} -> m\n  after\n    t -> :timeout\n  end\nend"
        )

      branch = node_at(flow, 2)

      assert flow.defs[k(:m, 0)] == branch.id
      assert branch.uses == [k(:t, 0)]
      assert node_at(flow, 3).uses == [k(:m, 0)]
    end

    test "a binding in a case scrutinee is visible after the case (Elixir does not scope it)" do
      flow = flow!("case x = f() do\n  _ -> :ok\nend\nx")

      assert node_at(flow, 1).binds == [k(:x, 0)]
      assert node_at(flow, 4).uses == [k(:x, 0)]
    end

    test "guards are uses: a guard-only parameter is read by the guard" do
      flow = flow!("def f(a, b) when b > 0 do\n  a\nend")

      assert flow.guard_uses == [k(:b, 0)]
    end

    test "analyze/1 refuses anything that is not a clause triple" do
      assert_raise ArgumentError, ~r/clause/, fn -> DataFlow.analyze(:not_a_clause) end
      assert_raise ArgumentError, fn -> DataFlow.analyze({:a, [], nil}) end
    end
  end

  describe "sinks/2 and backward_slice/2" do
    test "14: the result's slice holds what it reads, not an unrelated binding" do
      flow = flow!("a = f(x)\nb = g(y)\na")
      slice = DataFlow.backward_slice(flow, DataFlow.sinks(flow, @no_effects))

      assert MapSet.member?(slice, id_at(flow, 1))
      refute MapSet.member?(slice, id_at(flow, 2))
    end

    test "15: a node the effect predicate marks is a sink" do
      flow = flow!("a = f(x)\nb = g(y)\na")
      sinks = DataFlow.sinks(flow, &calls?(&1, :g))
      slice = DataFlow.backward_slice(flow, sinks)

      assert id_at(flow, 2) in sinks
      assert MapSet.member?(slice, id_at(flow, 1))
      assert MapSet.member?(slice, id_at(flow, 2))
      refute id_at(flow, 2) in DataFlow.sinks(flow, @no_effects)
    end

    test "16: a node inside a branch depends on the branch and its scrutinee" do
      source = """
      s = h()
      u = z()
      case s do
        :ok ->
          r = k()
          r
      end
      """

      flow = flow!(source)
      slice = DataFlow.backward_slice(flow, DataFlow.sinks(flow, @no_effects))

      for line <- [1, 3, 5, 6],
          do: assert(MapSet.member?(slice, id_at(flow, line)), "line #{line}")

      refute MapSet.member?(slice, id_at(flow, 2))

      # `r = k()` reads nothing: only control dependence brings in the case and `s`.
      from_inside = DataFlow.backward_slice(flow, [id_at(flow, 5)])

      assert MapSet.equal?(
               from_inside,
               MapSet.new([id_at(flow, 5), id_at(flow, 3), id_at(flow, 1)])
             )
    end

    test "16b: an effect inside a branch needs the branch's decision, not the branch's value" do
      source = """
      s = h()
      case s do
        :ok ->
          log(1)
          q = k()
          q
      end
      :done
      """

      flow = flow!(source)
      # The predicate sees each node's whole AST, so it matches the call itself,
      # not the case that holds it.
      slice = DataFlow.backward_slice(flow, DataFlow.sinks(flow, &match?({:log, _, _}, &1)))

      for line <- [1, 2, 4], do: assert(MapSet.member?(slice, id_at(flow, line)), "line #{line}")
      refute MapSet.member?(slice, id_at(flow, 5))
      refute MapSet.member?(slice, id_at(flow, 6))
    end

    test "17: with control dependence holds the with node (its steps and their right sides)" do
      flow = flow!("t = f()\nwith {:ok, a} <- g(t) do\n  a\nend")
      with_id = id_at(flow, 2)
      body_id = id_at(flow, 3)

      assert body_id in DataFlow.sinks(flow, @no_effects)
      slice = DataFlow.backward_slice(flow, [body_id])
      assert MapSet.member?(slice, with_id)
      assert MapSet.member?(slice, id_at(flow, 1))
      assert Macro.to_string(flow.nodes[with_id].ast) =~ "g(t)"
    end

    test "18: an unsliceable node is a sink under any predicate" do
      flow = flow!("Process.put(:k, 1)\n:ok")

      assert id_at(flow, 1) in DataFlow.sinks(flow, @no_effects)
    end

    test "backward_slice/2 refuses an unknown sink id" do
      flow = flow!("a = 1\na")

      assert_raise ArgumentError, fn -> DataFlow.backward_slice(flow, [[9]]) end
    end
  end

  describe "dead/2" do
    test "19: an unused pure binding is dead" do
      flow = flow!("t = String.upcase(s)\n:ok")

      assert DataFlow.dead(flow, @no_effects) == [id_at(flow, 1)]
    end

    test "20: positive control: the same binding feeding the result is not dead" do
      flow = flow!("t = String.upcase(s)\nt")

      assert DataFlow.dead(flow, @no_effects) == []
    end

    test "21: an effect is never dead; positive control without the predicate" do
      flow = flow!("Logger.info(s)\n:ok")
      logger? = &match?({{:., _, [{:__aliases__, _, [:Logger]}, _]}, _, _}, &1)

      assert DataFlow.dead(flow, logger?) == []
      assert DataFlow.dead(flow, @no_effects) == [id_at(flow, 1)]
    end

    test "22: an unsliceable node is never dead" do
      flow = flow!("receive do\n  m -> m\nend\n:ok")

      assert DataFlow.dead(flow, @no_effects) == []
    end

    test "the nodes of a dead branch are dead, sorted by line" do
      flow = flow!("case v do\n  :a ->\n    x = 1\n    x\nend\n:ok")

      assert DataFlow.dead(flow, @no_effects) == [id_at(flow, 1), id_at(flow, 3), id_at(flow, 4)]
    end
  end

  describe "regions/1" do
    test "23: a 3-statement run with one escaping variable is a region with its inputs" do
      flow = flow!("a = f(x)\nb = g(a)\nc = h(b)\nsave(c)")
      run = Enum.map(1..3, &id_at(flow, &1))

      assert %DataFlow.Region{
               inputs: [{:x, nil, :free}],
               output: {:var, {:c, nil, 0}},
               lines: 1..3//1
             } =
               Enum.find(DataFlow.regions(flow), &(&1.nodes == run))
    end

    test "24: a run with two escaping variables is not a region; each alone is" do
      flow = flow!("a = f(x)\nb = g(x)\nsave(a, b)")
      regions = DataFlow.regions(flow)
      runs = Enum.map(regions, & &1.nodes)

      refute [id_at(flow, 1), id_at(flow, 2)] in runs
      assert Enum.find(regions, &(&1.nodes == [id_at(flow, 1)])).output == {:var, k(:a, 0)}
      assert Enum.find(regions, &(&1.nodes == [id_at(flow, 2)])).output == {:var, k(:b, 0)}
      # The whole body consumes both inside; its one exit is the block's value.
      assert Enum.find(regions, &(length(&1.nodes) == 3)).output == :block_value
    end

    test "25: a run that ends the block and binds nothing used outside exits by the block value" do
      flow = flow!("a = f(x)\ng(a)")

      assert %DataFlow.Region{output: :block_value, inputs: [{:x, nil, :free}]} =
               Enum.find(DataFlow.regions(flow), &(&1.nodes == [id_at(flow, 1), id_at(flow, 2)]))
    end

    test "26: regions never cross blocks" do
      flow = flow!("case v do\n  :ok ->\n    a = f()\n    g(a)\nend")
      branch = id_at(flow, 1)
      regions = DataFlow.regions(flow)
      clause_block = branch ++ [:clause, 0]

      for region <- regions, id <- region.nodes, do: assert(flow.nodes[id].block == region.block)

      assert %DataFlow.Region{output: :block_value} =
               Enum.find(regions, &(&1.block == clause_block and length(&1.nodes) == 2))

      refute Enum.any?(
               regions,
               &(branch in &1.nodes and Enum.any?(&1.nodes, fn id -> id != branch end))
             )
    end
  end

  describe "orphans_if_removed/2" do
    test "27: removing a binding another node reads orphans it" do
      flow = flow!("x = f()\ng(x)")

      assert DataFlow.orphans_if_removed(flow, id_at(flow, 1)) == [k(:x, 0)]
    end

    test "28: a binding nothing reads orphans nothing" do
      flow = flow!("x = f()\ng(1)")

      assert DataFlow.orphans_if_removed(flow, id_at(flow, 1)) == []
    end

    test "29: removing a rebinding orphans that version only" do
      flow = flow!("x = 1\nx = x + 1\nx")

      assert DataFlow.orphans_if_removed(flow, id_at(flow, 2)) == [k(:x, 1)]
      assert DataFlow.orphans_if_removed(flow, id_at(flow, 1)) == [k(:x, 0)]
    end

    test "keys bound and read only inside the node are not orphaned" do
      flow = flow!("y = fn z -> z end\ny")

      assert DataFlow.orphans_if_removed(flow, id_at(flow, 1)) == [k(:y, 0)]
    end
  end

  describe "unsliceable forms" do
    @forms [
      {"receive do\n  m -> m\nend", :receive},
      {"m = receive do\n  m -> m\nend", :receive},
      {"Process.get(:k)", :process_dictionary},
      {"Process.put(:k, v)", :process_dictionary},
      {"Process.delete(:k)", :process_dictionary},
      {":erlang.get(:k)", :process_dictionary},
      {":erlang.put(:k, v)", :process_dictionary},
      {":erlang.erase(:k)", :process_dictionary},
      {"foo(Process.get(:k))", :process_dictionary},
      {":k |> Process.get()", :process_dictionary},
      {"case Process.get(:k) do\n  _ -> :ok\nend", :process_dictionary},
      {"Process.get_keys()", :process_dictionary},
      {":erlang.get_keys()", :process_dictionary},
      {"var!(x)", :var_bang},
      {"Code.eval_string(s, binding())", :binding}
    ]

    for {source, reason} <- @forms do
      test "30: #{inspect(source)} is flagged #{reason} on its line and is never dead" do
        flow = flow!("a = 1\n" <> unquote(source) <> "\n:ok")
        node = node_at(flow, 2)

        assert node.unsliceable == unquote(reason)
        assert node.line == 2
        refute node.id in DataFlow.dead(flow, @no_effects)
      end
    end

    test "31: positive control: Map.get is not unsliceable" do
      flow = flow!("a = 1\nMap.get(m, :k)\n:ok")

      assert node_at(flow, 2).unsliceable == nil
      assert node_at(flow, 2).id in DataFlow.dead(flow, @no_effects)
    end
  end

  describe "review-floor regressions (no expression wrongly dead)" do
    test "a = inside quote binds nothing in the clause" do
      flow = flow!("x = compute()\nast = quote do\n  x = 1\nend\n{ast, x}")

      assert DataFlow.dead(flow, @no_effects) == []
      assert node_at(flow, 2).binds == [k(:ast, 0)]
    end

    test "quote positive control: unquote reads the outer variable" do
      flow = flow!("x = compute()\nquote do\n  unquote(x) + 1\nend")

      assert node_at(flow, 2).uses == [k(:x, 0)]
      assert DataFlow.dead(flow, @no_effects) == []
    end

    test "for reduce: generators read the enclosing scope before the reducer pattern binds" do
      flow = flow!("list = f()\nfor x <- list, reduce: [] do\n  list -> [x | list]\nend")

      assert DataFlow.dead(flow, @no_effects) == []
      assert k(:list, 0) in node_at(flow, 2).uses
    end

    test "for with a literal [] body still reads its generators" do
      flow = flow!("y = f()\nfor x <- g(y), do: []")

      assert DataFlow.dead(flow, @no_effects) == []
      assert k(:y, 0) in node_at(flow, 2).uses
    end

    test "binding() reads every variable in scope" do
      flow = flow!("x = f()\nCode.eval_string(s, binding())")

      assert k(:x, 0) in node_at(flow, 2).uses
      assert DataFlow.dead(flow, @no_effects) == []
    end

    test "a refutable match is an assertion: a sink, never dead" do
      for source <- [
            "true = valid?(x)\n:ok",
            "{:ok, _} = parse(s)\n:ok",
            "[_] = list\n:ok",
            "{a, b} = pair\n:ok"
          ] do
        flow = flow!(source)

        assert node_at(flow, 1).refutable, source
        assert DataFlow.dead(flow, @no_effects) == [], source
      end
    end

    test "refutable positive control: a bare variable bind that nothing reads is dead" do
      flow = flow!("x = f()\n:ok")

      refute node_at(flow, 1).refutable
      assert DataFlow.dead(flow, @no_effects) == [id_at(flow, 1)]
    end

    test "try else clauses read the do value's scope of their own" do
      flow = flow!("try do\n  f()\nelse\n  v -> v\nend")
      try_node = node_at(flow, 1)

      assert flow.defs[k(:v, 0)] == try_node.id
      assert node_at(flow, 4).uses == [k(:v, 0)]
    end
  end

  describe "AC7 purity" do
    test "the data_flow modules call no IO, process, ETS or code-loading module" do
      impure = [File, IO, Process, Code, System, Port, Node, :ets, :persistent_term, :erlang]

      files = [
        "lib/anchor/domain/data_flow.ex" | Path.wildcard("lib/anchor/domain/data_flow/*.ex")
      ]

      assert length(files) == 6

      called =
        Map.new(files, fn file ->
          {file,
           file
           |> File.read!()
           |> Code.string_to_quoted!()
           |> DependencyAnalyzer.extract_call_dependencies()}
        end)

      for {file, modules} <- called,
          do: assert(modules -- impure == modules, "#{file} calls #{inspect(modules)}")

      # Positive control: the extraction sees the calls the modules do make.
      assert Macro in called["lib/anchor/domain/data_flow/forms.ex"]
      assert Map in called["lib/anchor/domain/data_flow/scope.ex"]
    end
  end
end
