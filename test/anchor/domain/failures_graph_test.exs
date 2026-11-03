defmodule Anchor.Domain.FailuresGraphTest do
  # DND-5440: the graph runner's fail-closed messages (shared contract
  # section 7's table). Each is a fail-closed violation on the right file,
  # names its subject and ends with a Fix: line. Table-driven.
  #
  # Sabotage record: ../../sabotage_records/failures-20261103-dnd_5440_graph_runner.md
  # Sabotage record: ../../sabotage_records/failures-20261103-dnd_5551_graph_hardening.md
  # (rule_cfa_crashed, DND-5574: ../../sabotage_records/failures-20261103-dnd_5574_cfa_wiring.md)
  # Sabotage record: ../../sabotage_records/failures-20261103-dnd_5581_hardening_batch.md
  # DND-5441 (the baseline_* messages):
  #   ../../sabotage_records/baseline-20261103-dnd_5441_graph_rules_a.md
  # DND-5584 (graph_app_no_modules): ../../sabotage_records/graph_runner-20261103-dnd_5441_graph_rules_a.md
  # DND-5628 (the symlink rows): ../../sabotage_records/baseline_symlink-20261103-dnd_5441_graph_rules_a.md
  # DND-5648 (baseline_base_config_unreadable/4): ../../sabotage_records/baseline-20261103-dnd_5648_graph_followups.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Failures
  alias Anchor.Domain.Violation

  @beam "_build/dev/lib/app/ebin/Elixir.MyApp.X.beam"

  defp unreadable(reason, module \\ MyApp.X),
    do: Failures.graph_unreadable(%{path: @beam, module: module, reason: reason})

  # {reason, the texts its message must hold}
  @unreadable_rows [
    {:no_debug_info,
     ["MyApp.X was compiled without debug_info", "Fix: remove debug_info: false"]},
    {:debug_info_stripped,
     ["MyApp.X was compiled without debug_info", "Fix: remove debug_info: false"]},
    {{:elixir_v1_refused, :boom},
     [
       "could not produce its Elixir debug info (:boom)",
       "Fix: recompile with the project's own Elixir"
     ]},
    {{:core_v1_refused, :boom},
     ["could not produce Core Erlang (:boom)", "Fix: recompile with the project's own Elixir"]},
    {{:core_v1_refused, {:transform, {:parse_transform, :my_pt}}},
     [
       "was compiled with {:parse_transform, :my_pt}",
       "Fix: remove the transform from the module's compile options"
     ]},
    {{:core_v1_refused, {:option, {:plugins, [MyPlugin]}}},
     [
       "was compiled with the option {:plugins, [MyPlugin]}",
       "not on Anchor's list of options that run no code",
       "Fix: remove the option from the module's compile options"
     ]},
    {{:no_core, [{:run, 1}, {:m, 2}]},
     [
       "has no Core Erlang body for run/1, m/2",
       "Fix: this is an Anchor bug"
     ]},
    {{:decode_crashed, "RuntimeError: x"},
     ["Anchor crashed reading it (RuntimeError: x)", "Fix: this is an Anchor bug"]},
    {{:walk_crashed, "FunctionClauseError: y"},
     ["Anchor crashed walking it (FunctionClauseError: y)", "Fix: this is an Anchor bug"]},
    {{:duplicate_module, "other/ebin/Elixir.MyApp.X.beam"},
     ["is in two ebins: #{@beam} and other/ebin/Elixir.MyApp.X.beam (kept)", "Fix: run mix clean"]},
    {{:unreadable, :eacces}, ["could not be read (:eacces)", "Fix: make #{@beam} readable"]},
    {{:not_elixir, :erl_abstract_code},
     ["was not compiled from Elixir", "Fix: move it under a dependency"]},
    {:something_new, ["could not be read (:something_new)", "Fix: this is an Anchor bug"]}
  ]

  describe "graph_unreadable/1" do
    for {reason, texts} <- @unreadable_rows do
      test "#{inspect(reason)}: on the beam path, naming the module, with its Fix:" do
        assert %Violation{kind: :fail_closed, filename: @beam, line: nil, message: message} =
                 unreadable(unquote(Macro.escape(reason)))

        for text <- unquote(texts), do: assert(message =~ text)
      end
    end

    test "a beam whose module is unknown is named by its path" do
      assert unreadable({:unreadable, :enoent}, nil).message =~
               "The beam #{@beam} could not be read"
    end
  end

  # {name, violation, its file, the texts its message must hold}
  defp rows do
    rule = %{type: :layering, id: "web", index: 2}
    baselined = Map.put(rule, :baseline, "b.txt")

    crashed =
      try do
        raise "rule blew up"
      rescue
        e -> Failures.rule_crashed(rule, :error, e, __STACKTRACE__, "proj/.anchor.yml")
      end

    cfa_crashed =
      try do
        raise "cfa blew up"
      rescue
        e -> Failures.rule_cfa_crashed(rule, :error, e, __STACKTRACE__, nil)
      end

    [
      {"graph_no_architecture", Failures.graph_no_architecture("proj/.anchor.yml"),
       "proj/.anchor.yml",
       [
         "COULD NOT MEASURE: proj/.anchor.yml has no architecture: section",
         "Fix: add an architecture: section"
       ]},
      {"graph_no_architecture without a path", Failures.graph_no_architecture(nil), ".anchor.yml",
       ["COULD NOT MEASURE: .anchor.yml has no architecture: section"]},
      {"graph_no_modules",
       Failures.graph_no_modules(["_build/dev/lib/a/ebin", "_build/dev/lib/b/ebin"]),
       "_build/dev/lib/a/ebin",
       [
         "COULD NOT MEASURE: read 0 modules from _build/dev/lib/a/ebin, _build/dev/lib/b/ebin.",
         "Fix: run mix compile in this project"
       ]},
      # DND-5655: an umbrella app outside the root, refused with a Fix:.
      {"graph_apps_path_outside",
       Failures.graph_apps_path_outside([{:alpha, "/elsewhere/alpha"}], "/proj", nil),
       ".anchor.yml",
       [
         "COULD NOT MEASURE: the apps_path of :alpha is /elsewhere/alpha, outside the project root /proj",
         "Fix: set apps_path in the umbrella's mix.exs to a directory under the project root"
       ]},
      {"graph_app_no_modules", Failures.graph_app_no_modules(:other, "_build/dev/lib/other/ebin"),
       "_build/dev/lib/other/ebin",
       [
         "read 0 modules for app :other from _build/dev/lib/other/ebin",
         "Fix: run mix compile for :other"
       ]},
      {"baseline_unreadable", Failures.baseline_unreadable(baselined, "b.txt", :enoent), "b.txt",
       [
         ~s|rule 2 (id: "web", layering)'s baseline b.txt could not be read (:enoent)|,
         "Fix: create it with mix anchor.graph --write-baseline web"
       ]},
      {"baseline_unreadable not UTF-8",
       Failures.baseline_unreadable(baselined, "b.txt", {:line, 4, :invalid_utf8}), "b.txt",
       ["b.txt line 4 is not UTF-8", "Fix: rewrite that line as UTF-8"]},
      {"baseline_foreign", Failures.baseline_foreign(baselined, "b.txt", "x|A|y"), "b.txt",
       [~s(b.txt is the baseline of "web" but holds "x|A|y"), "Fix: one baseline per rule"]},
      {"baseline_base_unreadable", Failures.baseline_base_unreadable("b.txt", "main", :boom),
       "b.txt",
       [
         "could not read b.txt at main (:boom)",
         "(GREW) could not be judged",
         "Fix: pass a --base"
       ]},
      # DND-5648: one issue for the config, naming every rule it left unjudged.
      {"baseline_base_config_unreadable",
       Failures.baseline_base_config_unreadable(".anchor.yml", "main", :boom, ["web", "core"]),
       ".anchor.yml",
       [
         "Anchor could not read .anchor.yml at main (:boom)",
         ~s|GREW could not be judged for rules "web", "core"|,
         "Fix: pass a --base ref whose .anchor.yml loads"
       ]},
      {"baseline_first_landing", Failures.baseline_first_landing("b.txt", "main"), "b.txt",
       ["NOTE: first landing of b.txt (absent at main); review is the gate.", "Fix: review"]},
      {"baseline_exists", Failures.baseline_exists("b.txt"), "b.txt",
       ["b.txt exists; --write-baseline only creates", "Fix: delete the lines of fixed findings"]},
      {"baseline_written", Failures.baseline_written("b.txt", 3), "b.txt",
       ["wrote 3 entries to b.txt.", "Fix: review it in this change"]},
      {"baseline_not_written", Failures.baseline_not_written("b.txt", :eacces), "b.txt",
       ["could not create b.txt (:eacces)", "Fix: make its directory writable"]},
      # DND-5628: a symlink on the path is named, with what to do about it.
      {"baseline_unreadable symlink",
       Failures.baseline_unreadable(baselined, "b/x.txt", {:symlink, "b"}), "b/x.txt",
       [
         ~s|rule 2 (id: "web", layering)'s baseline b/x.txt was not read: b is a symlink|,
         "Anchor never follows one out of the project root",
         "Fix: replace the symlink b with a real directory or file inside the project"
       ]},
      {"baseline_not_written symlink",
       Failures.baseline_not_written("b/x.txt", {:symlink, "b/x.txt"}), "b/x.txt",
       [
         "Anchor did not create b/x.txt: b/x.txt is a symlink",
         "Fix: replace the symlink b/x.txt with a real directory or file inside the project"
       ]},
      {"baseline_base_unreadable symlink",
       Failures.baseline_base_unreadable("b/x.txt", "main", {:symlink, "b"}), "b/x.txt",
       [
         "b/x.txt at main was not read: b is a symlink there",
         "(GREW) could not be judged",
         "Fix: replace the symlink b with a real directory or file inside the project"
       ]},
      # DND-5647: the write escaped the root after the check, and was removed.
      {"baseline_not_written escaped",
       Failures.baseline_not_written("b/x.txt", {:escaped_root, "/elsewhere/x.txt"}), "b/x.txt",
       [
         "Anchor did not create b/x.txt: a directory on its path became a symlink",
         "landed at /elsewhere/x.txt, outside the project root, and was removed there",
         "Fix: find what is replacing directories"
       ]},
      {"write_baseline_unknown", Failures.write_baseline_unknown("web", nil), ".anchor.yml",
       [~s|--write-baseline "web" names no graph rule of .anchor.yml|, "Fix: give that rule"]},
      {"graph_unknown_only", Failures.graph_unknown_only(["nope"], "proj/.anchor.yml"),
       "proj/.anchor.yml",
       [
         ~s(COULD NOT MEASURE: --only "nope" names no graph rule of proj/.anchor.yml),
         "Fix: pass the id of a graph rule"
       ]},
      {"graph_uses_unknown", Failures.graph_uses_unknown(MyApp.X, "lib/x.ex"), "lib/x.ex",
       [
         "MyApp.X's literal uses cannot be read from lib/x.ex",
         "Fix: give it a literal defmodule name"
       ]},
      {"ambiguous Erlang module, on its beam",
       Failures.ambiguous(
         %{module: :my_erl, source_file: nil, beam_path: "ebin/my_erl.beam", line: nil},
         [{"a", "pattern \"my_erl\""}, {"b", "pattern \"my_*\""}]
       ), "ebin/my_erl.beam", [":my_erl is in buckets a (by pattern \"my_erl\") and b"]},
      {"graph_erlang_module", Failures.graph_erlang_module(:my_erl, "ebin/my_erl.beam"),
       "ebin/my_erl.beam",
       [
         ":my_erl is Erlang source",
         "Fix: move it under a dependency, or classify it with a pattern: selector"
       ]},
      {"graph_source_unreadable", Failures.graph_source_unreadable("lib/x.ex", :enoent),
       "lib/x.ex",
       ["could not read the source of lib/x.ex (:enoent)", "Fix: make lib/x.ex a readable file"]},
      {"unclassified",
       Failures.unclassified(%{module: MyApp.X, source_file: "lib/x.ex", line: 1}), "lib/x.ex",
       [
         "MyApp.X is in no architecture bucket.",
         "Fix: add a selector that matches lib/x.ex",
         "mix anchor.explain lib/x.ex"
       ]},
      {"ambiguous",
       Failures.ambiguous(
         %{module: MyApp.X, source_file: "lib/x.ex", line: 1},
         [{"domain", "paths [\"lib/**\"]"}, {"ui", "pattern \"MyApp.*\""}]
       ), "lib/x.ex",
       [
         ~s|MyApp.X is in buckets domain (by paths ["lib/**"]) and ui (by pattern "MyApp.*")|,
         "Fix: narrow one selector"
       ]},
      {"bucket_below_floor", Failures.bucket_below_floor("domain", 3, 10, "proj/.anchor.yml"),
       "proj/.anchor.yml",
       [
         "architecture bucket domain selects 3 modules, below min_modules 10.",
         "Fix: correct the selector"
       ]},
      {"rule_below_floor", Failures.rule_below_floor(rule, 0, 1, nil), ".anchor.yml",
       [
         ~s|rule 2 (id: "web", layering) selects 0 modules, below min_modules 1.|,
         "lowering min_modules is the owner's call"
       ]},
      {"rule_crashed", crashed, "proj/.anchor.yml",
       [
         ~s|rule 2 (id: "web", layering) could not run: RuntimeError: rule blew up|,
         "Fix: this is an Anchor bug; file it with this line."
       ]},
      {"rule_cfa_crashed", cfa_crashed, ".anchor.yml",
       [
         ~s|rule 2 (id: "web", layering) could not run: the higher-order flow analysis it | <>
           "needs (Anchor.Domain.Cfa) crashed: RuntimeError: cfa blew up",
         "so it checked nothing. Fix: this is an Anchor bug; file it with this line."
       ]},
      {"interface_export_missing",
       Failures.interface_export_missing(MyApp.Gone, "proj/.anchor.yml"), "proj/.anchor.yml",
       [
         "architecture interfaces.exports names MyApp.Gone, which is no module of the project",
         "Fix: in proj/.anchor.yml, rename the entry"
       ]},
      {"graph_artifact_not_written",
       Failures.graph_artifact_not_written("_build/dev/anchor", :eacces), "_build/dev/anchor",
       [
         "could not write the graph artifact under _build/dev/anchor (:eacces)",
         "Fix: make _build/dev/anchor writable (_build/dev/anchor is Mix's build path joined with anchor)."
       ]}
    ]
  end

  test "every graph message is fail-closed, on its file, with its subject and a Fix: line" do
    for {name, violation, file, texts} <- rows() do
      assert %Violation{kind: :fail_closed, filename: ^file} = violation, name
      assert violation.message =~ "Fix: ", name

      for text <- texts,
          do:
            assert(violation.message =~ text, "#{name}: #{inspect(text)} in #{violation.message}")
    end
  end

  # STALE and GREW are rule findings (they take the rule's enforcement), not
  # fail-closed issues: on the baseline path, keyed, ending with Fix:.
  test "baseline_stale and baseline_grew are rule violations on the baseline path, keyed" do
    stale = Failures.baseline_stale("b.txt", "web|A|x")
    grew = Failures.baseline_grew("b.txt", "web|B|y", "main")

    assert %Violation{kind: :rule, filename: "b.txt", key: "web|A|x"} = stale
    assert stale.message =~ "web|A|x in b.txt matches no finding (it was fixed). Fix: delete"
    assert %Violation{kind: :rule, filename: "b.txt", key: "web|B|y"} = grew
    assert grew.message =~ "web|B|y was added to b.txt since main. Fix: fix the finding instead"
  end
end
