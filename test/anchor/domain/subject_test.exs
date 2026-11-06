defmodule Anchor.Domain.SubjectTest do
  # DND-5446: what mix anchor.explain is asked about. Pure Domain.
  #
  # Sabotage record: ../../sabotage_records/explain-20261103-dnd_5443_graph_rules_b.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Subject

  @root "/repo"

  describe "parse/2" do
    test "a module name is a module" do
      assert Subject.parse("Anchor.Domain.Graph", @root) == {:module, Anchor.Domain.Graph}
    end

    test "a path under lib/ implies its module by Elixir's naming convention" do
      assert Subject.parse("lib/anchor/domain/graph.ex", @root) ==
               {:path, "lib/anchor/domain/graph.ex", Anchor.Domain.Graph}

      assert Subject.parse("lib/anchor/domain/new_thing.ex", @root) ==
               {:path, "lib/anchor/domain/new_thing.ex", Anchor.Domain.NewThing}
    end

    test "an umbrella app's path drops the app directory" do
      assert Subject.parse("apps/foo/lib/foo/bar.ex", @root) ==
               {:path, "apps/foo/lib/foo/bar.ex", Foo.Bar}
    end

    test "an absolute path inside the root is made relative" do
      assert Subject.parse("/repo/lib/a/b_c.ex", @root) == {:path, "lib/a/b_c.ex", A.BC}
    end

    test "a path with no lib/ segment implies no module" do
      assert Subject.parse("scripts/run.ex", @root) == {:path, "scripts/run.ex", nil}
    end

    test "a path that leaves the root is refused" do
      assert Subject.parse("../etc/passwd.ex", @root) == {:error, :outside_root}
      assert Subject.parse("/etc/passwd.ex", @root) == {:error, :outside_root}
      assert Subject.parse("lib/../../x.ex", @root) == {:error, :outside_root}
    end

    test "anything else is not a subject" do
      assert Subject.parse("", @root) == {:error, :not_a_subject}
      assert Subject.parse("lib/a/b.exs", @root) == {:error, :not_a_subject}
      assert Subject.parse("MyApp.*", @root) == {:error, :not_a_subject}
      assert Subject.parse("my_app.thing", @root) == {:error, :not_a_subject}
    end
  end

  describe "implied_path/1" do
    test "the convention's path for a module" do
      assert Subject.implied_path(Anchor.Domain.NewThing) == "lib/anchor/domain/new_thing.ex"
    end
  end
end
