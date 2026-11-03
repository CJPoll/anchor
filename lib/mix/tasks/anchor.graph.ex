defmodule Mix.Tasks.Anchor.Graph do
  @shortdoc "Judges the compiled code against the architecture: section and the graph rules"

  @moduledoc """
  The graph engine's verdict, the **Framework** entry point (ADR 001;
  DND-5440). It compiles the project, gathers each app's ebin from Mix, makes
  one `Anchor.Managers.Graph.run/2` call, renders the report and exits. It
  calls no adapter itself.

      mix anchor.graph [--format text|json] [--only RULE_ID]...

  It builds the graph fresh from this compile's beams every run (never a
  cached verdict), classifies every project module into exactly one bucket of
  `.anchor.yml`'s `architecture:` section, checks every floor, and runs every
  graph rule. Text output is one line per finding,
  `path:line: [enforce|report] <rule label> <message> Fix: <shape>`, then the
  summary `anchor.graph: <M> modules in <A> apps, <R> rules, <V> violations
  (<P> report-only, <H> baselined)`. `--format json` prints the JSON document
  instead. `--only RULE_ID` (repeatable) runs only the rules with those ids
  (each still judged against its floor); an id that names no graph rule is
  COULD NOT MEASURE.

  It reads beams with `:beam_lib` only: no project module is loaded or run.
  The only file it writes is `_build/<env>/anchor/graph.etf`, the graph for
  `mix anchor.explain` and `place`; the verdict never reads it.

  Exit codes: 0 pass (report-only findings print); 1 a violation or a
  fail-closed issue (a module Anchor could not read or classify, a floor, a
  rule that crashed); 2 usage; 3 COULD NOT MEASURE (no or invalid config, no
  `architecture:` section, zero modules read). `--base` and
  `--write-baseline` come with baselines (DND-5441) and are refused until
  then.
  """

  use Mix.Task

  alias Anchor.Domain.GraphReport
  alias Anchor.Managers.Graph
  alias Anchor.Managers.Graph.Request

  @usage "Usage: mix anchor.graph [--format text|json] [--only RULE_ID]..."

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task. `opts` may hold `:compile` (a zero-arity function, default
  `Mix.Task.run("compile", [])`) and the Manager's adapter options, which
  tests inject here.
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(argv, opts) do
    case OptionParser.parse(argv, strict: [format: :string, only: :keep]) do
      {parsed, [], []} ->
        run_parsed(format(parsed[:format]), Keyword.get_values(parsed, :only), opts)

      _invalid ->
        usage()
    end
  end

  defp run_parsed(:invalid, _only, _opts), do: usage()

  defp run_parsed(format, only, opts) do
    {compile, deps} = Keyword.pop(opts, :compile, &compile/0)
    compile.()

    request = %Request{
      apps: ebins(),
      root: File.cwd!(),
      env: Mix.env(),
      opts: %{format: format, only: only}
    }

    report = Graph.run(request, deps)
    Mix.shell().info(GraphReport.render(report, format))
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
        "\nFix: pass only --format text|json and --only RULE_ID (repeatable); --base and " <>
        "--write-baseline arrive with baselines (DND-5441)."
    )

    exit({:shutdown, 2})
  end
end
