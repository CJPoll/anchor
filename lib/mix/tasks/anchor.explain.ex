defmodule Mix.Tasks.Anchor.Explain do
  @shortdoc "Says what a module or path is, what it may call and which rules select it"

  @moduledoc """
  Ask Anchor before you write: the **Framework** entry point (ADR 001;
  DND-5446) of `Anchor.Managers.Explain`. It compiles the project, gathers
  the Mix facts a graph run takes, makes one Manager call and prints the
  answer. It calls no adapter itself.

      mix anchor.explain <path|Module> [--format text|json]

  For a module, or the module a source path defines (or would define, by
  Elixir's file naming convention, when the file does not exist yet), it
  prints, from `.anchor.yml` and the compiled graph only, never from prose:

    * its classification: bucket and role, context, app, whether it is its
      context's interface, and its aggregate;
    * what it may call: its bucket's `calls` row, resolved to the concrete
      modules (only the interface modules of other contexts), and the
      buckets it must not call;
    * every rule of either engine that selects it, with its enforcement and
      its conforming shape (the text its findings' `Fix:` lines end with);
    * its findings in the last `mix anchor.graph` run's graph, used only when
      that graph's key matches this build (else `not computed`).

  A path that does not exist yet is classified by its path and the module
  name it implies; the facts only a beam has (behaviours, `use`s, exported
  functions, its app) are listed as unknown until compiled. If the project
  does not compile, it still answers from the config and the paths. It
  writes no file of its own: the compile it runs writes `_build` as `mix
  compile` does, and the graph artifact is `mix anchor.graph`'s. It loads no
  project module.

  `--format json` prints `{subject, module, path, exists, notes,
  classification, may_call, must_not_call, rules, findings, unknown}` for
  agents.

  Exit codes: 0 answered; 2 usage (no subject, two subjects, an unknown
  option, or a subject that is neither a module name nor an `.ex` path under
  the project root); 3 no or invalid config, or no `architecture:` section.
  """

  use Mix.Task

  alias Anchor.Domain.Explain
  alias Anchor.Managers.Explain, as: ExplainManager
  alias Anchor.Managers.Graph.Request
  alias Mix.Tasks.Anchor.Graph, as: GraphTask

  @usage "Usage: mix anchor.explain <path|Module> [--format text|json]"

  @impl Mix.Task
  def run(argv), do: run(argv, [])

  @doc """
  Runs the task. `opts` may hold `:compile` (a zero-arity function returning
  whether the project compiled, default `Mix.Task.run("compile", [])`) and
  the Manager's adapter options, which tests inject here.
  """
  @spec run([String.t()], keyword()) :: :ok
  def run(argv, opts) do
    case OptionParser.parse(argv, strict: [format: :string]) do
      {parsed, [subject], []} -> run_parsed(subject, format(parsed[:format]), opts)
      _invalid -> usage()
    end
  end

  defp run_parsed(_subject, :invalid, _opts), do: usage()

  defp run_parsed(subject, format, opts) do
    {compile, deps} = Keyword.pop(opts, :compile, &compile/0)
    compiled? = compile.()

    request = %{
      argument: subject,
      compiled?: compiled?,
      graph: %Request{
        apps: GraphTask.ebins(),
        root: File.cwd!(),
        build_path: Mix.Project.build_path(),
        env: Mix.env()
      }
    }

    case ExplainManager.explain(request, deps) do
      {:ok, explain} ->
        Mix.shell().info(Explain.render(explain, format))

      {:error, {:could_not_check, violation}} ->
        Mix.shell().error("#{violation.filename}: #{violation.message}")
        exit({:shutdown, 3})

      {:error, {:usage, _reason}} ->
        Mix.shell().error(
          "#{inspect(subject)} is neither a module name nor an .ex path under the project " <>
            "root. Fix: pass a path relative to the project root or a module name."
        )

        exit({:shutdown, 2})
    end
  end

  # A compile that fails still gets an answer from the config and the paths;
  # the Manager reads no beam then.
  defp compile do
    case Mix.Task.run("compile", []) do
      {:error, _diagnostics} -> false
      _ok_or_noop -> true
    end
  rescue
    _compile_error -> false
  end

  defp format(nil), do: :text
  defp format("text"), do: :text
  defp format("json"), do: :json
  defp format(_other), do: :invalid

  defp usage do
    Mix.shell().error(
      @usage <>
        "\nFix: pass exactly one subject (a module name such as MyApp.Accounts.User, or a " <>
        "path such as lib/my_app/accounts/user.ex) and only --format text|json."
    )

    exit({:shutdown, 2})
  end
end
