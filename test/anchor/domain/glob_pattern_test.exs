defmodule Anchor.Domain.GlobPatternTest do
  # Owns docs/five-bucket-test-matrix.md rows:
  #   base.ex -> matches_recursive_pattern?/2 -> #1-7
  #   base.ex -> matches_pattern?/2          -> #1-4
  #   base.ex -> matches_module_pattern?/2   -> #1-5
  # These pure glob helpers moved out of the Anchor.Check.Base __using__ macro
  # into Anchor.Domain.GlobPattern (T2 / DND-122); the behavioral contract is
  # the matrix, unchanged across the move.
  #
  # Sabotage record: ../../sabotage_records/glob_pattern-20260913-dnd_122_t2_domain_patterns.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.GlobPattern

  describe "matches_recursive_pattern?/2 (glob with **)" do
    test "#1 ** matches across path segments" do
      assert GlobPattern.matches_recursive_pattern?(
               "lib/my_app/web/user.ex",
               "lib/my_app/**/*.ex"
             )
    end

    test "#2 **/ matches zero segments" do
      assert GlobPattern.matches_recursive_pattern?("lib/user.ex", "lib/**/*.ex")
    end

    test "#3 single * does not cross a /" do
      refute GlobPattern.matches_recursive_pattern?("lib/a/b.ex", "lib/*.ex")
    end

    test "#4 single * matches within one segment" do
      assert GlobPattern.matches_recursive_pattern?("lib/user.ex", "lib/*.ex")
    end

    test "#5 literal . is not a wildcard" do
      refute GlobPattern.matches_recursive_pattern?("libXex", "lib.ex")
    end

    test "#6 extension mismatch" do
      refute GlobPattern.matches_recursive_pattern?("lib/user.exs", "lib/**/*.ex")
    end

    test "#7 leading ** matches anything" do
      assert GlobPattern.matches_recursive_pattern?("deep/a/b/c.ex", "**/*.ex")
    end
  end

  describe "matches_pattern?/2 (glob without **, single *)" do
    test "#1 * matches within a segment" do
      assert GlobPattern.matches_pattern?("lib/user.ex", "lib/*.ex")
    end

    test "#2 * does not cross /" do
      refute GlobPattern.matches_pattern?("lib/a/b.ex", "lib/*.ex")
    end

    test "#3 exact match" do
      assert GlobPattern.matches_pattern?("lib/user.ex", "lib/user.ex")
    end

    test "#4 anchored full match (no partial)" do
      refute GlobPattern.matches_pattern?("xlib/user.exy", "lib/user.ex")
    end
  end

  describe "matches_module_pattern?/2 (module-name glob)" do
    test "#1 trailing * matches submodules" do
      assert GlobPattern.matches_module_pattern?("MyApp.Web.UserController", "MyApp.Web.*")
    end

    test "#2 * may cross dots for module names" do
      assert GlobPattern.matches_module_pattern?("App.Schemas.User", "*.Schemas.*")
    end

    test "#3 suffix pattern" do
      assert GlobPattern.matches_module_pattern?("App.UserQueries", "*Queries")
    end

    test "#4 non-match" do
      refute GlobPattern.matches_module_pattern?("App.Service", "*.Schemas.*")
    end

    test "#5 literal dots are escaped" do
      refute GlobPattern.matches_module_pattern?("AppXSchemasXUser", "*.Schemas.*")
    end
  end

  # DND-1290: a module name reaches the matcher fully qualified
  # (`Elixir.MyApp.Web.Foo`, from `to_string/1`), so a pattern written in alias
  # form (`MyApp.Web.*`, as the README's own examples are) matched nothing, and
  # a rule selecting or forbidding by it checked nothing.
  # Sabotage record: ../../sabotage_records/glob_pattern-20260929-dnd_1290_empty_relation_list.md
  describe "matches_module_pattern?/2 (alias-form patterns, DND-1290)" do
    test "an alias-form pattern matches the fully-qualified Elixir module name" do
      assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Web.Foo", "MyApp.Web.*")
      assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Repo", "MyApp.Repo")
    end

    test "a pattern with the Elixir. prefix, or a leading *, still matches" do
      assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Web.Foo", "Elixir.MyApp.Web.*")
      assert GlobPattern.matches_module_pattern?("Elixir.MyApp.Web.Foo", "*.Web.*")
    end

    test "an alias-form pattern still does not match a different module" do
      refute GlobPattern.matches_module_pattern?("Elixir.MyApp.Domain.Foo", "MyApp.Web.*")
      refute GlobPattern.matches_module_pattern?("Elixir.OtherApp.Web.Foo", "MyApp.Web.*")
    end

    test "an Erlang module name is matched as written" do
      assert GlobPattern.matches_module_pattern?("telemetry", "telemetry*")
      refute GlobPattern.matches_module_pattern?("telemetry", "Elixir.telemetry")
    end
  end
end
