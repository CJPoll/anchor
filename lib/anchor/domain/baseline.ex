defmodule Anchor.Domain.Baseline do
  @moduledoc """
  The shrink-only ratchet (DND-5441, shared contract section 8) — a **Domain**
  module (ADR 001). Pure: it parses a baseline file's bytes, compares a rule's
  finding keys with its entries, and renders a new file. No IO.

  ## The file

  One key per line. A line whose first non-blank character is `#` is a
  comment, a blank line is ignored, and trailing whitespace is stripped. The
  entries form a **multiset**: a key listed twice holds two findings with that
  key. A key carries no line number and no message text (`Anchor.Domain.ViolationKey`),
  so moving code does not churn the file. The convention is
  `.anchor/baselines/<rule-id>.txt`; every entry starts with the rule's id and
  `|`, so a file holding another rule's entries is refused (`foreign/2`).

  ## The comparison

    * `compare/2` — a finding whose key no entry covers is **new** (it fails an
      `enforce` rule); an entry no finding consumes is **stale** (it fails too:
      the finding was fixed, so the line must go); covered findings are
      **held**.
    * `grew/2` — the entries of the working file that the base branch's copy
      does not hold (multiset difference): a baseline only shrinks, so adding
      to it in a branch fails as GREW.
  """

  @doc """
  Parses a baseline file. Returns the keys in file order, or
  `{:error, {:line, n, :invalid_utf8}}` for the first line (1-based) that is
  not UTF-8.
  """
  @spec parse(binary()) :: {:ok, [String.t()]} | {:error, {:line, pos_integer(), :invalid_utf8}}
  def parse(bytes) when is_binary(bytes) do
    bytes
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, &parse_line/2)
    |> then(fn
      {:ok, keys} -> {:ok, Enum.reverse(keys)}
      error -> error
    end)
  end

  defp parse_line({line, number}, {:ok, keys}) do
    if String.valid?(line) do
      {:cont, {:ok, add_key(String.trim(line), keys)}}
    else
      {:halt, {:error, {:line, number, :invalid_utf8}}}
    end
  end

  defp add_key("", keys), do: keys
  defp add_key("#" <> _comment, keys), do: keys
  defp add_key(key, keys), do: [key | keys]

  @doc """
  Compares `finding_keys` (one per finding) with `entries` as multisets:
  `new` are the finding keys no entry covers, `stale` the entries no finding
  consumes, `held` the finding keys an entry covers. Each list keeps its input
  order.
  """
  @spec compare([String.t()], [String.t()]) :: %{
          new: [String.t()],
          stale: [String.t()],
          held: [String.t()]
        }
  def compare(finding_keys, entries) do
    {held, new, left} =
      Enum.reduce(finding_keys, {[], [], counts(entries)}, fn key, {held, new, left} ->
        case Map.get(left, key, 0) do
          0 -> {held, [key | new], left}
          n -> {[key | held], new, Map.put(left, key, n - 1)}
        end
      end)

    %{new: Enum.reverse(new), stale: remaining(entries, left), held: Enum.reverse(held)}
  end

  @doc """
  The entries `working` holds beyond `base` (multiset difference), in
  `working` order: what a branch added to a baseline. An entry the branch
  dropped is not growth.
  """
  @spec grew([String.t()], [String.t()]) :: [String.t()]
  def grew(working, base) do
    {grown, _left} =
      Enum.reduce(working, {[], counts(base)}, fn key, {grown, left} ->
        case Map.get(left, key, 0) do
          0 -> {[key | grown], left}
          n -> {grown, Map.put(left, key, n - 1)}
        end
      end)

    Enum.reverse(grown)
  end

  @doc """
  The entries of `entries` that do not belong to the rule `rule_id`: every
  entry starts with the rule's id and `|`.
  """
  @spec foreign(String.t(), [String.t()]) :: [String.t()]
  def foreign(rule_id, entries) do
    prefix = rule_id <> "|"
    Enum.reject(entries, &String.starts_with?(&1, prefix))
  end

  @doc """
  The baseline file for `rule_id` holding `keys`: a header comment, the keys
  sorted, a trailing newline.
  """
  @spec render(String.t(), [String.t()]) :: String.t()
  def render(rule_id, keys) do
    Enum.join(["# anchor baseline for #{rule_id}; shrink only" | Enum.sort(keys)], "\n") <> "\n"
  end

  @doc """
  Whether `ref` is a git ref `mix anchor.graph --base` may pass to git: a
  non-empty string of letters, digits and `_ . / @ ^ ~ -` that does not start
  with `-` (it would read as an option). Anything else is refused before git
  runs.
  """
  @spec valid_ref?(term()) :: boolean()
  def valid_ref?("-" <> _option), do: false
  def valid_ref?(""), do: false

  def valid_ref?(ref) when is_binary(ref),
    do: ref |> String.to_charlist() |> Enum.all?(&ref_char?/1)

  def valid_ref?(_ref), do: false

  defp ref_char?(char) when char in ?a..?z or char in ?A..?Z or char in ?0..?9, do: true
  defp ref_char?(char), do: char in ~c"_./@^~-"

  defp counts(keys), do: Enum.frequencies(keys)

  # The entries still left over in `left`, in `entries` order.
  defp remaining(entries, left) do
    {stale, _left} =
      Enum.reduce(entries, {[], left}, fn key, {stale, left} ->
        case Map.get(left, key, 0) do
          0 -> {stale, left}
          n -> {[key | stale], Map.put(left, key, n - 1)}
        end
      end)

    Enum.reverse(stale)
  end
end
