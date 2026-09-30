defmodule Anchor.Domain.GlobPattern do
  @moduledoc """
  Pure glob and module-name pattern matching used for rule selection.

  Domain bucket (ADR 001): these are side-effect-free functions over strings.
  They never read a file, never parse an AST, and never call Credo — the same
  inputs always produce the same output.

  Four flavors of matching, each anchored (a full-string match, never a partial
  match):

    * `matches_pattern?/2` — a glob where a single `*` matches within one path
      segment and does not cross a `/`.
    * `matches_recursive_pattern?/2` — a glob where `**` matches across path
      segments (`**/` matches zero or more leading segments, `/**` zero or more
      trailing segments) while a single `*` still stays within a segment.
    * `matches_module_pattern?/2` — a glob over a module name where `*` may
      cross dots (module separators), so `*.Schemas.*` matches `App.Schemas.User`.
    * `matches_name_pattern?/2` — a glob over a function name (`allowed_functions`)
      where `*` matches any run of characters.

  ## The glob syntax is `*` and `**`, and nothing else

  Every user-supplied glob in a config (`paths`, `pattern`, `forbidden_patterns`,
  `allowed_functions`) is compiled here, by `to_regex/2`, and nowhere else. The
  pattern is split into wildcard tokens and literal text. Each wildcard becomes
  its regex; every literal run goes through `Regex.escape/1`. So every other
  character (`.`, `?`, `+`, `(`, `[`, `{`, `|`, `^`, `$`, `\\`, …) matches only
  itself.

  Before DND-1292 only `.` was escaped, and every other regex metacharacter in a
  glob was live regex: `allowed_functions: ["*?"]` was a lazy match-all that
  allowed every function, `lib/c++/*.ex` matched `lib/c/a.ex` and not itself,
  and `lib/(old/*.ex` raised a `Regex.CompileError` at run time.
  """

  @doc """
  Returns `true` when `path` matches a single-`*` glob `pattern`.

  A `*` matches any run of non-`/` characters, so it stays within one path
  segment. The match is anchored: the whole path must match the whole pattern.
  Every other character is a literal.
  """
  @spec matches_pattern?(String.t(), String.t()) :: boolean()
  def matches_pattern?(path, pattern) do
    Regex.match?(to_regex(pattern, :path), path)
  end

  @doc """
  Returns `true` when `path` matches a recursive glob `pattern` (with `**`).

  `**/` matches zero or more leading path segments, `/**` zero or more trailing
  segments, and a bare `**` matches anything. A single `*` still matches only
  within one segment (does not cross a `/`). The match is anchored. Every other
  character is a literal.
  """
  @spec matches_recursive_pattern?(String.t(), String.t()) :: boolean()
  def matches_recursive_pattern?(path, pattern) do
    Regex.match?(to_regex(pattern, :recursive), path)
  end

  @doc """
  Returns `true` when `module_name` matches a module-name glob `pattern`.

  Unlike `matches_pattern?/2`, a `*` here may cross dots, so `*.Schemas.*`
  matches `App.Schemas.User` and `*Queries` matches `App.UserQueries`. The match
  is anchored. Every other character is a literal, so a `.` is dot-bounded.

  An Elixir module name arrives fully qualified (`Elixir.App.Web.User`, as
  `to_string/1` gives it), and also matches in its alias form (`App.Web.User`).
  So `App.Web.*`, the way a module is written in code, matches it, as do
  `Elixir.App.Web.*` and `*.Web.*`. Before DND-1290 only the qualified form was
  tried, and an alias-form pattern matched nothing, so a rule selecting or
  forbidding by one checked nothing.
  """
  @spec matches_module_pattern?(String.t(), String.t()) :: boolean()
  def matches_module_pattern?(module_name, pattern) do
    regex = to_regex(pattern, :module)
    Enum.any?(module_name_forms(module_name), &Regex.match?(regex, &1))
  end

  @doc """
  Returns `true` when `name` (a function name) matches a name glob `pattern`.

  A `*` matches any run of characters, `/` included, so `*` matches every
  function name, a user-defined `/` operator too. The match is anchored. Every
  other character is a literal, so `*?` matches the names ending in `?`.
  """
  @spec matches_name_pattern?(String.t(), String.t()) :: boolean()
  def matches_name_pattern?(name, pattern) do
    Regex.match?(to_regex(pattern, :name), name)
  end

  @doc """
  Returns `true` when `pattern` is made only of wildcards (`*`, `**`, `***`, …).

  Such a glob has no literal character, so it matches every function name
  (`matches_name_pattern?/2`) and every module name. Since DND-1292 this is
  the only glob that does: any other character is a literal that a name must
  contain. `Anchor.Domain.RuleSchema` refuses it where matching everything
  defeats the key (an `allowed_functions` entry that allows every function).
  """
  @spec wildcard_only?(String.t()) :: boolean()
  def wildcard_only?(pattern), do: pattern != "" and String.trim(pattern, "*") == ""

  defp module_name_forms("Elixir." <> alias_form = module_name), do: [module_name, alias_form]
  defp module_name_forms(module_name), do: [module_name]

  # THE glob compiler (DND-1292): split the pattern into the flavor's wildcard
  # tokens and the literal text between them, translate each token, escape each
  # literal, and anchor the whole with \A..\z (`$` would also match before a
  # trailing newline).
  defp to_regex(pattern, flavor) do
    flavor
    |> tokenizer()
    |> Regex.split(pattern, include_captures: true, trim: true)
    |> Enum.map_join(&translate(&1, flavor))
    |> then(&Regex.compile!("\\A#{&1}\\z"))
  end

  # The wildcard tokens of each flavor, longest first. In a recursive glob,
  # `**/` and `/**` absorb their slash so `lib/**/*.ex` also matches
  # `lib/a.ex` (zero segments).
  defp tokenizer(:recursive), do: ~r{\*\*/|/\*\*|\*\*|\*}
  defp tokenizer(_flavor), do: ~r/\*/

  defp translate("**/", :recursive), do: "(.*/)?"
  defp translate("/**", :recursive), do: "(/.*)?"
  defp translate("**", :recursive), do: ".*"
  defp translate("*", flavor) when flavor in [:module, :name], do: ".*"
  defp translate("*", _path_flavor), do: "[^/]*"
  defp translate(literal, _flavor), do: Regex.escape(literal)
end
