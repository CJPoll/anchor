defmodule Anchor.Domain.Sabotage.TestPath do
  @moduledoc """
  The one rule for a path a sabotage run hands to `mix test` (DND-5640).
  Pure **Domain**.

  A path read from a coverage map or a sabotage record reaches the test
  command's argv, so it must be a test file inside the project and never an
  option. `check/1` accepts a path only when:

    * it is not empty;
    * it does not start with `-` (a `mix test` option) or `/` (absolute);
    * no segment is `..` (outside the project) or empty (`a//b`);
    * it ends in `_test.exs`.

  A test arg may carry a line (`test/a_test.exs:12`); `check_arg/1` checks
  the file part. The coverage map, the kill map and the test selection all
  call this module, so the rule is one rule.
  """

  @type reason ::
          :empty | :option | :absolute | :parent_segment | :empty_segment | :not_a_test_file

  @doc "`:ok` when `path` is a project test file path, else why not."
  @spec check(String.t()) :: :ok | {:error, reason()}
  def check(""), do: {:error, :empty}
  def check("-" <> _rest), do: {:error, :option}
  def check("/" <> _rest), do: {:error, :absolute}

  def check(path) when is_binary(path) do
    segments = String.split(path, "/")

    cond do
      ".." in segments -> {:error, :parent_segment}
      "" in segments -> {:error, :empty_segment}
      not String.ends_with?(path, "_test.exs") -> {:error, :not_a_test_file}
      true -> :ok
    end
  end

  @doc "`check/1` on the file part of a test arg (`file` or `file:line`)."
  @spec check_arg(String.t()) :: :ok | {:error, reason()}
  def check_arg(arg), do: arg |> String.split(":", parts: 2) |> hd() |> check()

  @doc "Whether `check_arg/1` accepts `arg`."
  @spec safe_arg?(String.t()) :: boolean()
  def safe_arg?(arg), do: check_arg(arg) == :ok

  @doc "The reason in words, for a refusal line."
  @spec describe(reason()) :: String.t()
  def describe(:empty), do: "an empty path"
  def describe(:option), do: "starts with -, so mix test would read it as an option"
  def describe(:absolute), do: "an absolute path, outside the project"
  def describe(:parent_segment), do: "a .. segment, outside the project"
  def describe(:empty_segment), do: "an empty path segment"
  def describe(:not_a_test_file), do: "not a _test.exs file"
end
