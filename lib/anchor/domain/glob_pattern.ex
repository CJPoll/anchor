defmodule Anchor.Domain.GlobPattern do
  @moduledoc """
  Pure glob and module-name pattern matching used for rule selection.

  Domain bucket (ADR 001): these are side-effect-free functions over strings.
  They never read a file, never parse an AST, and never call Credo — the same
  inputs always produce the same output.

  Three flavors of matching, each anchored (`^...$`, full-string match, never a
  partial match):

    * `matches_pattern?/2` — a glob where a single `*` matches within one path
      segment and does not cross a `/`.
    * `matches_recursive_pattern?/2` — a glob where `**` matches across path
      segments (`**/` matches zero or more leading segments, `/**` zero or more
      trailing segments) while a single `*` still stays within a segment.
    * `matches_module_pattern?/2` — a glob over a module name where `*` may
      cross dots (module separators), so `*.Schemas.*` matches `App.Schemas.User`.

  In every flavor a literal `.` in the pattern is escaped, so it matches only a
  real dot and is not a regex wildcard.
  """

  @doc """
  Returns `true` when `path` matches a single-`*` glob `pattern`.

  A `*` matches any run of non-`/` characters, so it stays within one path
  segment. The match is anchored: the whole path must match the whole pattern.
  """
  @spec matches_pattern?(String.t(), String.t()) :: boolean()
  def matches_pattern?(path, pattern) do
    Regex.match?(pattern_to_regex(pattern), path)
  end

  @doc """
  Returns `true` when `path` matches a recursive glob `pattern` (with `**`).

  `**/` matches zero or more leading path segments, `/**` zero or more trailing
  segments, and a bare `**` matches anything. A single `*` still matches only
  within one segment (does not cross a `/`). The match is anchored.
  """
  @spec matches_recursive_pattern?(String.t(), String.t()) :: boolean()
  def matches_recursive_pattern?(path, pattern) do
    Regex.match?(recursive_pattern_to_regex(pattern), path)
  end

  @doc """
  Returns `true` when `module_name` matches a module-name glob `pattern`.

  Unlike `matches_pattern?/2`, a `*` here may cross dots, so `*.Schemas.*`
  matches `App.Schemas.User` and `*Queries` matches `App.UserQueries`. The match
  is anchored.
  """
  @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
  def matches_module_pattern?(module_name, pattern) do
    Regex.match?(module_pattern_to_regex(pattern), module_name)
  end

  defp pattern_to_regex(pattern) do
    pattern
    |> String.replace(".", "\\.")
    |> String.replace("*", "[^/]*")
    |> then(&"^#{&1}$")
    |> Regex.compile!()
  end

  defp recursive_pattern_to_regex(pattern) do
    pattern
    |> String.replace(".", "\\.")
    # Temporarily protect `**` so the single-`*` rule below cannot touch it.
    |> String.replace("**", "___DOUBLE_STAR___")
    |> String.replace("*", "[^/]*")
    |> String.replace("___DOUBLE_STAR___/", "(.*/)?")
    |> String.replace("/___DOUBLE_STAR___", "(/.*)?")
    |> String.replace("___DOUBLE_STAR___", ".*")
    |> then(&"^#{&1}$")
    |> Regex.compile!()
  end

  defp module_pattern_to_regex(pattern) do
    pattern
    |> String.replace(".", "\\.")
    |> String.replace("*", ".*")
    |> then(&"^#{&1}$")
    |> Regex.compile!()
  end
end
