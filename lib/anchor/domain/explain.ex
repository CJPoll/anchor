defmodule Anchor.Domain.Explain do
  @moduledoc """
  What `mix anchor.explain` answers about one module or path (DND-5446,
  shared contract section 9) — a **Domain** module (ADR 001). Pure: it reads
  the config, the model of the last `mix anchor.graph` run (or `nil` when
  there is none whose key matches this build) and the subject the Manager
  gathered, and does no IO. Everything it prints comes from `.anchor.yml`
  and the graph, never from prose.

  `build/3` answers:

    * `classification` — the module's bucket and role, context, app, whether
      it is its context's interface, and its aggregate (`unknown (no
      aggregates configured)` until the transactional epic lands). From the
      model when the module is in it; otherwise by path and pattern
      selectors only (`Anchor.Domain.Classification.classify_planned/3`):
      a bucket only a beam fact could select is `possible`, and those facts
      are listed in `unknown`. An unclassified or ambiguous module says so,
      with every bucket's selectors and its `Fix:`;
    * `may_call` — the module's bucket's `calls` row, each entry resolved to
      the concrete modules it may call when the model is known: its own
      context's modules of that bucket, and only the interface modules of
      every other context;
    * `must_not_call` — the buckets its row leaves out (deny by default);
    * `rules` — every rule of either engine whose selector selects it, with
      its id, type, engine, enforcement and shape (`Anchor.Domain.RuleShapes`);
    * `findings` — the graph rules' findings on its source file when the
      model is known, else `nil` (`not computed (run mix anchor.graph)`): a
      stale artifact is never read.

  `render/2` prints it as text or as the JSON agents read (`R5` keys:
  `subject`, `exists`, `classification`, `may_call`, `must_not_call`,
  `rules`, `findings`, `unknown`).
  """

  alias Anchor.Config
  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Architecture.Selector
  alias Anchor.Domain.Classification
  alias Anchor.Domain.Failures
  alias Anchor.Domain.GlobPattern
  alias Anchor.Domain.Model
  alias Anchor.Domain.RuleMatching
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.RuleShapes
  alias Anchor.Domain.Violation

  @aggregate "unknown (no aggregates configured)"
  @beam_facts ~w(app behaviours exports_function uses_module)
  @text_names 8

  defstruct [
    :subject,
    :module,
    :path,
    :exists,
    :classification,
    :may_call,
    :must_not_call,
    :rules,
    :findings,
    unknown: [],
    notes: []
  ]

  @type t :: %__MODULE__{}

  @typedoc """
  What the Manager gathered about the subject: the argument as given, the
  module (the one the graph places at the path, else the one the path
  implies), the repo-relative path (`nil` when unknown), whether the file
  exists, its source facts (`nil` when it does not exist or did not parse),
  whether the project compiled, and the graph findings on it (`nil` without
  a model).
  """
  @type subject :: %{
          required(:argument) => String.t(),
          required(:module) => module() | nil,
          required(:path) => String.t() | nil,
          required(:exists?) => boolean(),
          required(:source) => map() | nil,
          required(:compiled?) => boolean(),
          required(:findings) => [Violation.t()] | nil
        }

  @doc "Builds the answer for `subject` under `config`, with the run's model or `nil`."
  @spec build(Config.t(), Model.t() | nil, subject()) :: t()
  def build(%Config{architecture: %Architecture{} = arch} = config, model, subject) do
    classification = classify(model, arch, subject)

    %__MODULE__{
      subject: subject.argument,
      module: subject.module,
      path: subject.path,
      exists: subject.exists?,
      classification: classification,
      may_call: may_call(arch, model, classification),
      must_not_call: must_not_call(arch, classification),
      rules: rules(config, subject, classification),
      findings: subject.findings,
      unknown: unknown(model, classification),
      notes: notes(subject)
    }
  end

  @doc "The answer as `:text` or `:json`."
  @spec render(t(), :text | :json) :: String.t()
  def render(%__MODULE__{} = explain, :json) do
    JSON.encode!(%{
      "subject" => explain.subject,
      "module" => module_name(explain.module),
      "path" => explain.path,
      "exists" => explain.exists,
      "notes" => explain.notes,
      "classification" => explain.classification,
      "may_call" => explain.may_call,
      "must_not_call" => explain.must_not_call,
      "rules" => explain.rules,
      "findings" => findings_json(explain.findings),
      "unknown" => explain.unknown
    })
  end

  def render(%__MODULE__{} = explain, :text) do
    [
      "anchor.explain: #{explain.subject}",
      "  module: #{module_name(explain.module) || "(none implied)"}",
      "  path: #{explain.path || "(unknown)"} (#{exists_text(explain.exists)})"
    ]
    |> Enum.concat(Enum.map(explain.notes, &"  note: #{&1}"))
    |> Enum.concat(["classification:" | classification_lines(explain.classification)])
    |> Enum.concat(["may call:" | may_call_lines(explain.may_call)])
    |> Enum.concat(["must not call: " <> list_or_none(explain.must_not_call)])
    |> Enum.concat(["rules:" | rule_lines(explain.rules)])
    |> Enum.concat(findings_lines(explain.findings))
    |> Enum.concat(unknown_lines(explain.unknown))
    |> Enum.join("\n")
  end

  # ---- classification ----

  defp classify(model, arch, subject) do
    case model && Map.get(model.classification, subject.module) do
      %Classification{} = class -> classified(class)
      nil -> unplaced(model, arch, subject)
    end
  end

  defp classified(%Classification{} = class) do
    %{
      "status" => "classified",
      "bucket" => class.bucket,
      "role" => Atom.to_string(class.role),
      "context" => class.context,
      "app" => class.app && Atom.to_string(class.app),
      "interface" => class.interface?,
      "aggregate" => @aggregate
    }
  end

  # In the graph but not classified: the run's own verdict (unclassified or
  # ambiguous), with every bucket's selectors.
  defp unplaced(%Model{graph: graph} = _model, arch, %{module: module} = subject)
       when is_map_key(graph.modules, module) do
    facts = Model.facts(Map.fetch!(graph.modules, module), %{})
    issue = graph_issue(Classification.classify(facts, arch), facts, arch)

    %{
      "status" => issue.status,
      "bucket" => nil,
      "context" => Classification.context_of(module, arch.context_depth),
      "aggregate" => @aggregate,
      "selectors" => selectors(arch, Classification.matching_selectors(facts, arch)),
      "fix" => issue.message
    }
    |> Map.merge(%{"path" => subject.path})
  end

  defp unplaced(_model, arch, subject), do: planned(arch, subject)

  defp graph_issue({:error, {:unclassified, _module}}, facts, _arch),
    do: %{status: "unclassified", message: Failures.unclassified(facts).message}

  defp graph_issue({:error, {:ambiguous, _module, _names}}, facts, arch) do
    %{
      status: "ambiguous",
      message: Failures.ambiguous(facts, Classification.matching_selectors(facts, arch)).message
    }
  end

  defp planned(arch, subject) do
    planned = Classification.classify_planned(subject.path, subject.module, arch)
    bucket = planned.definite && Enum.find(arch.buckets, &(&1.name == planned.definite))

    %{
      "status" => planned_status(planned),
      "bucket" => planned.definite,
      "role" => bucket && Atom.to_string(bucket.role),
      "context" =>
        subject.module && Classification.context_of(subject.module, arch.context_depth),
      "app" => "unknown until compiled",
      "interface" => planned_interface(bucket, subject.module, arch),
      "aggregate" => @aggregate,
      "ambiguous" => planned.ambiguous,
      "possible" => planned.possible,
      "unknown_selectors" => Enum.map(planned.unknown, &Atom.to_string/1),
      "selectors" => selectors(arch, [])
    }
    |> with_planned_fix(planned, subject)
  end

  defp planned_status(%{ambiguous: [_ | _]}), do: "ambiguous"
  defp planned_status(%{definite: name}) when is_binary(name), do: "classified by path"
  defp planned_status(%{possible: [_ | _]}), do: "possible"
  defp planned_status(_none), do: "unclassified"

  defp planned_interface(nil, _module, _arch), do: nil

  defp planned_interface(bucket, module, arch),
    do: bucket.name in arch.interface_buckets or module in arch.interface_exports

  defp with_planned_fix(map, %{definite: nil, ambiguous: [], possible: []}, subject) do
    file = subject.path || "(no source file)"

    Map.put(
      map,
      "fix",
      Failures.unclassified(%{module: subject.module, source_file: file}).message
    )
  end

  defp with_planned_fix(map, %{ambiguous: [_ | _] = names}, _subject) do
    Map.put(
      map,
      "fix",
      "the path or name is in buckets #{Enum.join(names, " and ")}. Fix: narrow one selector; " <>
        "buckets never take precedence."
    )
  end

  defp with_planned_fix(map, _planned, _subject), do: map

  defp selectors(%Architecture{buckets: buckets}, matched) do
    matched = Map.new(matched)

    Enum.map(buckets, fn bucket ->
      %{
        "bucket" => bucket.name,
        "select" => Enum.map(bucket.selectors, &Selector.describe/1),
        "matched" => Map.get(matched, bucket.name)
      }
    end)
  end

  # ---- calls ----

  defp may_call(arch, model, %{"bucket" => bucket} = class) when is_binary(bucket) do
    arch.calls
    |> Map.get(bucket, [])
    |> Enum.map(fn {target, scope} ->
      %{
        "bucket" => target,
        "scope" => Atom.to_string(scope),
        "modules" => callable(model, target, scope, class["context"])
      }
    end)
  end

  defp may_call(_arch, _model, _class), do: []

  # `nil` without a model: the buckets are known, the modules are not.
  defp callable(nil, _bucket, _scope, _context), do: nil

  defp callable(%Model{classification: classification}, bucket, scope, context) do
    in_bucket =
      classification
      |> Map.values()
      |> Enum.filter(&(&1.bucket == bucket))

    %{
      "same_context" => if(scope != :other_context, do: same(in_bucket, context), else: []),
      "other_contexts" => if(scope != :same_context, do: others(in_bucket, context), else: %{})
    }
  end

  defp same(classes, context) do
    classes
    |> Enum.filter(&(&1.context == context))
    |> Enum.map(&inspect(&1.module))
    |> Enum.sort()
  end

  # Another context's modules: its interface modules only (DND-5443).
  defp others(classes, context) do
    classes
    |> Enum.filter(&(&1.context != context and &1.context != nil and &1.interface?))
    |> Enum.group_by(& &1.context, &inspect(&1.module))
    |> Map.new(fn {ctx, modules} -> {ctx, Enum.sort(modules)} end)
  end

  defp must_not_call(arch, %{"bucket" => bucket}) when is_binary(bucket) do
    allowed = arch.calls |> Map.get(bucket, []) |> Enum.map(&elem(&1, 0))
    arch |> Architecture.bucket_names() |> Enum.reject(&(&1 in allowed)) |> Enum.sort()
  end

  defp must_not_call(_arch, _class), do: []

  # ---- rules ----

  defp rules(%Config{rules: rules}, subject, class) do
    for rule <- rules, selects?(RuleSchema.engine(rule.type), rule, subject, class) do
      %{
        "id" => Map.get(rule, :id),
        "type" => Atom.to_string(rule.type),
        "engine" => Atom.to_string(RuleSchema.engine(rule.type)),
        "enforcement" => Atom.to_string(RuleSchema.enforcement(rule)),
        "shape" => RuleShapes.for(rule)
      }
    end
  end

  defp selects?(:graph, %{bucket: bucket}, _subject, class) when is_binary(bucket),
    do: class["bucket"] == bucket

  defp selects?(:graph, %{paths: [_ | _] = globs}, %{path: path}, _class) when is_binary(path),
    do: Enum.any?(globs, &GlobPattern.matches_recursive_pattern?(path, &1))

  defp selects?(:graph, %{pattern: pattern}, %{module: module}, _class)
       when is_binary(pattern) and is_atom(module) and module != nil,
       do: GlobPattern.matches_module_pattern?(Atom.to_string(module), pattern)

  defp selects?(:graph, _rule, _subject, _class), do: false

  defp selects?(:ast, rule, subject, _class) do
    RuleMatching.rule_matches_file?(rule, %{
      filename: subject.path || "",
      module_names: module_names(subject),
      uses: uses(subject)
    })
  end

  defp module_names(%{source: %{defmodules: [_ | _] = names}}), do: names
  defp module_names(%{module: nil}), do: []
  defp module_names(%{module: module}), do: [module_name(module)]

  defp uses(%{source: %{uses: uses}}),
    do: uses |> Map.values() |> List.flatten() |> Enum.map(&Module.concat([&1]))

  defp uses(_subject), do: []

  # ---- unknown ----

  defp unknown(%Model{}, %{"status" => "classified"}), do: []
  defp unknown(_model, _class), do: @beam_facts

  defp notes(%{compiled?: false}), do: ["compile failed; beam facts unknown"]
  defp notes(_subject), do: []

  # ---- rendering ----

  defp findings_json(nil), do: nil

  defp findings_json(findings) do
    Enum.map(findings, fn %Violation{} = v ->
      %{
        "rule_id" => v.rule_id,
        "key" => v.key,
        "file" => v.filename,
        "line" => v.line,
        "message" => v.message
      }
    end)
  end

  defp module_name(nil), do: nil
  defp module_name(module), do: inspect(module)

  defp exists_text(true), do: "exists"
  defp exists_text(false), do: "does not exist yet"

  defp classification_lines(class) do
    [
      "  status: #{class["status"]}",
      "  bucket: #{class["bucket"] || "none"}#{role_text(class["role"])}",
      "  context: #{class["context"] || "none"}",
      "  app: #{class["app"] || "none"}",
      "  interface: #{interface_text(class["interface"])}",
      "  aggregate: #{class["aggregate"]}"
    ]
    |> Enum.concat(optional_list("possible buckets", class["possible"]))
    |> Enum.concat(optional_list("ambiguous between", class["ambiguous"]))
    |> Enum.concat(selector_lines(class))
    |> Enum.concat(if class["fix"], do: ["  #{class["fix"]}"], else: [])
  end

  defp role_text(nil), do: ""
  defp role_text(role), do: " (role #{role})"

  defp interface_text(true), do: "yes"
  defp interface_text(false), do: "no"
  defp interface_text(nil), do: "unknown"

  defp optional_list(_label, nil), do: []
  defp optional_list(_label, []), do: []
  defp optional_list(label, items), do: ["  #{label}: #{Enum.join(items, ", ")}"]

  # Every bucket's selectors, shown when the module is not classified into one.
  defp selector_lines(%{"status" => "classified"}), do: []

  defp selector_lines(%{"selectors" => selectors}) do
    Enum.map(selectors, fn selector ->
      matched = if selector["matched"], do: " (matched by #{selector["matched"]})", else: ""
      "  bucket #{selector["bucket"]} selects: #{Enum.join(selector["select"], "; ")}#{matched}"
    end)
  end

  defp selector_lines(_class), do: []

  defp may_call_lines([]), do: ["  nothing: the module has no bucket"]

  defp may_call_lines(entries) do
    Enum.map(entries, fn entry ->
      "  #{entry["bucket"]} (#{entry["scope"]})#{modules_text(entry["modules"])}"
    end)
  end

  defp modules_text(nil), do: " (modules not computed: run mix anchor.graph)"

  defp modules_text(%{"same_context" => same, "other_contexts" => others}) do
    other_text =
      others
      |> Enum.sort()
      |> Enum.map_join("; ", fn {ctx, modules} -> "#{ctx}: #{names(modules)}" end)

    ": same context: #{names(same)}; other contexts (interface only): " <>
      if(other_text == "", do: "none", else: other_text)
  end

  defp names([]), do: "none"

  defp names(modules) do
    {shown, rest} = Enum.split(modules, @text_names)
    text = Enum.join(shown, ", ")
    if rest == [], do: text, else: "#{text} and #{length(rest)} more"
  end

  defp list_or_none([]), do: "nothing"
  defp list_or_none(items), do: Enum.join(items, ", ")

  defp rule_lines([]), do: ["  none selects it"]

  defp rule_lines(rules) do
    Enum.map(rules, fn rule ->
      id = if rule["id"], do: "id: #{rule["id"]}, ", else: ""
      "  [#{rule["enforcement"]}] #{rule["type"]} (#{id}#{rule["engine"]}): #{rule["shape"]}"
    end)
  end

  defp findings_lines(nil), do: ["findings: not computed (run mix anchor.graph)"]
  defp findings_lines([]), do: ["findings: none"]

  defp findings_lines(findings) do
    ["findings:" | Enum.map(findings, &"  #{&1.filename}:#{&1.line || 1}: #{&1.message}")]
  end

  defp unknown_lines([]), do: []
  defp unknown_lines(facts), do: ["unknown until compiled: #{Enum.join(facts, ", ")}"]
end
