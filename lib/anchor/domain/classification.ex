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
  decide silently which rule a module is held to. The runner reports both
  errors.

  ## Context

  A module's context is its first `depth` name segments (`context_of/2`). A
  module with fewer segments, or an Erlang module, has no context (`nil`),
  which the interface and context rules report rather than skip.
  """

  alias Anchor.Domain.Architecture
  alias Anchor.Domain.Architecture.Bucket
  alias Anchor.Domain.Architecture.Selector

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
