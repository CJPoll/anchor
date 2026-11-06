defmodule Anchor.TestPreloadTest do
  # DND-5690: `Anchor.TestPreload` over fixture applications, so what it loads,
  # and what it refuses, is seen on modules nothing else has touched.
  # sync: vm-global-state - each test adds a directory to the VM's one code path
  # and loads application specs into the VM's one application controller.
  # Sabotage record: ../sabotage_records/test_preload-20261106-dnd_5690_preload.md
  use ExUnit.Case, async: false

  alias Anchor.Test.BeamFixtures
  alias Anchor.TestPreload

  @moduletag :tmp_dir

  @host :anchor_fixture_preload_host
  @dep :anchor_fixture_preload_dep
  @extra :anchor_fixture_preload_extra

  @dep_module AnchorFixtures.TestPreloadTest.Dep
  @extra_module AnchorFixtures.TestPreloadTest.Extra
  @no_beam AnchorFixtures.TestPreloadTest.NoBeam

  # A module with its beam on the code path and not loaded: the state a
  # dependency module is in until something first calls it.
  defp beam_on_path!(dir, module) do
    [{^module, binary}] = BeamFixtures.compile_unloaded("defmodule #{inspect(module)} do end")
    File.write!(Path.join(dir, "#{module}.beam"), binary)
    true = Code.prepend_path(dir)

    on_exit(fn ->
      Code.delete_path(dir)
      :code.purge(module)
      :code.delete(module)
      :code.purge(module)
    end)

    module
  end

  defp load_app!(app, props) do
    # A repeated key takes its first value, so `props` come first.
    spec =
      {:application, app,
       props ++ [description: ~c"fixture", vsn: ~c"1.0.0", registered: [], modules: []]}

    :ok = :application.load(spec)
    on_exit(fn -> :application.unload(app) end)
    app
  end

  describe "load!/1" do
    test "loads a dependency's module that nothing has called, and says how much it loaded", %{
      tmp_dir: dir
    } do
      module = beam_on_path!(dir, @dep_module)
      load_app!(@dep, modules: [module], applications: [:kernel, :stdlib])
      load_app!(@host, applications: [:kernel, :stdlib, @dep])

      refute :erlang.module_loaded(module)
      assert TestPreload.unloaded(@host) == [module]

      assert %{apps: 4, modules: modules} = TestPreload.load!(@host)

      assert modules ==
               length(Application.spec(:kernel, :modules) ++ Application.spec(:stdlib, :modules)) +
                 1

      assert :erlang.module_loaded(module)
      assert TestPreload.unloaded(@host) == []
    end

    test "a module that cannot load refuses by name and reason, with a Fix: line" do
      load_app!(@dep, modules: [@no_beam], applications: [:kernel, :stdlib])

      error = assert_raise RuntimeError, fn -> TestPreload.load!(@dep) end

      assert error.message =~ "1 module(s) of #{inspect(@dep)}'s closure failed to load"
      assert error.message =~ "#{inspect(@no_beam)}: :nofile"
      assert error.message =~ "Fix:"
    end
  end

  describe "apps/1" do
    test "follows :applications and :included_applications, sorted and each once" do
      load_app!(@extra, applications: [:kernel, :stdlib])
      load_app!(@dep, applications: [:kernel, :stdlib, @extra])
      load_app!(@host, applications: [:kernel, @dep, @dep], included_applications: [@extra])

      assert TestPreload.apps(@host) == Enum.sort([@host, @dep, @extra, :kernel, :stdlib])
    end

    test "an :included_applications entry alone is in the closure" do
      load_app!(@extra, applications: [:kernel, :stdlib])
      load_app!(@host, applications: [:kernel, :stdlib], included_applications: [@extra])

      assert @extra in TestPreload.apps(@host)
    end

    test "an optional dependency absent from this build is skipped; a present one is in" do
      load_app!(@dep, applications: [:kernel, :stdlib])

      load_app!(@host,
        applications: [:kernel, :stdlib, @dep, @extra],
        optional_applications: [@dep, @extra]
      )

      apps = TestPreload.apps(@host)

      assert @dep in apps
      refute @extra in apps
    end

    test "a required application that is not loaded refuses by name, never reads as empty" do
      load_app!(@host, applications: [:kernel, :stdlib, @extra])

      error = assert_raise ArgumentError, fn -> TestPreload.apps(@host) end

      assert error.message =~ "#{inspect(@extra)} is not loaded"
      assert error.message =~ "Fix:"
    end
  end

  describe "modules/1" do
    test "every listed application's modules, sorted and each once" do
      load_app!(@dep, modules: [@no_beam, @dep_module], applications: [:kernel])
      load_app!(@extra, modules: [@dep_module, @extra_module], applications: [:kernel])

      assert TestPreload.modules([@dep, @extra]) ==
               Enum.sort([@dep_module, @extra_module, @no_beam])
    end
  end
end
