defmodule Anchor.Domain.Architecture.SelectorTest do
  # DND-5437: one selector of an `architecture:` bucket, matched against a
  # module's facts. Pure Domain. Parsing (and every refusal) is in
  # `architecture_checks_nothing_test.exs`.
  #
  # Sabotage record: ../../../sabotage_records/architecture-20261103-dnd_5437.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Architecture.Selector

  @facts %{
    module: MyApp.Domain.X,
    app: :my_app,
    source_file: "lib/a/domain/x/y.ex",
    uses: [],
    behaviours: [],
    exports: []
  }

  defp facts(overrides), do: Map.merge(@facts, Map.new(overrides))

  describe "matches?/2 with paths" do
    test "a recursive glob matches a file nested under it" do
      assert Selector.matches?({:paths, ["lib/**/domain/**/*.ex"]}, @facts)
    end

    test "positive control: a file outside the glob does not match" do
      refute Selector.matches?({:paths, ["lib/**/web/**/*.ex"]}, @facts)
    end

    test "any one of several globs is enough" do
      assert Selector.matches?({:paths, ["test/**/*.exs", "lib/**/domain/**/*.ex"]}, @facts)
    end

    test "a module with no known source file matches no paths selector" do
      refute Selector.matches?({:paths, ["lib/**/domain/**/*.ex"]}, facts(source_file: nil))
      refute Selector.matches?({:paths, ["**"]}, facts(source_file: nil))
    end
  end

  describe "matches?/2 with pattern" do
    test "a module-name glob matches the module" do
      assert Selector.matches?({:pattern, "MyApp.Domain.*"}, @facts)
    end

    test "the dot is literal" do
      refute Selector.matches?({:pattern, "MyApp.Domain.*"}, facts(module: MyApp.DomainX))
    end

    test "an Erlang module is matched by its own name" do
      assert Selector.matches?({:pattern, "gen_*"}, facts(module: :gen_tcp))
    end
  end

  describe "matches?/2 with uses_module" do
    test "a module that uses the named module matches" do
      assert Selector.matches?({:uses_module, GenServer}, facts(uses: [Ecto.Schema, GenServer]))
    end

    test "a module that uses nothing does not" do
      refute Selector.matches?({:uses_module, GenServer}, facts(uses: []))
    end
  end

  describe "matches?/2 with behaviour" do
    test "a module declaring the behaviour matches" do
      assert Selector.matches?({:behaviour, Supervisor}, facts(behaviours: [Supervisor]))
    end

    test "a module without it does not" do
      refute Selector.matches?({:behaviour, Supervisor}, facts(behaviours: [GenServer]))
    end
  end

  describe "matches?/2 with exports_function" do
    test "a module exporting name/arity matches" do
      assert Selector.matches?(
               {:exports_function, {:__aggregate__, 0}},
               facts(exports: [{:__aggregate__, 0}])
             )
    end

    test "another arity does not" do
      refute Selector.matches?(
               {:exports_function, {:__aggregate__, 1}},
               facts(exports: [{:__aggregate__, 0}])
             )
    end
  end

  describe "parse/2" do
    test "each selector key parses to its tuple" do
      path = "architecture.roots[0]"

      assert Selector.parse(%{"paths" => ["lib/*.ex"]}, path) == {:ok, {:paths, ["lib/*.ex"]}}
      assert Selector.parse(%{"pattern" => "A.*"}, path) == {:ok, {:pattern, "A.*"}}

      assert Selector.parse(%{"uses_module" => "GenServer"}, path) ==
               {:ok, {:uses_module, GenServer}}

      assert Selector.parse(%{"behaviour" => ":gen_server"}, path) ==
               {:ok, {:behaviour, :gen_server}}

      assert Selector.parse(%{"exports_function" => "run!/2"}, path) ==
               {:ok, {:exports_function, {:run!, 2}}}
    end

    test "keys/0 lists the five selector keys" do
      assert Selector.keys() == ~w(behaviour exports_function paths pattern uses_module)
    end
  end
end
