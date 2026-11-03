defmodule Mix.Tasks.Anchor.Graph do
  @shortdoc "Judges the compiled code against the architecture: section and the graph rules"

  @moduledoc """
  The graph engine's verdict, the **Framework** entry point (ADR 001;
  DND-5440). It compiles the project, gathers each app's ebin from Mix, makes
  one `Anchor.Managers.Graph.run/2` call, renders the report and exits. It
  calls no adapter itself.

      mix anchor.graph [--format text|json] [--only RULE_ID]... [--base REF]
                       [--write-baseline RULE_ID] [--project DIR] [--verbose]

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

  `--project DIR` (DND-5658) judges another checkout with this one's
  Anchor: DIR's `.anchor.yml`, sources, baselines and git (`--base` resolves
  there), and DIR's beams, at this project's compile path relative to its
  root (`_build/dev/lib/anchor/ebin` under `MIX_ENV=dev`), which DIR's own
  compile wrote. This checkout is still compiled (it is the judge); DIR is
  not, and an ebin with no beams is COULD NOT MEASURE. CI runs it from a
  checkout of the base branch (`bin/ci/base-judge.sh`), so the ratchet that
  judges a pull request is the code landed on its base, never the pull
  request's own. It refuses (exit 2) a DIR that is not a directory, an
  umbrella judge, a compile path outside this checkout (`MIX_BUILD_PATH`), and
  `--write-baseline`: the judge never writes the judged tree.

  It reads beams with `:beam_lib` only: no project module is loaded or run.
  The only file it writes is `<build_path>/anchor/graph.etf` (Mix's build
  path: `_build/<env>`, or what `MIX_BUILD_PATH` names), the graph for
  `mix anchor.explain` and `place`; the verdict never reads it.
  `--write-baseline` also creates the one baseline file it names.

  Exit codes: 0 pass (report-only and held findings print); 1 a violation
  or a fail-closed issue (a module Anchor could not read or classify, a
  floor, a rule that crashed, a baseline that could not be read, STALE or
  GREW); 2 usage, a `--base` ref Anchor refuses to pass to git, a
  `--project` refusal, or a `--write-baseline` refusal; 3 COULD NOT MEASURE (no or invalid config, no
  `architecture:` section, zero modules read).
  """

  use Mix.Task

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.GraphReport
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  @usage "Usage: mix anchor.graph [--format text|json] [--only RULE_ID]... [--base REF] " <>
           "[--write-baseline RULE_ID] [--project DIR] [--verbose]"

  @switches [
    format: :string,
    only: :keep,
    base: :string,
    write_baseline: :string,
    project: :string,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task. `opts` may hold `:compile` (a zero-arity function, default
  `Mix.Task.run("compile", [])`), `:apps_paths` (default
  `Mix.Project.apps_paths/0`: an umbrella's `%{app => dir}`, `nil` for a
  single project) and the Manager's adapter options, which tests inject
  here.
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(argv, opts) do
    case OptionParser.parse(argv, strict: @switches) do
      {parsed, [], []} -> run_parsed(request_opts(parsed), parsed[:project], opts)
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

  defp run_parsed(:invalid, _project, _opts), do: usage()

  defp run_parsed(request_opts, project, opts) do
    {compile, deps} = Keyword.pop(opts, :compile, &compile/0)
    {apps_paths, deps} = Keyword.pop_lazy(deps, :apps_paths, &Mix.Project.apps_paths/0)
    target = target(project, apps_paths, request_opts)
    compile.()

    request = %Request{
      apps: target.apps,
      # An umbrella app's beams carry paths relative to its own directory,
      # where Mix compiled it (DND-5637).
      source_dirs: apps_paths || %{},
      root: target.root,
      build_path: Mix.Project.build_path(),
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

  # What is judged: this project (its root and ebins), or under `--project
  # DIR` (DND-5658) the checkout at DIR, read at this project's own compile
  # path relative to its root. The judge's build stays its own: the graph
  # artifact is written under this checkout's build path, never DIR's.
  defp target(nil, apps_paths, _request_opts),
    do: %{root: File.cwd!(), apps: ebins(apps_paths)}

  defp target(project, apps_paths, request_opts) do
    root = Path.expand(project)
    compile_path = Path.relative_to(Mix.Project.compile_path(), File.cwd!())

    cond do
      request_opts.write_baseline != nil ->
        refuse_project("--write-baseline writes the judged tree; run it in #{project} itself")

      not File.dir?(root) ->
        refuse_project("#{project} is not a directory")

      apps_paths != nil ->
        refuse_project("judging another checkout from an umbrella is not supported")

      Path.type(compile_path) != :relative ->
        refuse_project("the compile path #{compile_path} is outside this checkout")

      true ->
        %{root: root, apps: [{Mix.Project.config()[:app], Path.join(root, compile_path)}]}
    end
  end

  defp refuse_project(reason) do
    Mix.shell().error(
      "anchor.graph: --project refused: #{reason}. Fix: pass --project the root of a " <>
        "compiled single-project checkout, from a checkout whose build path is under its " <>
        "own root (unset MIX_BUILD_PATH)."
    )

    exit({:shutdown, 2})
  end

  defp ebins(apps_paths) do
    case apps_paths do
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
        "--write-baseline RULE_ID, --project DIR and --verbose."
    )

    exit({:shutdown, 2})
  end
end
