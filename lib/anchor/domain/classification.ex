defmodule Anchor.Domain.Classification do
  @moduledoc """
  Which bucket of the `architecture:` section a module is in (DND-5437) — a
  **Domain** module (ADR 001). Pure: it reads a module's facts (plain data the
  graph runner fills from beams and source, DND-5438/5440) and an
  `%Anchor.Domain.Architecture{}`, and does no IO.

  ## Exactly one bucket, no precedence

  A module is in a bucket when any one of the bucket's selectors matches it
  (`Anchor.Domain.Architecture.Selector.matches?/2`). `classify/2` answers:

    * one bucket: `{:ok, %Classification{}}`, with the module's context and
      whether it is an interface module;
    * no bucket: `{:error, {:unclassified, module}}`;
    * two or more: `{:error, {:ambiguous, module, names}}`, every matching
      bucket's name, sorted.

  There is no precedence between buckets, ever: an order in the config would
  decide silently which rule a module is held to. The graph runner
  (DND-5440) reports both through `classify_all/3`.

  ## Context

  A module's context is its first `depth` name segments (`context_of/2`). A
  module with fewer segments, or an Erlang module, has no context (`nil`),
  which the interface and context rules report rather than skip.
  """

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Architecture.Bucket
  alias Anchor.Domain.Architecture.Selector
  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  @enforce_keys [:module, :bucket, :role]
  defstruct [:module, :bucket, :role, :context, :app, :source_file, interface?: false]

  @type t :: %__MODULE__{
          module: module(),
          bucket: String.t(),
          role: Bucket.role(),
          context: String.t() | nil,
          app: atom() | nil,
          source_file: String.t() | nil,
          interface?: boolean()
        }

  @typedoc """
  What is known about one module. `source_file` is repo-relative (`nil` when
  unknown); `uses` are the modules a literal `use` in its own `defmodule` body
  names; `behaviours` are its declared behaviours; `exports` its exported
  functions.
  """
  @type facts :: %{
          required(:module) => module(),
          required(:app) => atom() | nil,
          required(:source_file) => String.t() | nil,
          required(:uses) => [module()],
          required(:behaviours) => [module()],
          required(:exports) => [{atom(), arity()}]
        }

  @doc """
  Each bucket, in config order, with how many of `facts` its selectors match.
  A bucket matching none is kept, with 0. A module two buckets select counts
  toward each, so a floor never hides behind an ambiguity (reported on its
  own).
  """
  @spec bucket_counts([facts()], Architecture.t()) :: [{Bucket.t(), non_neg_integer()}]
  def bucket_counts(facts, %Architecture{buckets: buckets}) do
    Enum.map(buckets, fn bucket -> {bucket, Enum.count(facts, &selects?(bucket, &1))} end)
  end

  @doc """
  Classifies every module of `facts` (DND-5440) and reports what the run
  found: each unclassified module (`Failures.unclassified/1`, on its source
  file at its `defmodule` line), each ambiguous one (`Failures.ambiguous/2`,
  naming every matching bucket and the first selector that matched in it),
  then each bucket that selects fewer modules than its `min_modules`
  (`Failures.bucket_below_floor/4`, on `config_path`). Returns the classified
  modules keyed by module, and the issues in that order.
  """
  @spec classify_all([facts()], Architecture.t(), String.t() | nil) ::
          {%{module() => t()}, [Violation.t()]}
  def classify_all(facts, %Architecture{} = architecture, config_path) do
    {classified, issues} =
      Enum.reduce(facts, {%{}, []}, fn module_facts, acc ->
        add_classified(acc, module_facts, architecture)
      end)

    floors =
      for {bucket, count} <- bucket_counts(facts, architecture),
          count < bucket.min_modules,
          do: Failures.bucket_below_floor(bucket.name, count, bucket.min_modules, config_path)

    {classified, Enum.reverse(issues) ++ floors}
  end

  @doc "Classifies the module `facts` describes into exactly one bucket."
  @spec classify(facts(), Architecture.t()) ::
          {:ok, t()}
          | {:error, {:unclassified, module()}}
          | {:error, {:ambiguous, module(), [String.t()]}}
  def classify(%{module: module} = facts, %Architecture{} = architecture) do
    case Enum.filter(architecture.buckets, &selects?(&1, facts)) do
      [bucket] -> {:ok, build(facts, bucket, architecture)}
      [] -> {:error, {:unclassified, module}}
      several -> {:error, {:ambiguous, module, several |> Enum.map(& &1.name) |> Enum.sort()}}
    end
  end

  @doc """
  The context of `module`: its first `depth` name segments joined by `.`, or
  `nil` when it has fewer segments or is an Erlang module.
  """
  @spec context_of(module(), pos_integer()) :: String.t() | nil
  def context_of(module, depth) when is_atom(module) and is_integer(depth) and depth > 0 do
    case Atom.to_string(module) do
      "Elixir." <> name -> leading_segments(String.split(name, "."), depth)
      _erlang -> nil
    end
  end

  @doc """
  Each bucket that selects the module `facts` describes, in config order, with
  the first of its selectors that matched, described
  (`Anchor.Domain.Architecture.Selector.describe/1`).
  """
  @spec matching_selectors(facts(), Architecture.t()) :: [{String.t(), String.t()}]
  def matching_selectors(facts, %Architecture{buckets: buckets}) do
    for %Bucket{name: name, selectors: selectors} <- buckets,
        selector = Enum.find(selectors, &Selector.matches?(&1, facts)),
        selector != nil,
        do: {name, Selector.describe(selector)}
  end

  defp add_classified({classified, issues}, facts, architecture) do
    case classify(facts, architecture) do
      {:ok, %__MODULE__{} = one} ->
        {Map.put(classified, one.module, one), issues}

      {:error, {:unclassified, _module}} ->
        {classified, [Failures.unclassified(facts) | issues]}

      {:error, {:ambiguous, _module, _names}} ->
        {classified,
         [Failures.ambiguous(facts, matching_selectors(facts, architecture)) | issues]}
    end
  end

  defp leading_segments(segments, depth) when length(segments) < depth, do: nil
  defp leading_segments(segments, depth), do: segments |> Enum.take(depth) |> Enum.join(".")

  defp build(facts, bucket, architecture) do
    %__MODULE__{
      module: facts.module,
      bucket: bucket.name,
      role: bucket.role,
      context: context_of(facts.module, architecture.context_depth),
      app: facts.app,
      source_file: facts.source_file,
      interface?:
        bucket.name in architecture.interface_buckets or
          facts.module in architecture.interface_exports
    }
  end

  defp selects?(%Bucket{selectors: selectors}, facts),
    do: Enum.any?(selectors, &Selector.matches?(&1, facts))
end
