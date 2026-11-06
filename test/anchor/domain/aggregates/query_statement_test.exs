defmodule Anchor.Domain.Aggregates.QueryStatementTest do
  # DND-5480: what one Ecto query event says it did, read from the metadata
  # shapes DND-5479 pinned (Anchor.Test.BackstopMetadata).
  #
  # Sabotage record: ../../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Aggregates.QueryStatement
  alias Anchor.Test.BackstopMetadata, as: Meta

  test "begin, commit and rollback are the boundaries, whatever their case or trailing ;" do
    assert QueryStatement.classify(Meta.begin()) == :begin
    assert QueryStatement.classify(Meta.commit()) == :commit
    assert QueryStatement.classify(Meta.rollback()) == :rollback
    assert QueryStatement.classify(%{query: " BEGIN; ", source: nil}) == :begin
    assert QueryStatement.classify(%{query: "COMMIT", source: nil}) == :commit
    assert QueryStatement.classify(%{query: "Rollback;", source: nil}) == :rollback
  end

  test "an insert, update and delete are writes of their source table" do
    assert QueryStatement.classify(Meta.insert("orders")) == {:write, :insert, "orders"}
    assert QueryStatement.classify(Meta.update("orders")) == {:write, :update, "orders"}
    assert QueryStatement.classify(Meta.delete("orders")) == {:write, :delete, "orders"}
  end

  test "the kind is read from the first word, in any case, after leading whitespace" do
    assert QueryStatement.classify(%{query: "\n  insert into x values (1)", source: "x"}) ==
             {:write, :insert, "x"}
  end

  test "a read is a read, and is never a write" do
    assert QueryStatement.classify(Meta.select("orders")) == :read
  end

  test "raw SQL is a write with no table" do
    assert QueryStatement.classify(Meta.raw_insert("orders")) == {:write, :insert, nil}
  end

  test "an empty source is no table" do
    assert QueryStatement.classify(%{query: "DELETE FROM x", source: ""}) ==
             {:write, :delete, nil}
  end

  test "savepoint statements are neither boundaries nor writes" do
    assert QueryStatement.classify(%{query: "SAVEPOINT s1", source: nil}) == :savepoint
    assert QueryStatement.classify(%{query: "RELEASE SAVEPOINT s1", source: nil}) == :savepoint

    assert QueryStatement.classify(%{query: "ROLLBACK TO SAVEPOINT s1", source: nil}) ==
             :savepoint
  end

  test "a statement read as neither a read nor a write is an unknown write, never a read" do
    assert QueryStatement.classify(%{
             query: "WITH t AS (SELECT 1) UPDATE x SET y = 1",
             source: "x"
           }) ==
             {:write, :unknown, "x"}

    assert QueryStatement.classify(%{query: "TRUNCATE x", source: nil}) == {:write, :unknown, nil}
    assert QueryStatement.classify(%{query: "   ", source: nil}) == {:write, :unknown, nil}
  end

  test "metadata with no query text is not a query event: it raises" do
    assert_raise FunctionClauseError, fn ->
      QueryStatement.classify(%{query: nil, source: nil})
    end

    no_query = Map.delete(Meta.insert("orders"), :query)
    assert_raise FunctionClauseError, fn -> QueryStatement.classify(no_query) end
  end
end
