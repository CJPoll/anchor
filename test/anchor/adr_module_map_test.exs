defmodule Anchor.AdrModuleMapTest do
  # DND-5620: ADR 001's module map ("How this maps to Anchor") lists every
  # module of lib/, each under the bucket .anchor.yml classifies it into. A
  # module added without a row, or a row whose bucket disagrees with the
  # config, fails here and names the module, so the map cannot drift.
  #
  # It reads the compiled :anchor application's modules and the source file
  # each was compiled from (`module_info(:compile)`: Anchor's own modules,
  # already loaded by the suite), the ADR's tables, and .anchor.yml through
  # the real loader.
  #
  # Sabotage record: ../sabotage_records/module_map-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Domain.Classification

  @adr "adrs/001-five-bucket-architecture.md"

  # The ADR's bucket words, as the Bucket column writes them, to the
  # .anchor.yml bucket names.
  @buckets [
    {"framework", "framework"},
    {"side effect", "adapters"},
    {"domain", "domain"},
    {"manager", "managers"}
  ]

  describe "map_rows/1 (the reader this test relies on)" do
    test "reads the module column's code spans and the bucket, from every table in the section" do
      adr = """
      ## Context

      | Module | Bucket | Why |
      |---|---|---|
      | `Outside.Section` | Domain | not read |

      ## How this maps to Anchor

      | Module | Bucket | Why |
      |---|---|---|
      | `A.B` (e.g. `Ignored`), `A.C.*` | Side Effect (port) | x |
      | Orchestration with no module | Manager | y |

      #### Amendment

      | Module | Bucket | Why |
      |---|---|---|
      | `%A.D{}` struct | Domain (data) | z |

      ## Examples

      | `After.Section` | Domain | not read |
      """

      assert map_rows(adr) == [
               {"A.B", "adapters"},
               {"A.C.*", "adapters"},
               {"A.D", "domain"}
             ]
    end
  end

  describe "covering_row/2" do
    @rows [{"A.B", "domain"}, {"A.*", "managers"}, {"A.B.*", "adapters"}]

    test "an exact row wins; else the longest namespace row; else none" do
      assert covering_row("A.B", @rows) == {"A.B", "domain"}
      assert covering_row("A.B.C", @rows) == {"A.B.*", "adapters"}
      assert covering_row("A.X", @rows) == {"A.*", "managers"}
      assert covering_row("A", @rows) == nil
      assert covering_row("AB.C", @rows) == nil
    end
  end

  describe "problem/4" do
    test "a row whose bucket disagrees with .anchor.yml, and a module with no row, are each named" do
      {:ok, config} = ConfigFile.load()
      source = "lib/anchor/managers/explain.ex"
      arch = config.architecture

      assert problem(
               Anchor.Managers.Explain,
               source,
               [{"Anchor.Managers.Explain", "managers"}],
               arch
             ) ==
               nil

      assert problem(
               Anchor.Managers.Explain,
               source,
               [{"Anchor.Managers.Explain", "domain"}],
               arch
             ) ==
               "  Anchor.Managers.Explain (#{source}): row `Anchor.Managers.Explain` says domain; " <>
                 ".anchor.yml says managers"

      assert problem(Anchor.Managers.Explain, source, [], arch) ==
               "  Anchor.Managers.Explain (#{source}): no row; .anchor.yml buckets it managers"
    end
  end

  test "every lib module has a row in ADR 001's module map, under the bucket .anchor.yml gives it" do
    rows = map_rows(File.read!(@adr))
    {:ok, config} = ConfigFile.load()
    root = File.cwd!()

    problems =
      for {module, source} <- lib_modules(root),
          problem = problem(module, source, rows, config.architecture),
          do: problem

    assert problems == [],
           "ADR 001's module map (#{@adr}, \"How this maps to Anchor\") is out of date. " <>
             "Fix: add a row for each module below to the DND-5620 amendment's table, with " <>
             "the bucket .anchor.yml classifies it into:\n" <> Enum.join(problems, "\n")
  end

  defp problem(module, source, rows, arch) do
    name = inspect(module)
    want = Classification.classify_planned(source, module, arch).definite

    case covering_row(name, rows) do
      nil -> "  #{name} (#{source}): no row; .anchor.yml buckets it #{want || "nowhere"}"
      {_row, ^want} -> nil
      {row, got} -> "  #{name} (#{source}): row `#{row}` says #{got}; .anchor.yml says #{want}"
    end
  end

  # Every module of the compiled :anchor application whose source is under
  # lib/, with that source relative to the project root.
  defp lib_modules(root) do
    for module <- Application.spec(:anchor, :modules),
        source = module.module_info(:compile)[:source] |> to_string(),
        relative = Path.relative_to(source, root),
        String.starts_with?(relative, "lib/"),
        do: {module, relative}
  end

  defp covering_row(name, rows) do
    Enum.find(rows, fn {row, _bucket} -> row == name end) ||
      rows
      |> Enum.filter(fn {row, _bucket} ->
        String.ends_with?(row, ".*") and String.starts_with?(name, String.trim_trailing(row, "*"))
      end)
      |> Enum.max_by(fn {row, _bucket} -> String.length(row) end, fn -> nil end)
  end

  defp map_rows(adr) do
    adr
    |> section("## How this maps to Anchor")
    |> String.split("\n")
    |> Enum.flat_map(&row/1)
  end

  defp section(text, heading) do
    [_before, rest] = String.split(text, heading <> "\n", parts: 2)
    rest |> String.split(~r/^## /m, parts: 2) |> hd()
  end

  defp row("| Module |" <> _header), do: []
  defp row("|---" <> _rule), do: []

  defp row("|" <> _ = line) do
    [_lead, module_column, bucket_column | _rest] = String.split(line, "|")
    bucket = bucket(bucket_column)

    module_column
    |> String.replace(~r/\(e\.g\.[^)]*\)|\(earlier[^)]*\)/, "")
    |> then(&Regex.scan(~r/`%?([A-Z][\w.]*(?:\.\*)?)(?:\{\})?`/, &1, capture: :all_but_first))
    |> Enum.map(fn [module] -> {module, bucket} end)
  end

  defp row(_other_line), do: []

  defp bucket(column) do
    text = column |> String.trim() |> String.downcase()

    Enum.find_value(@buckets, fn {word, name} -> String.starts_with?(text, word) && name end) ||
      flunk(
        "ADR 001 bucket #{inspect(column)} is none of #{inspect(Enum.map(@buckets, &elem(&1, 0)))}"
      )
  end
end
