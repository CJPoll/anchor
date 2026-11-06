defmodule Mix.Tasks.Anchor.Baseline do
  @shortdoc "Writes an ast rule's baseline, or fails what a branch added to one (GREW)"

  @moduledoc """
  The ast (Credo-engine) rules' baseline ratchet, the **Framework** entry
  point (ADR 001; DND-5632). It makes one `Anchor.Managers.AstBaseline` call,
  prints the result and exits. It calls no adapter itself.

      mix anchor.baseline --write RULE_ID
      mix anchor.baseline --base REF

  An ast rule with `baseline: <path>` (and an `id`) has its findings compared
  with that file by its own Credo check, every `mix credo` run: a held
  finding is dropped, a NEW one stands, and an entry no finding matches
  (STALE) is a finding on the baseline path. A run given only some files
  (`mix credo lib/a.ex`) judges only the entries on files it read and notes
  the rest, so it never reports a false STALE.

    * `--write RULE_ID` creates that rule's baseline from its current
      findings: it compiles the project, runs Credo over the whole file set
      (its report is not printed) and writes the rule's keys, sorted. It only
      creates: it refuses (exit 2) when the file exists.
    * `--base REF` fails every entry the branch added to an ast rule's
      baseline since `REF` (GREW), read with `git show`, the base copy found
      by the rule's id in the config at `REF`. A first landing is a NOTE.
      Graph rules' baselines are `mix anchor.graph --base`'s.

  Output is one line per finding, `path[:line]: [enforce|report] <message>`,
  then `anchor.baseline: <B> ast baselines, <V> violations (<P>
  report-only)`.

  Exit codes: 0 pass (or written); 1 a GREW entry, or a baseline that could
  not be read or written; 2 usage, a `--base` ref Anchor refuses to pass to
  git, or a refused write; 3 COULD NOT MEASURE (no or invalid config, Credo
  halted, or the rule's check is not enabled).
  """

  use Mix.Task

  alias Anchor.Domain.AstBaseline, as: Ratchet
  alias Anchor.Domain.Baseline
  alias Anchor.Managers.AstBaseline

  @usage "Usage: mix anchor.baseline --write RULE_ID | --base REF"

  @switches [write: :string, base: :string]

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task. `opts` may hold `:compile` (a zero-arity function, default
  `Mix.Task.run("compile", [])`, run before `--write` only) and the
  Manager's adapter options, which tests inject here.
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(argv, opts) do
    case OptionParser.parse(argv, strict: @switches) do
      {[write: id], [], []} when id != "" -> write(id, opts)
      {[base: ref], [], []} -> base(ref, opts)
      _invalid -> usage()
    end
  end

  defp write(id, opts) do
    {compile, deps} = Keyword.pop(opts, :compile, &compile/0)
    compile.()
    finish(AstBaseline.write(%{root: File.cwd!(), id: id}, deps))
  end

  defp base(ref, opts) do
    if Baseline.valid_ref?(ref) do
      opts
      |> Keyword.delete(:compile)
      |> then(&AstBaseline.grew(%{root: File.cwd!(), ref: ref}, &1))
      |> finish()
    else
      usage()
    end
  end

  defp compile, do: Mix.Task.run("compile", [])

  defp finish(%{violations: violations, baselines: baselines, exit_code: code}) do
    Mix.shell().info(Ratchet.render(violations, baselines))

    case code do
      0 -> :ok
      code -> exit({:shutdown, code})
    end
  end

  defp usage do
    Mix.shell().error(
      @usage <>
        "\nFix: pass exactly one of --write RULE_ID (an ast rule with an id: and a baseline:) " <>
        "and --base REF (a branch, tag or commit: letters, digits and _ . / @ ^ ~ -, not " <>
        "starting with -)."
    )

    exit({:shutdown, 2})
  end
end
