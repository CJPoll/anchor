defmodule Anchor.Test.BackstopMetadata do
  @moduledoc """
  The metadata of Ecto's `[<prefix>, :query]` telemetry event, in the shapes
  DND-5479 pinned on a real database under the SQL sandbox
  (gen_saas `Todos.RepoTelemetryFactsTest`; ecto 3.14, ecto_sql 3.14,
  postgrex 0.22): the keys Ecto SQL sends, `type: :ecto_sql_query`,
  `options: []`, `source` the table for a schema or bare-table write and a
  read, `nil` for raw SQL and for `"begin"`, `"commit"` and `"rollback"`.

  The query texts are Ecto's Postgres SQL for each kind. Each event carries
  `params`, `cast_params` and a `result` holding `secret/0`, so a test can
  prove the backstop keeps none of them.
  """

  @secret "row-value-dnd-5480-must-never-be-recorded"

  @doc "A value only params and results hold: it must appear in no recorded term."
  @spec secret() :: String.t()
  def secret, do: @secret

  @doc "An insert into `table` through a schema (`Repo.insert/2`)."
  @spec insert(String.t()) :: map()
  def insert(table) do
    query(
      ~s|INSERT INTO "#{table}" ("name","inserted_at","updated_at","id") VALUES ($1,$2,$3,$4)|,
      table
    )
  end

  @doc "An update of `table` (`Repo.update/2`, `update_all/3`)."
  @spec update(String.t()) :: map()
  def update(table),
    do: query(~s|UPDATE "#{table}" SET "name" = $1, "updated_at" = $2 WHERE "id" = $3|, table)

  @doc "A delete from `table` (`Repo.delete/2`, `delete_all/2`)."
  @spec delete(String.t()) :: map()
  def delete(table), do: query(~s|DELETE FROM "#{table}" WHERE "id" = $1|, table)

  @doc "A read of `table` (`Repo.all/2`)."
  @spec select(String.t()) :: map()
  def select(table),
    do: query(~s|SELECT t0."id", t0."name" FROM "#{table}" AS t0|, table)

  @doc "Raw SQL through `Repo.query/2`: no source."
  @spec raw_insert(String.t()) :: map()
  def raw_insert(table) do
    query("INSERT INTO #{table} (id, name, inserted_at, updated_at) VALUES ($1, $2, $3, $3)", nil)
  end

  @doc "The `begin` event of the outermost `Repo.transaction`."
  @spec begin() :: map()
  def begin, do: boundary("begin")

  @doc "The `commit` event of the outermost `Repo.transaction`."
  @spec commit() :: map()
  def commit, do: boundary("commit")

  @doc "The `rollback` event (`Repo.rollback/1`, or a raise in the transaction)."
  @spec rollback() :: map()
  def rollback, do: boundary("rollback")

  defp boundary(query) do
    %{
      type: :ecto_sql_query,
      repo: AnchorFixtures.Backstop.Repo,
      result: {:ok, %{command: query, rows: nil, num_rows: 0}},
      params: [],
      cast_params: [],
      query: query,
      source: nil,
      stacktrace: nil,
      options: []
    }
  end

  defp query(query, source) do
    %{
      type: :ecto_sql_query,
      repo: AnchorFixtures.Backstop.Repo,
      result: {:ok, %{num_rows: 1, rows: [[@secret]]}},
      params: [@secret, 1, 2, "00000000-0000-0000-0000-000000000001"],
      cast_params: [@secret],
      query: query,
      source: source,
      stacktrace: nil,
      options: []
    }
  end
end
