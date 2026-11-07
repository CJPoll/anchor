defmodule Anchor.Domain.Aggregates.BackstopTest do
  # DND-5480: the test-time backstop's verdict, pure, over hand-built events
  # and an index. Aggregate A holds table `orders`, B holds `invoices`; `audit`
  # is in no aggregate. That a schema's derived table lands in `by_table` is
  # Index's own test (index_test.exs) and the integration test's (I1).
  #
  # Sabotage record: ../../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Aggregates.Backstop
  alias Anchor.Domain.Aggregates.BackstopEvent
  alias Anchor.Domain.Aggregates.Index

  @index %Index{
    by_table: %{"orders" => "A", "order_lines" => "A", "invoices" => "B", "ledger" => "C"}
  }
  @test_name "MyApp.OrdersTest test pays"

  defp write(table, tx, overrides \\ []) do
    BackstopEvent.new(
      Map.merge(
        %{pid: self(), test_pid: self(), table: table, kind: :insert, tx: tx, emitted_by: :test},
        Map.new(overrides)
      )
    )
  end

  defp zero_escapes do
    %{
      other_process: 0,
      no_source: 0,
      undeclared_table: 0,
      unclassified: 0,
      outside_transaction: 0
    }
  end

  describe "verdict/2" do
    test "D1: one transaction writing one aggregate twice is no crossing (positive control)" do
      r1 = make_ref()

      assert Backstop.verdict(
               [write("orders", {:in_tx, r1}), write("order_lines", {:in_tx, r1})],
               @index
             ) ==
               %{crossings: [], escapes: zero_escapes()}
    end

    test "D2: one transaction writing A and B is one crossing, one table each" do
      r1 = make_ref()
      events = [write("orders", {:in_tx, r1}), write("invoices", {:in_tx, r1})]

      assert %{crossings: [crossing], escapes: escapes} = Backstop.verdict(events, @index)

      assert crossing == %{
               tx: r1,
               aggregates: ["A", "B"],
               tables: %{"A" => "orders", "B" => "invoices"}
             }

      assert escapes == zero_escapes()
    end

    test "D2: the table named per aggregate is the lexically first it wrote" do
      r1 = make_ref()

      events = [
        write("orders", {:in_tx, r1}),
        write("invoices", {:in_tx, r1}),
        write("order_lines", {:in_tx, r1})
      ]

      assert %{crossings: [%{tables: %{"A" => "order_lines"}}]} = Backstop.verdict(events, @index)
    end

    test "D3: A and B written in two separate transactions are no crossing" do
      events = [write("orders", {:in_tx, make_ref()}), write("invoices", {:in_tx, make_ref()})]
      assert %{crossings: []} = Backstop.verdict(events, @index)
    end

    test "D4: A and B written outside any transaction are no crossing, and are counted" do
      events = [write("orders", :no_tx), write("invoices", :no_tx)]

      assert Backstop.verdict(events, @index) ==
               %{crossings: [], escapes: %{zero_escapes() | outside_transaction: 2}}
    end

    test "D5: a write with no source is a no_source escape, never judged" do
      r1 = make_ref()
      events = [write("orders", {:in_tx, r1}), write(nil, {:in_tx, r1})]

      assert Backstop.verdict(events, @index) ==
               %{crossings: [], escapes: %{zero_escapes() | no_source: 1}}
    end

    test "D6: a write from another process is an other_process escape, never joined to the test's transaction" do
      r1 = make_ref()

      events = [
        write("orders", {:in_tx, r1}),
        write("invoices", {:in_tx, r1}, emitted_by: :other)
      ]

      assert Backstop.verdict(events, @index) ==
               %{crossings: [], escapes: %{zero_escapes() | other_process: 1}}
    end

    test "D7: a table in no aggregate is an undeclared_table escape and no crossing" do
      r1 = make_ref()
      events = [write("orders", {:in_tx, r1}), write("audit", {:in_tx, r1})]

      assert Backstop.verdict(events, @index) ==
               %{crossings: [], escapes: %{zero_escapes() | undeclared_table: 1}}
    end

    test "a statement read as neither a read nor a write is an unclassified escape" do
      r1 = make_ref()
      events = [write("orders", {:in_tx, r1}), write("invoices", {:in_tx, r1}, kind: :unknown)]

      assert Backstop.verdict(events, @index) ==
               %{crossings: [], escapes: %{zero_escapes() | unclassified: 1}}
    end

    test "each event is read once, by the first row that matches" do
      # other process before unknown before no source before no transaction
      events = [
        write(nil, :no_tx, emitted_by: :other, kind: :unknown),
        write(nil, :no_tx, kind: :unknown),
        write(nil, :no_tx),
        write("audit", :no_tx)
      ]

      assert Backstop.verdict(events, @index).escapes == %{
               other_process: 1,
               unclassified: 1,
               no_source: 1,
               outside_transaction: 1,
               undeclared_table: 0
             }
    end

    test "two crossing transactions are two crossings, in the order of their first write" do
      r1 = make_ref()
      r2 = make_ref()

      events = [
        write("ledger", {:in_tx, r2}),
        write("orders", {:in_tx, r1}),
        write("invoices", {:in_tx, r1}),
        write("orders", {:in_tx, r2})
      ]

      assert %{
               crossings: [%{tx: ^r2, aggregates: ["A", "C"]}, %{tx: ^r1, aggregates: ["A", "B"]}]
             } =
               Backstop.verdict(events, @index)
    end
  end

  describe "failure/3" do
    test "a crossing fails, naming the test, both aggregates, a table each and the outbox Fix" do
      r1 = make_ref()

      result =
        Backstop.verdict([write("orders", {:in_tx, r1}), write("invoices", {:in_tx, r1})], @index)

      assert Backstop.failure(result, @test_name, :report) ==
               {:fail,
                "MyApp.OrdersTest test pays: transaction wrote aggregates A (table orders) and B " <>
                  "(table invoices). Fix: write B's change as an outbox row in A, consumed by " <>
                  "B's owner; or declare one aggregate holding both."}
    end

    test "a crossing of three aggregates names each, with one Fix" do
      r1 = make_ref()

      events = [
        write("orders", {:in_tx, r1}),
        write("invoices", {:in_tx, r1}),
        write("ledger", {:in_tx, r1})
      ]

      assert {:fail, message} =
               Backstop.failure(Backstop.verdict(events, @index), @test_name, :report)

      assert message ==
               "MyApp.OrdersTest test pays: transaction wrote aggregates A (table orders), B " <>
                 "(table invoices) and C (table ledger). Fix: write each of B and C's changes " <>
                 "as an outbox row in A, consumed by that aggregate's owner; or declare one " <>
                 "aggregate holding all of them."
    end

    test "no crossing passes under :report, escapes or not" do
      result =
        Backstop.verdict([write(nil, :no_tx), write("x", :no_tx, emitted_by: :other)], @index)

      assert Backstop.failure(result, @test_name, :report) == :pass
    end

    test "under :fail an escape fails, naming each kind it saw" do
      r1 = make_ref()

      events = [
        write(nil, {:in_tx, r1}),
        write("audit", {:in_tx, r1}),
        write("orders", {:in_tx, r1}, emitted_by: :other)
      ]

      assert Backstop.failure(Backstop.verdict(events, @index), @test_name, :fail) ==
               {:fail,
                "MyApp.OrdersTest test pays: 3 writes could not be tied to a transaction " <>
                  "(1 other-process, 1 no-source, 1 undeclared). Fix: write through the repo " <>
                  "in the test process, or list the table under an aggregate."}
    end

    test "under :fail an unclassified statement fails too" do
      events = [write("orders", {:in_tx, make_ref()}, kind: :unknown)]

      assert {:fail, message} =
               Backstop.failure(Backstop.verdict(events, @index), @test_name, :fail)

      assert message =~ "(1 unclassified)"
    end

    test "under :fail a write outside a transaction alone passes: it is counted, not an escape" do
      result = Backstop.verdict([write("orders", :no_tx)], @index)
      assert Backstop.failure(result, @test_name, :fail) == :pass
    end

    test "under :fail with no escape a test passes (positive control)" do
      r1 = make_ref()
      result = Backstop.verdict([write("orders", {:in_tx, r1})], @index)
      assert Backstop.failure(result, @test_name, :fail) == :pass
    end
  end

  describe "counts/1 and summary_line/1" do
    test "a test counts itself, its crossings and every counted kind" do
      r1 = make_ref()

      result =
        Backstop.verdict(
          [write("orders", {:in_tx, r1}), write("invoices", {:in_tx, r1}), write(nil, :no_tx)],
          @index
        )

      assert Backstop.counts(result) ==
               %{zero_escapes() | no_source: 1} |> Map.merge(%{tests: 1, crossings: 1})
    end

    test "F3: the summary is one line with every documented field" do
      totals = %{
        tests: 12,
        crossings: 1,
        other_process: 2,
        no_source: 3,
        undeclared_table: 4,
        unclassified: 5,
        outside_transaction: 6,
        unattributed: 7
      }

      assert Backstop.summary_line(totals) ==
               "anchor backstop: 12 tests watched, 1 crossings; escapes: 2 other-process, " <>
                 "3 no-source, 4 undeclared, 5 unclassified; not judged: 6 outside a " <>
                 "transaction, 7 unattributed"

      assert Enum.sort(Backstop.total_keys()) == Enum.sort(Map.keys(totals))
    end
  end
end
