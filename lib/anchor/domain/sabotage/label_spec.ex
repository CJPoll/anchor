defmodule Anchor.Domain.Sabotage.LabelSpec do
  @moduledoc """
  The match specs of a coverage run (DND-5691), as data. Pure **Domain**:
  `Anchor.Adapters.CallTracer` installs them, and the VM runs them at the call.

  Two values are read by the VM at the call, so attribution never depends on
  when a trace message arrives:

    * the **window word**, the trace control word. A test's window opens at an
      odd word and closes at the next even one. `test_started/2` and
      `test_finished/2` add 1; `module_finished/2` adds 2, so it stays even, and
      any word at or above the one it reports is past that module.
    * the **label**, the seq_trace token's label: a test's open word, or a
      module's atom. A process holds it from `register/1` (a test),
      `run_setup_all/4` or `exec_on_exit/3`, and it travels with every message
      that process sends. A guard cannot read it, so `call_spec/0` reads it in
      the body.

  Three of the functions are private to ExUnit (1.19.4). `CallTracer.start/2`
  refuses a pattern that matches no function, so an Elixir upgrade that moves
  one is a loud COULD NOT MEASURE, never a smaller map.

  Every call is traced: DND-5691's measurement after DND-5715 (slowest test at
  most 3.9 s in 3 builds of every call traced, against the 30 s the design set
  for needing one) settled that no silencing gate is built.
  """

  @event_manager ExUnit.EventManager
  @on_exit_handler ExUnit.OnExitHandler
  @runner ExUnit.Runner
  @label {:element, 2, {:get_seq_token}}

  @type pattern :: {mfa(), [tuple()], [:global | :local]}

  @doc "Every pattern that is not a project function: `{mfa, match spec, flags}`."
  @spec patterns() :: [pattern()]
  def patterns do
    [
      {{@event_manager, :test_started, 2}, window_spec(), [:global]},
      {{@event_manager, :test_finished, 2}, window_spec(), [:global]},
      {{@event_manager, :module_finished, 2}, module_finished_spec(), [:global]},
      {{@on_exit_handler, :register, 1}, entry_spec(), [:global]},
      {{@runner, :run_setup_all, 4}, setup_all_spec(), [:local]},
      {{@runner, :exec_on_exit, 3}, on_exit_spec(), [:local]}
    ]
  end

  @doc "A project function: the message is `{label or :none, word}`, read at the call."
  @spec call_spec() :: [tuple()]
  def call_spec do
    [
      {:_, [{:is_seq_trace}], [{:message, {{@label, {:get_tcw}}}}]},
      {:_, [], [{:message, {{:none, {:get_tcw}}}}]}
    ]
  end

  @doc "The modules `patterns/0` names, which must be loaded before a pattern can be set."
  @spec modules() :: [module()]
  def modules,
    do: patterns() |> Enum.map(fn {{module, _f, _a}, _s, _o} -> module end) |> Enum.uniq()

  defp window_spec do
    [{[:_, :"$1"], [], [{:set_tcw, {:+, {:get_tcw}, 1}}, {:message, {{:"$1", {:get_tcw}}}}]}]
  end

  defp module_finished_spec do
    [
      {[:_, %{__struct__: ExUnit.TestModule, name: :"$1"}], [],
       [{:set_tcw, {:+, {:get_tcw}, 2}}, {:message, {{:"$1", {:get_tcw}}}}]}
    ]
  end

  # The process's first call into ExUnit. An odd word is a test's process; an
  # even word is setup_all's, which already holds its module's label.
  defp entry_spec do
    [
      {:_, [{:==, {:band, {:get_tcw}, 1}, 1}],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, {{:entry, {:get_tcw}}}}]},
      {:_, [], [{:message, false}]}
    ]
  end

  defp setup_all_spec do
    [
      {[:_, %{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, {{:module, :"$1"}}}]}
    ]
  end

  defp on_exit_spec do
    [
      {[%{__struct__: ExUnit.TestModule, name: :"$1"}, :_, :_], [],
       [{:set_seq_token, :label, :"$1"}, {:message, false}]},
      {[%{__struct__: ExUnit.Test}, :_, :_], [],
       [{:set_seq_token, :label, {:get_tcw}}, {:message, false}]}
    ]
  end
end
