defmodule Anchor.Domain.Sabotage.KillMap do
  @moduledoc """
  The machine-readable kill map of a sabotage record (DND-5484): which test
  killed which mutant. Pure **Domain**.

  A fenced block with the info string `anchor-kills`, a header comment, then
  one tab-separated row per mutant:

      id  file  Module.fun/arity  operator  status  killers

  `status` is `killed`, `timeout`, `survived`, `no_tests`, `invalid` or
  `crashed` (DND-5570);
  `killers` are `file:line name`, each escaped, then joined by ` ; ` (empty
  when none). In every field a backslash, a tab, a newline and a `;` are
  written `\\\\`, `\\t`, `\\n` and `\\;`, so an escaped killer never holds the
  separator and a test named `a ; b` reads back as one killer.

  `parse/1` reads every `anchor-kills` block of a record (an appended record
  holds several) and refuses a row with the wrong number of fields, an
  unknown status, or a `killed` row's killer whose file fails
  `Anchor.Domain.Sabotage.TestPath.check/1` (DND-5640: a killer's file reaches
  `mix test`'s argv, so `--opt`, `/abs`, `../x` and a non-test file are
  refused), naming the line (`{:error, {line, message}}`): a record it cannot
  read is never read as an empty map. Only `killed` rows are selected from;
  a `timeout` row's killer is `(timeout)`, not a file.
  """

  alias Anchor.Domain.Sabotage.TestPath

  @fence "```"
  @info "anchor-kills"
  @header "# id\tfile\tmfa\toperator\tstatus\tkillers"
  @statuses ~w(killed timeout survived no_tests invalid crashed)
  @separator " ; "

  @type row :: %{
          id: String.t(),
          file: String.t(),
          mfa: String.t(),
          operator: String.t(),
          status: String.t(),
          killers: [String.t()]
        }

  @doc "The rows of a run's outcomes."
  @spec rows([map()]) :: [row()]
  def rows(outcomes) do
    Enum.map(outcomes, fn %{mutant: mutant} = outcome ->
      %{
        id: mutant.id,
        file: mutant.file,
        mfa: mfa(mutant),
        operator: to_string(mutant.operator),
        status: to_string(outcome.status),
        killers: Enum.map(outcome.killers, &killer/1)
      }
    end)
  end

  @doc "The fenced `anchor-kills` block of `outcomes`, ending with a newline."
  @spec render_block([map()]) :: String.t()
  def render_block(outcomes) do
    lines =
      Enum.map(rows(outcomes), fn row ->
        fields = Enum.map([row.id, row.file, row.mfa, row.operator, row.status], &escape/1)
        Enum.join(fields ++ [Enum.map_join(row.killers, @separator, &escape/1)], "\t")
      end)

    Enum.join([@fence <> @info, @header | lines] ++ [@fence], "\n") <> "\n"
  end

  @doc "Every row of every `anchor-kills` block in `text`."
  @spec parse(String.t()) :: {:ok, [row()]} | {:error, {pos_integer(), String.t()}}
  def parse(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce_while({:out, []}, &step/2)
    |> case do
      {:out, rows} -> {:ok, Enum.reverse(rows)}
      {:in, _rows, line} -> {:error, {line, "the anchor-kills block opened here is never closed"}}
      {:error, _reason} = error -> error
    end
  end

  @doc "`\"M.f/a\" => killers` of every killed row (a `timeout` names no test)."
  @spec killers_by_function([row()]) :: %{String.t() => [String.t()]}
  def killers_by_function(rows) do
    rows
    |> Enum.filter(&(&1.status == "killed" and &1.killers != []))
    |> Enum.group_by(& &1.mfa, & &1.killers)
    |> Map.new(fn {mfa, killers} -> {mfa, killers |> List.flatten() |> Enum.uniq()} end)
  end

  @doc "The test file of a killer (`file:line name`)."
  @spec killer_file(String.t()) :: String.t()
  def killer_file(killer), do: killer |> String.split(":", parts: 2) |> hd()

  @doc "A killer as the kill map writes it."
  @spec killer({String.t(), non_neg_integer(), String.t()} | String.t()) :: String.t()
  def killer({file, line, name}), do: "#{file}:#{line} #{name}"
  def killer(text) when is_binary(text), do: text

  defp step({@fence <> @info, line}, {:out, rows}), do: {:cont, {:in, rows, line}}
  defp step({_text, _line}, {:out, _rows} = acc), do: {:cont, acc}
  defp step({@fence, _line}, {:in, rows, _open}), do: {:cont, {:out, rows}}
  defp step({"#" <> _comment, _line}, {:in, _rows, _open} = acc), do: {:cont, acc}
  defp step({"", _line}, {:in, _rows, _open} = acc), do: {:cont, acc}

  defp step({text, line}, {:in, rows, open}) do
    case row(text) do
      {:ok, row} -> {:cont, {:in, [row | rows], open}}
      {:error, message} -> {:halt, {:error, {line, message}}}
    end
  end

  defp row(text) do
    case String.split(text, "\t") do
      [id, file, mfa, operator, status, killers] ->
        status = unescape(status)
        killers = killers(killers)

        cond do
          status not in @statuses ->
            {:error, "unknown status #{inspect(status)}"}

          refused = status == "killed" && refused_killer(killers) ->
            refused

          true ->
            {:ok,
             %{
               id: unescape(id),
               file: unescape(file),
               mfa: unescape(mfa),
               operator: unescape(operator),
               status: status,
               killers: killers
             }}
        end

      fields ->
        {:error, "a row has #{length(fields)} fields, not 6"}
    end
  end

  defp refused_killer(killers) do
    Enum.find_value(killers, fn killer ->
      case TestPath.check(killer_file(killer)) do
        :ok ->
          nil

        {:error, reason} ->
          {:error, "killer #{inspect(killer)} refused: #{TestPath.describe(reason)}"}
      end
    end)
  end

  defp killers(""), do: []
  defp killers(text), do: text |> String.split(@separator) |> Enum.map(&unescape/1)

  defp mfa(%{module: module, function: {name, arity}}), do: "#{inspect(module)}.#{name}/#{arity}"

  defp escape(text),
    do:
      text
      |> String.replace("\\", "\\\\")
      |> String.replace("\t", "\\t")
      |> String.replace("\n", "\\n")
      |> String.replace(";", "\\;")

  defp unescape(text), do: unescape(text, "")

  defp unescape("\\\\" <> rest, acc), do: unescape(rest, acc <> "\\")
  defp unescape("\\t" <> rest, acc), do: unescape(rest, acc <> "\t")
  defp unescape("\\n" <> rest, acc), do: unescape(rest, acc <> "\n")
  defp unescape("\\;" <> rest, acc), do: unescape(rest, acc <> ";")
  defp unescape(<<c, rest::binary>>, acc), do: unescape(rest, acc <> <<c>>)
  defp unescape("", acc), do: acc
end
