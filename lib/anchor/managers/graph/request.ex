defmodule Anchor.Managers.Graph.Request do
  @moduledoc """
  What `mix anchor.graph` hands `Anchor.Managers.Graph.run/2` (DND-5440):
  plain data the Framework gathered from Mix, so the Manager never calls Mix.

    * `apps` — `[{app, ebin_dir}]`, every app of the project (an umbrella's
      every `apps/*` app);
    * `root` — the project root, where source paths are relative to;
    * `source_dirs` — `%{app => dir}`, the directory (relative to `root`)
      Mix compiled each app from: an umbrella's `apps/<app>`, from
      `Mix.Project.apps_paths/0` (DND-5637). Each beam's `relative_file` is
      relative to that directory, so the runner reads it there and keys it
      against `root`. An app with no entry was compiled from `root` itself;
    * `build_path` — `Mix.Project.build_path/0`, the build directory of this
      env (`_build/<env>`, or what `MIX_BUILD_PATH` / `MIX_BUILD_ROOT` say);
      the graph artifact is written under `<build_path>/anchor` (DND-5585);
    * `env` — the Mix env (`:dev`, `:test`, ...);
    * `opts` — `%{format: :text | :json, only: [rule_id]}`.
  """

  @enforce_keys [:apps, :root, :build_path, :env]
  defstruct [:apps, :root, :build_path, :env, source_dirs: %{}, opts: %{format: :text, only: []}]

  @type t :: %__MODULE__{
          apps: [{atom(), Path.t()}],
          root: Path.t(),
          source_dirs: %{atom() => Path.t()},
          build_path: Path.t(),
          env: atom(),
          opts: %{format: :text | :json, only: [String.t()]}
        }
end
