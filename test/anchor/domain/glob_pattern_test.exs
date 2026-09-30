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

  # DND-1292: the glob syntax is `*` and (in recursive path globs) `**`, and
  # nothing else. Before this ticket only `.` was escaped, so every other regex
  # metacharacter in a glob was live regex: `allowed_functions: ["*?"]` was a
  # lazy match-all, `lib/c++/*.ex` matched `lib/c/a.ex` and not itself, and
  # `lib/(old/*.ex` raised a Regex.CompileError at run time. Every other
  # character is now a literal, in every flavor.
  #
  # Each table collects every failing row, so one run shows the whole table.
  #
  # Sabotage record: ../../sabotage_records/glob_pattern-20260929-dnd_1292_glob_escape.md
  @flavors [
    path: &GlobPattern.matches_pattern?/2,
    recursive: &GlobPattern.matches_recursive_pattern?/2,
    module: &GlobPattern.matches_module_pattern?/2
  ]

  # Every character PCRE gives a meaning to somewhere, outside the glob's own
  # `*`. Some (`=`, `!`, `<`, `>`, `:`, `-`, `#`, space) were already literal in
  # the old unescaped position and passed before the fix; they stay as a guard
  # against a future flag or context that gives them a meaning.
  @metacharacters [".", "\\", "+", "?", "[", "]", "^", "$", "(", ")", "{", "}"] ++
                    ["|", "=", "!", "<", ">", ":", "-", "#", " "]

  # Globs whose text is a regex construct, each with a string the regex would
  # have matched and the literal glob must not.
  @regex_constructs [
    {"a{2}", "aa"},
    {"a|b", "a"},
    {"[ab]", "a"},
    {"a+", "aaa"},
    {"xa?", "x"},
    {"(a)", "a"},
    {"^a$", "a"},
    {"a\\d", "a1"},
    {"x.?y", "xy"},
    {"a\\w+", "abc"},
    {"a(?=b)", "a"}
  ]

  describe "regex metacharacters are literal (DND-1292)" do
    for {flavor, _matcher} <- @flavors do
      @tag flavor: flavor
      test "#{flavor}: a metacharacter matches only itself", %{flavor: flavor} do
        failures =
          for char <- @metacharacters,
              glob = "a" <> char <> "b",
              probe <- ["a" <> char <> "b", "ab", "aXb", "a" <> char <> char <> "b", "aab"],
              failure = row_failure(flavor, glob, probe, probe == glob),
              do: failure

        assert failures == [], Enum.join(failures, "\n")
      end

      @tag flavor: flavor
      test "#{flavor}: a metacharacter after a `*` is literal", %{flavor: flavor} do
        failures =
          for char <- @metacharacters,
              glob = "x*" <> char,
              {probe, expected} <- [{"xy" <> char, true}, {"x" <> char, true}, {"xy", false}],
              failure = row_failure(flavor, glob, probe, expected),
              do: failure

        assert failures == [], Enum.join(failures, "\n")
      end

      @tag flavor: flavor
      test "#{flavor}: a regex construct is a literal string", %{flavor: flavor} do
        failures =
          for {glob, regex_match} <- @regex_constructs,
              {probe, expected} <- [{glob, true}, {regex_match, false}],
              failure = row_failure(flavor, glob, probe, expected),
              do: failure

        assert failures == [], Enum.join(failures, "\n")
      end
    end

    test "`*?` matches names ending in `?`, not every name (it was a lazy match-all)" do
      assert GlobPattern.matches_pattern?("valid?", "*?")
      refute GlobPattern.matches_pattern?("run", "*?")
      refute GlobPattern.matches_pattern?("", "*?")
    end

    test "`*+` and `*{0}` are not match-alls either" do
      refute GlobPattern.matches_pattern?("run", "*+")
      refute GlobPattern.matches_pattern?("run", "*{0}")
      assert GlobPattern.matches_pattern?("run{0}", "*{0}")
    end

    test "a path containing `+` matches itself and not the regex reading" do
      assert GlobPattern.matches_pattern?("lib/c++/a.ex", "lib/c++/*.ex")
      refute GlobPattern.matches_pattern?("lib/c/a.ex", "lib/c++/*.ex")
      refute GlobPattern.matches_pattern?("lib/ccc/a.ex", "lib/c++/*.ex")

      assert GlobPattern.matches_recursive_pattern?("lib/c++/x/a.ex", "lib/c++/**/*.ex")
      refute GlobPattern.matches_recursive_pattern?("lib/c/x/a.ex", "lib/c++/**/*.ex")
    end

    test "an unbalanced bracket or parenthesis is a literal, not a crash" do
      assert GlobPattern.matches_pattern?("lib/(old/a.ex", "lib/(old/*.ex")
      assert GlobPattern.matches_recursive_pattern?("lib/[x/a.ex", "lib/[x/**/*.ex")
      assert GlobPattern.matches_module_pattern?("Elixir.App.W(eb", "*.W(eb")
    end

    test "a backslash is a literal, and does not escape the `*` after it" do
      assert GlobPattern.matches_pattern?("a\\xyz", "a\\*")
      refute GlobPattern.matches_pattern?("a*", "a\\*")
    end

    test "the match is anchored at the very end: a trailing newline is not ignored" do
      for {flavor, _matcher} <- @flavors do
        assert row_failure(flavor, "a", "a\n", false) == nil
        assert row_failure(flavor, "*.ex", "a.ex\n", false) == nil
      end
    end

    test "text that looks like an internal placeholder is a literal" do
      refute GlobPattern.matches_recursive_pattern?("axyzb", "a___DOUBLE_STAR___b")
      assert GlobPattern.matches_recursive_pattern?("a___DOUBLE_STAR___b", "a___DOUBLE_STAR___b")
    end
  end

  # The documented syntax is unchanged by the escaping (DND-1292).
  describe "the documented glob syntax still holds (DND-1292)" do
    test "path `*` stays within one segment" do
      assert GlobPattern.matches_pattern?("lib/a.ex", "lib/*.ex")
      refute GlobPattern.matches_pattern?("lib/a/b.ex", "lib/*.ex")
      assert GlobPattern.matches_pattern?("lib/a/b.ex", "lib/*/*.ex")
    end

    test "recursive `**/`, `/**` and a bare `**`" do
      assert GlobPattern.matches_recursive_pattern?("lib/a.ex", "lib/**/*.ex")
      assert GlobPattern.matches_recursive_pattern?("lib/a/b/c.ex", "lib/**/*.ex")
      assert GlobPattern.matches_recursive_pattern?("lib", "lib/**")
      assert GlobPattern.matches_recursive_pattern?("lib/a/b", "lib/**")
      refute GlobPattern.matches_recursive_pattern?("libx/a", "lib/**")
      assert GlobPattern.matches_recursive_pattern?("a.ex", "**/*.ex")
      assert GlobPattern.matches_recursive_pattern?("x/y/a.ex", "**/*.ex")
      assert GlobPattern.matches_recursive_pattern?("anything/at/all", "**")
      assert GlobPattern.matches_recursive_pattern?("a/b", "a/**/b")
      assert GlobPattern.matches_recursive_pattern?("a/x/y/b", "a/**/b")
      refute GlobPattern.matches_recursive_pattern?("a/x/y/c", "a/**/b")
    end

    test "module `*` crosses dots, and dots stay literal" do
      assert GlobPattern.matches_module_pattern?("Elixir.App.Web.User", "*.Web.*")
      assert GlobPattern.matches_module_pattern?("Elixir.App.Web.User", "App.Web.*")
      refute GlobPattern.matches_module_pattern?("Elixir.App.WebXUser", "*.Web.*")
      refute GlobPattern.matches_module_pattern?("Elixir.Foo.AdaptersHelper", "*.Adapters.*")
    end
  end

  # The class guard: a config string becomes a matcher in GlobPattern and
  # nowhere else, so the escaping cannot be skipped by a second compiler. Any
  # regex elsewhere in lib/, constant or not, fails here: there is no allowlist,
  # so a regex that never sees config text is a deliberate edit to this test.
  describe "GlobPattern is the only regex compiler in lib/ (DND-1292)" do
    test "no other lib/ file builds or runs a regex" do
      lib = Path.expand("../../../lib", __DIR__)
      own = Path.join(lib, "anchor/domain/glob_pattern.ex")
      needles = ["Regex.", "=~", "String.match?", "~r", "~R", ":re."]

      offenders =
        for file <- Path.wildcard(Path.join(lib, "**/*.ex")),
            file != own,
            needle <- needles,
            File.read!(file) =~ needle,
            do: "#{Path.relative_to(file, lib)} uses #{needle}"

      assert offenders == [], Enum.join(offenders, "\n")
    end
  end

  describe "matches_name_pattern?/2 (function-name globs, DND-1292)" do
    test "`*` matches every function name, a `/` operator included" do
      for name <- ["run", "valid?", "fetch!", "/", "//", "<>"],
          do: assert(GlobPattern.matches_name_pattern?(name, "*"), name)
    end

    test "every other character is a literal" do
      assert GlobPattern.matches_name_pattern?("valid?", "*?")
      refute GlobPattern.matches_name_pattern?("run", "*?")
      assert GlobPattern.matches_name_pattern?("with_status", "with_*")
      refute GlobPattern.matches_name_pattern?("without", "with_*")
      assert GlobPattern.matches_name_pattern?("new", "new")
      refute GlobPattern.matches_name_pattern?("renew", "new")
    end
  end

  describe "wildcard_only?/1 (DND-1292)" do
    test "a glob of only wildcards matches every name" do
      for glob <- ["*", "**", "***"], do: assert(GlobPattern.wildcard_only?(glob), glob)
    end

    test "a glob with any literal character does not" do
      for glob <- ["*?", "*+", "with_*", "*.*", " *", "new", "*{0}"],
          do: refute(GlobPattern.wildcard_only?(glob), glob)
    end
  end

  # `nil` when `matcher(probe, glob)` is `expected`, else a line naming the row.
  # A matcher that raises is a failed row too.
  defp row_failure(flavor, glob, probe, expected) do
    matcher = Keyword.fetch!(@flavors, flavor)

    actual =
      try do
        matcher.(probe, glob)
      rescue
        error -> {:raised, error.__struct__}
      end

    unless actual == expected do
      "#{flavor}: glob #{inspect(glob)} on #{inspect(probe)}: " <>
        "want #{expected}, got #{inspect(actual)}"
    end
  end
end
