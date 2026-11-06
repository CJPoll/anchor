defmodule Anchor.TestPreload do
  @moduledoc """
  Loads every module of an application and its dependency closure before the
  suite runs a test, the way a release boots in embedded mode (DND-5690; the
  same shape as gen_saas's `GenSaas.TestPreload`, DND-2282).

  `mix test` runs the VM in interactive mode: a module is loaded the first time
  something calls it, and that load is a synchronous request to the one
  `code_server` process, which also serves the test files Elixir 1.19 compiles
  while tests run. Loading the closure first keeps those loads out of every
  test. It does not cover what still reaches `code_server` at run time: test
  modules compiled while the suite runs, modules a test compiles (fixtures,
  Hammox mocks), and `:mix`, which is outside the closure because no application
  lists it.

  `test/test_helper.exs` calls `load!/1` before `ExUnit.start/0`, and
  `Anchor.TestBootTest` fails when it stops. Mix's own `--preload-modules` is
  not used: it reaches only a run that passes it and only applications already
  loaded, and it discards the load's result, so a module that cannot load would
  be skipped with nothing said.

  Every name comes from an application's module list, never a guess, so a miss
  here is a real miss.
  """

  @doc """
  `app` and every application it needs, transitively: `:applications`,
  `:included_applications`, and each `:optional_applications` entry that is
  loaded (an optional dependency absent from this build is skipped). A required
  application that is not loaded raises: its modules cannot be listed, and a
  closure missing it would load less than it claims.
  """
  @spec apps(atom()) :: [atom()]
  def apps(app) when is_atom(app) do
    app
    |> closure(MapSet.new())
    |> Enum.sort()
  end

  @doc """
  Loads every module of `app`'s closure and returns how many applications and
  modules that was. A module that fails to load raises, naming it and the
  reason: a preload that skips one leaves the on-demand load it exists to
  remove.
  """
  @spec load!(atom()) :: %{apps: non_neg_integer(), modules: non_neg_integer()}
  def load!(app) do
    apps = apps(app)
    modules = modules(apps)

    case :code.ensure_modules_loaded(modules) do
      :ok -> %{apps: length(apps), modules: length(modules)}
      {:error, failures} -> raise load_failed_message(app, failures)
    end
  end

  @doc "Every module the applications in `apps` list, sorted and each once."
  @spec modules([atom()]) :: [module()]
  def modules(apps) when is_list(apps) do
    apps
    |> Enum.flat_map(&spec!(&1, :modules))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "The modules of `app`'s closure that are not loaded, sorted."
  @spec unloaded(atom()) :: [module()]
  def unloaded(app) do
    app
    |> apps()
    |> modules()
    |> Enum.reject(&:erlang.module_loaded/1)
  end

  defp closure(app, seen) do
    if MapSet.member?(seen, app) do
      seen
    else
      # An optional dependency is listed in :applications too; only the ones
      # present in this build are part of the closure.
      optional = spec(app, :optional_applications)
      needed = (spec!(app, :applications) -- optional) ++ spec!(app, :included_applications)
      present = Enum.filter(optional, &loaded?/1)
      Enum.reduce(needed ++ present, MapSet.put(seen, app), &closure/2)
    end
  end

  defp load_failed_message(app, failures) do
    listed =
      Enum.map_join(failures, "\n", fn {module, reason} ->
        "  #{inspect(module)}: #{inspect(reason)}"
      end)

    "#{length(failures)} module(s) of #{inspect(app)}'s closure failed to load:\n#{listed}\n" <>
      "Fix: a module that cannot load is broken in this build (a missing beam or NIF, a " <>
      "failing on_load); repair it, or stop listing its application as a dependency."
  end

  defp loaded?(app), do: Application.spec(app, :vsn) != nil

  defp not_loaded_message(app) do
    "application #{inspect(app)} is not loaded, so its modules cannot be listed. " <>
      "Fix: load it before preloading (Application.load(#{inspect(app)})), or check the " <>
      "name: it must be an application in this build."
  end

  defp spec(app, key), do: Application.spec(app, key) || []

  defp spec!(app, key) do
    case Application.spec(app, key) do
      nil -> raise ArgumentError, not_loaded_message(app)
      value -> value
    end
  end
end
