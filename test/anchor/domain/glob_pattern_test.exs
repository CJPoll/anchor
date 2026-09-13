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
end
