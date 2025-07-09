defmodule Anchor.ConfigTest do
  use ExUnit.Case, async: true

  alias Anchor.Config

  describe "parse_config/1" do
    test "parses valid configuration" do
      yaml_content = """
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

      with_config_file(yaml_content, fn path ->
        assert {:ok, config} = Config.load_from_path(path)
        assert %Config{rules: [rule1, rule2]} = config

        assert rule1.type == :no_direct_dependency
        assert rule1.paths == ["lib/web/**/*.ex"]
        assert rule1.forbidden_modules == [MyApp.Repo]
        assert rule1.recursive == true

        assert rule2.type == :must_use_module
        assert rule2.paths == ["lib/schemas/**/*.ex"]
        assert rule2.required_modules == [MyApp.Schema]
        assert rule2.recursive == false
      end)
    end

    test "handles empty configuration" do
      yaml_content = ""

      with_config_file(yaml_content, fn path ->
        assert {:ok, config} = Config.load_from_path(path)
        assert %Config{rules: []} = config
      end)
    end

    test "handles missing file" do
      assert {:error, {:config_load_failed, :enoent}} = Config.load_from_path("nonexistent.yml")
    end
  end

  defp with_config_file(content, fun) do
    path = Path.join(System.tmp_dir!(), "anchor_test_#{:erlang.unique_integer()}.yml")
    File.write!(path, content)

    try do
      fun.(path)
    after
      File.rm(path)
    end
  end
end
