defmodule Anchor.Adapters.ConfigFileTest do
  # Side Effect adapter — the file boundary. Rows 1-4 drive `load_from_path/1`
  # against a temp file; rows 5-6 drive `load/0`, which reads the cwd.
  #
  # `async: false` because rows 5-6 briefly `File.cd/1` into a temp directory so
  # `load/0` (which reads `.anchor.yml` from the cwd) picks up the fixture.
  # ExUnit runs sync modules in isolation (no other test runs concurrently), so
  # the process-global cwd change is safe. This is the same discipline the E2E
  # harness uses; keep this module `async: false`.
  #
  # Sabotage record: ../../sabotage_records/config-20260913-dnd_123_t3_config_split.md
  use ExUnit.Case, async: false

  alias Anchor.Adapters.ConfigFile
  alias Anchor.Config

  describe "load_from_path/1 (test-matrix: config.ex -> load/0 and load_from_path/1)" do
    # Row 1
    test "loads and parses a valid config file" do
      yaml = """
      rules:
        - type: no_direct_dependency
          paths:
            - "lib/web/**/*.ex"
          forbidden_modules:
            - MyApp.Repo
          recursive: true
        - type: must_use_module
          paths:
            - "lib/schemas/**/*.ex"
          required_modules:
            - MyApp.Schema
          recursive: false
      """

      with_config_file(yaml, fn path ->
        assert {:ok, %Config{rules: [rule1, rule2]}} = ConfigFile.load_from_path(path)

        assert rule1.type == :no_direct_dependency
        assert rule1.forbidden_modules == [MyApp.Repo]
        assert rule1.recursive == true

        assert rule2.type == :must_use_module
        assert rule2.required_modules == [MyApp.Schema]
        assert rule2.recursive == false
      end)
    end

    # Row 2
    test "an empty file yields an empty rule list" do
      with_config_file("", fn path ->
        assert {:ok, %Config{rules: []}} = ConfigFile.load_from_path(path)
      end)
    end

    # Row 3
    test "a missing file returns {:error, {:config_load_failed, :enoent}}" do
      assert {:error, {:config_load_failed, :enoent}} =
               ConfigFile.load_from_path("nonexistent-#{:erlang.unique_integer([:positive])}.yml")
    end

    # Row 4
    test "malformed YAML returns {:error, {:config_load_failed, _reason}}" do
      with_config_file("rules: [unterminated", fn path ->
        assert {:error, {:config_load_failed, _reason}} = ConfigFile.load_from_path(path)
      end)
    end

    # Gap F (DND-149): an invalid rule must surface on load, not silently green.
    # A same_context: true rule with no forbidden_patterns has nothing to scope,
    # so the load fails through the existing {:config_load_failed, _} channel.
    test "an invalid same_context rule fails the load (not a silent no-op)" do
      yaml = """
      rules:
        - type: no_direct_dependency
          same_context: true
          forbidden_modules:
            - MyApp.Repo
      """

      with_config_file(yaml, fn path ->
        assert {:error, {:config_load_failed, {:invalid_rule, _reason}}} =
                 ConfigFile.load_from_path(path)
      end)
    end
  end

  describe "load/0 (test-matrix: config.ex -> load/0 and load_from_path/1)" do
    # Row 5
    test "returns an empty config when no candidate exists in the cwd" do
      with_cwd(fn _dir ->
        # No .anchor.yml written into the temp dir.
        assert {:ok, %Config{rules: []}} = ConfigFile.load()
      end)
    end

    # Row 6
    test "loads the first existing candidate (the cwd .anchor.yml)" do
      yaml = """
      rules:
        - type: no_direct_dependency
          forbidden_modules:
            - MyApp.Repo
      """

      with_cwd(fn dir ->
        File.write!(Path.join(dir, ".anchor.yml"), yaml)

        assert {:ok, %Config{rules: [rule]}} = ConfigFile.load()
        assert rule.type == :no_direct_dependency
        assert rule.forbidden_modules == [MyApp.Repo]
      end)
    end
  end

  defp with_config_file(content, fun) do
    path = Path.join(System.tmp_dir!(), "anchor_cfg_#{:erlang.unique_integer([:positive])}.yml")
    File.write!(path, content)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end

  defp with_cwd(fun) do
    dir = Path.join(System.tmp_dir!(), "anchor_cwd_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    original = File.cwd!()
    File.cd!(dir)

    try do
      fun.(dir)
    after
      File.cd!(original)
      File.rm_rf!(dir)
    end
  end
end
