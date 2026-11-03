defmodule Anchor.Domain.Sabotage.RecordNamingTest do
  # DND-5484: where a generated sabotage record goes, in each repo's naming.
  # Sabotage record: ../../../sabotage_records/sabotage-20261103-dnd_5484_records.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Sabotage.RecordNaming

  @anchor %{
    dir: "test/sabotage_records",
    naming: :domain_date_slot,
    domain_from: :module,
    domain_strip_prefixes: [
      "Anchor.Domain.Checks.",
      "Anchor.Domain.",
      "Anchor.Check.",
      "Anchor.Managers.",
      "Anchor.Adapters.",
      "Anchor."
    ]
  }
  @crew %{@anchor | dir: "apps/{app}/test/sabotage_records", domain_from: :context_dir}
  @gen_saas %{@crew | naming: :ticket_nn_what}

  describe "domain_for/3" do
    test "1: the longest prefix is dropped, the next segment snake_cased" do
      assert RecordNaming.domain_for("lib/x.ex", Anchor.Domain.Sabotage.Mutator, @anchor) ==
               "sabotage"
    end

    test "2: a Credo check's module" do
      assert RecordNaming.domain_for("lib/x.ex", Anchor.Check.NoDependency, @anchor) ==
               "no_dependency"
    end

    test "3: a module just under the shortest prefix" do
      assert RecordNaming.domain_for("lib/x.ex", Anchor.Config, @anchor) == "config"
    end

    test "4: context_dir: the directory under lib/<app>/" do
      assert RecordNaming.domain_for("apps/runtime/lib/runtime/agents/x.ex", X, @crew) == "agents"
    end

    test "5: context_dir: a file directly in lib/<app>/ takes the app's name" do
      assert RecordNaming.domain_for("apps/runtime/lib/runtime/x.ex", X, @crew) == "runtime"
    end
  end

  describe "slot/2 and path/2" do
    test "1: the slot is the branch sanitized, case kept (ADR 003); the ticket key upper-cased" do
      assert RecordNaming.slot("dnd-5473-runner") ==
               {:ok, %{slot: "dnd_5473_runner", ticket: "DND-5473"}}

      assert RecordNaming.slot("feat/Dnd-12_x") ==
               {:ok, %{slot: "feat_Dnd_12_x", ticket: "DND-12"}}
    end

    test "2: no ticket key: the branch, sanitized" do
      assert RecordNaming.slot("feat/umbrella-paths") ==
               {:ok, %{slot: "feat_umbrella_paths", ticket: nil}}
    end

    test "--ticket and --slot override; a detached HEAD needs --slot or --ticket" do
      assert RecordNaming.slot("main", ticket: "DND-9") ==
               {:ok, %{slot: "main", ticket: "DND-9"}}

      assert RecordNaming.slot(nil, ticket: "DND-9") == {:ok, %{slot: "DND_9", ticket: "DND-9"}}

      assert RecordNaming.slot(nil, slot: "x/y") == {:ok, %{slot: "x_y", ticket: nil}}
      assert RecordNaming.slot(nil) == {:error, :no_branch}
    end

    defp ctx(overrides) do
      {:ok, slot} = RecordNaming.slot("dnd-5473-runner")

      Map.merge(
        %{domain: "sabotage", app: nil, date: ~D[2026-11-05], slot: slot, existing_names: []},
        overrides
      )
    end

    test "3: domain_date_slot" do
      assert RecordNaming.path(@anchor, ctx(%{})) ==
               {:ok, "test/sabotage_records/sabotage-20261105-dnd_5473_runner.md"}
    end

    test "4: ticket_nn_what numbers one above the highest, not the count" do
      {:ok, slot} = RecordNaming.slot("DND-77-foo")
      names = ["DND-77-01-x.md", "DND-77-03-y.md", "DND-7-09-z.md", "README.md"]

      assert RecordNaming.path(
               @gen_saas,
               ctx(%{app: "core", slot: slot, existing_names: names})
             ) == {:ok, "apps/core/test/sabotage_records/DND-77-04-anchor-sabotage-run.md"}

      assert RecordNaming.path(@gen_saas, ctx(%{app: "core", slot: slot})) ==
               {:ok, "apps/core/test/sabotage_records/DND-77-01-anchor-sabotage-run.md"}
    end

    test "5: {app} in dir is the segment after apps/" do
      app = RecordNaming.app_for("apps/core/lib/core/a.ex")
      assert app == "core"

      assert RecordNaming.path(@crew, ctx(%{app: app})) ==
               {:ok, "apps/core/test/sabotage_records/sabotage-20261105-dnd_5473_runner.md"}
    end

    test "{app} for a file outside apps/ is refused" do
      assert RecordNaming.path(@crew, ctx(%{app: RecordNaming.app_for("lib/a.ex")})) ==
               {:error, :no_app}
    end

    test "6: ticket_nn_what with no ticket is refused" do
      {:ok, slot} = RecordNaming.slot("feat/umbrella-paths")

      assert RecordNaming.path(@gen_saas, ctx(%{app: "core", slot: slot})) ==
               {:error, :no_ticket}
    end

    test "sanitize collapses runs and trims, keeping case" do
      assert RecordNaming.sanitize("__adrs//seed-from-WALT__") == "adrs_seed_from_WALT"
    end
  end
end
