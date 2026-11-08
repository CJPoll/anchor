defmodule Anchor.Domain.Sabotage.TestMirror do
  @moduledoc """
  The `test_mirror` rules of the `sabotage:` section (DND-5473): a lib file's
  mirror test file. Pure **Domain**, string functions only (no regex: the one
  glob compiler is `Anchor.Domain.GlobPattern`, and it binds nothing).

  A rule is `%{from: glob, to: template}`. `from` is `/`-separated segments:
  literal segments, at most one `*` (one whole segment, bound as `{app}`), an
  optional `**` (any number of segments), and a last segment `*<suffix>`
  (`*.ex`). `{rest}` is what `**` and the last `*` matched, joined by `/`,
  without the suffix. `to` is a path using `{app}` (only when `from` has a `*`
  segment) and `{rest}`.

      from: "apps/*/lib/**/*.ex"   to: "apps/{app}/test/{rest}_test.exs"
      apps/core/lib/core/a/b.ex -> apps/core/test/core/a/b_test.exs
  """

  @type rule :: %{from: String.t(), to: String.t()}

  @doc """
  `:ok`, or the reason `from`/`to` cannot be a rule: `{:from, reason}` or
  `{:to, reason}`.
  """
  @spec validate(String.t(), String.t()) :: :ok | {:from | :to, String.t()}
  def validate(from, to) do
    with {:ok, segments} <- from_segments(from) do
      to_tokens(to, Enum.member?(segments, :app))
    end
  end

  @doc "The mirror path of `path` under `rule`, or `nil` when `from` does not match it."
  @spec target(rule(), String.t()) :: String.t() | nil
  def target(%{from: from, to: to}, path) do
    with {:ok, segments} <- from_segments(from),
         {:ok, binds} <- match(segments, String.split(path, "/"), %{}) do
      Enum.reduce(binds, to, fn {name, value}, acc ->
        String.replace(acc, "{#{name}}", value)
      end)
    else
      _no_match -> nil
    end
  end

  @doc "The first rule's mirror path that `path` matches, or `nil`."
  @spec first_target([rule()], String.t()) :: String.t() | nil
  def first_target(rules, path), do: Enum.find_value(rules, &target(&1, path))

  @test_suffix "_test.exs"

  @doc """
  Whether `path` is a sibling of the mirror path `mirror` (DND-6070): a file in
  the same directory named `<stem>_<topic>_test.exs`, where `mirror` is
  `<stem>_test.exs` and `<topic>` is not empty. A module's tests split by
  topic (`machine_decider_agents_test.exs` beside `machine_decider_test.exs`)
  are its siblings; another module's test (`xy_test.exs` beside
  `x_test.exs`) is not. A `mirror` that is not a non-empty `<stem>_test.exs`
  has no siblings.
  """
  @spec sibling?(String.t(), String.t()) :: boolean()
  def sibling?(mirror, path) do
    stem = test_stem(Path.basename(mirror))

    stem != nil and Path.dirname(mirror) == Path.dirname(path) and
      topic_of?(Path.basename(path), stem)
  end

  defp test_stem(name) do
    if String.ends_with?(name, @test_suffix) and byte_size(name) > byte_size(@test_suffix),
      do: String.replace_suffix(name, @test_suffix, ""),
      else: nil
  end

  # `<stem>_<topic>_test.exs` with a non-empty topic.
  defp topic_of?(name, stem) do
    prefix = stem <> "_"

    String.starts_with?(name, prefix) and String.ends_with?(name, @test_suffix) and
      byte_size(name) > byte_size(prefix) + byte_size(@test_suffix)
  end

  defp from_segments(from) when is_binary(from) do
    parts = String.split(from, "/")
    {init, [last]} = Enum.split(parts, -1)

    with {:ok, suffix} <- last_segment(last),
         {:ok, init} <- init_segments(init) do
      {:ok, init ++ [{:file, suffix}]}
    end
  end

  defp last_segment("*" <> suffix) when suffix != "" do
    if String.contains?(suffix, "*"),
      do: {:from, "its last segment may hold one `*` only"},
      else: {:ok, suffix}
  end

  defp last_segment(_last),
    do: {:from, "its last segment must be `*<suffix>` (for example `*.ex`)"}

  defp init_segments(parts) do
    segments =
      Enum.map(parts, fn
        "*" -> :app
        "**" -> :any
        "" -> :empty
        literal -> if String.contains?(literal, "*"), do: :partial, else: {:literal, literal}
      end)

    cond do
      Enum.member?(segments, :empty) -> {:from, "it has an empty segment"}
      Enum.member?(segments, :partial) -> {:from, "a `*` must be a whole segment"}
      Enum.count(segments, &(&1 == :app)) > 1 -> {:from, "it may have one `*` segment only"}
      Enum.count(segments, &(&1 == :any)) > 1 -> {:from, "it may have one `**` only"}
      :any in segments and List.last(segments) != :any -> {:from, "`**` must come last but one"}
      true -> {:ok, segments}
    end
  end

  defp to_tokens(to, app?) when is_binary(to) do
    tokens = to |> String.split("{") |> Enum.drop(1) |> Enum.map(&token/1)

    cond do
      to == "" -> {:to, "it is empty"}
      Enum.any?(tokens, &(&1 not in ["app", "rest"])) -> {:to, "the tokens are {app} and {rest}"}
      "app" in tokens and not app? -> {:to, "uses {app}, which its `from` does not bind"}
      true -> :ok
    end
  end

  defp token(text) do
    case String.split(text, "}", parts: 2) do
      [name, _rest] -> name
      [_unclosed] -> "{"
    end
  end

  defp match([{:file, suffix}], [name], binds) do
    if String.ends_with?(name, suffix) and byte_size(name) > byte_size(suffix),
      do: {:ok, put_rest(binds, String.replace_suffix(name, suffix, ""))},
      else: :error
  end

  defp match([:any, {:file, _suffix} = file], parts, binds) when parts != [] do
    {dirs, [name]} = Enum.split(parts, -1)

    with {:ok, binds} <- match([file], [name], binds) do
      {:ok, Map.update!(binds, "rest", &Enum.join(dirs ++ [&1], "/"))}
    end
  end

  defp match([:app | segments], [part | parts], binds),
    do: match(segments, parts, Map.put(binds, "app", part))

  defp match([{:literal, literal} | segments], [literal | parts], binds),
    do: match(segments, parts, binds)

  defp match(_segments, _parts, _binds), do: :error

  defp put_rest(binds, rest), do: Map.put(binds, "rest", rest)
end
