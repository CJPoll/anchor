defmodule Anchor.Domain.Sabotage.Mutator do
  @moduledoc """
  The causal sabotage generator (DND-5471): every mutant the six operators
  (`Anchor.Domain.Sabotage.Operators`) make of one function, each with a
  stable id and a patch. Pure **Domain**: it reads a source string and returns
  data. No file, process, clock or code-loading access: nothing is compiled or
  evaluated, the text is only parsed.

  For each literal `def`/`defp` clause of the function (in source order) and
  each operator (in `Operators.all/0` order) it takes the operator's edits in
  source order, applies each to the source text by its range, and checks the
  result with `Anchor.Domain.Sabotage.OrphanCheck`. An edit that would not
  compile under `--warnings-as-errors` (a variable left unbound or unused, the
  last use of a private function, attribute, alias or import removed) is
  returned in `skipped` with the reason, never as a mutant.

  A mutant's id (`Anchor.Domain.Sabotage.MutantId`) hashes the module, the
  function, the operator, the variant, the normalized target node (its text
  read as quoted code, metadata stripped, printed with `Macro.to_string/1`)
  and its occurrence among equal operator, variant and target earlier in the
  function (skipped edits counted too, so an id never depends on another
  edit's fate). No line, column or path enters it.

  Results:

    * `{:ok, %{mutants: [...], skipped: [...]}}`; both empty for a function
      with no mutation target (`def f, do: :ok`);
    * `{:error, :not_in_source}` when no literal `def`/`defp` head covers the
      function (a macro-generated function);
    * `{:error, {:parse_error, line, message}}` when the source does not parse.
  """

  alias Anchor.Domain.Sabotage.Mutant
  alias Anchor.Domain.Sabotage.MutantId
  alias Anchor.Domain.Sabotage.Operators
  alias Anchor.Domain.Sabotage.OrphanCheck
  alias Anchor.Domain.Sabotage.Patch
  alias Anchor.Domain.Sabotage.Skipped
  alias Anchor.Domain.Sabotage.SourceTree

  @spec generate(String.t(), String.t(), {module(), atom(), arity()}, keyword()) ::
          {:ok, %{mutants: [Mutant.t()], skipped: [Skipped.t()]}}
          | {:error, :not_in_source}
          | {:error, {:parse_error, pos_integer(), String.t()}}
  def generate(source, path, {module, name, arity} = mfa, opts \\ [])
      when is_binary(source) and is_binary(path) and is_atom(module) and is_atom(name) and
             is_integer(arity) do
    operators = operators!(opts)
    tokens = Keyword.get(opts, :effect_calls, [])

    with {:ok, ast} <- SourceTree.parse(source),
         {:ok, clauses} <- SourceTree.function_clauses(ast, module, name, arity) do
      edits =
        for clause <- clauses,
            operator <- operators,
            edit <-
              apply(Operators, operator, [
                %{
                  source: source,
                  clause: clause,
                  clause_count: length(clauses),
                  effect_calls: tokens
                }
              ]),
            do: %{edit | target: normalize(edit.target)}

      {mutants, skipped} =
        edits
        |> with_occurrences()
        |> Enum.map(&build(&1, source, path, mfa))
        |> Enum.split_with(&match?(%Mutant{}, &1))

      {:ok, %{mutants: mutants, skipped: skipped}}
    end
  end

  defp build({edit, occurrence}, source, path, {module, name, arity} = mfa) do
    common = %{
      file: path,
      module: module,
      function: {name, arity},
      operator: edit.operator,
      variant: edit.variant,
      target: edit.target
    }

    mutated = Patch.apply_range(source, edit.range, edit.replacement)

    case edit_verdict(edit, source, mutated, mfa) do
      :ok ->
        struct!(
          Mutant,
          Map.merge(common, %{
            id:
              MutantId.compute(%{
                module: module,
                name: name,
                arity: arity,
                operator: edit.operator,
                variant: edit.variant,
                target: edit.target,
                occurrence: occurrence
              }),
            range: edit.range,
            original: Patch.slice(source, edit.range),
            replacement: edit.replacement,
            patch: Patch.unified_diff(path, source, mutated)
          })
        )

      {:edit_refused, reason} ->
        struct!(Skipped, Map.put(common, :reason, reason))

      {:mutant_refused, reason} ->
        struct!(
          Skipped,
          Map.merge(common, %{reason: reason, range: edit.range, replacement: edit.replacement})
        )
    end
  end

  # The node's text read as quoted code with its metadata stripped; text that
  # is not an expression on its own (none of the operators' targets) is kept
  # as written, trimmed.
  defp normalize(text) do
    case SourceTree.quoted(text) do
      {:ok, ast} ->
        ast |> Macro.prewalk(&Macro.update_meta(&1, fn _meta -> [] end)) |> Macro.to_string()

      :error ->
        String.trim(text)
    end
  end

  defp operators!(opts) do
    operators = Keyword.get(opts, :operators, Operators.all())
    unknown = operators -- Operators.all()

    if unknown != [] do
      raise ArgumentError,
            "Mutator.generate/4: unknown operators #{inspect(unknown)}; the operators are " <>
              inspect(Operators.all())
    end

    Enum.filter(Operators.all(), &(&1 in operators))
  end

  defp edit_verdict(%{skip: reason}, _source, _mutated, _mfa) when is_binary(reason),
    do: {:edit_refused, reason}

  defp edit_verdict(edit, source, mutated, mfa) do
    case OrphanCheck.check(source, mutated, mfa, edit.range) do
      :ok -> :ok
      {:skip, reason} -> {:mutant_refused, reason}
    end
  end

  defp with_occurrences(edits) do
    {numbered, _seen} =
      Enum.map_reduce(edits, %{}, fn edit, seen ->
        key = {edit.operator, edit.variant, edit.target}
        {{edit, Map.get(seen, key, 0)}, Map.update(seen, key, 1, &(&1 + 1))}
      end)

    numbered
  end
end
