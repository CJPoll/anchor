defmodule Anchor.Adapters.BeamReaderTest do
  # Side Effect adapter (ADR 002): conversions only. QA plan rows 6-16
  # (DND-5438). Fixtures are compiled in the test and unloaded before decoding;
  # read_ebins/1 rows write binaries into an ExUnit tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/beam_reader-20261103-dnd_5438.md
  # Sabotage record (compile option allowlist): ../../sabotage_records/beam_reader-20261103-dnd_5551_graph_hardening.md
  # Sabotage record (Failures.crash_summary/3): ../../sabotage_records/failures-20261103-dnd_5438.md
  # Sabotage record (DND-5633): ../../sabotage_records/beam_reader-20261103-dnd_5648_graph_followups.md
  # Sabotage record (DND-5679): ../../sabotage_records/effects-20261106-dnd_5676_effects_cfa_batch.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.BeamReader
  alias Anchor.Domain.Graph.Beam
  alias AnchorFixtures.BeamReaderTest.Plain

  @plain_source """
  defmodule AnchorFixtures.BeamReaderTest.Plain do
    @behaviour AnchorFixtures.BeamReaderTest.Contract
    Module.register_attribute(__MODULE__, :tag, persist: true)
    @tag :hello
    defstruct [:a, b: 2]

    @spec run(integer()) :: integer()
    def run(x), do: helper(x)

    defp helper(x), do: x + 1

    def dyn(m, x), do: apply(m, :f, [x])
  end
  """

  setup_all do
    [{Plain, binary}] = compile_unloaded(@plain_source, "lib/plain.ex")
    %{binary: binary}
  end

  describe "decode/2" do
    # Row 6
    test "decodes the elixir_v1 metadata, the Core module and the specs", %{binary: binary} do
      assert %Beam{module: Plain, app: :demo, path: "x.beam"} =
               beam = BeamReader.decode(binary, app: :demo, path: "x.beam")

      assert beam.elixir.relative_file == "lib/plain.ex"
      assert Keyword.get_values(beam.elixir.attributes, :tag) == [:hello]
      assert :cerl.is_c_module(beam.core)
      assert [{{:run, 1}, [_spec]}] = beam.specs
    end

    # DND-5633: a behaviour's callbacks, by name and arity, so a dynamic call
    # can be narrowed to a behaviour only when f/arity is one of them.
    test "reads the callbacks a behaviour declares, sorted; none is []", %{binary: binary} do
      [{_module, contract}] =
        compile_unloaded("""
        defmodule AnchorFixtures.BeamReaderTest.Callbacks do
          @callback run([String.t()]) :: :ok
          @callback check(term(), term()) :: boolean()
          @macrocallback expand(term()) :: Macro.t()
        end
        """)

      assert %Beam{callbacks: callbacks} = BeamReader.decode(contract, app: :demo, path: "c.beam")
      assert callbacks == [{:"MACRO-expand", 2}, {:check, 2}, {:run, 1}]
      assert %Beam{callbacks: []} = BeamReader.decode(binary, app: :demo, path: "x.beam")
    end

    # Core is read with :no_copt: the optimiser would turn apply(m, :f, [x])
    # into a plain call m:f(x), and the :apply edge would be lost.
    test "decodes Core unoptimised, so apply/3 is still a call to erlang:apply", %{binary: binary} do
      assert %Beam{core: core} = BeamReader.decode(binary, app: :demo, path: "x.beam")

      {_fname, dyn} =
        Enum.find(:cerl.module_defs(core), fn {fname, _fun} ->
          :cerl.var_name(fname) == {:dyn, 2}
        end)

      calls =
        :cerl_trees.fold(
          fn node, acc ->
            if :cerl.is_c_call(node) and :cerl.is_literal(:cerl.call_module(node)),
              do: [
                {:cerl.concrete(:cerl.call_module(node)), :cerl.concrete(:cerl.call_name(node))}
                | acc
              ],
              else: acc
          end,
          [],
          dyn
        )

      assert {:erlang, :apply} in calls
    end

    # Row 7 (AC5)
    test "never loads the module it decodes", %{binary: binary} do
      assert :code.is_loaded(Plain) == false
      assert %Beam{} = BeamReader.decode(binary, app: :demo, path: "x.beam")
      assert :code.is_loaded(Plain) == false
    end

    # Row 7b (the behaviour on the code path) is in
    # beam_reader_code_path_test.exs: it changes the VM-wide code path, so it
    # runs synchronously.

    # The backend lowers elixir_v1 metadata to Core with the Erlang compiler; a
    # definition calling a local function that does not exist fails that
    # compile, and the backend answers {:error, :failed_conversion}.
    test "a backend that refuses core_v1 is {:core_v1_refused, reason}", %{binary: binary} do
      {:ok, {Plain, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}}]}} =
        :beam_lib.chunks(binary, [:debug_info])

      broken =
        {{:broken, 0}, :def, [line: 1], [{[line: 1], [], [], {:no_such_local, [line: 1], []}}]}

      map = Map.update!(map, :definitions, &[broken | &1])
      rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}})

      assert {:error, %{reason: {:core_v1_refused, :failed_conversion}, module: Plain}} =
               BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
    end

    # A parse_transform or core_transform in the module's compile options is
    # code lowering would run: refused, naming it, and never called.
    test "a module compiled with a transform is refused, naming it", %{binary: binary} do
      {:ok, {Plain, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}}]}} =
        :beam_lib.chunks(binary, [:debug_info])

      for kind <- [:parse_transform, :core_transform] do
        transform = {kind, :anchor_fixtures_no_such_transform}
        map = Map.put(map, :compile_opts, [:debug_info, transform])
        rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}})

        assert {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}, module: Plain}} =
                 BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
      end
    end

    # DND-5552: compile options are allowlisted, deny by default. An option
    # Anchor does not know might make lowering run code, so it is refused,
    # never passed to the compiler.
    test "every known-safe compile option decodes", %{binary: binary} do
      {:ok, {Plain, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}}]}} =
        :beam_lib.chunks(binary, [:debug_info])

      options = [
        :debug_info,
        {:debug_info, true},
        :inline,
        {:inline, [run: 1]},
        {:inline_size, 30},
        {:no_warn_undefined, Foo},
        {:no_warn_undefined, [{Foo, :bar, 1}]},
        {:autoload, false},
        :nowarn_unused_vars,
        {:nowarn_unused_function, [run: 1]},
        :warn_missing_spec,
        :deterministic
      ]

      for option <- options do
        map = Map.put(map, :compile_opts, [option])
        rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}})

        decoded = BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
        assert match?(%Beam{module: Plain}, decoded), "#{inspect(option)}: #{inspect(decoded)}"
      end
    end

    test "any other compile option is refused, naming it", %{binary: binary} do
      {:ok, {Plain, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}}]}} =
        :beam_lib.chunks(binary, [:debug_info])

      options = [
        :from_core,
        :something_new,
        :warnings_as_errors,
        {:d, :X},
        {:i, ~c"include"},
        {:plugins, [AnchorFixtures.NoSuchPlugin]},
        {:debug_info, {AnchorFixtures.NoSuchBackend, :data}},
        {:autoload, :maybe},
        {:inline_size, :big},
        {:nowarn_unused_vars, :extra, :arity}
      ]

      for option <- options do
        map = Map.put(map, :compile_opts, [:debug_info, option])
        rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}})

        assert {:error, %{reason: {:core_v1_refused, {:option, ^option}}, module: Plain}} =
                 BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
      end
    end

    test "a transform is named as one even after an unknown option", %{binary: binary} do
      {:ok, {Plain, [debug_info: {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}}]}} =
        :beam_lib.chunks(binary, [:debug_info])

      transform = {:parse_transform, :anchor_fixtures_no_such_transform}
      map = Map.put(map, :compile_opts, [:something_new, transform])
      rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, map, specs}})

      assert {:error, %{reason: {:core_v1_refused, {:transform, ^transform}}}} =
               BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
    end

    # Row 8
    test "a beam with no debug_info chunk is :no_debug_info, naming the module", %{binary: binary} do
      {:ok, {Plain, stripped}} = :beam_lib.strip(binary)

      assert {:error, %{reason: :no_debug_info, module: Plain, path: "x.beam"}} =
               BeamReader.decode(stripped, app: :demo, path: "x.beam")
    end

    # Row 9
    test "a debug_info chunk holding no metadata is :debug_info_stripped", %{binary: binary} do
      rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, :none})

      assert {:error, %{reason: :debug_info_stripped, module: Plain}} =
               BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
    end

    # Row 10
    test "an Erlang module is {:not_elixir, backend}" do
      forms = [
        {:attribute, 1, :module, :anchor_fixtures_beam_reader_erl},
        {:attribute, 1, :export, [{:f, 0}]},
        {:function, 1, :f, 0, [{:clause, 1, [], [], [{:atom, 1, :ok}]}]}
      ]

      {:ok, :anchor_fixtures_beam_reader_erl, binary} =
        :compile.forms(forms, [:binary, :debug_info])

      assert {:error,
              %{
                reason: {:not_elixir, :erl_abstract_code},
                module: :anchor_fixtures_beam_reader_erl
              }} =
               BeamReader.decode(binary, app: :demo, path: "x.beam")
    end

    # Row 11: the backend raises on malformed metadata; nothing escapes.
    test "a backend that crashes on the metadata is an error value, never a raise", %{
      binary: binary
    } do
      rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:elixir_v1, %{}, []}})

      assert {:error, %{reason: {:decode_crashed, message}, module: Plain}} =
               BeamReader.decode(rebuilt, app: :demo, path: "x.beam")

      assert message =~ "FunctionClauseError"
    end

    # Row 11b: a chunk in a format the backend does not know.
    test "a backend that refuses a debug-info format is {:elixir_v1_refused, reason}", %{
      binary: binary
    } do
      rebuilt = with_debug_info(binary, {:debug_info_v1, :elixir_erl, {:not_a_format, %{}}})

      assert {:error, %{reason: {:elixir_v1_refused, _reason}, module: Plain}} =
               BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
    end

    # Row 9b: an encrypted chunk with no key is as good as stripped.
    test "an encrypted debug_info chunk is :debug_info_stripped" do
      forms = [
        {:attribute, 1, :module, :anchor_fixtures_beam_reader_crypt},
        {:attribute, 1, :export, [{:f, 0}]},
        {:function, 1, :f, 0, [{:clause, 1, [], [], [{:atom, 1, :ok}]}]}
      ]

      {:ok, :anchor_fixtures_beam_reader_crypt, binary} =
        :compile.forms(forms, [
          :binary,
          :encrypt_debug_info,
          {:debug_info_key, ~c"anchor-test-key"}
        ])

      # DND-5679: the module is named, so a call into it is a project call
      # whose body was not read, never one outside the project.
      assert {:error, %{reason: :debug_info_stripped, module: :anchor_fixtures_beam_reader_crypt}} =
               BeamReader.decode(binary, app: :demo, path: "x.beam")
    end

    # Row 12
    test "bytes that are not a beam are {:unreadable, _} with no module" do
      assert {:error, %{reason: {:unreadable, _reason}, module: nil, path: "x.beam"}} =
               BeamReader.decode("not a beam", app: :demo, path: "x.beam")
    end

    # Row 13: positive control for rows 8-11 — the unmodified binary, rebuilt
    # through the same chunk round trip with its own Dbgi chunk, decodes.
    test "the unmodified fixture decodes through the same rebuild", %{binary: binary} do
      {:ok, {Plain, [debug_info: dbgi]}} = :beam_lib.chunks(binary, [:debug_info])
      rebuilt = with_debug_info(binary, dbgi)

      assert %Beam{module: Plain} = BeamReader.decode(rebuilt, app: :demo, path: "x.beam")
    end
  end

  describe "read_ebins/1" do
    # Row 14
    @tag :tmp_dir
    test "reads every beam of every ebin, sorted by path", %{tmp_dir: dir, binary: binary} do
      x = AnchorFixtures.BeamReaderTest.X
      y = AnchorFixtures.BeamReaderTest.Y

      modules =
        compile_unloaded("""
        defmodule AnchorFixtures.BeamReaderTest.Y do
        end

        defmodule AnchorFixtures.BeamReaderTest.X do
        end
        """)

      File.write!(Path.join(dir, "Elixir.Y.beam"), binary!(modules, y))
      File.write!(Path.join(dir, "Elixir.X.beam"), binary!(modules, x))
      File.write!(Path.join(dir, "notes.txt"), "not a beam file name")
      other = Path.join(dir, "other")
      File.mkdir_p!(other)
      File.write!(Path.join(other, "Elixir.Plain.beam"), binary)

      assert [
               %Beam{module: ^x, app: :demo, path: x_path},
               %Beam{module: ^y, app: :demo},
               %Beam{module: Plain, app: :other}
             ] = BeamReader.read_ebins([{:demo, dir}, {:other, other}])

      assert x_path == Path.join(dir, "Elixir.X.beam")
    end

    # Row 15
    @tag :tmp_dir
    test "a missing ebin directory is one error naming it, never []", %{tmp_dir: dir} do
      missing = Path.join(dir, "missing")

      assert [{:error, %{path: ^missing, module: nil, reason: {:unreadable, :enoent}}}] =
               BeamReader.read_ebins([{:demo, missing}])
    end

    # A beam file that exists but cannot be read is an error naming it.
    @tag :tmp_dir
    test "an unreadable beam file is {:unreadable, posix} naming it", %{
      tmp_dir: dir,
      binary: binary
    } do
      path = Path.join(dir, "Elixir.Plain.beam")
      File.write!(path, binary)
      File.chmod!(path, 0o000)
      on_exit(fn -> File.chmod(path, 0o644) end)

      # Positive control for the environment: a process that can read any file
      # (root) would make this row meaningless.
      assert {:error, :eacces} = File.read(path)

      assert [{:error, %{path: ^path, module: nil, reason: {:unreadable, :eacces}}}] =
               BeamReader.read_ebins([{:demo, dir}])
    end

    # Row 16
    @tag :tmp_dir
    test "one bad file among good ones is an error beside the good beam", %{
      tmp_dir: dir,
      binary: binary
    } do
      File.write!(Path.join(dir, "Elixir.Plain.beam"), binary)
      File.write!(Path.join(dir, "Elixir.Z.beam"), "garbage")
      z_path = Path.join(dir, "Elixir.Z.beam")

      assert [%Beam{module: Plain}, {:error, %{path: ^z_path, reason: {:unreadable, _reason}}}] =
               BeamReader.read_ebins([{:demo, dir}])
    end
  end

  # Rebuilds `binary` with its debug-info chunk replaced by `term`.
  defp with_debug_info(binary, term) do
    {:ok, _module, chunks} = :beam_lib.all_chunks(binary)
    chunks = List.keyreplace(chunks, ~c"Dbgi", 0, {~c"Dbgi", :erlang.term_to_binary(term)})
    {:ok, rebuilt} = :beam_lib.build_module(chunks)
    rebuilt
  end
end
