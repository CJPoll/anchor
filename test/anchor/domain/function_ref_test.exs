defmodule Anchor.Domain.FunctionRefTest do
  # The `forbidden_functions` token grammar (DND-1267): "Mod.fun",
  # "Mod.fun/arity", and ":erlang_mod.fun[/arity]". A token that does not name
  # one function exactly is an error, so a typo fails the load instead of
  # becoming a rule that checks nothing.
  #
  # Sabotage record: ../../sabotage_records/function_ref-20260929-dnd_1267_forbidden_functions.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.FunctionRef

  @valid [
    {"Athena.Slack.user_info", Athena.Slack, :user_info, :any},
    {"Athena.Slack.user_info/2", Athena.Slack, :user_info, 2},
    {"MyApp.Repo.insert!/1", MyApp.Repo, :insert!, 1},
    {"MyApp.Repo.exists?", MyApp.Repo, :exists?, :any},
    {"Code.eval_file", Code, :eval_file, :any},
    {"Finch.request/0", Finch, :request, 0},
    {"Elixir.Code.eval_string/3", Code, :eval_string, 3},
    {"My_App.V2.do_it", My_App.V2, :do_it, :any},
    {"MyApp.Mod._private", MyApp.Mod, :_private, :any},
    {":telemetry.execute/3", :telemetry, :execute, 3},
    {":ets.insert", :ets, :insert, :any},
    {":erlang.apply/3", :erlang, :apply, 3}
  ]

  @malformed [
    {"MyApp.Repo", "names no function"},
    {"insert", "names no module"},
    {".insert", "names no module"},
    {"MyApp.Repo.", "names no function"},
    {"MyApp..Repo.insert", "is not a module name"},
    {"myapp.Repo.insert", "is not a module name"},
    {"MyApp.repo.insert", "is not a module name"},
    {"My-App.Repo.insert", "is not a module name"},
    {"MyApp.Repo.Insert", "names no function"},
    {"MyApp.Repo.in-sert", "is not a function name"},
    {"MyApp.Repo.ins?ert", "is not a function name"},
    {"MyApp.Repo.1insert", "is not a function name"},
    {"MyApp.Repo.*", "is not a function name"},
    {"MyApp.*.insert", "is not a module name"},
    {"MyApp.Repo.insert/", "is not an arity"},
    {"MyApp.Repo.insert/x", "is not an arity"},
    {"MyApp.Repo.insert/-1", "is not an arity"},
    {"MyApp.Repo.insert/1.0", "is not an arity"},
    {"MyApp.Repo.insert/256", "is not an arity"},
    {"MyApp.Repo.insert/1/2", "is not an arity"},
    {"MyApp.Repo.insert()", "is not a function name"},
    {" MyApp.Repo.insert", "is not a module name"},
    {"MyApp.Repo.insert ", "is not a function name"},
    {":.insert", "is not a module name"},
    {":Ets.insert", "is not a module name"},
    {":ets", "names no function"},
    {"Kernel.+/2", "is not a function name"}
  ]

  test "every valid token parses to its module, function and arity" do
    for {token, module, function, arity} <- @valid do
      assert FunctionRef.parse(token) ==
               {:ok, %FunctionRef{module: module, function: function, arity: arity}},
             token
    end
  end

  test "every malformed token is an error naming the token and why" do
    failures =
      for {token, why} <- @malformed,
          result = FunctionRef.parse(token),
          not match?({:error, _}, result) or not (elem(result, 1) =~ why) or
            not (elem(result, 1) =~ inspect(token)) do
        "#{inspect(token)}: want an error with #{inspect(why)}, got #{inspect(result)}"
      end

    assert failures == [], Enum.join(failures, "\n")
  end

  test "an error says how the token should be written" do
    assert {:error, reason} = FunctionRef.parse("MyApp.Repo")
    assert reason =~ ~s("Module.function" or "Module.function/arity")
  end

  test "to_string/1 prints a parsed token back" do
    for token <- ["Athena.Slack.user_info", "Athena.Slack.user_info/2", ":ets.insert/3"] do
      assert {:ok, ref} = FunctionRef.parse(token)
      assert FunctionRef.to_string(ref) == token
    end
  end

  test "matches?/4 compares module and function exactly, and arity when the token has one" do
    {:ok, any} = FunctionRef.parse("Bad.Mod.f")
    {:ok, two} = FunctionRef.parse("Bad.Mod.f/2")

    assert FunctionRef.matches?(any, Bad.Mod, :f, 0)
    assert FunctionRef.matches?(any, Bad.Mod, :f, :any)
    assert FunctionRef.matches?(two, Bad.Mod, :f, 2)
    assert FunctionRef.matches?(two, Bad.Mod, :f, :any)
    refute FunctionRef.matches?(two, Bad.Mod, :f, 1)
    refute FunctionRef.matches?(any, Bad.Mod, :g, 1)
    refute FunctionRef.matches?(any, Bad.Mod.Sub, :f, 1)
    refute FunctionRef.matches?(any, Bad, :f, 1)
  end
end
