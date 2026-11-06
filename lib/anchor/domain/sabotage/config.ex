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
  | `coverage_map` | none | a per-test coverage map file (DND-5474), relative to the project root; `--coverage PATH` overrides |
  | `records` | below | where the run's sabotage record goes and how it is named (DND-5484) |
  | `survivors` | `.anchor/sabotage/survivors.txt` | the survivors list (DND-5483), relative to the project root; named here, it must exist; at the default path an absent file is an empty list, said loudly |

  `records` (every key optional): `dir` (default `test/sabotage_records`;
  may hold `{app}`; relative, with no `..` segment, read with a leading `./`
  and trailing `/` dropped, so `test/sabotage_records/` names the same
  directory), `naming` (`domain_date_slot`, the default, or
  `ticket_nn_what`), `domain_from` (`module`, the default, or `context_dir`),
  `domain_strip_prefixes` (a list of module-name prefixes, default `[]`),
  `adr` (the rule a test still lacking a red follows, named in the record;
  default `the repo's sabotage-record ADR`). See
  `Anchor.Domain.Sabotage.RecordNaming`.

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
  @keys ~w(test_command max_mutants timeout_seconds operators effect_calls test_mirror
           coverage_map records survivors)

  defstruct test_command: ["mix", "test", "--max-cases", "2"],
            max_mutants: 30,
            timeout_seconds: 300,
            operators: Operators.all(),
            effect_calls: [],
            test_mirror: @default_mirror,
            coverage_map: nil,
            survivors: nil,
            records: %{
              dir: "test/sabotage_records",
              naming: :domain_date_slot,
              domain_from: :module,
              domain_strip_prefixes: [],
              adr: "the repo's sabotage-record ADR"
            }

  @type t :: %__MODULE__{
          test_command: [String.t(), ...],
          max_mutants: pos_integer(),
          timeout_seconds: pos_integer(),
          operators: [atom()],
          effect_calls: [String.t()],
          test_mirror: [TestMirror.rule()],
          coverage_map: String.t() | nil,
          survivors: String.t() | nil,
          records: %{
            dir: String.t(),
            naming: :domain_date_slot | :ticket_nn_what,
            domain_from: :module | :context_dir,
            domain_strip_prefixes: [String.t()],
            adr: String.t()
          }
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
         {:ok, mirror} <- test_mirror(section),
         {:ok, coverage_map} <- coverage_map(section),
         {:ok, records} <- records(section),
         {:ok, survivors} <- survivors(section) do
      {:ok,
       %__MODULE__{
         test_command: command,
         max_mutants: max,
         timeout_seconds: timeout,
         operators: operators,
         effect_calls: effects,
         test_mirror: mirror,
         coverage_map: coverage_map,
         survivors: survivors,
         records: records
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

  defp coverage_map(%{"coverage_map" => path}) when is_binary(path) and path != "",
    do: {:ok, path}

  defp coverage_map(%{"coverage_map" => path}) do
    refuse(
      "sabotage.coverage_map must be a non-empty path, got: #{inspect(path)}",
      "set it to the coverage map file (the anchor-coverage artifact), or remove the key"
    )
  end

  defp coverage_map(_section), do: {:ok, nil}

  # DND-5483: a path inside the project; `nil` is the default path, where an
  # absent file is an empty list.
  defp survivors(%{"survivors" => path}) when is_binary(path) and path != "" do
    segments = String.split(path, "/")

    if String.starts_with?(path, "/") or ".." in segments,
      do: bad_survivors(path),
      else: {:ok, path}
  end

  defp survivors(%{"survivors" => path}), do: bad_survivors(path)
  defp survivors(_section), do: {:ok, nil}

  defp bad_survivors(path) do
    refuse(
      "sabotage.survivors must be a path inside the project, got: #{inspect(path)}",
      "set it relative to the project root, with no .. segment, or remove it for " <>
        ".anchor/sabotage/survivors.txt"
    )
  end

  @record_keys ~w(dir naming domain_from domain_strip_prefixes adr)
  @namings %{"domain_date_slot" => :domain_date_slot, "ticket_nn_what" => :ticket_nn_what}
  @domain_froms %{"module" => :module, "context_dir" => :context_dir}

  defp records(%{"records" => section}) when is_map(section) do
    defaults = %__MODULE__{}.records

    with :ok <- known_record_keys(section),
         {:ok, dir} <- record_string(section, "dir", defaults.dir),
         {:ok, dir} <- record_dir(dir),
         {:ok, naming} <- record_choice(section, "naming", @namings, defaults.naming),
         {:ok, from} <- record_choice(section, "domain_from", @domain_froms, defaults.domain_from),
         {:ok, prefixes} <- record_prefixes(section),
         {:ok, adr} <- record_string(section, "adr", defaults.adr) do
      {:ok,
       %{dir: dir, naming: naming, domain_from: from, domain_strip_prefixes: prefixes, adr: adr}}
    end
  end

  defp records(%{"records" => section}),
    do:
      refuse(
        "sabotage.records must be a mapping, got: #{inspect(section)}",
        "write `records:` with keys under it (#{Enum.join(@record_keys, ", ")}), or remove it"
      )

  defp records(_section), do: {:ok, %__MODULE__{}.records}

  defp known_record_keys(section) do
    case section |> Map.keys() |> Enum.reject(&(&1 in @record_keys)) |> Enum.sort() do
      [] ->
        :ok

      unknown ->
        refuse(
          "sabotage.records: unknown key(s) #{Enum.map_join(unknown, ", ", &inspect/1)}",
          "remove or correct it; the keys are #{Enum.join(@record_keys, ", ")}"
        )
    end
  end

  defp record_string(section, key, default) do
    case Map.get(section, key, default) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      value ->
        refuse(
          "sabotage.records.#{key} must be a non-empty string, got: #{inspect(value)}",
          "set it to a string, or remove it for the default"
        )
    end
  end

  defp record_dir(dir) do
    segments = dir |> String.split("/") |> drop_dot_slash() |> Enum.reject(&(&1 == ""))

    if String.starts_with?(dir, "/") or ".." in segments or segments == [] do
      refuse(
        "sabotage.records.dir must be a directory inside the project, got: #{inspect(dir)}",
        "set it relative to the project root, with no .. segment"
      )
    else
      {:ok, Enum.join(segments, "/")}
    end
  end

  defp drop_dot_slash(["." | rest]), do: drop_dot_slash(rest)
  defp drop_dot_slash(segments), do: segments

  defp record_choice(section, key, choices, default) do
    case Map.fetch(section, key) do
      :error ->
        {:ok, default}

      {:ok, value} when is_map_key(choices, value) ->
        {:ok, Map.fetch!(choices, value)}

      {:ok, value} ->
        refuse(
          "sabotage.records.#{key} #{inspect(value)} is not one of " <>
            Enum.join(choices |> Map.keys() |> Enum.sort(), ", "),
          "use one of #{Enum.join(choices |> Map.keys() |> Enum.sort(), ", ")}"
        )
    end
  end

  defp record_prefixes(section) do
    case Map.get(section, "domain_strip_prefixes", []) do
      prefixes when is_list(prefixes) ->
        if Enum.all?(prefixes, &(is_binary(&1) and &1 != "")),
          do: {:ok, prefixes},
          else: bad_prefixes(prefixes)

      prefixes ->
        bad_prefixes(prefixes)
    end
  end

  defp bad_prefixes(prefixes) do
    refuse(
      "sabotage.records.domain_strip_prefixes must be a list of non-empty strings, got: " <>
        inspect(prefixes),
      "list module-name prefixes such as \"MyApp.Domain.\""
    )
  end

  defp refuse(message, fix), do: {:error, {:invalid_config, message <> ". Fix: " <> fix}}
end
