defmodule Mix.Tasks.Anchor.Graph do
  @shortdoc "Judges the compiled code against the architecture: section and the graph rules"

  @moduledoc """
  The graph engine's verdict, the **Framework** entry point (ADR 001;
  DND-5440). It compiles the project, gathers each app's ebin from Mix, makes
  one `Anchor.Managers.Graph.run/2` call, renders the report and exits. It
  calls no adapter itself.

      mix anchor.graph [--format text|json] [--only RULE_ID]... [--base REF]
                       [--write-baseline RULE_ID] [--verbose]

  It builds the graph fresh from this compile's beams every run (never a
  cached verdict), classifies every project module into exactly one bucket of
  `.anchor.yml`'s `architecture:` section, checks every floor, and runs every
  graph rule. Text output is one line per finding,
  `path:line: [enforce|report] <rule label> <message> Fix: <shape>`, then the
  summary `anchor.graph: <M> modules in <A> apps, <R> rules, <V> violations
  (<P> report-only, <H> baselined)`, ending `; apply sites: <r> resolved, <a>
  any` when a rule that runs needs the higher-order flow analysis (DND-5574).
  `--format json` prints the JSON document
  instead. `--only RULE_ID` (repeatable) runs only the rules with those ids
  (each still judged against its floor); an id that names no graph rule is
  COULD NOT MEASURE.

  Baselines (DND-5441): a rule with `baseline: <path>` has its findings
  compared with that file; held findings are counted (`--verbose` prints
  them), NEW ones fail an `enforce` rule, and an entry no finding matches
  (STALE) fails too. `--base REF` also fails every entry the branch added to a
  baseline since `REF` (GREW), read with `git show`; a baseline absent at `REF`
  is a first landing, printed as a NOTE. `--write-baseline RULE_ID` creates
  that rule's baseline from its current findings, and refuses (exit 2) when
  the file exists.

  It reads beams with `:beam_lib` only: no project module is loaded or run.
  The only file it writes is `_build/<env>/anchor/graph.etf`, the graph for
  `mix anchor.explain` and `place`; the verdict never reads it.
  `--write-baseline` also creates the one baseline file it names.

  Exit codes: 0 pass (report-only and held findings print); 1 a violation
  or a fail-closed issue (a module Anchor could not read or classify, a
  floor, a rule that crashed, a baseline that could not be read, STALE or
  GREW); 2 usage, a `--base` ref Anchor refuses to pass to git, or a
  `--write-baseline` refusal; 3 COULD NOT MEASURE (no or invalid config, no
  `architecture:` section, zero modules read).
  """

  use Mix.Task

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.GraphReport
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  @usage "Usage: mix anchor.graph [--format text|json] [--only RULE_ID]... [--base REF] " <>
           "[--write-baseline RULE_ID] [--verbose]"

  @switches [
    format: :string,
    only: :keep,
    base: :string,
    write_baseline: :string,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task. `opts` may hold `:compile` (a zero-arity function, default
  `Mix.Task.run("compile", [])`) and the Manager's adapter options, which
  tests inject here.
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(argv, opts) do
    case OptionParser.parse(argv, strict: @switches) do
      {parsed, [], []} -> run_parsed(request_opts(parsed), opts)
      _invalid -> usage()
    end
  end

  # The Manager's request options, or `:invalid` (a usage error): an unknown
  # --format, or a --base ref Anchor would not pass to git
  # (`Anchor.Domain.Baseline.valid_ref?/1`).
  defp request_opts(parsed) do
    base = parsed[:base]

    with format when format != :invalid <- format(parsed[:format]),
         true <- is_nil(base) or Baseline.valid_ref?(base) do
      %{
        format: format,
        only: Keyword.get_values(parsed, :only),
        base: base,
        write_baseline: parsed[:write_baseline],
        verbose: parsed[:verbose] == true
      }
    else
      _invalid -> :invalid
    end
  end

  defp run_parsed(:invalid, _opts), do: usage()

  defp run_parsed(request_opts, opts) do
    {compile, deps} = Keyword.pop(opts, :compile, &compile/0)
    compile.()

    request = %Request{
      apps: ebins(),
      root: File.cwd!(),
      env: Mix.env(),
      opts: request_opts
    }

    report = Graph.run(request, deps)

    Mix.shell().info(
      GraphReport.render(report, request_opts.format, verbose: request_opts.verbose)
    )

    finish(report.exit_code)
  end

  defp compile, do: Mix.Task.run("compile", [])

  defp ebins do
    case Mix.Project.apps_paths() do
      nil ->
        [{Mix.Project.config()[:app], Mix.Project.compile_path()}]

      apps ->
        build = Mix.Project.build_path()

        apps
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(&{&1, Path.join([build, "lib", Atom.to_string(&1), "ebin"])})
    end
  end

  defp finish(0), do: :ok
  defp finish(code), do: exit({:shutdown, code})

  defp format(nil), do: :text
  defp format("text"), do: :text
  defp format("json"), do: :json
  defp format(_other), do: :invalid

  defp usage do
    Mix.shell().error(
      @usage <>
        "\nFix: pass only --format text|json, --only RULE_ID (repeatable), --base REF (a " <>
        "branch, tag or commit: letters, digits and _ . / @ ^ ~ -, not starting with -), " <>
        "--write-baseline RULE_ID and --verbose."
    )

    exit({:shutdown, 2})
  end
end
