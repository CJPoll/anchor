defmodule Anchor.Domain.Sabotage.KillerRef do
  @moduledoc """
  A killer named in a kill map, read back as a test to run (DND-5485). Pure
  **Domain**.

  A killer is `file:line full name` (`Anchor.Domain.Sabotage.KillMap`).
  `parse/1` splits it on the first `:<digits> `, so a name holding `:` and
  digits stays whole; a per-test timeout's killer, `(test timeout) file:line
  name` (DND-5653), names a test too. The run's own bound, `(timeout)`, names
  none: `{:error, :not_a_test}`. The file must pass
  `Anchor.Domain.Sabotage.TestPath.check/1`, since it reaches `mix test`'s
  argv.

  `to_test_args/1` runs killers by file and test name, so a line moved in the
  test file does not matter: every file once, then `--only test:<name>` per
  name. ExUnit's `--only` filters are global, so a name is matched in every
  listed file; that can only run more tests, never fewer.
  """

  alias Anchor.Domain.Sabotage.TestPath

  @test_timeout "(test timeout) "

  @type t :: %{file: String.t(), line: non_neg_integer(), name: String.t()}

  @doc "The test a killer names, or why it names none."
  @spec parse(String.t()) ::
          {:ok, t()} | {:error, :not_a_test | {:not_a_ref, String.t()} | {:bad_path, atom()}}
  def parse(@test_timeout <> killer), do: parse(killer)
  def parse("(" <> _placeholder), do: {:error, :not_a_test}

  def parse(killer) when is_binary(killer) do
    with {:ok, file, line, name} <- split(killer),
         {:path, :ok} <- {:path, TestPath.check(file)} do
      {:ok, %{file: file, line: line, name: name}}
    else
      {:path, {:error, reason}} -> {:error, {:bad_path, reason}}
      :error -> {:error, {:not_a_ref, killer}}
    end
  end

  @doc "The `mix test` arguments that run exactly `refs`, by file and name."
  @spec to_test_args([t()]) :: [String.t()]
  def to_test_args(refs) do
    files = refs |> Enum.map(& &1.file) |> Enum.uniq()
    names = refs |> Enum.map(& &1.name) |> Enum.uniq()
    files ++ Enum.flat_map(names, &["--only", "test:" <> &1])
  end

  # The first `:` followed by digits and a space.
  defp split(killer) do
    killer
    |> :binary.matches(":")
    |> Enum.find_value(:error, fn {at, 1} ->
      file = binary_part(killer, 0, at)
      rest = binary_part(killer, at + 1, byte_size(killer) - at - 1)

      with [digits, name] <- String.split(rest, " ", parts: 2),
           {line, ""} <- Integer.parse(digits),
           true <- digits != "" and name != "" and line >= 0 do
        {:ok, file, line, name}
      else
        _not_here -> nil
      end
    end)
  end
end
