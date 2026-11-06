defmodule Anchor.Domain.AstBaseline do
  @moduledoc """
  The shrink-only ratchet for an ast (Credo-engine) rule (DND-5632) — a
  **Domain** module (ADR 001). Pure: `Anchor.Managers.Lint` reads the file
  and the run's findings, this decides. The comparison itself is
  `Anchor.Domain.Baseline.compare/2`, shared with the graph engine.

  An ast rule's key is `<id>|<file>|<trigger>`
  (`Anchor.Domain.ViolationKey.ast_key/3`), so every entry names the file its
  finding sits in. That is what lets a run judge only what it read:

    * a run over the whole file set judges every entry, so an entry on a
      file that is gone is STALE;
    * a run Credo was given only some files (`mix credo lib/a.ex`) judges
      only the entries on files it read; the rest are **unjudged**, never
      STALE, and the run says how many (`Anchor.Domain.Failures.ast_baseline_unjudged/2`);
    * an entry on a file the run could not parse is unjudged too: the file's
      findings are unknown, not absent.

  `exit_code/1` and `render/2` are `mix anchor.baseline`'s verdict and text.
  """

  alias Anchor.Domain.Baseline
  alias Anchor.Domain.Violation

  @typedoc """
  What the run read: `whole?` (Credo had every file its config covers),
  the files it read and the ones among them it could not parse, each
  relative to the project root.
  """
  @type scope :: %{
          whole?: boolean(),
          read: MapSet.t(String.t()),
          unparsed: MapSet.t(String.t())
        }

  @doc """
  The file an entry of rule `rule_id` names: the segment after `<id>|`, up to
  the next `|`. `nil` when it names none.
  """
  @spec entry_file(String.t(), String.t()) :: String.t() | nil
  def entry_file(rule_id, entry) do
    prefix = rule_id <> "|"

    case String.split(entry, prefix, parts: 2) do
      ["", rest] -> rest |> String.split("|", parts: 2) |> hd() |> nonempty()
      _other -> nil
    end
  end

  @doc """
  Compares a rule's finding keys with its entries over `scope`: `new` (no
  entry covers it), `held`, `stale` (an entry no finding consumes, on a file
  the run judged) and `unjudged` (an entry on a file the run did not read or
  could not parse). Each list keeps its input order.
  """
  @spec judge(String.t(), [String.t()], [String.t()], scope()) :: %{
          new: [String.t()],
          held: [String.t()],
          stale: [String.t()],
          unjudged: [String.t()]
        }
  def judge(rule_id, keys, entries, scope) do
    {judged, unjudged} = Enum.split_with(entries, &judged?(entry_file(rule_id, &1), scope))
    %{new: new, held: held, stale: stale} = Baseline.compare(keys, judged)
    %{new: new, held: held, stale: stale, unjudged: unjudged}
  end

  @doc """
  `mix anchor.baseline`'s exit code: 1 when a violation is enforced (a GREW
  entry, a baseline that could not be read), else 0.
  """
  @spec exit_code([Violation.t()]) :: 0 | 1
  def exit_code(violations) do
    if Enum.any?(violations, &enforced?/1), do: 1, else: 0
  end

  @doc """
  `mix anchor.baseline`'s text: one line per violation,
  `path[:line]: [enforce|report] <message>`, then the summary over the
  `baselines` ast baselines it judged.
  """
  @spec render([Violation.t()], non_neg_integer()) :: String.t()
  def render(violations, baselines) do
    {enforced, reported} = Enum.split_with(violations, &enforced?/1)

    summary =
      "anchor.baseline: #{baselines} ast baselines, #{count(length(enforced), "violation")} " <>
        "(#{length(reported)} report-only)"

    Enum.map_join(violations ++ [summary], "\n", &line/1)
  end

  defp count(1, noun), do: "1 #{noun}"
  defp count(n, noun), do: "#{n} #{noun}s"

  defp enforced?(%Violation{enforcement: enforcement}), do: enforcement == :enforce

  defp nonempty(""), do: nil
  defp nonempty(file), do: file

  defp judged?(file, %{unparsed: unparsed, whole?: whole?, read: read}) do
    not MapSet.member?(unparsed, file) and (whole? or MapSet.member?(read, file))
  end

  defp line(summary) when is_binary(summary), do: summary

  defp line(%Violation{} = violation) do
    mode = if enforced?(violation), do: "enforce", else: "report"
    "#{location(violation)}: [#{mode}] #{violation.message}"
  end

  defp location(%Violation{filename: file, line: nil}), do: file
  defp location(%Violation{filename: file, line: line}), do: "#{file}:#{line}"
end
