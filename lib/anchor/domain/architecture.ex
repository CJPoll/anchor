defmodule Anchor.Domain.Architecture do
  @moduledoc """
  The `architecture:` section of `.anchor.yml` (DND-5437): the one model of
  buckets, the calls matrix, contexts, interfaces, effect primitives and roots
  that every graph check, placement proposal and `explain`/`place` answer reads
  — a **Domain** module (ADR 001). Pure: `parse/1` turns the decoded YAML value
  (string keys) into `%Architecture{}` and does no IO.

  ```yaml
  architecture:
    contexts:
      depth: 2
    buckets:
      - name: domain
        role: domain
        select:
          - paths: ["lib/**/domain/**/*.ex"]
        min_modules: 10
    calls:
      domain: [domain]
    interfaces:
      buckets: [managers]
      exports: [MyApp.Accounts.Api]
    effects: ["Req", ":gen_tcp.connect"]
    roots:
      - pattern: "Mix.Tasks.*"
    extract_pure_regions_from: [managers, framework]
  ```

  `contexts`, `buckets` and `calls` are required; the rest is optional. Each
  key's meaning is in the README section "The `architecture:` section".

  ## Failing closed

  Every way the section could check nothing, or less than it says, is refused
  at load as `{:error, {:invalid_config, message}}`: the message starts with the
  key path (`architecture.buckets[1].select[0]`, 0-based indexes) and ends with
  a `Fix:` sentence. Validation stops at the first refusal, in this order:
  unknown keys of the section; `contexts`; `buckets` (each bucket's keys,
  `name`, `role`, `select`, `min_modules`, `infer`, then duplicate names);
  `calls`; `interfaces`; `effects`; `roots`; `extract_pure_regions_from`.

  The calls matrix denies by default: a bucket needs a row (`[]` for "calls
  nothing"), and an absent row is refused rather than read as "allow all".

  What load time cannot decide (a bucket below its `min_modules`, a module no
  bucket or two buckets select, an `exports` entry naming no module) is decided
  at run time by the graph runner (DND-5440) through
  `Anchor.Domain.Classification`.

  ## Extending it

  A new key goes into its level's key list below (so `key_paths/0` names it),
  is parsed here, gets a table in
  `test/anchor/domain/architecture_checks_nothing_test.exs` (a test fails until
  every key path has one) and a row in the README section.
  """

  alias Anchor.Domain.Architecture.Bucket
  alias Anchor.Domain.Architecture.Selector
  alias Anchor.Domain.FunctionRef

  @enforce_keys [:context_depth, :buckets, :calls]
  defstruct context_depth: nil,
            buckets: [],
            calls: %{},
            interface_buckets: [],
            interface_exports: [],
            effects: [],
            roots: [],
            extract_pure_regions_from: [:managers, :framework]

  @type scope :: :any | :same_context | :other_context
  @type call_target :: {bucket_name :: String.t(), scope()}

  @type t :: %__MODULE__{
          context_depth: pos_integer(),
          buckets: [Bucket.t()],
          calls: %{String.t() => [call_target()]},
          interface_buckets: [String.t()],
          interface_exports: [module()],
          effects: [String.t()],
          roots: [Selector.t()],
          extract_pure_regions_from: [Bucket.role()]
        }

  @path "architecture"

  @section_keys ~w(buckets calls contexts effects extract_pure_regions_from interfaces roots)
  @contexts_keys ~w(depth)
  @bucket_keys ~w(infer min_modules name role select)
  @interfaces_keys ~w(buckets exports)

  @roles %{
    "adapters" => :adapters,
    "domain" => :domain,
    "framework" => :framework,
    "managers" => :managers,
    "ui" => :ui
  }

  @scopes %{"same_context" => :same_context, "other_context" => :other_context}

  @doc """
  Every key path the parser reads, sorted: one per key at every level, with
  `[]` standing for a list index (`buckets[].select[].paths`). The table test
  holds a table for each.
  """
  @spec key_paths() :: [String.t()]
  def key_paths do
    selector_paths = fn prefix -> Enum.map(Selector.keys(), &"#{prefix}[].#{&1}") end

    Enum.sort(
      [@path] ++
        @section_keys ++
        Enum.map(@contexts_keys, &"contexts.#{&1}") ++
        Enum.map(@bucket_keys, &"buckets[].#{&1}") ++
        selector_paths.("buckets[].select") ++
        Enum.map(@interfaces_keys, &"interfaces.#{&1}") ++
        selector_paths.("roots")
    )
  end

  @doc "The bucket named `name`, or `nil`."
  @spec bucket(t(), String.t()) :: Bucket.t() | nil
  def bucket(%__MODULE__{buckets: buckets}, name), do: Enum.find(buckets, &(&1.name == name))

  @doc "The bucket names, in file order."
  @spec bucket_names(t()) :: [String.t()]
  def bucket_names(%__MODULE__{buckets: buckets}), do: Enum.map(buckets, & &1.name)

  @doc "The five roles a bucket may have, sorted."
  @spec roles() :: [Bucket.role()]
  def roles, do: @roles |> Map.values() |> Enum.sort()

  @doc """
  Parses the decoded value of the `architecture:` key. Returns
  `{:ok, %Architecture{}}` or `{:error, {:invalid_config, message}}`.
  """
  @spec parse(term()) :: {:ok, t()} | {:error, {:invalid_config, String.t()}}
  def parse(section) do
    case parse_section(section) do
      {:ok, architecture} -> {:ok, architecture}
      {:error, message} -> {:error, {:invalid_config, message}}
    end
  end

  defp parse_section(section) when is_map(section) do
    with :ok <- known_keys(section, @section_keys, @path),
         {:ok, depth} <- parse_contexts(section["contexts"]),
         {:ok, buckets} <- parse_buckets(section["buckets"]),
         names = Enum.map(buckets, & &1.name),
         {:ok, calls} <- parse_calls(section["calls"], names),
         {:ok, interface_buckets, exports} <- parse_interfaces(section["interfaces"], names),
         {:ok, effects} <- parse_effects(section["effects"]),
         {:ok, roots} <- parse_roots(section["roots"]),
         {:ok, regions} <- parse_regions(section["extract_pure_regions_from"]) do
      {:ok,
       %__MODULE__{
         context_depth: depth,
         buckets: buckets,
         calls: calls,
         interface_buckets: interface_buckets,
         interface_exports: exports,
         effects: effects,
         roots: roots,
         extract_pure_regions_from: regions
       }}
    end
  end

  defp parse_section(section) do
    refuse(
      @path,
      "is not a mapping, got: #{inspect(section)}",
      "write architecture: as a mapping with contexts, buckets and calls"
    )
  end

  # ---- contexts ----

  defp parse_contexts(contexts) when is_map(contexts) do
    with :ok <- known_keys(contexts, @contexts_keys, "#{@path}.contexts") do
      parse_depth(contexts["depth"])
    end
  end

  defp parse_contexts(nil),
    do: refuse("#{@path}.contexts", "is missing", "add contexts: {depth: N}")

  defp parse_contexts(contexts) do
    refuse(
      "#{@path}.contexts",
      "is not a mapping, got: #{inspect(contexts)}",
      "write it as contexts: {depth: N}"
    )
  end

  defp parse_depth(depth) when is_integer(depth) and depth > 0, do: {:ok, depth}

  defp parse_depth(depth) do
    refuse(
      "#{@path}.contexts.depth",
      present("must be a positive integer", depth),
      "set it to how many leading module-name segments name a context, e.g. 2"
    )
  end

  # ---- buckets ----

  defp parse_buckets([_ | _] = buckets) do
    with {:ok, parsed} <- parse_each(buckets, "#{@path}.buckets", &parse_bucket/2) do
      refuse_duplicate_names(parsed)
    end
  end

  defp parse_buckets(buckets) do
    refuse(
      "#{@path}.buckets",
      present("must be a non-empty list of buckets", buckets),
      "list every bucket, each with a name, a role and a select list"
    )
  end

  defp parse_bucket(bucket, path) when is_map(bucket) do
    with :ok <- known_keys(bucket, @bucket_keys, path),
         {:ok, name} <- parse_name(bucket["name"], "#{path}.name"),
         {:ok, role} <- parse_role(bucket["role"], "#{path}.role"),
         {:ok, selectors} <- parse_select(bucket["select"], "#{path}.select"),
         {:ok, min_modules} <- parse_min_modules(bucket, "#{path}.min_modules"),
         {:ok, infer} <- parse_infer(bucket, "#{path}.infer") do
      {:ok,
       %Bucket{
         name: name,
         role: role,
         selectors: selectors,
         min_modules: min_modules,
         infer: infer
       }}
    end
  end

  defp parse_bucket(bucket, path) do
    refuse(
      path,
      "is not a mapping, got: #{inspect(bucket)}",
      "write each bucket as a mapping with name, role and select"
    )
  end

  defp parse_name(name, path) do
    if is_binary(name) and name != "" and bucket_name_chars?(name),
      do: {:ok, name},
      else:
        refuse(
          path,
          present("must be lower-case letters and _", name),
          "name the bucket, e.g. domain or my_bucket"
        )
  end

  defp bucket_name_chars?(name),
    do: name |> String.to_charlist() |> Enum.all?(&(&1 in ?a..?z or &1 == ?_))

  defp parse_role(role, path) do
    case Map.fetch(@roles, role) do
      {:ok, atom} -> {:ok, atom}
      :error -> refuse(path, present("is not a role", role), "use one of: #{role_names()}")
    end
  end

  defp parse_select([_ | _] = entries, path), do: parse_each(entries, path, &Selector.parse/2)

  defp parse_select(entries, path) do
    refuse(
      path,
      present("must be a non-empty list of selectors", entries),
      "list at least one selector (#{Enum.join(Selector.keys(), ", ")})"
    )
  end

  defp parse_min_modules(bucket, path) do
    case Map.fetch(bucket, "min_modules") do
      :error ->
        {:ok, 1}

      {:ok, floor} when is_integer(floor) and floor > 0 ->
        {:ok, floor}

      {:ok, floor} ->
        refuse(
          path,
          "is #{inspect(floor)}, not a positive integer",
          "a floor is a positive integer; omit it for the default 1"
        )
    end
  end

  defp parse_infer(bucket, path) do
    case Map.fetch(bucket, "infer") do
      :error -> {:ok, true}
      {:ok, infer} when is_boolean(infer) -> {:ok, infer}
      {:ok, infer} -> refuse(path, "is #{inspect(infer)}", "set it to true or false, or omit it")
    end
  end

  defp refuse_duplicate_names(buckets) do
    case buckets |> Enum.frequencies_by(& &1.name) |> Enum.find(fn {_, n} -> n > 1 end) do
      nil ->
        {:ok, buckets}

      {name, _count} ->
        refuse(
          "#{@path}.buckets",
          "names the bucket #{inspect(name)} more than once",
          "give each bucket its own name; a module matching both would be ambiguous"
        )
    end
  end

  # ---- calls ----

  defp parse_calls(calls, names) when is_map(calls) do
    path = "#{@path}.calls"

    with :ok <- refuse_unknown_rows(calls, names, path),
         :ok <- refuse_missing_rows(calls, names, path) do
      parse_rows(names, calls, path)
    end
  end

  defp parse_calls(calls, _names) do
    refuse(
      "#{@path}.calls",
      present("must be a mapping with one row per bucket", calls),
      "add calls: with a row per bucket listing the buckets it may call ([] for none)"
    )
  end

  defp refuse_unknown_rows(calls, names, path) do
    case calls |> Map.keys() |> Enum.reject(&(&1 in names)) |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        refuse(
          path,
          "has a row for #{Enum.map_join(unknown, ", ", &inspect/1)}, which is not a bucket",
          "remove the row, or add the bucket; buckets: #{Enum.join(names, ", ")}"
        )
    end
  end

  defp refuse_missing_rows(calls, names, path) do
    case Enum.reject(names, &Map.has_key?(calls, &1)) do
      [] ->
        :ok

      [name | _rest] ->
        refuse(
          path,
          "has no row for bucket #{inspect(name)}",
          "add calls.#{name}: [...] listing the buckets #{name} may call ([] for none)"
        )
    end
  end

  defp parse_rows(names, calls, path) do
    Enum.reduce_while(names, {:ok, %{}}, fn name, {:ok, acc} ->
      case parse_row(calls[name], names, "#{path}.#{name}") do
        {:ok, targets} -> {:cont, {:ok, Map.put(acc, name, targets)}}
        error -> {:halt, error}
      end
    end)
  end

  defp parse_row(row, names, path) when is_list(row) do
    parse_each(row, path, &parse_target(&1, &2, names))
  end

  defp parse_row(row, _names, path) do
    refuse(
      path,
      "must be a list of buckets, got: #{inspect(row)}",
      "list the buckets it may call, e.g. [domain, \"managers:other_context\"] ([] for none)"
    )
  end

  defp parse_target(target, path, names) when is_binary(target) do
    {bucket, scope} = split_scope(target)

    cond do
      bucket not in names ->
        refuse(
          path,
          "names #{inspect(bucket)}, which is not a bucket",
          "name one of: #{Enum.join(names, ", ")}"
        )

      scope == :unknown ->
        refuse(
          path,
          "names #{inspect(target)}",
          "the scope suffix is :same_context or :other_context"
        )

      true ->
        {:ok, {bucket, scope}}
    end
  end

  defp parse_target(target, path, _names) do
    refuse(path, "is #{inspect(target)}, not a bucket name", "write a bucket name as a string")
  end

  defp split_scope(target) do
    case String.split(target, ":", parts: 2) do
      [bucket] -> {bucket, :any}
      [bucket, suffix] -> {bucket, Map.get(@scopes, suffix, :unknown)}
    end
  end

  # ---- interfaces ----

  defp parse_interfaces(nil, _names), do: {:ok, [], []}

  defp parse_interfaces(interfaces, names) when is_map(interfaces) do
    path = "#{@path}.interfaces"

    with :ok <- known_keys(interfaces, @interfaces_keys, path),
         {:ok, buckets} <- parse_interface_buckets(interfaces["buckets"], names, path),
         {:ok, exports} <- parse_exports(interfaces["exports"], "#{path}.exports") do
      {:ok, buckets, exports}
    end
  end

  defp parse_interfaces(interfaces, _names) do
    refuse(
      "#{@path}.interfaces",
      "is not a mapping, got: #{inspect(interfaces)}",
      "write it as interfaces: {buckets: [...], exports: [...]}"
    )
  end

  defp parse_interface_buckets(nil, _names, _path), do: {:ok, []}

  defp parse_interface_buckets(buckets, names, path) when is_list(buckets) do
    parse_each(buckets, "#{path}.buckets", fn bucket, entry_path ->
      if bucket in names,
        do: {:ok, bucket},
        else:
          refuse(
            entry_path,
            "names #{inspect(bucket)}, which is not a bucket",
            "name one of: #{Enum.join(names, ", ")}"
          )
    end)
  end

  defp parse_interface_buckets(buckets, _names, path) do
    refuse(
      "#{path}.buckets",
      "must be a list of bucket names, got: #{inspect(buckets)}",
      "list the buckets whose modules are their context's interface, e.g. [managers]"
    )
  end

  defp parse_exports(nil, _path), do: {:ok, []}

  defp parse_exports(exports, path) when is_list(exports),
    do: parse_each(exports, path, &export/2)

  defp parse_exports(exports, path) do
    refuse(
      path,
      "must be a list of module names, got: #{inspect(exports)}",
      "list each extra interface module by its exact name, e.g. [MyApp.Accounts.Api]"
    )
  end

  defp export(name, path) do
    if is_binary(name) and FunctionRef.alias_name?(name),
      do: {:ok, Module.concat([name])},
      else:
        refuse(
          path,
          "#{inspect(name)} is not one exact Elixir module name (a glob, an Erlang module " <>
            "and a blank are refused)",
          "name the module exactly, as its defmodule spells it, e.g. MyApp.Accounts.Api"
        )
  end

  # ---- effects ----

  defp parse_effects(nil), do: {:ok, []}

  defp parse_effects(effects) when is_list(effects),
    do: parse_each(effects, "#{@path}.effects", &effect/2)

  defp parse_effects(effects) do
    refuse(
      "#{@path}.effects",
      "must be a list of module or function tokens, got: #{inspect(effects)}",
      "list the extra effect primitives, e.g. [\"Req\", \":gen_tcp.connect\"]"
    )
  end

  # Stored raw; `Anchor.Domain.Effects` (DND-5447) interprets them. Here a token
  # must parse: a module (`Req`, `:gen_tcp`) or a function (`File.write!/2`).
  defp effect(token, path) when is_binary(token) do
    cond do
      FunctionRef.alias_name?(token) -> {:ok, token}
      erlang_module_token?(token) -> {:ok, token}
      true -> effect_function(token, path)
    end
  end

  defp effect(token, path), do: effect_refused(path, "is #{inspect(token)}, not a string")

  defp effect_function(token, path) do
    case FunctionRef.parse(token) do
      {:ok, _ref} -> {:ok, token}
      {:error, reason} -> effect_refused(path, "names no module or function: #{reason}")
    end
  end

  defp erlang_module_token?(":" <> name), do: FunctionRef.erlang_module_name?(name)
  defp erlang_module_token?(_token), do: false

  defp effect_refused(path, problem) do
    refuse(
      path,
      problem,
      ~s|write a module ("Req", ":gen_tcp") or a function ("File.write!/2", | <>
        ~s|":gen_tcp.connect")|
    )
  end

  # ---- roots ----

  defp parse_roots(nil), do: {:ok, []}

  defp parse_roots(roots) when is_list(roots),
    do: parse_each(roots, "#{@path}.roots", &Selector.parse/2)

  defp parse_roots(roots) do
    refuse(
      "#{@path}.roots",
      "must be a list of selectors, got: #{inspect(roots)}",
      "list each extra root as one selector entry, e.g. - pattern: \"Mix.Tasks.*\""
    )
  end

  # ---- extract_pure_regions_from ----

  defp parse_regions(nil), do: {:ok, [:managers, :framework]}

  defp parse_regions(roles) when is_list(roles) do
    parse_each(roles, "#{@path}.extract_pure_regions_from", &parse_role/2)
  end

  defp parse_regions(roles) do
    refuse(
      "#{@path}.extract_pure_regions_from",
      "must be a list of roles, got: #{inspect(roles)}",
      "list roles from: #{role_names()} ([] for none)"
    )
  end

  # ---- shared ----

  defp known_keys(map, keys, path) do
    case map |> Map.keys() |> Enum.reject(&(&1 in keys)) |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        refuse(
          path,
          "has unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}",
          "remove or correct them; the keys of #{path} are: #{Enum.join(keys, ", ")}"
        )
    end
  end

  # Parses every entry of `list` with `parse.(entry, "path[i]")`, stopping at
  # the first refusal.
  defp parse_each(list, path, parse) do
    list
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case parse.(entry, "#{path}[#{index}]") do
        {:ok, parsed} -> {:cont, {:ok, [parsed | acc]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      error -> error
    end)
  end

  defp present(problem, nil), do: "is missing (#{problem})"
  defp present(problem, value), do: "#{problem}, got: #{inspect(value)}"

  defp role_names, do: @roles |> Map.keys() |> Enum.sort() |> Enum.join(", ")

  defp refuse(path, problem, fix), do: {:error, "#{path} #{problem}. Fix: #{fix}"}
end
