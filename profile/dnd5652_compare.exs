alias Anchor.Domain.Sabotage.CoverageMap
load = fn path -> path |> File.read!() |> :erlang.binary_to_term() end
[a_path, b_path] = System.argv()
a = load.(a_path)
b = load.(b_path)
say = fn text -> IO.puts("EQ " <> text) end
key = fn t -> {t.file, t.line, t.name} end
am = Map.new(a.tests, &{key.(&1), &1.functions})
bm = Map.new(b.tests, &{key.(&1), &1.functions})
say.("first_hit tests=#{map_size(am)} every_call tests=#{map_size(bm)} only_in_first_hit=#{length(Map.keys(am) -- Map.keys(bm))} only_in_every_call=#{length(Map.keys(bm) -- Map.keys(am))}")
diffs =
  for k <- Map.keys(am), Map.has_key?(bm, k), am[k] != bm[k] do
    {k, am[k] -- bm[k], bm[k] -- am[k]}
  end
say.("tests with differing function sets=#{length(diffs)} of #{map_size(am)}")
for {k, only_a, only_b} <- Enum.take(diffs, 20), do: say.("DIFF #{inspect(k)} only_first_hit=#{inspect(only_a)} only_every_call=#{inspect(only_b)}")
say.("functions total first_hit=#{am |> Map.values() |> Enum.map(&length/1) |> Enum.sum()} every_call=#{bm |> Map.values() |> Enum.map(&length/1) |> Enum.sum()}")
say.("outside_windows first_hit=#{a.outside_windows} every_call=#{b.outside_windows}; late first_hit=#{a.late_events} every_call=#{b.late_events}")
la = a.window_leaks |> Enum.map(&{&1.from, &1.to}) |> MapSet.new()
lb = b.window_leaks |> Enum.map(&{&1.from, &1.to}) |> MapSet.new()
say.("leak pairs first_hit=#{MapSet.size(la)} every_call=#{MapSet.size(lb)} only_first_hit=#{MapSet.size(MapSet.difference(la, lb))} only_every_call=#{MapSet.size(MapSet.difference(lb, la))}")
say.("leak calls first_hit=#{a.window_leaks |> Enum.map(& &1.calls) |> Enum.sum()} every_call=#{b.window_leaks |> Enum.map(& &1.calls) |> Enum.sum()}")

fmt = fn l -> "#{inspect(Enum.map(l.from, &{&1.file, &1.line}))} -> #{l.to.file}:#{l.to.line} calls=#{l.calls}" end
for l <- a.window_leaks, do: say.("LEAK first_hit #{fmt.(l)}")
for l <- b.window_leaks, do: say.("LEAK every_call #{fmt.(l)}")
