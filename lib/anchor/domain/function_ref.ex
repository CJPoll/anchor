defmodule Anchor.Domain.FunctionRef do
  @moduledoc """
  One `forbidden_functions` entry (DND-1267): a module, a function name, and an
  arity or `:any` — a **Domain** module (ADR 001). Pure: it parses a token and
  compares a parsed token with a call. No IO.

  ## Token grammar

    * `"Mod.fun"` — every arity of `fun` on the Elixir module `Mod`;
    * `"Mod.fun/2"` — only `fun/2`;
    * `":erl_mod.fun"`, `":erl_mod.fun/2"` — an Erlang/OTP module, as the
      leading-colon token of `forbidden_modules` spells it.

  `Mod` is one or more alias segments (`A-Z`, then letters, digits or `_`).
  `fun` is an identifier (`a-z` or `_`, then letters, digits or `_`), with an
  optional final `?` or `!`. An arity is `0` to `255`, in decimal digits.

  Anything else is an error, never a token that matches nothing: a missing
  function (`"MyApp.Repo"`), a missing module (`"insert"`), a glob
  (`"MyApp.Repo.*"`, which is `forbidden_patterns`' job), an operator, a
  non-numeric arity. `Anchor.Domain.RuleSchema` turns the error into a load
  failure. The grammar is checked with string functions, not a regex, because
  `Anchor.Domain.GlobPattern` is the one place a regex is built.
  """

  @enforce_keys [:module, :function, :arity]
  defstruct [:module, :function, :arity]

  @type t :: %__MODULE__{module: module(), function: atom(), arity: arity() | :any}

  @max_arity 255

  @doc """
  Parses one token. Returns `{:ok, %FunctionRef{}}`, or `{:error, reason}`
  naming the token, what is wrong with it, and how to write it.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(token) when is_binary(token) do
    with {:ok, path, arity} <- split_arity(token),
         {:ok, module, function} <- split_path(path) do
      {:ok, %__MODULE__{module: module, function: function, arity: arity}}
    else
      {:error, why} ->
        {:error,
         "#{inspect(token)} is not a function reference: it #{why}; write each entry as " <>
           ~s("Module.function" or "Module.function/arity" ) <>
           ~s|(e.g. "MyApp.Repo.insert/2", ":ets.insert")|}
    end
  end

  @doc "Prints a parsed token back in the token grammar (`Mod.fun`, `Mod.fun/2`)."
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{module: module, function: function, arity: arity}),
    do: format(module, function, arity)

  @doc """
  Prints a call on `module.function/arity` in the token grammar; an `:any`
  arity prints no arity.
  """
  @spec format(module(), atom(), arity() | :any) :: String.t()
  def format(module, function, :any), do: "#{inspect(module)}.#{function}"
  def format(module, function, arity), do: "#{inspect(module)}.#{function}/#{arity}"

  @doc """
  Whether a call on `module.function/arity` reaches the function `ref` names.
  Module and function compare exactly. An `:any` arity on either side (a token
  with no arity, or a call whose arity the source does not show) matches every
  arity, so an unknown arity is reported rather than assumed away.
  """
  @spec matches?(t(), module(), atom(), arity() | :any) :: boolean()
  def matches?(%__MODULE__{} = ref, module, function, arity) do
    ref.module == module and ref.function == function and arity_matches?(ref.arity, arity)
  end

  @doc """
  Whether a call the source cannot fully resolve could reach the function `ref`
  names. `module` and `function` are `nil` when unknown, and an unknown part
  could be anything; a known part must match.
  """
  @spec may_reach?(t(), module() | nil, atom() | nil, arity() | :any) :: boolean()
  def may_reach?(%__MODULE__{} = ref, module, function, arity) do
    (is_nil(module) or ref.module == module) and
      (is_nil(function) or ref.function == function) and arity_matches?(ref.arity, arity)
  end

  @doc """
  Whether `name` is an Elixir module name in this grammar's `Mod`: one or more
  alias segments (`A-Z`, then letters, digits or `_`) joined by `.`. The one
  definition of a module name that `Anchor.Domain.AllowedCallers` shares
  (DND-1269).
  """
  @spec alias_name?(String.t()) :: boolean()
  def alias_name?(name) when is_binary(name),
    do: name |> String.split(".") |> Enum.all?(&alias_segment?/1)

  defp arity_matches?(:any, _arity), do: true
  defp arity_matches?(_expected, :any), do: true
  defp arity_matches?(expected, arity), do: expected == arity

  # ---- parsing ----

  defp split_arity(token) do
    case String.split(token, "/") do
      [path] -> {:ok, path, :any}
      [path, arity] -> parse_arity(path, arity)
      _more -> {:error, "has more than one `/`, so what follows the first is not an arity"}
    end
  end

  defp parse_arity(path, digits) do
    with true <- digits?(digits),
         {arity, ""} when arity <= @max_arity <- Integer.parse(digits) do
      {:ok, path, arity}
    else
      _not_an_arity ->
        {:error, "has #{inspect(digits)}, which is not an arity (0 to #{@max_arity})"}
    end
  end

  defp digits?(""), do: false
  defp digits?(string), do: string |> String.to_charlist() |> Enum.all?(&(&1 in ?0..?9))

  defp split_path(":" <> erlang_path), do: split_erlang_path(erlang_path)
  defp split_path(path), do: split_elixir_path(path)

  defp split_erlang_path(path) do
    case String.split(path, ".") do
      [_module_only] -> {:error, "names no function"}
      [module, function] -> build_erlang(module, function)
      _dotted -> {:error, "has #{inspect(":" <> path)}, whose module is not a module name"}
    end
  end

  defp build_erlang(module, function) do
    cond do
      not erlang_module_name?(module) ->
        {:error, "has #{inspect(":" <> module)}, which is not a module name"}

      not function_name?(function) ->
        {:error, "has #{inspect(function)}, which is not a function name"}

      true ->
        {:ok, String.to_atom(module), String.to_atom(function)}
    end
  end

  defp split_elixir_path(path) do
    {segments, [function]} = path |> String.split(".") |> Enum.split(-1)

    cond do
      segments in [[], [""]] ->
        {:error, "names no module"}

      function == "" or alias_segment?(function) ->
        {:error, "names no function"}

      not Enum.all?(segments, &alias_segment?/1) ->
        {:error, "has #{inspect(Enum.join(segments, "."))}, which is not a module name"}

      not function_name?(function) ->
        {:error, "has #{inspect(function)}, which is not a function name"}

      true ->
        {:ok, Module.concat(segments), String.to_atom(function)}
    end
  end

  # An Elixir alias segment: an upper-case letter, then letters, digits or `_`.
  defp alias_segment?(<<first, rest::binary>>) when first in ?A..?Z, do: word_chars?(rest)
  defp alias_segment?(_segment), do: false

  # An Erlang module atom that needs no quoting: a lower-case letter, then
  # letters, digits, `_` or `@`.
  defp erlang_module_name?(<<first, rest::binary>>) when first in ?a..?z do
    rest |> String.to_charlist() |> Enum.all?(&(word_char?(&1) or &1 == ?@))
  end

  defp erlang_module_name?(_module), do: false

  # A function identifier: a lower-case letter or `_`, then letters, digits or
  # `_`, with an optional final `?` or `!`.
  defp function_name?(<<first, rest::binary>>) when first in ?a..?z or first == ?_ do
    rest |> drop_final_mark() |> word_chars?()
  end

  defp function_name?(_function), do: false

  defp drop_final_mark(name) do
    case String.last(name) do
      mark when mark in ["?", "!"] -> String.slice(name, 0..-2//1)
      _other -> name
    end
  end

  defp word_chars?(string), do: string |> String.to_charlist() |> Enum.all?(&word_char?/1)

  defp word_char?(char),
    do: char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_
end
