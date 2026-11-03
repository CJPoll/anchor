defmodule Anchor.Domain.Sabotage.Config do
  @moduledoc """
  The `sabotage:` section of `.anchor.yml` (DND-5473), parsed by
  `Anchor.Config.parse_config/1`. Pure **Domain**.

  | Key | Default | Meaning |
  |---|---|---|
  | `test_command` | `["mix", "test", "--max-cases", "2"]` | argv prefix of a test run, run with no shell |
  | `max_mutants` | 30 | mutants per local run; `--max N` overrides, `--max all` lifts it (CI) |
  | `timeout_seconds` | 300 | bound on one test run, killed by `timeout --kill-after=10` |
  | `operators` | all six | the subset of `Anchor.Domain.Sabotage.Operators.all/0` to run |
  | `effect_calls` | `[]` | extra effect calls (`Anchor.Domain.FunctionRef` tokens) |
  | `test_mirror` | the two rules below | lib file to test file, first matching `from` wins |

  The default `test_command` runs two test cases at once: a sabotage run must
  never load the machine it runs on (the sabotage load rule).

  Every refusal is `{:error, {:invalid_config, message}}`, the message starting
  with the key path (`sabotage.max_mutants ...`) and ending with a `Fix:` line.
  """

  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Sabotage.Operators
  alias Anchor.Domain.Sabotage.TestMirror

  @default_mirror [
    %{from: "apps/*/lib/**/*.ex", to: "apps/{app}/test/{rest}_test.exs"},
    %{from: "lib/**/*.ex", to: "test/{rest}_test.exs"}
  ]
  @keys ~w(test_command max_mutants timeout_seconds operators effect_calls test_mirror)

  defstruct test_command: ["mix", "test", "--max-cases", "2"],
            max_mutants: 30,
            timeout_seconds: 300,
            operators: Operators.all(),
            effect_calls: [],
            test_mirror: @default_mirror

  @type t :: %__MODULE__{
          test_command: [String.t(), ...],
          max_mutants: pos_integer(),
          timeout_seconds: pos_integer(),
          operators: [atom()],
          effect_calls: [String.t()],
          test_mirror: [TestMirror.rule()]
        }

  @doc "Parses the decoded section (`nil` for a bare `sabotage:`)."
  @spec parse(term()) :: {:ok, t()} | {:error, {:invalid_config, String.t()}}
  def parse(nil), do: parse(%{})

  def parse(section) when is_map(section) do
    with :ok <- known_keys(section),
         {:ok, command} <- test_command(section),
         {:ok, max} <- positive(section, "max_mutants", 30),
         {:ok, timeout} <- positive(section, "timeout_seconds", 300),
         {:ok, operators} <- operators(section),
         {:ok, effects} <- effect_calls(section),
         {:ok, mirror} <- test_mirror(section) do
      {:ok,
       %__MODULE__{
         test_command: command,
         max_mutants: max,
         timeout_seconds: timeout,
         operators: operators,
         effect_calls: effects,
         test_mirror: mirror
       }}
    end
  end

  def parse(section),
    do:
      refuse(
        "sabotage must be a mapping, got: #{inspect(section)}",
        "write `sabotage:` with keys under it, or remove it"
      )

  defp known_keys(section) do
    case section |> Map.keys() |> Enum.reject(&(&1 in @keys)) |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        refuse(
          "sabotage: unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}",
          "remove or correct it; the keys are #{Enum.join(@keys, ", ")}"
        )
    end
  end

  defp test_command(%{"test_command" => [_ | _] = argv}) do
    if Enum.all?(argv, &(is_binary(&1) and &1 != "")),
      do: {:ok, argv},
      else: bad_command(argv)
  end

  defp test_command(%{"test_command" => argv}), do: bad_command(argv)
  defp test_command(_section), do: {:ok, %__MODULE__{}.test_command}

  defp bad_command(argv) do
    refuse(
      "sabotage.test_command must be a non-empty list of strings, got: #{inspect(argv)}",
      "write it as an argv list, e.g. [\"mix\", \"test\"]"
    )
  end

  defp positive(section, key, default) do
    case Map.get(section, key, default) do
      value when is_integer(value) and value > 0 ->
        {:ok, value}

      value ->
        refuse(
          "sabotage.#{key} must be a positive integer, got: #{inspect(value)}",
          "set it to a whole number above 0"
        )
    end
  end

  defp operators(%{"operators" => [_ | _] = names}) do
    known = Map.new(Operators.all(), &{Atom.to_string(&1), &1})

    case Enum.reject(names, &Map.has_key?(known, &1)) do
      [] ->
        wanted = Enum.map(names, &known[&1])
        {:ok, Enum.filter(Operators.all(), &(&1 in wanted))}

      [unknown | _rest] ->
        refuse(
          "sabotage.operators names #{inspect(unknown)}, which is not an operator",
          "use any of #{Enum.map_join(Operators.all(), ", ", &Atom.to_string/1)}"
        )
    end
  end

  defp operators(%{"operators" => names}) do
    refuse(
      "sabotage.operators must be a non-empty list, got: #{inspect(names)}",
      "list the operators to run, or remove the key to run all six"
    )
  end

  defp operators(_section), do: {:ok, Operators.all()}

  defp effect_calls(%{"effect_calls" => tokens}) when is_list(tokens) do
    Enum.reduce_while(tokens, {:ok, tokens}, fn token, acc ->
      case token_error(token) do
        nil -> {:cont, acc}
        message -> {:halt, refuse("sabotage.effect_calls: #{message}", fix_token())}
      end
    end)
  end

  defp effect_calls(%{"effect_calls" => tokens}),
    do: refuse("sabotage.effect_calls must be a list, got: #{inspect(tokens)}", fix_token())

  defp effect_calls(_section), do: {:ok, []}

  defp token_error(token) when is_binary(token) do
    case FunctionRef.parse(token) do
      {:ok, _ref} -> nil
      {:error, message} -> message
    end
  end

  defp token_error(token), do: "#{inspect(token)} is not a string"

  defp fix_token, do: "write each as \"Module.function\" or \"Module.function/arity\""

  defp test_mirror(%{"test_mirror" => [_ | _] = rules}) do
    rules
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {rule, index}, {:ok, acc} ->
      case mirror_rule(rule, index) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        error -> {:halt, error}
      end
    end)
  end

  defp test_mirror(%{"test_mirror" => rules}) do
    refuse(
      "sabotage.test_mirror must be a non-empty list of {from, to} rules, got: #{inspect(rules)}",
      "list the rules, or remove the key for the defaults"
    )
  end

  defp test_mirror(_section), do: {:ok, @default_mirror}

  defp mirror_rule(%{"from" => from, "to" => to} = rule, index)
       when is_binary(from) and is_binary(to) and map_size(rule) == 2 do
    case TestMirror.validate(from, to) do
      :ok ->
        {:ok, %{from: from, to: to}}

      {:from, reason} ->
        refuse(
          "sabotage.test_mirror[#{index}].from #{inspect(from)}: #{reason}",
          "write `from` as segments and one `*` (bound as {app}), ending `**/*.ex`"
        )

      {:to, reason} ->
        refuse(
          "sabotage.test_mirror[#{index}].to #{reason}",
          "use only the tokens its `from` binds: {rest}, and {app} when `from` has a `*` segment"
        )
    end
  end

  defp mirror_rule(rule, index) do
    refuse(
      "sabotage.test_mirror[#{index}] must be a mapping with exactly `from` and `to` (strings), " <>
        "got: #{inspect(rule)}",
      "write it as {from: \"lib/**/*.ex\", to: \"test/{rest}_test.exs\"}"
    )
  end

  defp refuse(message, fix), do: {:error, {:invalid_config, message <> ". Fix: " <> fix}}
end
