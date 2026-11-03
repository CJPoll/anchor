defmodule Anchor.Adapters.BeamReaderTest do
  # Side Effect adapter (ADR 002): conversions only. QA plan rows 6-16
  # (DND-5438). Fixtures are compiled in the test and unloaded before decoding;
  # read_ebins/1 rows write binaries into an ExUnit tmp_dir.
  #
  # Sabotage record: ../../sabotage_records/beam_reader-20261103-dnd_5438.md
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

    # Row 7b (AC5, integrity): lowering to Core must not load the modules a
    # beam names either. The behaviour's beam is on the code path here, so a
    # decoder that loaded it would succeed; the positive control at the end
    # shows the probe sees a load.
    @tag :tmp_dir
    test "never loads a behaviour the decoded module names, even when it is on the code path", %{
      tmp_dir: dir
    } do
      behaviour = AnchorFixtures.BeamReaderTest.Behaviour
      user = AnchorFixtures.BeamReaderTest.BehaviourUser

      modules =
        compile_all_unloaded([
          {"defmodule #{inspect(behaviour)} do\n  @callback x() :: :ok\nend\n",
           "lib/behaviour.ex"},
          {"defmodule #{inspect(user)} do\n  @behaviour #{inspect(behaviour)}\n  def x, do: :ok\nend\n",
           "lib/user.ex"}
        ])

      File.write!(Path.join(dir, "#{behaviour}.beam"), binary!(modules, behaviour))
      true = Code.append_path(dir)

      on_exit(fn ->
        Code.delete_path(dir)
        :code.purge(behaviour)
        :code.delete(behaviour)
      end)

      assert %Beam{module: ^user} =
               BeamReader.decode(binary!(modules, user), app: :demo, path: "x.beam")

      assert :code.is_loaded(behaviour) == false

      assert {:module, ^behaviour} = :code.ensure_loaded(behaviour)
      assert {:file, _path} = :code.is_loaded(behaviour)
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

      assert {:error, %{reason: :debug_info_stripped}} =
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
