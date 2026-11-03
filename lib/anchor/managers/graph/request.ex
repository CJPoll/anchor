defmodule Anchor.Managers.Graph.Request do
  @moduledoc """
  What `mix anchor.graph` hands `Anchor.Managers.Graph.run/2` (DND-5440):
  plain data the Framework gathered from Mix, so the Manager never calls Mix.

    * `apps` — `[{app, ebin_dir}]`, every app of the project (an umbrella's
      every `apps/*` app);
    * `root` — the project root, where source paths are relative to and
      `_build/<env>/anchor` lives;
    * `env` — the Mix env (`:dev`, `:test`, ...);
    * `opts` — `%{format: :text | :json, only: [rule_id]}`.
  """

  @enforce_keys [:apps, :root, :env]
  defstruct [:apps, :root, :env, opts: %{format: :text, only: []}]

  @type t :: %__MODULE__{
          apps: [{atom(), Path.t()}],
          root: Path.t(),
          env: atom(),
          opts: %{format: :text | :json, only: [String.t()]}
        }
end
