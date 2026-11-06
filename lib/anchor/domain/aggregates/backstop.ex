defmodule Anchor.Domain.Aggregates.Backstop do
  @moduledoc """
  The test-time backstop's verdict (DND-5480) — **Domain**, pure: the writes
  one test made (`Anchor.Domain.Aggregates.BackstopEvent`) and the declared
  aggregates (`Anchor.Domain.Aggregates.Index`) in, a verdict and its messages
  out.

  ## The verdict (`verdict/2`)

  Each event is read exactly once, by the first row that matches:

  | Event | Read as |
  |---|---|
  | `emitted_by: :other` (a Task or process the test called) | `other_process` escape |
  | `kind: :unknown` (a statement not read as a read or a write) | `unclassified` escape |
  | `table: nil` (raw SQL) | `no_source` escape |
  | `tx: :no_tx` (no transaction open in its process) | `outside_transaction`, counted |
  | a table no aggregate declares (`Index.aggregate_of/2`) | `undeclared_table` escape |
  | otherwise | judged: its transaction's write set gains the table's aggregate |

  A transaction whose write set holds two or more aggregates is a crossing,
  named with one table per aggregate (the lexically first it wrote). Two
  transactions that each write one aggregate are not a crossing here: a
  non-atomic crossing is the static rule's (T2), not the backstop's. A write
  outside any transaction is a single statement on one table, so it cannot
  cross; it is counted, never read as judged.

  What cannot be tied to a transaction is never read as clean: every escape
  is counted, and the four escape kinds fail the test under `escapes: :fail`
  (`failure/3`). `outside_transaction` is counted in the summary only.
  """

  alias Anchor.Domain.Aggregates.BackstopEvent
  alias Anchor.Domain.Aggregates.Index

  @escape_kinds [:other_process, :no_source, :undeclared_table, :unclassified]
  @counted_kinds @escape_kinds ++ [:outside_transaction]
  @labels %{
    other_process: "other-process",
    no_source: "no-source",
    undeclared_table: "undeclared",
    unclassified: "unclassified"
  }

  @type crossing :: %{
          tx: reference(),
          aggregates: [String.t()],
          tables: %{String.t() => String.t()}
        }
  @type escapes :: %{
          other_process: non_neg_integer(),
          no_source: non_neg_integer(),
          undeclared_table: non_neg_integer(),
          unclassified: non_neg_integer(),
          outside_transaction: non_neg_integer()
        }
  @type result :: %{crossings: [crossing()], escapes: escapes()}
  @type totals :: %{
          tests: non_neg_integer(),
          crossings: non_neg_integer(),
          other_process: non_neg_integer(),
          no_source: non_neg_integer(),
          undeclared_table: non_neg_integer(),
          unclassified: non_neg_integer(),
          outside_transaction: non_neg_integer(),
          unattributed: non_neg_integer()
        }

  @doc "The verdict over one test's events; see the moduledoc."
  @spec verdict([BackstopEvent.t()], Index.t()) :: result()
  def verdict(events, %Index{} = index) when is_list(events) do
    read = Enum.map(events, &read(&1, index))

    escapes =
      Map.new(@counted_kinds, fn kind -> {kind, Enum.count(read, &(&1 == kind))} end)

    %{crossings: crossings(read), escapes: escapes}
  end

  @doc """
  What fails the test, if anything: `{:fail, message}` for a crossing (one
  paragraph per crossing), or, under `escapes: :fail`, for an escape; else
  `:pass`. `test` names the test in the message.
  """
  @spec failure(result(), String.t(), :report | :fail) :: :pass | {:fail, String.t()}
  def failure(%{crossings: [_ | _] = crossings}, test, _mode) do
    {:fail, Enum.map_join(crossings, "\n", &crossing_message(test, &1))}
  end

  def failure(%{crossings: [], escapes: escapes}, test, :fail) do
    case escaped(escapes) do
      0 -> :pass
      count -> {:fail, escape_message(test, escapes, count)}
    end
  end

  def failure(%{crossings: []}, _test, :report), do: :pass

  @doc """
  What one test adds to the suite's totals: one test, its crossings, and its
  counted kinds (`unattributed` is counted by the recorder, suite-wide).
  """
  @spec counts(result()) :: %{atom() => non_neg_integer()}
  def counts(%{crossings: crossings, escapes: escapes}) do
    Map.merge(escapes, %{tests: 1, crossings: length(crossings)})
  end

  @doc "The keys `counts/1` and `summary_line/1` share, in summary order."
  @spec total_keys() :: [atom()]
  def total_keys, do: [:tests, :crossings] ++ @counted_kinds ++ [:unattributed]

  @doc """
  The one line printed when the suite ends:

      anchor backstop: 12 tests watched, 0 crossings; escapes: 0 other-process,
      0 no-source, 0 undeclared, 0 unclassified; not judged: 3 outside a
      transaction, 0 unattributed

  (on one line). `unattributed` is a write from a process with no watched
  test in itself or its `$callers` (a process given a sandbox allowance, say):
  it belongs to no test, so it is counted for the whole suite.
  """
  @spec summary_line(totals()) :: String.t()
  def summary_line(%{} = totals) do
    escapes = Enum.map_join(@escape_kinds, ", ", &"#{Map.fetch!(totals, &1)} #{@labels[&1]}")

    "anchor backstop: #{totals.tests} tests watched, #{totals.crossings} crossings; " <>
      "escapes: #{escapes}; not judged: #{totals.outside_transaction} outside a " <>
      "transaction, #{totals.unattributed} unattributed"
  end

  # --- reading -------------------------------------------------------------

  defp read(%BackstopEvent{emitted_by: :other}, _index), do: :other_process
  defp read(%BackstopEvent{kind: :unknown}, _index), do: :unclassified
  defp read(%BackstopEvent{table: nil}, _index), do: :no_source
  defp read(%BackstopEvent{tx: :no_tx}, _index), do: :outside_transaction

  defp read(%BackstopEvent{tx: {:in_tx, ref}, table: table}, index) do
    case Index.aggregate_of(index, table) do
      {:ok, aggregate} -> {:judged, ref, aggregate, table}
      :error -> :undeclared_table
    end
  end

  # Transactions in the order their first judged write came, each with the
  # lexically first table it wrote per aggregate.
  defp crossings(read) do
    judged = for {:judged, ref, aggregate, table} <- read, do: {ref, aggregate, table}
    refs = judged |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
    by_ref = Enum.group_by(judged, &elem(&1, 0), &{elem(&1, 1), elem(&1, 2)})

    for ref <- refs,
        tables = first_tables(Map.fetch!(by_ref, ref)),
        map_size(tables) > 1 do
      %{tx: ref, aggregates: tables |> Map.keys() |> Enum.sort(), tables: tables}
    end
  end

  defp first_tables(writes) do
    writes
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {aggregate, tables} -> {aggregate, Enum.min(tables)} end)
  end

  # --- messages ------------------------------------------------------------

  defp crossing_message(test, %{aggregates: [first | rest] = aggregates, tables: tables}) do
    wrote = aggregates |> Enum.map(&"#{&1} (table #{tables[&1]})") |> and_list()
    "#{test}: transaction wrote aggregates #{wrote}. Fix: #{outbox_fix(first, rest)}"
  end

  defp outbox_fix(first, [other]) do
    "write #{other}'s change as an outbox row in #{first}, consumed by #{other}'s owner; " <>
      "or declare one aggregate holding both."
  end

  defp outbox_fix(first, others) do
    "write each of #{and_list(others)}'s changes as an outbox row in #{first}, consumed by " <>
      "that aggregate's owner; or declare one aggregate holding all of them."
  end

  defp escape_message(test, escapes, count) do
    kinds =
      @escape_kinds
      |> Enum.reject(&(escapes[&1] == 0))
      |> Enum.map_join(", ", &"#{escapes[&1]} #{@labels[&1]}")

    "#{test}: #{count} writes could not be tied to a transaction (#{kinds}). Fix: write " <>
      "through the repo in the test process, or list the table under an aggregate."
  end

  defp escaped(escapes), do: @escape_kinds |> Enum.map(&Map.fetch!(escapes, &1)) |> Enum.sum()

  defp and_list([one]), do: one
  defp and_list(items), do: Enum.join(Enum.drop(items, -1), ", ") <> " and " <> List.last(items)
end
