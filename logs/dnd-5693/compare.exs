# DND-5693 Q5/Q6 (throwaway, CI only): reads suite_map.exs output.
#   elixir logs/dnd-5693/compare.exs shares <a.etf>
#   elixir logs/dnd-5693/compare.exs diff <a.etf> <b.etf>
#
# Mechanisms, each a pure function of one row {mfa, word, label, owner, origin}:
#   window : the window open at the call (the tcw at the call), as a time-free
#            version of today's rule; an even word credits nothing.
#   token  : seq_trace label alone.
#   spawn  : ownership by spawn ancestry alone.
#   hybrid : spawn ownership for a test-owned process; the label for anything else.

defmodule Spike.Mech do
  @moduledoc false
  def test_ref(windows, word) do
    case windows do
      %{^word => test} -> {test.module, test.name}
      _none -> {:unknown_word, word}
    end
  end

  def tests_of(windows, module) do
    for {_word, %{module: ^module} = test} <- windows, do: {test.module, test.name}
  end

  # Credit list and leak list of one row under one mechanism.
  def credit(:window, {_mfa, word, _label, _owner, _origin}, windows) do
    if rem(word, 2) == 1, do: {[test_ref(windows, word)], []}, else: {[], []}
  end

  def credit(:token, {_mfa, _word, :none, _owner, _origin}, _windows), do: {[], []}

  def credit(:token, {_mfa, word, label, _owner, _origin}, windows) when is_integer(label) do
    ref = test_ref(windows, label)
    {[ref], if(word > label, do: [ref], else: [])}
  end

  def credit(:token, {_mfa, _word, module, _owner, _origin}, windows), do: {tests_of(windows, module), []}

  def credit(:spawn, {_mfa, word, _label, {:test, owner}, _origin}, windows) do
    ref = test_ref(windows, owner)
    {[ref], if(word > owner, do: [ref], else: [])}
  end

  def credit(:spawn, {_mfa, _word, _label, {:module, module}, _origin}, windows) when is_atom(module) and module != :none,
    do: {tests_of(windows, module), []}

  def credit(:spawn, _row, _windows), do: {[], []}

  def credit(:hybrid, {_mfa, _word, _label, {:test, _}, _origin} = row, windows), do: credit(:spawn, row, windows)

  def credit(:hybrid, {_mfa, _word, _label, {:module, module}, _origin} = row, windows) when is_atom(module) and module != :none,
    do: credit(:spawn, row, windows)

  # Not test-owned: the label says whose request it handles; never a leak (R3).
  def credit(:hybrid, row, windows) do
    {credits, _leaks} = credit(:token, row, windows)
    {credits, []}
  end

  def outputs(mechanism, %{rows: rows, windows: windows}) do
    Enum.reduce(rows, {MapSet.new(), MapSet.new(), MapSet.new()}, fn {{mfa, _, _, _, _} = row, _count}, {map, leaks, ambient} ->
      {credits, leak_refs} = credit(mechanism, row, windows)
      map = Enum.reduce(credits, map, &MapSet.put(&2, {&1, mfa}))
      leaks = Enum.reduce(leak_refs, leaks, &MapSet.put(&2, {&1, mfa}))
      ambient = if credits == [], do: MapSet.put(ambient, mfa), else: ambient
      {map, leaks, ambient}
    end)
  end

  def class({_mfa, word, label, owner, _origin}) do
    case {owner, label} do
      {{:test, w}, ^w} -> :owned_label_agrees
      {{:test, _w}, :none} -> :owned_no_label
      {{:test, _w}, _other} -> :owned_label_disagrees
      {{:module, _m}, :none} -> :setup_all_no_label
      {{:module, _m}, _label} -> :setup_all_labelled
      {_unowned, :none} when word == 0 -> :unowned_no_label_before_any_test
      {_unowned, :none} -> :unowned_no_label_during_suite
      {_unowned, label} when is_integer(label) and word == label -> :unowned_label_in_its_window
      {_unowned, label} when is_integer(label) -> :unowned_label_past_its_window
      {_unowned, _module} -> :unowned_module_label
    end
  end
end

alias Spike.Mech

load = fn path -> path |> File.read!() |> :erlang.binary_to_term() end
say = fn text -> IO.puts("COMPARE " <> text) end

