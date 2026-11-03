defmodule Anchor.Domain.Sabotage.Report do
  @moduledoc """
  The text of a sabotage run and its exit code (DND-5473). Pure **Domain**.

  One tab-separated line per mutant: id, `Module.name/arity`, operator,
  status, killers, how its tests were selected. A survivor's line ends with a
  `Fix:`; a `no_tests` mutant names the mirror path it looked for; an
  `invalid` one says why. Then the skipped mutants (with their reason), the
  functions no mutant could be made of, the cap, and a summary that counts
  every status, `invalid` included.

  Exit codes (DND-5570, the epic's amended invariant 6): the refusal's own
  code; a dry run 0; else

    * 0 when no mutant was run (zero changed functions from a good diff read
      is a legitimate empty scope, said loudly:
      `sabotage: 0 changed functions in <base>..HEAD`);
    * 3, `COULD NOT MEASURE`, when mutants were run and none was measured
      (every one invalid, crashed or without a test);
    * 1 when a mutant survived, or crashed, or had no test (an unmeasured
      mutant in a measured run fails like a survivor; DND-5483's survivors
      list will be where one gets a reason instead);
    * 0 otherwise. A mutant that did not compile (`invalid`) is listed and
      counted and never changes the code.

  A mutant is measured when it was killed, survived or timed out.
  """

  alias Anchor.Domain.Sabotage.Run

  @statuses [:killed, :survived, :timeout, :invalid, :crashed, :no_tests]
  @measured [:killed, :survived, :timeout]
  @failing [:survived, :crashed, :no_tests]

  @spec exit_code(Run.t()) :: 0 | 1 | pos_integer()
  def exit_code(%Run{refusal: {code, _message}}), do: code
  def exit_code(%Run{dry_run: true}), do: 0
  def exit_code(%Run{} = run), do: run |> verdict() |> verdict_code()

  defp verdict_code(:pass), do: 0
  defp verdict_code(:violation), do: 1
  defp verdict_code(:unmeasured), do: 3

  defp verdict(%Run{outcomes: []}), do: :pass

  defp verdict(%Run{outcomes: outcomes}) do
    statuses = Enum.map(outcomes, & &1.status)
    verdict(Enum.any?(statuses, &(&1 in @measured)), Enum.any?(statuses, &(&1 in @failing)))
  end

  defp verdict(false, _failing), do: :unmeasured
  defp verdict(true, true), do: :violation
  defp verdict(true, false), do: :pass

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
        zero_scope(run) ++
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
        zero_scope(run) ++
        Enum.map(run.outcomes, &outcome/1) ++
        skipped(run) ++
        errors(run) ++ not_run(run) ++ [summary(run)] ++ conclusion(verdict(run), run)
    )
  end

  # A diff that was read and holds no changed function is a clean scope; it is
  # never allowed to read like a run that measured something.
  defp zero_scope(%Run{changed_functions: 0, base: base}),
    do: ["sabotage: 0 changed functions in #{base}..HEAD"]

  defp zero_scope(_run), do: []

  defp conclusion(:unmeasured, run),
    do: [
      "COULD NOT MEASURE: #{length(run.outcomes)} mutants were run and none was measured " <>
        "(every one was invalid, crashed or had no test). Fix: make the mutants compile, " <>
        "the selected tests run, or add tests for the changed files; see the lines above"
    ]

  defp conclusion(_verdict, _run), do: []

  defp outcome(%{mutant: mutant, status: status} = outcome) do
    base = [mutant.id, mfa(mutant), mutant.operator, status, killers(outcome.killers)]
    tsv(base ++ [selected(outcome.selection)] ++ tail(status, outcome))
  end

  defp tail(:survived, _outcome), do: ["Fix: add a test that fails under this mutant"]

  defp tail(:no_tests, %{selection: {:none, _tests}, reason: looked}),
    do: ["Fix: add #{looked}, or a test_mirror rule that finds this file's tests"]

  defp tail(:no_tests, %{reason: reason}),
    do: [reason, "Fix: make the selected tests run at least one test under this mutant"]

  defp tail(:crashed, %{reason: reason}),
    do: [reason, "Fix: run the selected tests to see why the run crashed, then fix that"]

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
