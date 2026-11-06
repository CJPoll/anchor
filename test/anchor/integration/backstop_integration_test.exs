defmodule Anchor.Integration.BackstopIntegrationTest do
  # DND-5480 I1: the backstop with no double. Fixture beams are compiled in
  # the test and written to an ebin under a tmp dir beside a real
  # .anchor.yml: aggregate A is declared by `use Anchor.Aggregate` over an
  # Ecto schema (its table "orders" is derived from the schema's Core), and
  # aggregate B in the config by table name ("invoices"). The real ConfigFile,
  # BeamReader, TelemetryRecorder and EctoTransactionProbe run; the repo's
  # query events are synthetic `:telemetry.execute/3` calls replaying
  # DND-5479's transaction sequence (begin, writes, commit).
  #
  # Sabotage record: ../../sabotage_records/backstop-20261106-dnd_5480_test_backstop.md
  use ExUnit.Case, async: true

  import Anchor.Test.BeamFixtures

  alias Anchor.Adapters.TelemetryRecorder
  alias Anchor.Managers.Backstop
  alias Anchor.Test.BackstopMetadata, as: Meta

  @moduletag :tmp_dir

  @source """
  defmodule AnchorFixtures.BackstopIntegration.Order do
    use Ecto.Schema

    schema "orders" do
      field :name, :string
    end
  end

  defmodule AnchorFixtures.BackstopIntegration.Orders do
    use Anchor.Aggregate,
      name: AnchorFixtures.BackstopIntegration.A,
      schemas: [AnchorFixtures.BackstopIntegration.Order]
  end
  """

  @config """
  rules:
    - type: aggregate_declarations
      id: aggregate_declarations
      paths: ["lib/**/*.ex"]

  aggregates:
    declare:
      - name: AnchorFixtures.BackstopIntegration.B
        tables: ["invoices"]

  architecture:
    contexts:
      depth: 2
    buckets:
      - name: domain
        role: domain
        select:
          - paths: ["lib/**/*.ex"]
    calls:
      domain: [domain]
  """

  setup_all do
    %{modules: compile_unloaded(@source, "lib/backstop_integration.ex")}
  end

  setup %{tmp_dir: root, modules: modules, test: test} do
    ebin = Path.join(root, "_build/test/lib/bsi/ebin")
    File.mkdir_p!(ebin)
    for {module, binary} <- modules, do: File.write!(Path.join(ebin, "#{module}.beam"), binary)
    File.write!(Path.join(root, ".anchor.yml"), @config)

    event = [:anchor_backstop_integration, test, :query]

    session =
      Backstop.start(%{event: event, root: root, apps: [{:bsi, ebin}], escapes: :report})

    on_exit(fn -> TelemetryRecorder.detach_recorder(session.recorder) end)
    %{session: session, event: event}
  end

  defp replay(event, metadata), do: Enum.each(metadata, &:telemetry.execute(event, %{}, &1))

  test "I1: a transaction writing orders then invoices fails with the crossing", %{
    session: session,
    event: event
  } do
    :ok = Backstop.watch(session, self())
    replay(event, [Meta.begin(), Meta.insert("orders"), Meta.insert("invoices"), Meta.commit()])

    error =
      assert_raise ExUnit.AssertionError, fn ->
        Backstop.verdict!(session, self(), "I1 test")
      end

    assert error.message ==
             "I1 test: transaction wrote aggregates AnchorFixtures.BackstopIntegration.A (table " <>
               "orders) and AnchorFixtures.BackstopIntegration.B (table invoices). Fix: write " <>
               "AnchorFixtures.BackstopIntegration.B's change as an outbox row in " <>
               "AnchorFixtures.BackstopIntegration.A, consumed by " <>
               "AnchorFixtures.BackstopIntegration.B's owner; or declare one aggregate holding both."
  end

  test "I1: the same transaction writing orders only passes", %{session: session, event: event} do
    :ok = Backstop.watch(session, self())
    replay(event, [Meta.begin(), Meta.insert("orders"), Meta.update("orders"), Meta.commit()])

    assert Backstop.verdict!(session, self(), "I1 test") == :ok
  end

  test "I1: orders and invoices in two transactions pass, and the summary counts the test", %{
    session: session,
    event: event
  } do
    :ok = Backstop.watch(session, self())

    replay(event, [
      Meta.begin(),
      Meta.insert("orders"),
      Meta.commit(),
      Meta.begin(),
      Meta.insert("invoices"),
      Meta.rollback(),
      Meta.raw_insert("audit")
    ])

    assert Backstop.verdict!(session, self(), "I1 test") == :ok

    assert Backstop.summary(session) ==
             "anchor backstop: 1 tests watched, 0 crossings; escapes: 0 other-process, " <>
               "1 no-source, 0 undeclared, 0 unclassified; not judged: 0 outside a " <>
               "transaction, 0 unattributed"
  end
end
