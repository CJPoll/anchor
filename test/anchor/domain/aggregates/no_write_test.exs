defmodule Anchor.Domain.Aggregates.NoWriteTest do
  # DND-5889: what the default clears without reading it.
  #
  # Sabotage record: ../../../sabotage_records/aggregates-20261106-dnd_5889_default_deny_walker.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Aggregates.NoWrite

  describe "member?/2" do
    test "a pure library call is cleared" do
      assert NoWrite.member?({Enum, :count, 1}, [])
      assert NoWrite.member?({:erlang, :+, 2}, [])
      assert NoWrite.member?({Kernel, :inspect, 1}, [])
      assert NoWrite.member?({Ecto.Changeset, :change, 1}, [])
      assert NoWrite.member?({DateTime, :utc_now, 0}, [])
      assert NoWrite.member?({RuntimeError, :exception, 1}, [])
      assert NoWrite.member?({:elixir_erl_pass, :no_parens_remote, 2}, [])
      assert NoWrite.member?({Application, :get_env, 3}, [])
      assert NoWrite.member?({Process, :get, 1}, [])
      assert NoWrite.member?({System, :monotonic_time, 1}, [])
    end

    test "what hands work to another process, or runs code, is never cleared" do
      for mfa <- [
            {GenServer, :call, 2},
            {Task, :async, 1},
            {Agent, :get, 2},
            {:erlang, :send, 2},
            {:erlang, :apply, 3},
            {:erlang, :spawn, 1},
            {Kernel, :apply, 3},
            {Kernel, :spawn, 1},
            {Kernel, :send, 2},
            {Application, :ensure_all_started, 1},
            {Process, :send, 3},
            {Process, :exit, 2},
            {System, :cmd, 2},
            {Phoenix.PubSub, :broadcast, 3},
            {Ecto.Multi, :insert, 3},
            {Ecto.Adapters.SQL, :query, 2}
          ] do
        refute NoWrite.member?(mfa, []), "#{inspect(mfa)} must be a gap"
      end
    end

    test "a module under aggregates.no_write_modules is cleared; with no list it is not" do
      assert NoWrite.member?({Lib, :save, 1}, [Lib])
      refute NoWrite.member?({Lib, :save, 1}, [])
      refute NoWrite.member?({Lib, :save, 1}, [Other])
    end

    test "listing a module held by function clears its other functions" do
      assert NoWrite.member?({:erlang, :send, 2}, [:erlang])
      assert NoWrite.member?({Kernel, :apply, 3}, [Kernel])
      assert NoWrite.member?({System, :cmd, 2}, [System])
    end
  end

  describe "gives_back?/1" do
    test "a function that returns its default, never runs it; any other is not" do
      assert NoWrite.gives_back?({Keyword, :get, 3})
      assert NoWrite.gives_back?({Map, :get, 3})
      refute NoWrite.gives_back?({Keyword, :put, 3})
    end
  end
end
