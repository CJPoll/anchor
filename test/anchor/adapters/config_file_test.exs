defmodule Anchor.Adapters.ConfigFileTest do
  # Side Effect adapter — the file boundary. `load_from_path/1` rows run against
  # a temp file; `load/0` rows read the cwd.
  #
  # `async: false` because the `load/0` rows briefly `File.cd/1` into a temp
  # directory so `load/0` (which reads `.anchor.yml` from the cwd) picks up the
  # fixture. ExUnit runs sync modules in isolation (no other test runs
  # concurrently), so the process-global cwd change is safe. This is the same
  # discipline the E2E harness uses; keep this module `async: false`.
  #
  # Sabotage record: ../../sabotage_records/config-20260913-dnd_123_t3_config_split.md
  # Sabotage record (DND-1265 fail-closed rows): ../../sabotage_records/config-20260929-dnd_1265_anchor_fail_closed.md
  # Sabotage record (DND-1286 README blocks, selector fixtures): ../../sabotage_records/config-20260929-dnd_1286_rule_key_allowlist.md
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

    # Row 2 (DND-1265): an empty file checks nothing, so it fails the load.
    test "an empty file fails the load, naming the file" do
      with_config_file("", fn path ->
        assert {:error, {:config_load_failed, ^path, {:invalid_config, _reason}}} =
                 ConfigFile.load_from_path(path)
      end)
    end

    # Row 3 (DND-1265): the failure names the path it could not read.
    test "a missing file returns {:error, {:config_load_failed, path, {:read, :enoent}}}" do
      path = "nonexistent-#{:erlang.unique_integer([:positive])}.yml"

      assert {:error, {:config_load_failed, ^path, {:read, :enoent}}} =
               ConfigFile.load_from_path(path)
    end

    # Row 4 (DND-1265): the YAML error arrives as plain text, not a YamlElixir
    # struct, so the Domain never depends on the YAML library.
    test "malformed YAML returns {:error, {:config_load_failed, path, {:yaml, message}}}" do
      with_config_file("rules: [unterminated", fn path ->
        assert {:error, {:config_load_failed, ^path, {:yaml, message}}} =
                 ConfigFile.load_from_path(path)

        assert is_binary(message)
        assert message != ""
      end)
    end

    # DND-1265 (A8): an unknown rule type fails the load through the adapter.
    test "an unknown rule type fails the load, naming the file" do
      yaml = """
      rules:
        - type: no_direct_dependancy
          forbidden_modules:
            - MyApp.Repo
      """

      with_config_file(yaml, fn path ->
        assert {:error, {:config_load_failed, ^path, {:invalid_rule, reason}}} =
                 ConfigFile.load_from_path(path)

        assert reason =~ "no_direct_dependancy"
      end)
    end

    # Gap F (DND-149): an invalid rule must surface on load, not silently green.
    # A same_context: true rule with no forbidden_patterns has nothing to scope,
    # so the load fails through the existing {:config_load_failed, _} channel.
    test "an invalid same_context rule fails the load (not a silent no-op)" do
      yaml = """
      rules:
        - type: no_direct_dependency
          pattern: "*.Domain.*"
          same_context: true
          forbidden_modules:
            - MyApp.Repo
      """

      # DND-1286: the rule carries a selector, so it fails for its same_context
      # (the reason is asserted), not for selecting nothing.
      with_config_file(yaml, fn path ->
        assert {:error, {:config_load_failed, ^path, {:invalid_rule, reason}}} =
                 ConfigFile.load_from_path(path)

        assert reason =~ "same_context: true requires forbidden_patterns"
      end)
    end

    # DND-1265: the shipped example and the dogfood config must load under the
    # strict parser, so neither documents a config Anchor rejects.
    # DND-1286: that now includes the per-type key allowlist and the selector
    # requirement.
    test "the repo's .anchor.yml and .anchor.example.yml both load" do
      assert {:ok, %Config{rules: [_ | _]}} = ConfigFile.load_from_path(".anchor.yml")
      assert {:ok, %Config{rules: [_ | _]}} = ConfigFile.load_from_path(".anchor.example.yml")
    end

    # The README's main Configuration example (its first YAML block) must load
    # too. It spells `mode: :separate`, which the strict `mode` parse accepts.
    test "the README's Configuration example loads" do
      [_before, configuration] =
        "README.md" |> File.read!() |> String.split("## Configuration\n", parts: 2)

      [_intro, rest] = String.split(configuration, "```yaml\n", parts: 2)
      [yaml, _after] = String.split(rest, "```", parts: 2)

      with_config_file(yaml, fn path ->
        assert {:ok, %Config{rules: rules}} = ConfigFile.load_from_path(path)
        assert length(rules) > 5
        assert Enum.any?(rules, &(&1.mode == :separate))
      end)
    end

    # DND-1286: every rule the README shows must load under the per-type key
    # allowlist and the selector requirement, so no example teaches a key
    # Anchor rejects. A block that is a bare list of rules is loaded under a
    # `rules:` key; a block with no rule in it (a shell snippet's YAML) is skipped.
    # Sabotage record: ../../sabotage_records/rule_schema-20260929-dnd_1286_rule_key_allowlist.md
    test "every rule in every README YAML block loads" do
      blocks =
        ~r/```yaml\n(.*?)```/s
        |> Regex.scan(File.read!("README.md"), capture: :all_but_first)
        |> List.flatten()
        |> Enum.filter(&(&1 =~ ~r/^\s*- type:/m))

      assert length(blocks) > 10

      for block <- blocks do
        with_config_file(as_document(block), fn path ->
          assert {:ok, %Config{rules: [_ | _]}} = ConfigFile.load_from_path(path),
                 "README block failed to load:\n#{block}"
        end)
      end
    end
  end

  defp as_document("rules:" <> _rest = block), do: block

  defp as_document(block) do
    "rules:\n" <> (block |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1)))
  end

  describe "load/0 (test-matrix: config.ex -> load/0 and load_from_path/1)" do
    # Row 5 (DND-1265, A6): no candidate is a failure naming every path
    # searched, never an empty config that reads green.
    test "returns {:config_not_found, searched} when no candidate exists in the cwd" do
      with_cwd(fn dir ->
        # No .anchor.yml written into the temp dir.
        assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()
        assert searched == Path.join(dir, ".anchor.yml")
      end)
    end

    # Row 6
    test "loads the first existing candidate (the cwd .anchor.yml)" do
      yaml = """
      rules:
        - type: no_direct_dependency
          pattern: "*.Domain.*"
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

    # DND-1265 miss case: a config that exists, but not where the lookup
    # searches (run from a subdirectory), is reported with the path the lookup
    # actually computed, not read as an empty config.
    test "a config outside the computed candidates is reported, not read as empty" do
      with_cwd(fn dir ->
        File.write!(Path.join(dir, ".anchor.yml"), "rules: []\n")
        sub = Path.join(dir, "lib")
        File.mkdir_p!(sub)
        File.cd!(sub)

        assert {:error, {:config_not_found, [searched]}} = ConfigFile.load()
        assert searched == Path.join(sub, ".anchor.yml")
      end)
    end

    # DND-1265 miss case: from inside an umbrella app, both the app and the
    # umbrella-root candidates are searched, and both are named.
    test "from an umbrella app with no config, both searched candidates are named" do
      with_cwd(fn dir ->
        app = Path.join([dir, "apps", "my_app"])
        File.mkdir_p!(app)
        File.cd!(app)

        assert {:error, {:config_not_found, searched}} = ConfigFile.load()

        assert searched == [Path.join(app, ".anchor.yml"), Path.join(dir, ".anchor.yml")]
      end)
    end

    # DND-1265: a candidate that exists but cannot be read (here, a directory)
    # is a load failure naming it, not a skipped candidate.
    test "an existing but unreadable candidate fails the load, naming it" do
      with_cwd(fn dir ->
        File.mkdir_p!(Path.join(dir, ".anchor.yml"))

        assert {:error, {:config_load_failed, path, {:read, :eisdir}}} = ConfigFile.load()
        assert path == Path.join(dir, ".anchor.yml")
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

  # Hands `fun` the cwd as `File.cwd!/0` reports it after the `cd`, which is the
  # resolved path when the temp dir sits behind a symlink, so path assertions
  # compare like with like. The original cwd is always restored.
  defp with_cwd(fun) do
    dir = Path.join(System.tmp_dir!(), "anchor_cwd_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    original = File.cwd!()
    File.cd!(dir)

    try do
      fun.(File.cwd!())
    after
      File.cd!(original)
      File.rm_rf!(dir)
    end
  end
end
