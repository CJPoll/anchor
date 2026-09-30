defmodule Anchor.Domain.AllowedCallers do
  @moduledoc """
  A `no_direct_dependency` rule's `allowed_callers` (DND-1269): the modules
  that may do what the rule forbids everyone else — a **Domain** module (ADR
  001). Pure: it parses entries and answers questions about parsed ones. No IO.

  ## An entry is one module, named exactly

  Each entry is an Elixir module name as its `defmodule` spells it in full
  (`Athena.Priorities.SlackNameAdapter`), in `Anchor.Domain.FunctionRef`'s
  grammar for a module. Anything else fails the load, through
  `Anchor.Domain.RuleSchema`:

    * a glob (`MyApp.Adapters.*`, `*`). An allow-list widens a rule, and a glob
      widens it again every time a later change adds a module with a matching
      name, with no config change to review. `*` allows every caller, so the
      rule would check nothing. Each allowed module is named, so each widening
      is a diff to this list;
    * an Erlang module (`:telemetry`). Elixir source never defines one, so
      Anchor could never find it;
    * anything that is not a module name.

  The name is not resolved through aliases: the config has no lexical scope, so
  a short name (`SlackNameAdapter`) is just a module no file defines, which the
  run reports (below).

  ## Who is exempt

  `allows?/2` is true only for a caller that is a listed module. Code is
  attributed to the module whose body it is in
  (`Anchor.Domain.DependencyAnalyzer`, *Attribution*); code whose module the
  source cannot show has the owner `nil`, which no list allows. The exemption
  covers every relation of the rule (`forbidden_modules`,
  `forbidden_patterns`, `forbidden_functions`, and dynamic calls that could
  reach a forbidden function), for that rule only.

  ## A listed caller that no longer exists

  `missing/2` names the entries no selected file defines. A rename or a move
  leaves the old name here, allowing nothing today and silently allowing
  whatever module is given that name later. `Anchor.Domain.RuleCoverage` reports
  it at run time, on a whole-project run only, like the `min_files` floor: a
  partial run cannot know which modules exist.
  """

  alias Anchor.Domain.FunctionRef

  @example "\"MyApp.Priorities.SlackNameAdapter\""

  @doc """
  Parses one `allowed_callers` entry into the module it names, or returns
  `{:error, reason}`, where `reason` says what is wrong with the entry and how
  to write it.
  """
  @spec parse(String.t()) :: {:ok, module()} | {:error, String.t()}
  def parse(token) when is_binary(token) do
    cond do
      String.contains?(token, "*") ->
        {:error,
         "is a glob, and a glob allows every module a later change gives a matching name " <>
           "(`*` allows every caller, so the rule checks nothing); " <> write_it()}

      String.starts_with?(token, ":") ->
        {:error,
         "names an Erlang module, which Elixir source never defines, so no caller could " <>
           "ever match it; " <> write_it()}

      FunctionRef.alias_name?(token) ->
        {:ok, Module.concat([token])}

      true ->
        {:error, "is not a module name; " <> write_it()}
    end
  end

  @doc """
  Whether `owner`, the module a piece of code belongs to, is one of `allowed`.
  An unknown owner (`nil`) is never allowed.
  """
  @spec allows?([module()], module() | nil) :: boolean()
  def allows?(_allowed, nil), do: false
  def allows?(allowed, owner), do: owner in allowed

  @doc """
  The entries of `allowed`, in order, that are not among `defined`, the modules
  the rule's selected files define.
  """
  @spec missing([module()], Enumerable.t()) :: [module()]
  def missing(allowed, defined) do
    defined = MapSet.new(defined)
    Enum.reject(allowed, &MapSet.member?(defined, &1))
  end

  defp write_it do
    "name each allowed module exactly, as its defmodule spells it in full (e.g. #{@example})"
  end
end
