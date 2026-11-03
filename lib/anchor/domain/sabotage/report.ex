defmodule Anchor.Domain.Sabotage.Report do
  @moduledoc """
  The text of a sabotage run and its exit code (DND-5473). Pure **Domain**.

  One tab-separated line per mutant: id, `Module.name/arity`, operator,
  status, killers, how its tests were selected. A survivor's line ends with a
  `Fix:`; a `no_tests` mutant names the mirror path it looked for (or, when
  its tests ran none, says so); a `crashed` one says why, with a `Fix:`; an
  `invalid` one says why. A run that measured nothing ends with a
  `COULD NOT MEASURE` line. Then the skipped mutants (with their reason), the
  functions no mutant could be made of, the cap, and a summary that counts
  every status, `invalid` included. Before the summary, one line counts the
  mutants run by the source that chose their tests (`coverage`, `mirror`,
  `none`; DND-5474).

  The sabotage records written (DND-5484) are named before the summary, as
  `sabotage record created: <path>` or `appended`.

  Changed functions that yielded no mutant at all (every edit skipped, a
  macro, no mutable site) print one `sabotage: no mutant from M.f/a (file):
  <reason>` line each and `sabotage: no mutants generated from N changed
  functions: nothing was measured` (DND-5617); the exit code stays 0.

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
      counted and, beside a measured mutant, never changes the code.

  A mutant is measured when it was killed, survived or timed out.

  A sabotage record that could not be written (DND-5484) is said loudly,
  `sabotage: record not written: <why>`, and changes only a passing verdict:
  0 becomes 2. A survivor stays 1 and an unmeasured run stays 3 (DND-5641).
  """

  alias Anchor.Domain.Sabotage.Run

  @statuses [:killed, :survived, :timeout, :invalid, :crashed, :no_tests]
  @measured [:killed, :survived, :timeout]
  @failing [:survived, :crashed, :no_tests]

  @spec exit_code(Run.t()) :: 0 | 1 | pos_integer()
  def exit_code(%Run{refusal: {code, _message}}), do: code
  def exit_code(%Run{dry_run: true}), do: 0
  def exit_code(%Run{} = run), do: run |> verdict() |> verdict_code() |> with_record(run)

  # DND-5641: the measured verdict wins; a record that could not be written
  # turns only a pass into a failure (exit 2).
  defp with_record(0, %Run{record_error: message}) when is_binary(message), do: 2
  defp with_record(code, _run), do: code

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
        no_mutants(run) ++
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
        no_mutants(run) ++
        Enum.map(run.outcomes, &outcome/1) ++
        skipped(run) ++
        errors(run) ++
        not_run(run) ++
        sources(run) ++ records(run) ++ [summary(run)] ++ conclusion(verdict(run), run)
    )
  end

  # A diff that was read and holds no changed function is a clean scope; it is
  # never allowed to read like a run that measured something.
  defp zero_scope(%Run{changed_functions: 0, base: base}),
    do: ["sabotage: 0 changed functions in #{base}..HEAD"]

  defp zero_scope(_run), do: []

  # Changed functions that yielded no mutant at all: nothing was measured.
  # Still exit 0 (nothing to measure is not a failure), but never silent: one
  # line per function with its reason, then the count (DND-5617).
  defp no_mutants(%Run{changed_functions: n, generated: 0, no_mutant: functions})
       when is_integer(n) and n > 0 do
    Enum.map(functions, fn {function, reason} ->
      "sabotage: no mutant from #{mfa(function)} (#{function.file}): #{reason}"
    end) ++
      [
        "sabotage: no mutants generated from #{n} changed functions: nothing was measured " <>
          "(exit 0; see the lines above for why)"
      ]
  end

  defp no_mutants(_run), do: []

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

  defp records(run) do
    written =
      Enum.map(run.records, fn
        {:create, path} -> "sabotage record created: #{path}"
        {:append, path} -> "sabotage record appended: #{path}"
      end)

    if run.record_error,
      do: written ++ ["sabotage: record not written: " <> run.record_error],
      else: written
  end

  defp sources(%Run{outcomes: []}), do: []

  defp sources(run) do
    counts =
      run.outcomes
      |> Enum.frequencies_by(fn %{selection: {source, _tests}} -> source end)
      |> Enum.sort()
      |> Enum.map_join(", ", fn {source, n} -> "#{n} #{source}" end)

    ["tests selected by: #{counts}"]
  end

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
