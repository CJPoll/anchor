defmodule Anchor.Domain.ViolationKey do
  @moduledoc """
  The stable key of a graph rule's finding (DND-5441, shared contract section
  6) — a **Domain** module (ADR 001). Pure.

  A key is what a baseline file lists (`Anchor.Domain.Baseline`), so it must
  not move when unrelated code moves: it carries **no line number and no
  message text**, only `<rule>|<subject>|<detail>`:

    * `rule` — the rule's `id`, or its type when it has none (a rule that
      carries a `baseline` must have an `id`, so every baselined key starts
      with the id);
    * `subject` — what the finding is about, `Mod.fun/arity` or `Mod`;
    * `detail` — the rule's own target (for layering `-> Target.fun/arity`).

  A segment holding a newline would split one key over two baseline lines,
  so it raises `ArgumentError`.
  """

  @doc "The key of a finding of `rule` (a parsed rule map) about `subject`, with `detail`."
  @spec graph_key(map(), String.t(), String.t()) :: String.t()
  def graph_key(rule, subject, detail) do
    Enum.map_join([rule_name(rule), subject, detail], "|", &segment!/1)
  end

  @doc "The key segment naming `rule`: its `id`, or its type when it has none."
  @spec rule_name(map()) :: String.t()
  def rule_name(%{id: id}) when is_binary(id), do: id
  def rule_name(%{type: type}), do: Atom.to_string(type)

  @doc """
  `Mod.fun/arity` for an mfa, without the `Elixir.` prefix. An arity of `nil`
  (a dynamic call whose argument list is not literal) prints as `?`.
  """
  @spec mfa({module(), atom(), arity() | nil}) :: String.t()
  def mfa({module, name, nil}), do: "#{inspect(module)}.#{name}/?"
  def mfa({module, name, arity}), do: "#{inspect(module)}.#{name}/#{arity}"

  defp segment!(segment) when is_binary(segment) do
    if String.contains?(segment, ["\n", "\r"]) do
      raise ArgumentError, "a baseline key segment cannot hold a newline: #{inspect(segment)}"
    end

    segment
  end
end
