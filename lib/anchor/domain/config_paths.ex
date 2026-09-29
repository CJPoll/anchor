defmodule Anchor.Domain.ConfigPaths do
  @moduledoc """
  Pure computation of the ordered `.anchor.yml` candidate paths — a **Domain**
  module (ADR 001).

  `candidates/2` is a pure function of the working directory and a boolean
  saying whether that directory is an umbrella root. It does **no IO**: deciding
  which of the returned candidates actually exists on disk is the job of the
  Side Effect adapter `Anchor.Adapters.ConfigFile`.
  """

  @config_filename ".anchor.yml"

  @doc """
  Returns the ordered, de-duplicated list of `.anchor.yml` paths to try.

  `cwd` is the working directory. `apps?` is `true` when `cwd` is an umbrella
  root (it contains an `apps/` directory).

  The current directory's `.anchor.yml` is always the first candidate. The
  umbrella-root `.anchor.yml` (two directories up) is added as well when either

    * `cwd` is an umbrella root (`apps?`), or
    * `cwd` is an umbrella *app* directory — its immediate parent is `apps/`
      (BUG 5 fix). Run from `/proj/apps/my_app`, this yields `/proj/.anchor.yml`
      so the umbrella-root config is discoverable from inside an app.

  Paths are expanded, so a candidate that resolves to the same file as another
  is removed by the final de-duplication.

  `cwd` must be an absolute path. A relative one would be expanded against
  whatever the process cwd happens to be, so the lookup would search, and then
  report, the wrong place. It raises `ArgumentError` instead (DND-1265): the
  malformed key is rejected where it is produced, not where it fails to match.
  """
  def candidates(cwd, apps?) when is_binary(cwd) and is_boolean(apps?) do
    if Path.type(cwd) != :absolute do
      raise ArgumentError, "the cwd must be an absolute path, got: #{inspect(cwd)}"
    end

    root = Path.expand(@config_filename, cwd)

    [root | umbrella_root_candidates(cwd, apps?)]
    |> Enum.uniq()
  end

  defp umbrella_root_candidates(cwd, apps?) do
    if apps? or in_apps_subdir?(cwd) do
      [Path.expand(Path.join(["..", "..", @config_filename]), cwd)]
    else
      []
    end
  end

  defp in_apps_subdir?(cwd) do
    cwd |> Path.dirname() |> Path.basename() == "apps"
  end
end
