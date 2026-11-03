defmodule Anchor.Adapters.GitEnv do
  @moduledoc """
  The environment every git command Anchor runs gets (DND-5581), shared by the
  **Side Effect** adapters `Anchor.Adapters.GitChangeSource` and
  `Anchor.Adapters.GitStatus` (ADR 001).

  Git finds its repository from the working directory unless the environment
  says otherwise. A git hook runs with `GIT_DIR` and `GIT_INDEX_FILE` set, and a
  wrapper can export `GIT_WORK_TREE`, so `mix anchor.sabotage` run there would
  read another repository's history or another index, and compute its scope
  from the wrong diff without any error. `env/0` unsets every variable git
  itself treats as repository-local (`git rev-parse --local-env-vars`: the set
  git clears when it enters a submodule), so the repository is always the one
  at the command's `cd:` root. It also sets `GIT_OPTIONAL_LOCKS=0`, so a read
  never refreshes the index.

  The list is held here, not read from git at run time; a test fails when the
  installed git names a variable it lacks.
  """

  @local_env_vars ~w(
    GIT_ALTERNATE_OBJECT_DIRECTORIES
    GIT_COMMON_DIR
    GIT_CONFIG
    GIT_CONFIG_COUNT
    GIT_CONFIG_PARAMETERS
    GIT_DIR
    GIT_GRAFT_FILE
    GIT_IMPLICIT_WORK_TREE
    GIT_INDEX_FILE
    GIT_NO_REPLACE_OBJECTS
    GIT_OBJECT_DIRECTORY
    GIT_PREFIX
    GIT_REPLACE_REF_BASE
    GIT_SHALLOW_FILE
    GIT_WORK_TREE
  )

  @doc "The `env:` option for `System.cmd/3`: repository-locating variables unset, optional locks off."
  @spec env() :: [{String.t(), String.t() | nil}]
  def env, do: [{"GIT_OPTIONAL_LOCKS", "0"} | Enum.map(@local_env_vars, &{&1, nil})]

  @doc "The variables `env/0` unsets."
  @spec local_env_vars() :: [String.t()]
  def local_env_vars, do: @local_env_vars
end