case System.argv() do
  ["shares", path] ->
    run = load.(path)
    say.("shares #{path} mode=#{run.mode} tests=#{map_size(run.windows)} rows=#{map_size(run.rows)} (calls are exact only in an every-call run)")
    total = run.rows |> Map.values() |> Enum.sum()

    run.rows
    |> Enum.group_by(fn {row, _count} -> Mech.class(row) end, fn {_row, count} -> count end)
    |> Enum.sort_by(fn {_class, counts} -> -Enum.sum(counts) end)
    |> Enum.each(fn {class, counts} ->
      calls = Enum.sum(counts)
      say.("SHARE #{class}: calls=#{calls} share=#{Float.round(calls / max(total, 1) * 100, 4)}% rows=#{length(counts)}")
    end)

    say.("SHARE total calls=#{total}")

    for mechanism <- [:window, :token, :spawn, :hybrid] do
      {map, leaks, ambient} = Mech.outputs(mechanism, run)
      attributed = run.rows |> Enum.filter(fn {row, _} -> elem(Mech.credit(mechanism, row, run.windows), 0) != [] end) |> Enum.map(&elem(&1, 1)) |> Enum.sum()

      say.(
        "MECH #{mechanism}: pairs=#{MapSet.size(map)} leak_pairs=#{MapSet.size(leaks)} ambient_functions=#{MapSet.size(ambient)} " <>
          "calls_attributed=#{attributed} share=#{Float.round(attributed / max(total, 1) * 100, 4)}%"
      )
    end

    # Every row that is not plain agreement, so each kind has a name.
    run.rows
    |> Enum.filter(fn {row, _} -> Mech.class(row) in [:owned_no_label, :owned_label_disagrees, :unowned_label_past_its_window, :unowned_label_in_its_window, :unowned_no_label_during_suite, :setup_all_no_label] end)
    |> Enum.group_by(fn {{_mfa, _word, _label, _owner, origin} = row, _count} -> {Mech.class(row), origin} end, fn {_row, count} -> count end)
    |> Enum.sort_by(fn {_key, counts} -> -Enum.sum(counts) end)
    |> Enum.take(40)
    |> Enum.each(fn {{class, origin}, counts} ->
      say.("KIND #{class} origin=#{inspect(origin, limit: 8)} calls=#{Enum.sum(counts)} rows=#{length(counts)}")
    end)

    {_map, leaks, _} = Mech.outputs(:hybrid, run)

    for {ref, mfa} <- leaks |> Enum.sort() |> Enum.take(60) do
      say.("LEAK hybrid #{inspect(ref)} #{inspect(mfa)}")
    end

    {_map, token_leaks, _} = Mech.outputs(:token, run)
    say.("LEAK sets token-only=#{MapSet.size(token_leaks)} hybrid=#{MapSet.size(leaks)} only_hybrid=#{MapSet.size(MapSet.difference(leaks, token_leaks))} only_token=#{MapSet.size(MapSet.difference(token_leaks, leaks))}")

  ["diff", a_path, b_path] ->
    a = load.(a_path)
    b = load.(b_path)
    say.("diff #{a_path}(#{a.mode}) #{b_path}(#{b.mode})")
    test_names = fn run -> run.windows |> Map.values() |> Enum.map(&{&1.module, &1.name}) |> Enum.sort() end
    say.("same tests in the same order of words: #{a.windows == b.windows}; same test set: #{test_names.(a) == test_names.(b)}")

    # A source for one (test, mfa) pair: the rows of that run that credit it.
    sources = fn run, mechanism, ref, mfa ->
      run.rows
      |> Map.keys()
      |> Enum.filter(fn {row_mfa, _, _, _, _} = row ->
        row_mfa == mfa and ref in elem(Mech.credit(mechanism, row, run.windows), 0)
      end)
      |> Enum.map(fn {_mfa, word, label, owner, origin} -> %{word: word, label: label, owner: owner, origin: origin} end)
      |> Enum.take(2)
    end

    for mechanism <- [:window, :token, :spawn, :hybrid] do
      {map_a, leaks_a, ambient_a} = Mech.outputs(mechanism, a)
      {map_b, leaks_b, ambient_b} = Mech.outputs(mechanism, b)
      only_a = MapSet.difference(map_a, map_b)
      only_b = MapSet.difference(map_b, map_a)

      canonical = fn map, leaks, ambient ->
        :crypto.hash(:sha256, :erlang.term_to_binary({Enum.sort(map), Enum.sort(leaks), Enum.sort(ambient)})) |> Base.encode16() |> binary_part(0, 16)
      end

      leak_diff = MapSet.size(MapSet.difference(leaks_a, leaks_b)) + MapSet.size(MapSet.difference(leaks_b, leaks_a))
      ambient_diff = MapSet.size(MapSet.difference(ambient_a, ambient_b)) + MapSet.size(MapSet.difference(ambient_b, ambient_a))

      say.(
        "MECH #{mechanism}: pairs a=#{MapSet.size(map_a)} b=#{MapSet.size(map_b)} only_a=#{MapSet.size(only_a)} only_b=#{MapSet.size(only_b)} " <>
          "leak_diff=#{leak_diff} (a=#{MapSet.size(leaks_a)} b=#{MapSet.size(leaks_b)}) ambient_diff=#{ambient_diff} " <>
          "canonical a=#{canonical.(map_a, leaks_a, ambient_a)} b=#{canonical.(map_b, leaks_b, ambient_b)}"
      )

      if mechanism in [:hybrid, :token, :spawn] do
        for {ref, mfa} <- only_a |> Enum.sort() |> Enum.take(25) do
          say.("DIFF #{mechanism} only_a #{inspect(ref)} #{inspect(mfa)} source=#{inspect(sources.(a, mechanism, ref, mfa), limit: 12)}")
        end

        for {ref, mfa} <- only_b |> Enum.sort() |> Enum.take(25) do
          say.("DIFF #{mechanism} only_b #{inspect(ref)} #{inspect(mfa)} source=#{inspect(sources.(b, mechanism, ref, mfa), limit: 12)}")
        end

        for pair <- MapSet.difference(leaks_a, leaks_b) |> Enum.sort() |> Enum.take(15), do: say.("DIFF #{mechanism} leak_only_a #{inspect(pair)}")
        for pair <- MapSet.difference(leaks_b, leaks_a) |> Enum.sort() |> Enum.take(15), do: say.("DIFF #{mechanism} leak_only_b #{inspect(pair)}")
        for mfa <- MapSet.difference(ambient_a, ambient_b) |> Enum.sort() |> Enum.take(15), do: say.("DIFF #{mechanism} ambient_only_a #{inspect(mfa)}")
        for mfa <- MapSet.difference(ambient_b, ambient_a) |> Enum.sort() |> Enum.take(15), do: say.("DIFF #{mechanism} ambient_only_b #{inspect(mfa)}")
      end
    end

    # Positive control: this comparison sees a one-pair change.
    {map_a, _, _} = Mech.outputs(:hybrid, a)
    dropped = map_a |> Enum.take(1) |> MapSet.new()
    say.("CONTROL dropping one pair from a is seen: #{MapSet.size(MapSet.difference(map_a, MapSet.difference(map_a, dropped))) == 1}")
end
