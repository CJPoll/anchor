defmodule Anchor.Domain.ArchitectureChecksNothingTest do
  # DND-5437: the `architecture:` section of `.anchor.yml`, as one class: every
  # way the section could check nothing, or less than it says, is refused at
  # load, and the positive rows load. In the style of
  # `rule_checks_nothing_test.exs`.
  #
  # ONE table per key path the parser reads (`Architecture.key_paths/0`, `[]`
  # standing for a list index). A `:refused` row must fail the load with
  # `{:invalid_config, message}` whose message STARTS with the key path given
  # (0-based indexes, as YAML shows them) and carries a `Fix:` sentence. An
  # `:accepted` row must load.
  #
  # Extension rule (enforced by "every key path has a table"): a new key of
  # `architecture:` MUST add a table with at least one refused and one
  # accepted row. That test fails until it does.
  #
  # Sabotage record: ../../sabotage_records/architecture-20261103-dnd_5437.md
  # The Config wiring (the top-level key, the section parsed at all):
  #   ../../sabotage_records/config-20261103-dnd_5437.md
  use ExUnit.Case, async: true

  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Architecture.Bucket

  @bucket %{
    "name" => "domain",
    "role" => "domain",
    "select" => [%{"paths" => ["lib/**/domain/**/*.ex"]}]
  }

  @minimal %{
    "contexts" => %{"depth" => 2},
    "buckets" => [@bucket],
    "calls" => %{"domain" => ["domain"]}
  }

  @managers %{
    "name" => "managers",
    "role" => "managers",
    "select" => [%{"pattern" => "*.Managers.*"}]
  }

  @two_buckets %{
    @minimal
    | "buckets" => [@bucket, @managers],
      "calls" => %{"domain" => ["domain"], "managers" => ["managers", "domain"]}
  }

  for key_path <- Architecture.key_paths() do
    @tag key_path: key_path
    test "#{key_path}: every refusal is refused with its key path and Fix:, positives load",
         %{key_path: key_path} do
      failures =
        key_path |> table() |> Enum.map(&row_failure(key_path, &1)) |> Enum.reject(&is_nil/1)

      assert failures == [], Enum.join(failures, "\n")
    end
  end

  test "every key path has a table with a refused row and an accepted row" do
    for key_path <- Architecture.key_paths() do
      expectations = key_path |> table() |> Enum.map(&elem(&1, 2))

      assert :accepted in expectations, "#{key_path}: no accepted row"

      assert Enum.any?(expectations, &match?({:refused, _}, &1)),
             "#{key_path}: no refused row"
    end
  end

  test "the key paths are exactly the documented keys" do
    assert Architecture.key_paths() ==
             Enum.sort(~w(
               architecture buckets calls contexts effects extract_pure_regions_from interfaces
               roots contexts.depth buckets[].infer buckets[].min_modules buckets[].name
               buckets[].role buckets[].select buckets[].select[].behaviour
               buckets[].select[].exports_function buckets[].select[].paths
               buckets[].select[].pattern buckets[].select[].uses_module interfaces.buckets
               interfaces.exports roots[].behaviour roots[].exports_function roots[].paths
               roots[].pattern roots[].uses_module
             ))
  end

  describe "a config with no architecture: section (AC3)" do
    test "loads as before, with architecture: nil" do
      assert %Config{rules: [], architecture: nil} = Config.parse_config(%{"rules" => []})
    end

    test "a rules-only config with rules loads its rules unchanged" do
      rule = %{"type" => "single_control_flow", "paths" => ["lib/**/*.ex"], "recursive" => true}

      assert %Config{rules: [%{type: :single_control_flow, index: 1}], architecture: nil} =
               Config.parse_config(%{"rules" => [rule]})
    end

    test "architecture: still needs rules: beside it" do
      assert {:error, {:invalid_config, reason}} =
               Config.parse_config(%{"architecture" => @minimal})

      assert reason =~ "rules"
    end
  end

  describe "the parsed struct" do
    test "a minimal section fills the defaults" do
      assert %Config{architecture: architecture} = Config.parse_config(doc(@minimal))

      assert architecture == %Architecture{
               context_depth: 2,
               buckets: [
                 %Bucket{
                   name: "domain",
                   role: :domain,
                   selectors: [{:paths, ["lib/**/domain/**/*.ex"]}],
                   min_modules: 1,
                   infer: true
                 }
               ],
               calls: %{"domain" => [{"domain", :any}]},
               interface_buckets: [],
               interface_exports: [],
               effects: [],
               roots: [],
               extract_pure_regions_from: [:managers, :framework]
             }
    end

    test "bucket/2 and bucket_names/1 read the buckets in file order" do
      assert %Config{architecture: architecture} = Config.parse_config(doc(@two_buckets))

      assert Architecture.bucket_names(architecture) == ["domain", "managers"]
      assert %Bucket{role: :managers} = Architecture.bucket(architecture, "managers")
      assert Architecture.bucket(architecture, "nope") == nil
    end

    test "roles/0 are the five roles of ADR 001" do
      assert Architecture.roles() == [:adapters, :domain, :framework, :managers, :ui]
    end

    test "Architecture.parse/1 returns the struct on its own, outside a config" do
      assert {:ok, %Architecture{context_depth: 2}} = Architecture.parse(@minimal)

      assert {:error, {:invalid_config, "architecture is not a mapping" <> _}} =
               Architecture.parse([])
    end
  end

  # AC1: the worked example of the shared contract, section 3.1. The contract's
  # example lists calls rows for ui, adapters and managers but defines only the
  # domain and framework buckets, so as printed it is refused ("a row for an
  # unknown bucket"). The three buckets are added here, one per remaining role.
  describe "the worked example (shared contract 3.1)" do
    @worked_example """
    rules: []
    architecture:
      contexts:
        depth: 2
      buckets:
        - name: domain
          role: domain
          select:
            - paths: ["apps/*/lib/**/domain/**/*.ex"]
          min_modules: 178
          infer: true
        - name: framework
          role: framework
          select:
            - paths: ["apps/*/lib/**/framework/**/*.ex"]
            - uses_module: GenServer
            - behaviour: Supervisor
            - exports_function: "__aggregate__/0"
            - pattern: "Mix.Tasks.*"
        - name: ui
          role: ui
          select:
            - paths: ["apps/*/lib/**/ui/**/*.ex"]
        - name: adapters
          role: adapters
          select:
            - paths: ["apps/*/lib/**/adapters/**/*.ex"]
        - name: managers
          role: managers
          select:
            - paths: ["apps/*/lib/**/managers/**/*.ex"]
      calls:
        framework: [framework, ui, domain, managers]
        ui: [ui, domain]
        adapters: [adapters, domain, "managers:other_context"]
        domain: [domain]
        managers: [managers, adapters, domain]
      interfaces:
        buckets: [managers]
        exports: []
      effects: ["Req", ":gen_tcp.connect"]
      roots:
        - pattern: "Mix.Tasks.*"
      extract_pure_regions_from: [managers, framework]
    """

    test "parses into %Architecture{} with every field populated" do
      {:ok, document} = YamlElixir.read_from_string(@worked_example)

      assert %Config{architecture: architecture} = Config.parse_config(document)

      paths = fn bucket -> [{:paths, ["apps/*/lib/**/#{bucket}/**/*.ex"]}] end

      assert architecture == %Architecture{
               context_depth: 2,
               buckets: [
                 %Bucket{
                   name: "domain",
                   role: :domain,
                   selectors: paths.("domain"),
                   min_modules: 178
                 },
                 %Bucket{
                   name: "framework",
                   role: :framework,
                   selectors:
                     paths.("framework") ++
                       [
                         {:uses_module, GenServer},
                         {:behaviour, Supervisor},
                         {:exports_function, {:__aggregate__, 0}},
                         {:pattern, "Mix.Tasks.*"}
                       ]
                 },
                 %Bucket{name: "ui", role: :ui, selectors: paths.("ui")},
                 %Bucket{name: "adapters", role: :adapters, selectors: paths.("adapters")},
                 %Bucket{name: "managers", role: :managers, selectors: paths.("managers")}
               ],
               calls: %{
                 "framework" => [
                   {"framework", :any},
                   {"ui", :any},
                   {"domain", :any},
                   {"managers", :any}
                 ],
                 "ui" => [{"ui", :any}, {"domain", :any}],
                 "adapters" => [
                   {"adapters", :any},
                   {"domain", :any},
                   {"managers", :other_context}
                 ],
                 "domain" => [{"domain", :any}],
                 "managers" => [{"managers", :any}, {"adapters", :any}, {"domain", :any}]
               },
               interface_buckets: ["managers"],
               interface_exports: [],
               effects: ["Req", ":gen_tcp.connect"],
               roots: [{:pattern, "Mix.Tasks.*"}],
               extract_pure_regions_from: [:managers, :framework]
             }
    end
  end

  # --- the tables ---------------------------------------------------------

  defp table("architecture") do
    [
      {"positive: architecture: beside rules: []", doc(@minimal), :accepted},
      {"positive: no architecture: at all", %{"rules" => []}, :accepted},
      {"architectur: misspelt is an unknown top-level key",
       %{"rules" => [], "architectur" => @minimal}, {:refused, "unknown top-level key"}},
      {"not a mapping", doc(["buckets"]), {:refused, "architecture is not a mapping"}},
      {"null", doc(nil), {:refused, "architecture is not a mapping"}},
      {"unknown key bucket", doc(Map.put(@minimal, "bucket", [])),
       {:refused, ~s|architecture has unknown key(s) "bucket"|}}
    ]
  end

  defp table("contexts") do
    [
      {"positive: contexts with depth", doc(@minimal), :accepted},
      {"missing", doc(Map.delete(@minimal, "contexts")), {:refused, "architecture.contexts"}},
      {"not a mapping", doc(%{@minimal | "contexts" => 2}), {:refused, "architecture.contexts"}},
      {"unknown key dept", doc(%{@minimal | "contexts" => %{"depth" => 2, "dept" => 2}}),
       {:refused, "architecture.contexts has unknown key"}}
    ]
  end

  defp table("contexts.depth") do
    with_depth = fn depth -> doc(%{@minimal | "contexts" => %{"depth" => depth}}) end

    [
      {"positive: 1", with_depth.(1), :accepted},
      {"positive: 3", with_depth.(3), :accepted},
      {"missing", doc(%{@minimal | "contexts" => %{}}),
       {:refused, "architecture.contexts.depth is missing"}},
      {"0", with_depth.(0), {:refused, "architecture.contexts.depth"}},
      {"-1", with_depth.(-1), {:refused, "architecture.contexts.depth"}},
      {~s("2"), with_depth.("2"), {:refused, "architecture.contexts.depth"}},
      {"1.5", with_depth.(1.5), {:refused, "architecture.contexts.depth"}}
    ]
  end

  defp table("buckets") do
    [
      {"positive: one bucket", doc(@minimal), :accepted},
      {"positive: two buckets", doc(@two_buckets), :accepted},
      {"missing", doc(Map.delete(@minimal, "buckets")), {:refused, "architecture.buckets"}},
      {"[]", doc(%{@minimal | "buckets" => []}), {:refused, "architecture.buckets"}},
      {"not a list", doc(%{@minimal | "buckets" => @bucket}), {:refused, "architecture.buckets"}},
      {"an entry that is not a mapping", doc(%{@minimal | "buckets" => ["domain"]}),
       {:refused, "architecture.buckets[0] is not a mapping"}},
      {"unknown bucket key", with_bucket(Map.put(@bucket, "selct", [])),
       {:refused, ~s|architecture.buckets[0] has unknown key(s) "selct"|}}
    ]
  end

  defp table("buckets[].name") do
    [
      {"positive: domain", doc(@minimal), :accepted},
      {"positive: my_bucket", with_bucket(%{@bucket | "name" => "my_bucket"}, "my_bucket"),
       :accepted},
      {"missing", with_bucket(Map.delete(@bucket, "name")),
       {:refused, "architecture.buckets[0].name"}},
      {"uppercase Domain", with_bucket(%{@bucket | "name" => "Domain"}, "Domain"),
       {:refused, "architecture.buckets[0].name"}},
      {"blank", with_bucket(%{@bucket | "name" => ""}, ""),
       {:refused, "architecture.buckets[0].name"}},
      {"digits", with_bucket(%{@bucket | "name" => "layer2"}, "layer2"),
       {:refused, "architecture.buckets[0].name"}},
      {"duplicate", doc(%{@minimal | "buckets" => [@bucket, @bucket]}),
       {:refused, ~s(architecture.buckets names the bucket "domain" more than once)}}
    ]
  end

  defp table("buckets[].role") do
    accepted =
      for role <- ~w(framework ui adapters domain managers) do
        {"positive: #{role}", with_bucket(%{@bucket | "role" => role}), :accepted}
      end

    accepted ++
      [
        {"missing", with_bucket(Map.delete(@bucket, "role")),
         {:refused, "architecture.buckets[0].role"}},
        {"service", with_bucket(%{@bucket | "role" => "service"}),
         {:refused, "architecture.buckets[0].role"}},
        {"Domain (case)", with_bucket(%{@bucket | "role" => "Domain"}),
         {:refused, "architecture.buckets[0].role"}}
      ]
  end

  defp table("buckets[].select") do
    [
      {"positive: two entries",
       with_bucket(%{@bucket | "select" => [%{"paths" => ["lib/a.ex"]}, %{"pattern" => "A.*"}]}),
       :accepted},
      {"missing", with_bucket(Map.delete(@bucket, "select")),
       {:refused, "architecture.buckets[0].select"}},
      {"[]", with_bucket(%{@bucket | "select" => []}),
       {:refused, "architecture.buckets[0].select"}},
      {"not a list", with_bucket(%{@bucket | "select" => %{"paths" => ["lib/a.ex"]}}),
       {:refused, "architecture.buckets[0].select"}},
      {"an entry with no selector key", with_bucket(%{@bucket | "select" => [%{}]}),
       {:refused, "architecture.buckets[0].select[0] names no selector"}},
      {"an entry that is not a mapping", with_bucket(%{@bucket | "select" => ["lib/a.ex"]}),
       {:refused, "architecture.buckets[0].select[0] is not a mapping"}},
      {"an entry with two selector keys",
       with_bucket(%{@bucket | "select" => [%{"paths" => ["lib/a.ex"], "pattern" => "A.*"}]}),
       {:refused, "architecture.buckets[0].select[0] names 2 selectors (paths, pattern)"}},
      {"an unknown selector key",
       with_bucket(%{@bucket | "select" => [%{"path" => ["lib/a.ex"]}]}),
       {:refused, ~s|architecture.buckets[0].select[0] has unknown key(s) "path"|}},
      {"the second entry is the bad one",
       with_bucket(%{@bucket | "select" => [%{"pattern" => "A.*"}, %{"pattern" => "*"}]}),
       {:refused, "architecture.buckets[0].select[1].pattern"}}
    ]
  end

  defp table("buckets[].select[]." <> key) do
    selector_rows(key, fn entry -> with_bucket(%{@bucket | "select" => [entry]}) end)
    |> Enum.map(fn {label, document, expected} ->
      {label, document, prefix(expected, "architecture.buckets[0].select[0]")}
    end)
  end

  defp table("buckets[].min_modules") do
    with_floor = fn floor -> with_bucket(Map.put(@bucket, "min_modules", floor)) end

    [
      {"positive: absent (default 1)", doc(@minimal), :accepted},
      {"positive: 178", with_floor.(178), :accepted},
      {"0", with_floor.(0),
       {:refused, "architecture.buckets[0].min_modules must be a positive integer, got: 0"}},
      {"-3", with_floor.(-3), {:refused, "architecture.buckets[0].min_modules"}},
      {~s("5"), with_floor.("5"), {:refused, "architecture.buckets[0].min_modules"}},
      {"null", with_floor.(nil), {:refused, "architecture.buckets[0].min_modules"}}
    ]
  end

  defp table("buckets[].infer") do
    with_infer = fn infer -> with_bucket(Map.put(@bucket, "infer", infer)) end

    [
      {"positive: absent (true)", doc(@minimal), :accepted},
      {"positive: false", with_infer.(false), :accepted},
      {~s("yes"), with_infer.("yes"), {:refused, "architecture.buckets[0].infer"}},
      {"null", with_infer.(nil), {:refused, "architecture.buckets[0].infer"}}
    ]
  end

  defp table("calls") do
    with_calls = fn calls -> doc(%{@two_buckets | "calls" => calls}) end
    managers_row = fn row -> with_calls.(%{"domain" => ["domain"], "managers" => row}) end

    [
      {"positive: a [] row", managers_row.([]), :accepted},
      {"positive: plain names", managers_row.(["managers", "domain"]), :accepted},
      {"positive: both suffixes",
       managers_row.(["domain:same_context", "managers:other_context"]), :accepted},
      {"missing", doc(Map.delete(@minimal, "calls")), {:refused, "architecture.calls"}},
      {"not a mapping", with_calls.(["domain"]), {:refused, "architecture.calls"}},
      {"a row for an unknown bucket",
       with_calls.(%{"domain" => [], "managers" => [], "ui" => ["domain"]}),
       {:refused, ~s(architecture.calls has a row for "ui")}},
      {"a bucket with no row", with_calls.(%{"domain" => ["domain"]}),
       {:refused, ~s(architecture.calls has no row for bucket "managers")}},
      {"a null row (YAML `managers:`)", managers_row.(nil),
       {:refused, "architecture.calls.managers must be a list"}},
      {"a row that is not a list", managers_row.("domain"),
       {:refused, "architecture.calls.managers must be a list"}},
      {"an unknown target bucket", managers_row.(["domain", "ui"]),
       {:refused, ~s(architecture.calls.managers[1] names "ui")}},
      {"an unknown scope suffix", managers_row.(["domain:elsewhere"]),
       {:refused, ~s(architecture.calls.managers[0] names "domain:elsewhere")}},
      {"a suffix on an unknown bucket", managers_row.(["ui:same_context"]),
       {:refused, ~s(architecture.calls.managers[0] names "ui")}},
      {"a target that is not a string", managers_row.([1]),
       {:refused, "architecture.calls.managers[0]"}}
    ]
  end

  defp table("interfaces") do
    with_interfaces = fn interfaces -> doc(Map.put(@two_buckets, "interfaces", interfaces)) end

    [
      {"positive: absent", doc(@two_buckets), :accepted},
      {"positive: empty mapping", with_interfaces.(%{}), :accepted},
      {"not a mapping", with_interfaces.(["managers"]), {:refused, "architecture.interfaces"}},
      {"unknown key bucket", with_interfaces.(%{"bucket" => ["managers"]}),
       {:refused, ~s|architecture.interfaces has unknown key(s) "bucket"|}}
    ]
  end

  defp table("interfaces.buckets") do
    with_buckets = fn buckets ->
      doc(Map.put(@two_buckets, "interfaces", %{"buckets" => buckets}))
    end

    [
      {"positive: [managers]", with_buckets.(["managers"]), :accepted},
      {"positive: []", with_buckets.([]), :accepted},
      {"an unknown bucket", with_buckets.(["managers", "services"]),
       {:refused, ~s(architecture.interfaces.buckets[1] names "services")}},
      {"not a list", with_buckets.("managers"), {:refused, "architecture.interfaces.buckets"}}
    ]
  end

  defp table("interfaces.exports") do
    with_exports = fn exports ->
      doc(Map.put(@two_buckets, "interfaces", %{"exports" => exports}))
    end

    [
      {"positive: an exact name", with_exports.(["MyApp.Accounts"]), :accepted},
      {"positive: []", with_exports.([]), :accepted},
      {"a glob", with_exports.(["MyApp.*"]), {:refused, "architecture.interfaces.exports[0]"}},
      {"a match-all glob", with_exports.(["*"]),
       {:refused, "architecture.interfaces.exports[0]"}},
      {"an Erlang module", with_exports.([":ets"]),
       {:refused, "architecture.interfaces.exports[0]"}},
      {"blank", with_exports.(["MyApp.A", "  "]),
       {:refused, "architecture.interfaces.exports[1]"}},
      {"lower case", with_exports.(["myapp.accounts"]),
       {:refused, "architecture.interfaces.exports[0]"}},
      {"not a list", with_exports.("MyApp.Accounts"),
       {:refused, "architecture.interfaces.exports"}}
    ]
  end

  defp table("effects") do
    with_effects = fn effects -> doc(Map.put(@minimal, "effects", effects)) end

    [
      {"positive: Elixir module, Erlang function, function with arity",
       with_effects.(["Req", ":gen_tcp.connect", "File.write!/2"]), :accepted},
      {"positive: an Erlang module", with_effects.([":gen_tcp"]), :accepted},
      {"positive: []", with_effects.([]), :accepted},
      {~s("Req."), with_effects.(["Req."]), {:refused, "architecture.effects[0]"}},
      {~s("Mod.fun/x"), with_effects.(["Req", "Mod.fun/x"]),
       {:refused, "architecture.effects[1]"}},
      {"blank", with_effects.([""]), {:refused, "architecture.effects[0]"}},
      {"a glob", with_effects.(["Req.*"]), {:refused, "architecture.effects[0]"}},
      {"not a string", with_effects.([1]), {:refused, "architecture.effects[0]"}},
      {"not a list", with_effects.("Req"), {:refused, "architecture.effects"}}
    ]
  end

  defp table("roots") do
    with_roots = fn roots -> doc(Map.put(@minimal, "roots", roots)) end

    [
      {"positive: a pattern", with_roots.([%{"pattern" => "Mix.Tasks.*"}]), :accepted},
      {"positive: []", with_roots.([]), :accepted},
      {"an entry with two selector keys",
       with_roots.([%{"pattern" => "Mix.Tasks.*", "paths" => ["lib/mix/**/*.ex"]}]),
       {:refused, "architecture.roots[0] names 2 selectors"}},
      {"an entry with none", with_roots.([%{}]),
       {:refused, "architecture.roots[0] names no selector"}},
      {"not a list", with_roots.(%{"pattern" => "Mix.Tasks.*"}), {:refused, "architecture.roots"}}
    ]
  end

  defp table("roots[]." <> key) do
    selector_rows(key, fn entry -> doc(Map.put(@minimal, "roots", [entry])) end)
    |> Enum.map(fn {label, document, expected} ->
      {label, document, prefix(expected, "architecture.roots[0]")}
    end)
  end

  defp table("extract_pure_regions_from") do
    with_regions = fn regions -> doc(Map.put(@minimal, "extract_pure_regions_from", regions)) end

    [
      {"positive: []", with_regions.([]), :accepted},
      {"positive: [managers]", with_regions.(["managers"]), :accepted},
      {"positive: absent (managers, framework)", doc(@minimal), :accepted},
      {"services", with_regions.(["managers", "services"]),
       {:refused, "architecture.extract_pure_regions_from[1]"}},
      {"not a list", with_regions.("managers"),
       {:refused, "architecture.extract_pure_regions_from"}}
    ]
  end

  # The rows of one selector key, built by `place` into a document. Refused
  # fragments are relative to the entry (`.paths`, or "" for the entry).
  defp selector_rows("paths", place) do
    [
      {"positive: a recursive glob", place.(%{"paths" => ["lib/**/domain/**/*.ex"]}), :accepted},
      {"[]", place.(%{"paths" => []}), {:refused, ".paths"}},
      {~s([""]), place.(%{"paths" => [""]}), {:refused, ".paths"}},
      {"a string, not a list", place.(%{"paths" => "lib/a.ex"}), {:refused, ".paths"}},
      {"a non-string entry", place.(%{"paths" => ["lib/a.ex", 1]}), {:refused, ".paths"}},
      {~s(a match-all ["**"]), place.(%{"paths" => ["**"]}), {:refused, ".paths"}},
      {"a match-all **/* beside a real glob", place.(%{"paths" => ["lib/a.ex", "**/*"]}),
       {:refused, ".paths"}},
      {"a match-all *", place.(%{"paths" => ["*"]}), {:refused, ".paths"}}
    ]
  end

  defp selector_rows("pattern", place) do
    [
      {"positive: a module glob", place.(%{"pattern" => "MyApp.Domain.*"}), :accepted},
      {"a match-all *", place.(%{"pattern" => "*"}), {:refused, ".pattern"}},
      {"a match-all **", place.(%{"pattern" => "**"}), {:refused, ".pattern"}},
      {"a match-all *.*", place.(%{"pattern" => "*.*"}), {:refused, ".pattern"}},
      {"blank", place.(%{"pattern" => ""}), {:refused, ".pattern"}},
      {"not a string", place.(%{"pattern" => ["A.*"]}), {:refused, ".pattern"}}
    ]
  end

  defp selector_rows("uses_module", place) do
    [
      {"positive: GenServer", place.(%{"uses_module" => "GenServer"}), :accepted},
      {"blank", place.(%{"uses_module" => ""}), {:refused, ".uses_module"}},
      {"a glob", place.(%{"uses_module" => "MyApp.*"}), {:refused, ".uses_module"}},
      {"an Erlang module", place.(%{"uses_module" => ":gen_server"}), {:refused, ".uses_module"}}
    ]
  end

  defp selector_rows("behaviour", place) do
    [
      {"positive: Supervisor", place.(%{"behaviour" => "Supervisor"}), :accepted},
      {"positive: :gen_server", place.(%{"behaviour" => ":gen_server"}), :accepted},
      {"blank", place.(%{"behaviour" => ""}), {:refused, ".behaviour"}},
      {"a glob", place.(%{"behaviour" => "MyApp.*"}), {:refused, ".behaviour"}},
      {"a bare colon", place.(%{"behaviour" => ":"}), {:refused, ".behaviour"}},
      {"not a string", place.(%{"behaviour" => 1}), {:refused, ".behaviour"}}
    ]
  end

  defp selector_rows("exports_function", place) do
    [
      {"positive: __aggregate__/0", place.(%{"exports_function" => "__aggregate__/0"}),
       :accepted},
      {"positive: valid?/1", place.(%{"exports_function" => "valid?/1"}), :accepted},
      {"no arity", place.(%{"exports_function" => "run"}), {:refused, ".exports_function"}},
      {"run/x", place.(%{"exports_function" => "run/x"}), {:refused, ".exports_function"}},
      {"a module-qualified name", place.(%{"exports_function" => "Mod.run/1"}),
       {:refused, ".exports_function"}},
      {"not a string", place.(%{"exports_function" => 5}), {:refused, ".exports_function"}}
    ]
  end

  defp prefix(:accepted, _path), do: :accepted
  defp prefix({:refused, fragment}, path), do: {:refused, path <> fragment}

  defp doc(section), do: %{"rules" => [], "architecture" => section}

  # @minimal with its one bucket replaced; the calls row follows the name.
  defp with_bucket(bucket, name \\ "domain") do
    doc(%{@minimal | "buckets" => [bucket], "calls" => %{name => []}})
  end

  # `nil` when the row holds, else a line saying how it failed.
  defp row_failure(key_path, {label, document, expected}) do
    document
    |> parse()
    |> row_result(document, expected)
    |> then(&(&1 && "#{key_path} / #{label}: #{&1}"))
  end

  defp parse(document) do
    Config.parse_config(document)
  rescue
    error -> {:raised, Exception.message(error) |> String.split("\n") |> hd()}
  end

  defp row_result({:raised, message}, _document, _expected), do: "RAISED: #{message}"

  defp row_result(%Config{architecture: %Architecture{}}, %{"architecture" => _}, :accepted),
    do: nil

  defp row_result(%Config{architecture: nil}, document, :accepted)
       when not is_map_key(document, "architecture"),
       do: nil

  defp row_result(result, _document, :accepted), do: "refused: #{inspect(result)}"

  defp row_result({:error, {:invalid_config, message}}, _document, {:refused, fragment}) do
    if String.starts_with?(message, fragment) and message =~ "Fix:",
      do: nil,
      else: "wrong message (want it to start with #{inspect(fragment)} and hold Fix:): #{message}"
  end

  defp row_result(result, _document, {:refused, _fragment}),
    do: "LOADED: #{inspect(result, limit: 6)}"
end
