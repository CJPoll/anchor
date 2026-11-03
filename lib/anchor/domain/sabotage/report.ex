defmodule Anchor.Domain.Sabotage.Report do
  @moduledoc """
  The text of a sabotage run and its exit code (DND-5473). Pure **Domain**.

  One tab-separated line per mutant: id, `Module.name/arity`, operator,
  status, killers, how its tests were selected. A survivor's line ends with a
  `Fix:`; a `no_tests` mutant names the mirror path it looked for; an
  `invalid` one says why. Then the skipped mutants (with their reason), the
  functions no mutant could be made of, the cap, and a summary that counts
  every status, `invalid` included.

  Exit codes: the refusal's own code; else 1 when a mutant survived or had no
  test; else 0 (every mutant run was killed, timed out or was invalid).
  """

  alias Anchor.Domain.Sabotage.Run

  @statuses [:killed, :survived, :timeout, :invalid, :no_tests]

  @spec exit_code(Run.t()) :: 0 | 1 | pos_integer()
  def exit_code(%Run{refusal: {code, _message}}), do: code
  def exit_code(%Run{dry_run: true}), do: 0

  def exit_code(%Run{outcomes: outcomes}) do
    if Enum.any?(outcomes, &(&1.status in [:survived, :no_tests])), do: 1, else: 0
  end

  @spec render(Run.t()) :: String.t()
  def render(%Run{refusal: {_code, message}} = run), do: lines(run.notes ++ [message])

  def render(%Run{restore: true} = run), do: lines(run.notes)

  def render(%Run{dry_run: true} = run) do
    planned =
      Enum.map(run.planned, fn {mutant, selection} ->
        tsv([mutant.id, mfa(mutant), mutant.operator, "planned", "", selected(selection)])
      end)

    lines(
      run.notes ++
        planned ++
        skipped(run) ++
        errors(run) ++
        not_run(run) ++
        ["anchor.sabotage run --dry-run: #{length(run.planned)} mutants planned; nothing applied"]
    )
  end

  def render(%Run{} = run) do
    lines(
      run.notes ++
        Enum.map(run.outcomes, &outcome/1) ++
        skipped(run) ++ errors(run) ++ not_run(run) ++ [summary(run)]
    )
  end

  defp outcome(%{mutant: mutant, status: status} = outcome) do
    base = [mutant.id, mfa(mutant), mutant.operator, status, killers(outcome.killers)]
    tsv(base ++ [selected(outcome.selection)] ++ tail(status, outcome))
  end

  defp tail(:survived, _outcome), do: ["Fix: add a test that fails under this mutant"]

  defp tail(:no_tests, %{reason: looked}),
    do: ["Fix: add #{looked}, or a test_mirror rule that finds this file's tests"]

  defp tail(:invalid, %{reason: reason}), do: [reason]
  defp tail(_status, _outcome), do: []

  defp selected({:none, []}), do: "selected by: none"
  defp selected({source, tests}), do: "selected by #{source}: #{Enum.join(tests, " ")}"

  defp killers(killers), do: Enum.map_join(killers, "; ", &killer/1)

  defp killer({file, line, name}), do: "#{file}:#{line} #{name}"
  defp killer(text) when is_binary(text), do: text

  defp skipped(run) do
    Enum.map(run.skipped, fn s ->
      tsv(["skipped", mfa(s), s.operator, inspect(s.target), s.reason])
    end)
  end

  defp errors(run) do
    Enum.map(run.errors, fn {function, reason} ->
      tsv(["error", function.file, mfa(function), error_text(reason)])
    end)
  end

  defp error_text(:not_in_source),
    do: "no literal def/defp clause in the source (a macro made it): no mutant, not killed"

  defp error_text({:parse_error, line, message}), do: "does not parse at line #{line}: #{message}"
  defp error_text({:unreadable, posix}), do: "could not be read (#{inspect(posix)})"
  defp error_text(other), do: inspect(other)

  defp not_run(%Run{not_run: []}), do: []

  defp not_run(%Run{not_run: not_run}),
    do: ["not run (cap): #{length(not_run)} mutants; rerun with --max all (CI)"]

  defp summary(run) do
    counts = Enum.frequencies_by(run.outcomes, & &1.status)
    by_status = Enum.map_join(@statuses, ", ", &"#{Map.get(counts, &1, 0)} #{&1}")

    "anchor.sabotage run: #{length(run.outcomes)} mutants run: #{by_status}; " <>
      "#{length(run.skipped)} skipped; #{length(run.not_run)} not run (cap); " <>
      "#{length(run.errors)} errors"
  end

  defp mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"
  defp mfa(%{module: module, name: name, arity: arity}), do: "#{inspect(module)}.#{name}/#{arity}"

  defp tsv(fields), do: Enum.map_join(fields, "\t", &to_string/1)

  defp lines(lines), do: Enum.join(lines, "\n")
end
