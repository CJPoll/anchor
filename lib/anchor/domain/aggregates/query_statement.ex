defmodule Anchor.Domain.Aggregates.QueryStatement do
  @moduledoc """
  What one Ecto query event says it did (DND-5480) — **Domain**, pure.

  `Anchor.Backstop` hears every query a repo runs through its telemetry event
  (`<telemetry_prefix> ++ [:query]`). `classify/1` reads two keys of that
  event's metadata, `query` (the SQL text) and `source` (the table Ecto wrote
  or read, `nil` for raw SQL and for transaction boundaries), and nothing
  else: never `params`, `cast_params` or `result`, which hold row values.

  DND-5479 pinned the shapes (ecto 3.14, ecto_sql 3.14, postgrex 0.22):

    * a transaction is a `"begin"` event, then its queries, then `"commit"` or
      `"rollback"`, each with `source: nil`. Only the outermost
      `Repo.transaction` emits them; a nested one emits none;
    * an insert, update or delete (single row or `*_all`, through a schema or
      a bare table name) starts `INSERT`, `UPDATE` or `DELETE` and carries its
      table in `source`;
    * a read starts `SELECT` and carries its table too;
    * raw SQL (`Repo.query/2`) carries `source: nil`.

  The kinds:

  | Query text | Result |
  |---|---|
  | exactly `begin`, `commit`, `rollback` (any case, trimmed, a trailing `;` dropped) | `:begin`, `:commit`, `:rollback` |
  | first word `INSERT`, `UPDATE`, `DELETE` | `{:write, :insert \\| :update \\| :delete, source}` |
  | first word `SELECT` | `:read` |
  | first word `SAVEPOINT` or `RELEASE`, or first words `ROLLBACK TO` | `:savepoint`: inside a transaction already open, never a boundary |
  | anything else (`WITH`, `MERGE`, `TRUNCATE`, `COPY`, ...) | `{:write, :unknown, source}` |

  The last row fails closed: a statement this module cannot read as a read is
  never dropped as one. `Anchor.Domain.Aggregates.Backstop` counts it as an
  `unclassified` escape, never judged and never clean.

  Metadata without a binary `query` and a `source` key is not an Ecto query
  event: `classify/1` raises `FunctionClauseError`, `:telemetry` detaches the
  handler, and the next verdict fails the test (`the backstop handler was
  detached`).
  """

  @type kind :: :insert | :update | :delete | :unknown
  @type t ::
          :begin
          | :commit
          | :rollback
          | :savepoint
          | :read
          | {:write, kind(), String.t() | nil}

  @boundaries %{"begin" => :begin, "commit" => :commit, "rollback" => :rollback}
  @writes %{"INSERT" => :insert, "UPDATE" => :update, "DELETE" => :delete}

  @doc "The statement an Ecto query event's metadata describes; see the moduledoc."
  @spec classify(%{required(:query) => String.t(), required(:source) => term()}) :: t()
  def classify(%{query: query, source: source}) when is_binary(query) do
    text = query |> String.trim() |> String.trim_trailing(";") |> String.trim()

    case Map.fetch(@boundaries, String.downcase(text)) do
      {:ok, boundary} -> boundary
      :error -> statement(words(text), source)
    end
  end

  # The first two whitespace-separated words, upper-cased. Only the head of
  # the text is split: a statement's kind is in its first words.
  defp words(text) do
    text
    |> String.slice(0, 64)
    |> String.split()
    |> Enum.take(2)
    |> Enum.map(&String.upcase/1)
  end

  defp statement(["SELECT" | _rest], _source), do: :read
  defp statement(["SAVEPOINT" | _rest], _source), do: :savepoint
  defp statement(["RELEASE" | _rest], _source), do: :savepoint
  defp statement(["ROLLBACK", "TO"], _source), do: :savepoint

  defp statement([word | _rest], source),
    do: {:write, Map.get(@writes, word, :unknown), table(source)}

  defp statement([], source), do: {:write, :unknown, table(source)}

  defp table(source) when is_binary(source) and source != "", do: source
  defp table(_none), do: nil
end
