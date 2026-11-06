defmodule Anchor.Domain.Sabotage.TestRunRefusal do
  @moduledoc """
  What a test run that could not start means for the whole run: its exit code
  and its message. Pure **Domain**, shared by `run` and `replay`
  (`Anchor.Managers.Sabotage.Runner`, `Anchor.Managers.Sabotage.Replay`).

  The `reason` is the one `Anchor.Adapters.TestExecution` gives. A missing
  `timeout` binary is exit 2, a tool to install; a results file that could not
  be cleared or a results directory that could not be made is exit 3, COULD NOT
  MEASURE.
  """

  @type reason ::
          :timeout_not_found
          | {:results_not_removed, String.t(), term()}
          | {:results_dir_not_created, String.t(), term()}

  @doc "The exit code a run ends with for `reason`."
  @spec code(reason()) :: pos_integer()
  def code(:timeout_not_found), do: 2
  def code({:results_not_removed, _path, _posix}), do: 3
  def code({:results_dir_not_created, _dir, _posix}), do: 3

  @doc "The message a run ends with for `reason`, ending with its `Fix:`."
  @spec message(reason()) :: String.t()
  def message(:timeout_not_found) do
    "the `timeout` binary was not found, so a test run could not be bounded. " <>
      "Fix: install coreutils timeout"
  end

  def message({:results_not_removed, path, posix}) do
    "COULD NOT MEASURE: the previous results file #{path} could not be removed " <>
      "(#{inspect(posix)}), so a test run's failures could be an earlier run's. " <>
      "Fix: remove #{path} by hand"
  end

  def message({:results_dir_not_created, dir, posix}) do
    "COULD NOT MEASURE: the results directory #{dir} could not be made " <>
      "(#{inspect(posix)}), so no test run's failures can be read. Fix: make #{dir} " <>
      "(or its parent) a writable directory"
  end
end
