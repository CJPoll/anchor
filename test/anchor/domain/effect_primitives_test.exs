defmodule Anchor.Domain.EffectPrimitivesTest do
  # Domain (ADR 002). DND-5498 R2-R3: the effect and escape table, read by
  # the demand analysis, keyed by the callee as Core names it.
  #
  # Sabotage record: ../../sabotage_records/demand-20261103-dnd_5498_demand.md
  # Sabotage record (DND-5677): ../../sabotage_records/effects-20261106-dnd_5676_effects_cfa_batch.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.EffectPrimitives

  describe "escape?/1" do
    test "send, spawn, Task, ETS writes, persistent_term and the process dictionary escape" do
      for mfa <- [
            {:erlang, :send, 2},
            {:erlang, :spawn, 1},
            {Task, :start, 1},
            {Task, :async, 1},
            {:ets, :insert, 2},
            {:persistent_term, :put, 2},
            {:erlang, :put, 2},
            {Process, :put, 2},
            {GenServer, :cast, 2}
          ] do
        assert EffectPrimitives.escape?(mfa), "#{inspect(mfa)} should escape"
      end
    end

    test "a read is no escape" do
      for mfa <- [{:ets, :lookup, 2}, {:persistent_term, :get, 1}, {:erlang, :get, 1}] do
        refute EffectPrimitives.escape?(mfa), "#{inspect(mfa)} should not escape"
      end
    end
  end

  describe "effect?/2" do
    test "IO, Logger, a raise and a Repo write are effects; a pure call is not" do
      assert EffectPrimitives.effect?({IO, :puts, 1}, [])
      assert EffectPrimitives.effect?({Logger, :__do_log__, 4}, [])
      assert EffectPrimitives.effect?({:erlang, :error, 1}, [])
      assert EffectPrimitives.effect?({MyApp.Repo, :insert, 2}, [])
      refute EffectPrimitives.effect?({MyApp.Repository, :insert, 2}, [])
      refute EffectPrimitives.effect?({MyApp.Repo, :get, 2}, [])
      refute EffectPrimitives.effect?({:repo, :insert, 2}, [])
      refute EffectPrimitives.effect?({String, :upcase, 1}, [])
    end

    test "an extra token makes its function an effect, at its arity only" do
      extra = EffectPrimitives.parse_extra!(["Notifier.push/1"])
      assert EffectPrimitives.effect?({Notifier, :push, 1}, extra)
      refute EffectPrimitives.effect?({Notifier, :push, 2}, extra)
      refute EffectPrimitives.effect?({Notifier, :push, 1}, [])
    end

    test "a module token makes every function of that module an effect" do
      extra = EffectPrimitives.parse_extra!(["Req", ":gen_tcp"])
      assert EffectPrimitives.effect?({Req, :get, 2}, extra)
      assert EffectPrimitives.effect?({:gen_tcp, :connect, 3}, extra)
      refute EffectPrimitives.effect?({Req.Request, :new, 1}, extra)
      refute EffectPrimitives.effect?({Req, :get, 2}, [])
    end

    test "module_name/1 spells a module as a token does" do
      assert EffectPrimitives.module_name(IO) == "IO"
      assert EffectPrimitives.module_name(:ets) == ":ets"
    end

    test "a token that does not parse raises with the grammar's message" do
      assert_raise ArgumentError, ~r/is not a function reference/, fn ->
        EffectPrimitives.parse_extra!(["Notifier.*"])
      end
    end

    test "default/0 lists every row once with its kind" do
      rows = EffectPrimitives.default()
      assert {:escape, {":erlang", :send, :*}} in rows
      assert {:effect, {"IO", :*, :*}} in rows
      assert length(rows) == length(Enum.uniq(rows))
    end
  end

  # DND-5447: effect inference reads a wider list (reads, clocks, randomness),
  # matched through every source name of a Core call (DND-5613).
  # Sabotage record: ../../sabotage_records/effects-20261103-dnd_5447_graph_rules_c.md
  describe "primitive?/2 (DND-5447)" do
    defp primitives(effects \\ [], modules \\ %{}),
      do: EffectPrimitives.build(%{effects: effects}, %{modules: modules})

    test "a default module primitive matches any of its functions" do
      assert EffectPrimitives.primitive?(primitives(), {File, :read, 1})
      assert EffectPrimitives.primitive?(primitives(), {:ets, :lookup, 2})
    end

    test "a function-level primitive matches only that function" do
      assert EffectPrimitives.primitive?(primitives(), {:erlang, :send, 2})
      refute EffectPrimitives.primitive?(primitives(), {:erlang, :element, 2})
    end

    test "a pure stdlib call is not a primitive (positive control for the module rows)" do
      refute EffectPrimitives.primitive?(primitives(), {Enum, :map, 2})
      refute EffectPrimitives.primitive?(primitives(), {Map, :put, 3})
    end

    test "a clock or randomness read is a primitive" do
      assert EffectPrimitives.primitive?(primitives(), {DateTime, :utc_now, 0})
      assert EffectPrimitives.primitive?(primitives(), {:rand, :uniform, 1})
      assert EffectPrimitives.primitive?(primitives(), {:crypto, :strong_rand_bytes, 1})
    end

    test "a call Elixir inlined matches through its source name" do
      # System.unique_integer/0 reaches Core as :erlang.unique_integer/0.
      assert EffectPrimitives.primitive?(primitives(), {:erlang, :unique_integer, 0})
      refute EffectPrimitives.primitive?(primitives(), {:erlang, :element, 2})
    end
  end

  describe "build/2 (DND-5447)" do
    test "config effects add to the defaults" do
      primitives = EffectPrimitives.build(%{effects: ["Req"]}, %{modules: %{}})
      assert EffectPrimitives.primitive?(primitives, {Req, :get, 1})
      assert EffectPrimitives.primitive?(primitives, {File, :read, 1})
    end

    test "a module declaring the Ecto.Repo behaviour is a primitive" do
      modules = %{App.Repo => %{behaviours: [Ecto.Repo]}, App.Other => %{behaviours: []}}
      primitives = EffectPrimitives.build(%{effects: []}, %{modules: modules})

      assert EffectPrimitives.primitive?(primitives, {App.Repo, :insert, 1})
      refute EffectPrimitives.primitive?(primitives, {App.Other, :insert, 1})
    end

    test "config cannot remove a default" do
      primitives = EffectPrimitives.build(%{effects: []}, %{modules: %{}})
      assert EffectPrimitives.primitive?(primitives, {File, :read, 1})
    end

    test "the demand table is unchanged: a file read is no demand effect" do
      refute EffectPrimitives.effect?({File, :read, 1}, [])
      assert EffectPrimitives.effect?({File, :write, 2}, [])
    end
  end

  describe "the clock and randomness families (DND-5677)" do
    @clock [
      {DateTime, :utc_now, 0},
      {DateTime, :now, 1},
      {DateTime, :now!, 1},
      {NaiveDateTime, :utc_now, 0},
      {NaiveDateTime, :local_now, 0},
      {Time, :utc_now, 0},
      {Date, :utc_today, 0},
      {System, :system_time, 1},
      {System, :monotonic_time, 0},
      {System, :os_time, 0},
      {:os, :timestamp, 0},
      {:os, :system_time, 1},
      {:erlang, :timestamp, 0},
      {:erlang, :now, 0},
      {:erlang, :time, 0},
      {:erlang, :date, 0},
      {:erlang, :localtime, 0},
      {:erlang, :universaltime, 0},
      {:erlang, :system_time, 0},
      {:erlang, :monotonic_time, 1},
      {:erlang, :time_offset, 0},
      {:calendar, :local_time, 0},
      {:calendar, :universal_time, 0}
    ]

    @random [
      {:rand, :uniform, 1},
      {:rand, :seed, 1},
      {:random, :uniform, 0},
      {Enum, :random, 1},
      {Enum, :take_random, 2},
      {Enum, :shuffle, 1},
      {:crypto, :strong_rand_bytes, 1},
      {:crypto, :rand_seed, 0},
      {System, :unique_integer, 1},
      {:erlang, :unique_integer, 0}
    ]

    test "every clock read is a primitive of kind :clock" do
      for mfa <- @clock do
        assert EffectPrimitives.primitive?(primitives(), mfa), inspect(mfa)
        assert EffectPrimitives.inference_kind(mfa) == :clock, inspect(mfa)
      end
    end

    test "every random draw is a primitive of kind :random" do
      for mfa <- @random do
        assert EffectPrimitives.primitive?(primitives(), mfa), inspect(mfa)
        assert EffectPrimitives.inference_kind(mfa) == :random, inspect(mfa)
      end
    end

    test "control: their pure neighbours are no primitive and have no kind" do
      for mfa <- [
            {DateTime, :add, 3},
            {DateTime, :to_unix, 1},
            {NaiveDateTime, :compare, 2},
            {Time, :new, 3},
            {Date, :new, 3},
            {Enum, :sort, 1},
            {Enum, :take, 2},
            {Enum, :at, 2},
            {:crypto, :hash, 2},
            {:calendar, :valid_date, 1},
            {:erlang, :phash2, 1}
          ] do
        refute EffectPrimitives.primitive?(primitives(), mfa), inspect(mfa)
        assert EffectPrimitives.inference_kind(mfa) == nil, inspect(mfa)
      end
    end

    test "any other default row is of kind :effect; an extra token has none" do
      assert EffectPrimitives.inference_kind({File, :read, 1}) == :effect
      assert EffectPrimitives.inference_kind({System, :get_env, 1}) == :effect
      assert EffectPrimitives.inference_kind({Req, :get, 1}) == nil
    end
  end
end
