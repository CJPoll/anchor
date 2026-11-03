defmodule Anchor.Domain.Architecture.Selector do
  @moduledoc """
  One selector entry of an `architecture:` bucket's `select` list, or of
  `roots` (DND-5437) — a **Domain** module (ADR 001). Pure: it parses a decoded
  YAML entry and matches a parsed selector against a module's facts. No IO.

  An entry names exactly one selector key:

    * `paths: ["apps/*/lib/**/domain/**/*.ex"]` — source-path globs, `**`
      always recursive (`Anchor.Domain.GlobPattern.matches_recursive_pattern?/2`).
      A module with no known source file matches no `paths` selector. A glob
      with no literal character (`**`, `**/*`) is refused: it puts every file
      in the bucket;
    * `pattern: "Mix.Tasks.*"` — a module-name glob
      (`Anchor.Domain.GlobPattern.matches_module_pattern?/2`). A glob with no
      literal character (`*`, `*.*`) is refused: it puts every module in the
      bucket;
    * `uses_module: GenServer` — a literal `use` in the module's own
      `defmodule` body, named exactly (an Elixir module name);
    * `behaviour: Supervisor` — a behaviour the module declares, named exactly
      (an Elixir module name, or an Erlang one with a leading colon:
      `:gen_server`);
    * `exports_function: "__aggregate__/0"` — the module exports this
      function; the arity is required.

  Module and function names go through `Anchor.Domain.FunctionRef`'s grammar,
  so only grammar-valid names become atoms, and globs go through
  `Anchor.Domain.GlobPattern` only.
  """

  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.GlobPattern

  @type t ::
          {:paths, [String.t()]}
          | {:pattern, String.t()}
          | {:uses_module, module()}
          | {:behaviour, module()}
          | {:exports_function, {atom(), arity()}}

  @keys ~w(behaviour exports_function paths pattern uses_module)

  @doc "The keys a selector entry may carry, sorted: it carries exactly one."
  @spec keys() :: [String.t()]
  def keys, do: @keys

  @doc """
  Whether `selector` selects the module `facts` describe
  (`Anchor.Domain.Classification.facts/0`).
  """
  @spec matches?(t(), map()) :: boolean()
  def matches?({:paths, _globs}, %{source_file: nil}), do: false

  def matches?({:paths, globs}, %{source_file: file}),
    do: Enum.any?(globs, &GlobPattern.matches_recursive_pattern?(file, &1))

  def matches?({:pattern, glob}, %{module: module}),
    do: GlobPattern.matches_module_pattern?(Atom.to_string(module), glob)

  def matches?({:uses_module, used}, %{uses: uses}), do: used in uses
  def matches?({:behaviour, behaviour}, %{behaviours: behaviours}), do: behaviour in behaviours
  def matches?({:exports_function, export}, %{exports: exports}), do: export in exports

  @doc """
  `selector` as `.anchor.yml` writes it, for a message: `paths ["lib/**"]`,
  `pattern "MyApp.*"`, `uses_module GenServer`, `behaviour :gen_server`,
  `exports_function "__aggregate__/0"`.
  """
  @spec describe(t()) :: String.t()
  def describe({:paths, globs}), do: "paths #{inspect(globs)}"
  def describe({:pattern, glob}), do: "pattern #{inspect(glob)}"
  def describe({:uses_module, module}), do: "uses_module #{inspect(module)}"
  def describe({:behaviour, module}), do: "behaviour #{inspect(module)}"
  def describe({:exports_function, {name, arity}}), do: ~s(exports_function "#{name}/#{arity}")

  @doc """
  Parses one decoded selector entry found at `path` (a key path such as
  `architecture.buckets[0].select[1]`). Returns `{:ok, selector}`, or
  `{:error, message}` where the message starts with the key path and ends with
  a `Fix:` sentence.
  """
  @spec parse(term(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(entry, path) when is_map(entry) do
    case {Enum.sort(Map.keys(entry)) -- @keys, Enum.filter(@keys, &Map.has_key?(entry, &1))} do
      {[], [key]} -> parse_value(key, entry[key], "#{path}.#{key}")
      {[], []} -> refuse(path, "names no selector", "give it one of: #{list(@keys)}")
      {[], several} -> two_selectors(path, several)
      {unknown, _known} -> unknown_keys(path, unknown)
    end
  end

  def parse(entry, path) do
    refuse(
      path,
      "is not a mapping, got: #{inspect(entry)}",
      "write it as one selector key and its value, e.g. `- pattern: \"MyApp.*\"`"
    )
  end

  defp two_selectors(path, several) do
    refuse(
      path,
      "names #{length(several)} selectors (#{Enum.join(several, ", ")})",
      "split them into one entry each; a module matching any entry is selected"
    )
  end

  defp unknown_keys(path, unknown) do
    refuse(
      path,
      "has unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}",
      "use exactly one selector key: #{list(@keys)}"
    )
  end

  defp parse_value("paths", globs, path) do
    cond do
      not (is_list(globs) and globs != [] and Enum.all?(globs, &non_blank?/1)) ->
        refuse(
          path,
          "must be a non-empty list of non-empty path globs, got: #{inspect(globs)}",
          "list the source-path globs the bucket holds, e.g. [\"lib/**/domain/**/*.ex\"]"
        )

      glob = Enum.find(globs, &GlobPattern.literal_free?(&1, "/")) ->
        refuse(
          path,
          "#{inspect(glob)} matches every source file",
          "give each glob a literal directory or name, e.g. \"lib/**/domain/**/*.ex\""
        )

      true ->
        {:ok, {:paths, globs}}
    end
  end

  defp parse_value("pattern", glob, path) do
    cond do
      not non_blank?(glob) ->
        refuse(path, "must be a non-empty module-name glob, got: #{inspect(glob)}", pattern_fix())

      GlobPattern.literal_free?(glob, ".") ->
        refuse(path, "#{inspect(glob)} matches every module", pattern_fix())

      true ->
        {:ok, {:pattern, glob}}
    end
  end

  defp parse_value("uses_module", name, path) do
    if is_binary(name) and FunctionRef.alias_name?(name),
      do: {:ok, {:uses_module, Module.concat([name])}},
      else:
        refuse(
          path,
          "must name one Elixir module exactly, got: #{inspect(name)}",
          "name the module the bucket's modules `use`, e.g. GenServer"
        )
  end

  defp parse_value("behaviour", name, path), do: parse_behaviour(name, path)

  defp parse_value("exports_function", token, path) when is_binary(token) do
    case FunctionRef.parse_name_arity(token) do
      {:ok, export} -> {:ok, {:exports_function, export}}
      {:error, why} -> refuse(path, "#{inspect(token)} #{why}", exports_fix())
    end
  end

  defp parse_value("exports_function", token, path),
    do: refuse(path, "must be a string, got: #{inspect(token)}", exports_fix())

  defp parse_behaviour(":" <> erlang = name, path) do
    if FunctionRef.erlang_module_name?(erlang),
      do: {:ok, {:behaviour, String.to_atom(erlang)}},
      else: behaviour_refused(name, path)
  end

  defp parse_behaviour(name, path) when is_binary(name) do
    if FunctionRef.alias_name?(name),
      do: {:ok, {:behaviour, Module.concat([name])}},
      else: behaviour_refused(name, path)
  end

  defp parse_behaviour(name, path), do: behaviour_refused(name, path)

  defp behaviour_refused(name, path) do
    refuse(
      path,
      "must name one behaviour module exactly, got: #{inspect(name)}",
      "name the behaviour, e.g. Supervisor or :gen_server"
    )
  end

  defp pattern_fix,
    do: "write a module-name glob with at least one literal segment, e.g. \"MyApp.Domain.*\""

  defp exports_fix,
    do: "write the function as \"name/arity\", e.g. \"__aggregate__/0\""

  defp non_blank?(value), do: is_binary(value) and String.trim(value) != ""

  defp list(keys), do: Enum.join(keys, ", ")

  defp refuse(path, problem, fix), do: {:error, "#{path} #{problem}. Fix: #{fix}"}
end
