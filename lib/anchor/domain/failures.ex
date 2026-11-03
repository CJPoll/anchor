defmodule Anchor.Domain.Failures do
  @moduledoc """
  The reports Anchor makes when it could not check something — a **Domain**
  module (ADR 001). Pure: it turns a failure reason into a
  `%Anchor.Domain.Violation{kind: :fail_closed}` and does no IO.

  Anchor fails closed (DND-1265). A run that checked nothing must never read
  the same as a run that found nothing, so each of these is a Credo issue:

    * **No `.anchor.yml`** — `{:config_not_found, searched}`. The issue names
      every candidate path the lookup searched, and sits on the first one.
    * **A config that did not load** — `{:config_load_failed, path, detail}`,
      where `detail` is `{:read, posix}`, `{:yaml, message}`,
      `{:invalid_rule, message}` or `{:invalid_config, message}`. The issue sits
      on `path` and says what failed.
    * **A source file Anchor could not parse** — `unparseable_violation/2`,
      on that file at the parser's line.
    * **A crash analysing a source file** (DND-1310) —
      `analysis_crash_violation/4`, on that file, naming the check (or Anchor's
      shared per-file analysis) and the reason.
    * **A rule that selected fewer files than its floor** (DND-1290) —
      `selection_floor_violation/4`, on the config the rule came from.
    * **A rule no enabled check reads** (DND-1290) —
      `unchecked_rule_violation/3`, on the config the rule came from.
    * **An allowed caller no selected file defines** (DND-1269) —
      `missing_allowed_callers_violation/3`, on the config the rule came from.

  The graph runner's (`mix anchor.graph`, DND-5440) are the `graph_*`,
  `unclassified/1`, `ambiguous/2`, `bucket_below_floor/4`,
  `rule_below_floor/4` and `rule_crashed/5` functions: one per row of the
  README's graph fail-closed table, each a fail-closed violation on its file
  (a beam, a source file, or the config) ending with a `Fix:` line.

  A rule is named as `rule_label/1` names it: its position and, when it has
  one, its `id` (`rule 2 (id: "web", no_direct_dependency)`).

  Every message says what was searched or what failed, that no Anchor rule was
  checked because of it, and ends with a `Fix:` line. A reason of a shape this
  module does not recognise is still reported (a config loader is a behaviour,
  so a new loader can return anything); it is never dropped.
  """

  alias Anchor.Domain.RuleCoverage
  alias Anchor.Domain.Violation

  @config_filename ".anchor.yml"
  @crash_reason_limit 300
  @schema_pointer "the README section \"Config schema: rule keys at a glance\" and its " <>
                    "table \"Keys each rule type accepts\""

  @type config_reason ::
          {:config_not_found, [String.t()]}
          | {:config_load_failed, String.t(), term()}
          | term()

  @doc """
  Builds the violation for a config that could not be found or loaded.
  """
  @spec config_violation(config_reason()) :: Violation.t()
  def config_violation({:config_not_found, [first | _rest] = searched}) do
    fail_closed(
      first,
      "Anchor found no #{@config_filename}, so no Anchor rule was checked. " <>
        "Searched: #{Enum.join(searched, ", ")}. " <>
        "Fix: create #{@config_filename} at one of the searched paths (the project root, or the " <>
        "umbrella root), or run credo from the directory that holds it."
    )
  end

  def config_violation({:config_load_failed, path, detail}) when is_binary(path) do
    fail_closed(path, load_failed_message(path, detail))
  end

  def config_violation(reason) do
    fail_closed(
      @config_filename,
      "Anchor could not load its configuration (#{inspect(reason)}), so no Anchor rule was " <>
        "checked. Fix: make #{@config_filename} load; the reason above names what failed."
    )
  end

  @doc """
  Builds the violation for a source file Anchor could not parse, at the
  parser's `line` (or `nil`) with the parser's `message`. It sits on the file
  the check ran on (`filename: nil`).
  """
  @spec unparseable_violation(pos_integer() | nil, String.t()) :: Violation.t()
  def unparseable_violation(line, message) do
    %Violation{
      line: line,
      trigger: nil,
      kind: :fail_closed,
      message:
        "Anchor could not parse this file, so no Anchor rule was checked against it: " <>
          "#{message}. Fix: correct the syntax error (`mix compile` reports it too)."
    }
  end

  @doc """
  Builds the violation for a crash while analysing a source file (DND-1310):
  `kind` and `reason` as a `catch kind, reason` sees them, and its
  `stacktrace`. It sits on that file (`filename: nil`) and names what crashed,
  the reason (at most #{@crash_reason_limit} characters) and the frame that
  raised, so the report can go to Anchor as it stands.

  `subject` is the check whose detection or module-graph build crashed, or
  `:file_analysis` for the per-file facts every check shares (reported once
  per run, like an unparseable file).
  """
  @spec analysis_crash_violation(
          module() | :file_analysis,
          :error | :exit | :throw,
          term(),
          Exception.stacktrace()
        ) :: Violation.t()
  def analysis_crash_violation(subject, kind, reason, stacktrace) do
    %Violation{
      line: nil,
      trigger: crash_trigger(subject),
      kind: :fail_closed,
      message:
        "#{crash_opening(subject)}: #{crash_reason(kind, reason, stacktrace)}" <>
          "#{raised_at(stacktrace)}. Fix: this is a defect in Anchor, not in this file; " <>
          "report it to Anchor with the file (or a minimal snippet that reproduces it). " <>
          "Excluding the file from Credo silences this and leaves the file unchecked."
    }
  end

  @doc """
  The reason text of a crash, as `analysis_crash_violation/4` words it: the
  exception (or kind and term), capped at #{@crash_reason_limit} characters, and
  the frame that raised. `Anchor.Adapters.BeamReader` uses it for a beam whose
  decoding crashed (DND-5438).
  """
  @spec crash_summary(:error | :exit | :throw, term(), Exception.stacktrace()) :: String.t()
  def crash_summary(kind, reason, stacktrace),
    do: "#{crash_reason(kind, reason, stacktrace)}#{raised_at(stacktrace)}"

  @doc """
  Builds the violation for a rule that selected fewer files than its floor
  (`min_files`, default 1) among the `file_count` files its check ran on
  (DND-1290). It sits on the config the rule came from, `config_path` (or
  `.anchor.yml` when the config was not read from a file).
  """
  @spec selection_floor_violation(map(), non_neg_integer(), non_neg_integer(), String.t() | nil) ::
          Violation.t()
  def selection_floor_violation(rule, selected, file_count, config_path) do
    floor = RuleCoverage.min_files(rule)
    config = config_path || @config_filename

    rule_violation(
      rule,
      config,
      "Anchor #{rule_label(rule)} selected #{selected} of the #{files(file_count)} this " <>
        "check ran on, below its floor of #{floor} (min_files), so it " <>
        "#{shortfall(selected)}. Fix: correct its selector (paths, pattern or uses_module) " <>
        "in #{config} so it selects the files it is meant to check#{lower_floor(selected)}, " <>
        "or remove the rule."
    )
  end

  @doc """
  Builds the violation for a rule that lists allowed callers no file it selects
  defines (DND-1269), naming each one in the order the rule lists them.
  """
  @spec missing_allowed_callers_violation(map(), [module()], String.t() | nil) :: Violation.t()
  def missing_allowed_callers_violation(rule, missing, config_path) do
    config = config_path || @config_filename
    names = Enum.map_join(missing, ", ", &inspect/1)

    rule_violation(
      rule,
      config,
      "Anchor #{rule_label(rule)} lists #{names} in allowed_callers, but no file it selects " <>
        "defines #{pronoun(missing)}, so it allows nothing today and would silently allow " <>
        "any module later given that name. Fix: in #{config}, rename each such entry to the " <>
        "module that now does this work, or remove it."
    )
  end

  @doc """
  Builds the violation for a rule whose type no enabled Credo check reads
  (DND-1290), naming `check`, the Anchor check that would read it.
  """
  @spec unchecked_rule_violation(map(), module() | nil, String.t() | nil) :: Violation.t()
  def unchecked_rule_violation(rule, check, config_path) do
    config = config_path || @config_filename

    rule_violation(
      rule,
      config,
      "Anchor #{rule_label(rule)} is not checked: no enabled Credo check reads " <>
        "#{rule.type} rules, so it checked nothing. Fix: enable #{check_name(check, rule)} " <>
        "in .credo.exs, or remove the rule from #{config}."
    )
  end

  @doc """
  The issue for a run that has no `architecture:` section (DND-5440): with
  no buckets nothing can be classified and no graph rule can run, so `mix
  anchor.graph` cannot measure (exit 3). It sits on the config.
  """
  @spec graph_no_architecture(String.t() | nil) :: Violation.t()
  def graph_no_architecture(config_path) do
    config = config_path || @config_filename

    graph_issue(
      config,
      nil,
      "COULD NOT MEASURE: #{config} has no architecture: section, so mix anchor.graph could " <>
        "classify no module and run no graph rule. Fix: add an architecture: section to " <>
        "#{config} (the README section \"The `architecture:` section\")."
    )
  end

  @doc """
  The issue for `--only` ids that name no graph rule of the config
  (DND-5440): the narrowed run would check nothing and read clean, so it is
  COULD NOT MEASURE (exit 3), on the config.
  """
  @spec graph_unknown_only([String.t()], String.t() | nil) :: Violation.t()
  def graph_unknown_only(ids, config_path) do
    config = config_path || @config_filename

    graph_issue(
      config,
      nil,
      "COULD NOT MEASURE: --only #{Enum.map_join(ids, ", ", &inspect/1)} names no graph rule " <>
        "of #{config}, so the run would check nothing. Fix: pass the id of a graph rule " <>
        "(its id: key), or drop --only."
    )
  end

  @doc """
  The issue for a run that read zero modules from `ebins` (the ebin
  directories it was given): COULD NOT MEASURE, exit 3.
  """
  @spec graph_no_modules([String.t()]) :: Violation.t()
  def graph_no_modules(ebins) do
    graph_issue(
      List.first(ebins) || ".",
      nil,
      "COULD NOT MEASURE: read 0 modules from #{Enum.join(ebins, ", ")}. Fix: run mix " <>
        "compile in this project; check that the ebin dirs above are the project's."
    )
  end

  @doc """
  The per-module issue for an entry of `graph.unreadable`
  (`Anchor.Domain.Graph`): a beam Anchor could not decode, a second beam of
  one module, or a module whose graph walk crashed. It sits on the beam's
  path and names the module when it is known. Each reason has its own `Fix:`;
  a reason of any other shape is still reported.

  An Erlang module (`{:not_elixir, backend}`) has its own issue,
  `graph_erlang_module/2`, raised only when no bucket classifies it.
  """
  @spec graph_unreadable(%{path: String.t(), module: module() | nil, reason: term()}) ::
          Violation.t()
  def graph_unreadable(%{path: path, module: module, reason: reason}) do
    graph_issue(path, nil, "#{beam_name(module, path)} #{unreadable_text(reason, path)}")
  end

  @doc """
  The issue for an Erlang module in the project that no bucket classifies by
  its name (DND-5440). The graph engine reads Elixir only: a classified Erlang
  module is an opaque node (counted, no edges); an unclassified one is this
  issue. No setting excludes it silently.
  """
  @spec graph_erlang_module(module(), String.t()) :: Violation.t()
  def graph_erlang_module(module, path) do
    graph_issue(
      path,
      nil,
      "#{inspect(module)} is Erlang source; the graph engine reads Elixir only, and no " <>
        "architecture bucket classifies it. Fix: move it under a dependency, or classify it " <>
        "with a pattern: selector so its calls are checked as a black box."
    )
  end

  @doc """
  The issue for a module's source file that could not be read or parsed
  (DND-5440): its literal `use`s are unknown (a `uses_module` selector cannot
  match it) and whether it is hand-written is `:unknown`.
  """
  @spec graph_source_unreadable(String.t(), term()) :: Violation.t()
  def graph_source_unreadable(file, reason) do
    graph_issue(
      file,
      nil,
      "Anchor could not read the source of #{file} (#{capped(inspect(reason))}), so its " <>
        "uses_module selectors and generated? are unknown. Fix: make #{file} a readable file " <>
        "that parses (mix compile reports a syntax error), or run from the project root."
    )
  end

  @doc """
  The issue for a module whose literal `use`s its source does not show (its
  file has a non-literal `defmodule`, or a relative name after a file-level
  `alias`) while the architecture has a `uses_module` selector (DND-5440):
  read as "no uses", that selector could silently miss it.
  """
  @spec graph_uses_unknown(module(), String.t()) :: Violation.t()
  def graph_uses_unknown(module, file) do
    graph_issue(
      file,
      nil,
      "#{inspect(module)}'s literal uses cannot be read from #{file} (its defmodule name is " <>
        "not literal there), so a uses_module selector cannot be judged for it. Fix: give it " <>
        "a literal defmodule name (no file-level alias before a relative name), or select its " <>
        "bucket with a paths: or pattern: selector instead of uses_module."
    )
  end

  @doc """
  The issue for a module that no `architecture:` bucket selects (DND-5440),
  on its source file at its `defmodule` line. An Erlang module (facts with a
  `beam_path`) gets `graph_erlang_module/2`.
  """
  @spec unclassified(map()) :: Violation.t()
  def unclassified(%{module: module, beam_path: path}), do: graph_erlang_module(module, path)

  def unclassified(%{module: module} = facts) do
    file = Map.get(facts, :source_file) || "(no source file)"

    graph_issue(
      file,
      Map.get(facts, :line),
      "#{inspect(module)} is in no architecture bucket. Fix: add a selector that matches " <>
        "#{file} to the bucket this module belongs in (mix anchor.explain #{file} shows the " <>
        "candidates)."
    )
  end

  @doc """
  The issue for a module that two or more buckets select (DND-5440), naming
  each bucket and the selector that matched in it. Buckets never take
  precedence, so the module is in none.
  """
  @spec ambiguous(map(), [{String.t(), String.t()}]) :: Violation.t()
  def ambiguous(%{module: module} = facts, matches) do
    file = Map.get(facts, :source_file) || Map.get(facts, :beam_path) || "(no source file)"

    named =
      Enum.map_join(matches, " and ", fn {bucket, selector} -> "#{bucket} (by #{selector})" end)

    graph_issue(
      file,
      Map.get(facts, :line),
      "#{inspect(module)} is in buckets #{named}. Fix: narrow one selector; buckets never " <>
        "take precedence."
    )
  end

  @doc """
  The issue for an `architecture:` bucket that selects fewer modules than its
  `min_modules` (DND-5440), on the config.
  """
  @spec bucket_below_floor(String.t(), non_neg_integer(), pos_integer(), String.t() | nil) ::
          Violation.t()
  def bucket_below_floor(bucket, selected, min, config_path) do
    graph_issue(
      config_path || @config_filename,
      nil,
      "architecture bucket #{bucket} #{below_floor_text(selected, min)}"
    )
  end

  @doc """
  The issue for an `interfaces.exports` entry that names no module of the
  project (DND-5440), on the config. It exports nothing today, and would
  silently export whatever module is given that name later.
  """
  @spec interface_export_missing(module(), String.t() | nil) :: Violation.t()
  def interface_export_missing(module, config_path) do
    config = config_path || @config_filename

    graph_issue(
      config,
      nil,
      "architecture interfaces.exports names #{inspect(module)}, which is no module of the " <>
        "project, so it exports nothing today and would export any module later given that " <>
        "name. Fix: in #{config}, rename the entry to the module that is the interface, or " <>
        "remove it."
    )
  end

  @doc """
  The issue for a graph rule that selects fewer modules than its
  `min_modules` (DND-5440), on the config.
  """
  @spec rule_below_floor(map(), non_neg_integer(), pos_integer(), String.t() | nil) ::
          Violation.t()
  def rule_below_floor(rule, selected, min, config_path) do
    graph_issue(
      config_path || @config_filename,
      nil,
      "#{rule_label(rule)} #{below_floor_text(selected, min)}"
    )
  end

  @doc """
  The issue for a graph rule whose `check/2` raised, threw or exited
  (DND-5440): one issue naming the rule and the reason (at most
  #{@crash_reason_limit} characters, with the frame that raised). The other
  rules still run.
  """
  @spec rule_crashed(
          map(),
          :error | :exit | :throw,
          term(),
          Exception.stacktrace(),
          String.t() | nil
        ) ::
          Violation.t()
  def rule_crashed(rule, kind, reason, stacktrace, config_path) do
    graph_issue(
      config_path || @config_filename,
      nil,
      "#{rule_label(rule)} could not run: #{crash_summary(kind, reason, stacktrace)}, so it " <>
        "checked nothing. Fix: this is an Anchor bug; file it with this line."
    )
  end

  @doc """
  The note for a graph artifact that could not be written (DND-5440). The
  verdict never reads the artifact, so this does not fail the run; `mix
  anchor.explain` and `place` rebuild the graph instead.
  """
  @spec graph_artifact_not_written(String.t(), term()) :: Violation.t()
  def graph_artifact_not_written(dir, reason) do
    graph_issue(
      dir,
      nil,
      "Anchor could not write the graph artifact under #{dir} (#{capped(inspect(reason))}); " <>
        "the verdict does not read it. Fix: make #{dir} writable, under _build/<env>/anchor."
    )
  end

  defp below_floor_text(selected, min) do
    "selects #{selected} modules, below min_modules #{min}. Fix: correct the selector; " <>
      "lowering min_modules is the owner's call."
  end

  defp beam_name(nil, path), do: "The beam #{path}"
  defp beam_name(module, _path), do: inspect(module)

  defp unreadable_text(reason, _path) when reason in [:no_debug_info, :debug_info_stripped] do
    "was compiled without debug_info, so Anchor cannot read it. Fix: remove debug_info: false " <>
      "from the project's elixirc_options (Elixir keeps debug_info by default)."
  end

  defp unreadable_text({:not_elixir, backend}, _path) do
    "was not compiled from Elixir (its debug info is #{inspect(backend)}'s), so the graph " <>
      "engine cannot read it. Fix: move it under a dependency, or classify it with a pattern: " <>
      "selector so its calls are checked as a black box."
  end

  defp unreadable_text({:core_v1_refused, {:transform, transform}}, _path) do
    "was compiled with #{capped(inspect(transform))}, which lowering to Core Erlang would " <>
      "run, and Anchor runs no project code. Fix: remove the transform from the module's " <>
      "compile options, or move the module into a dependency."
  end

  defp unreadable_text({:core_v1_refused, reason}, _path) do
    "the beam's backend could not produce Core Erlang (#{capped(inspect(reason))}). Fix: " <>
      "recompile with the project's own Elixir; report the reason if it persists."
  end

  defp unreadable_text({:elixir_v1_refused, reason}, _path) do
    "the beam's backend could not produce its Elixir debug info (#{capped(inspect(reason))}). " <>
      "Fix: recompile with the project's own Elixir; report the reason if it persists."
  end

  defp unreadable_text({:decode_crashed, summary}, _path) do
    "could not be decoded: Anchor crashed reading it (#{summary}). Fix: this is an Anchor " <>
      "bug; file it with this line."
  end

  defp unreadable_text({:walk_crashed, summary}, _path) do
    "could not be added to the graph: Anchor crashed walking it (#{summary}). Fix: this is an " <>
      "Anchor bug; file it with this line."
  end

  defp unreadable_text({:duplicate_module, kept}, path) do
    "is in two ebins: #{path} and #{kept} (kept). Fix: run mix clean to remove a stale beam, " <>
      "or rename one of the two modules."
  end

  defp unreadable_text({:unreadable, reason}, path) do
    "could not be read (#{capped(inspect(reason))}). Fix: make #{path} readable; run mix " <>
      "compile so every ebin holds the project's beams."
  end

  defp unreadable_text(reason, _path) do
    "could not be read (#{capped(inspect(reason))}). Fix: this is an Anchor bug; file it " <>
      "with this line."
  end

  defp graph_issue(file, line, message) do
    %Violation{filename: file, line: line, trigger: nil, kind: :fail_closed, message: message}
  end

  @doc """
  The text `mix anchor.sabotage scope` prints when it could not measure a
  diff's scope (DND-5472): it exits 3, and the text starts `COULD NOT MEASURE`
  and ends with a `Fix:` line. Reasons:

    * `{:not_a_work_tree, root}`;
    * `{:no_merge_base, ref}`: `ref` does not resolve, or shares no history
      with `HEAD`;
    * `{:git_failed, argv, status, output}`: a git command exited non-zero;
    * `{:unparseable_diff, reason}`: git printed a diff Anchor cannot read;
    * `{:unparseable, file, line, reason}`: a changed source file does not parse;
    * `{:unparseable_base, file, sha, line, reason}`: its copy at the merge-base
      does not parse, so its removed lines cannot be mapped;
    * `{:unreadable, file, posix}`: a changed source file could not be read.

  A reason of any other shape is still reported, never dropped.
  """
  @spec scope_could_not_measure(term()) :: String.t()
  def scope_could_not_measure({:not_a_work_tree, root}),
    do:
      "COULD NOT MEASURE: #{root} is not a git work tree. Fix: run from the repository checkout."

  def scope_could_not_measure({:no_merge_base, ref}) do
    "COULD NOT MEASURE: no merge-base with #{ref}. " <>
      "Fix: fetch it (git fetch origin) or pass --base <ref>."
  end

  def scope_could_not_measure({:git_failed, argv, status, output}) do
    "COULD NOT MEASURE: `git #{Enum.join(argv, " ")}` exited #{status}: " <>
      "#{git_output(String.trim(output))}. Fix: run the command by hand to see why."
  end

  def scope_could_not_measure({:unparseable_diff, reason}) do
    "COULD NOT MEASURE: git printed a diff Anchor cannot read (#{capped(inspect(reason))}). " <>
      "Fix: check git's diff config (an external diff driver or textconv), or report it to Anchor."
  end

  def scope_could_not_measure({:unparseable, file, line, reason}) do
    "COULD NOT MEASURE: #{file}:#{line} does not parse (#{reason}). " <>
      "Fix: make it compile; a file that does not parse cannot be scoped."
  end

  def scope_could_not_measure({:unparseable_base, file, sha, line, reason}) do
    "COULD NOT MEASURE: #{file}:#{line} at the merge-base #{sha} does not parse (#{reason}). " <>
      "Fix: pass a --base whose copy of #{file} parses; its removed lines cannot be mapped to " <>
      "functions otherwise."
  end

  def scope_could_not_measure({:unreadable, file, posix}) do
    "COULD NOT MEASURE: could not read #{file} (#{inspect(posix)}). " <>
      "Fix: make #{file} a readable file."
  end

  def scope_could_not_measure(reason) do
    "COULD NOT MEASURE: #{capped(inspect(reason))}. Fix: this is a defect in Anchor; report it with this text."
  end

  # The git adapter keeps git's stderr out of the output it reads, so a
  # failure usually quotes nothing: git's own message is on stderr.
  defp git_output(""), do: "(git's message is printed above, on stderr)"
  defp git_output(output), do: capped(output)

  @doc """
  Names a parsed rule the way a load error does: `rule 2 (id: "web", type)`, or
  `rule 2 (type)` without an id. A rule built in memory has no position.
  """
  @spec rule_label(map()) :: String.t()
  def rule_label(rule) do
    position = if index = Map.get(rule, :index), do: "rule #{index}", else: "rule"

    case Map.get(rule, :id) do
      nil -> "#{position} (#{rule.type})"
      id -> "#{position} (id: #{inspect(id)}, #{rule.type})"
    end
  end

  defp crash_trigger(:file_analysis), do: "Anchor"
  defp crash_trigger(check), do: inspect(check)

  defp crash_opening(:file_analysis),
    do: "Anchor crashed analysing this file, so no Anchor rule was checked against it"

  defp crash_opening(check),
    do:
      "Anchor check #{inspect(check)} crashed on this file, so it checked no Anchor rule against it"

  # The reason can hold a whole AST or the analyser's state (a `MatchError`
  # prints its term), so it is capped.
  defp crash_reason(:error, reason, stacktrace) do
    exception = Exception.normalize(:error, reason, stacktrace)
    "#{inspect(exception.__struct__)}: #{capped(Exception.message(exception))}"
  end

  defp crash_reason(kind, reason, _stacktrace), do: "#{kind}: #{capped(inspect(reason))}"

  defp capped(text) do
    if String.length(text) > @crash_reason_limit,
      do: String.slice(text, 0, @crash_reason_limit) <> "...",
      else: text
  end

  # Built from the frame alone. `Exception.format_stacktrace_entry/1` is not
  # used: it reads the VM's application table (and `format_file_line/2` the
  # cwd), so the same frame would give different text.
  defp raised_at([{module, function, arity_or_args, location} | _rest]) when is_list(location) do
    " (raised at #{frame_location(location)}" <>
      "#{Exception.format_mfa(module, function, frame_arity(arity_or_args))})"
  end

  defp raised_at(_stacktrace), do: ""

  defp frame_location(location) do
    case {Keyword.get(location, :file), Keyword.get(location, :line)} do
      {nil, _line} -> ""
      {file, nil} -> "#{file}: "
      {file, line} -> "#{file}:#{line}: "
    end
  end

  # The frame's arity, never its arguments: a `FunctionClauseError` frame
  # carries them, and they are the analyser's whole state.
  defp frame_arity(args) when is_list(args), do: length(args)
  defp frame_arity(arity), do: arity

  defp pronoun([_one]), do: "it"
  defp pronoun(_many), do: "them"

  defp files(1), do: "1 file"
  defp files(count), do: "#{count} files"

  defp shortfall(0), do: "checked nothing"
  defp shortfall(_selected), do: "checked fewer files than it requires"

  defp lower_floor(0), do: ""
  defp lower_floor(_selected), do: " (or, if fewer files is now right, lower min_files)"

  defp check_name(nil, rule), do: "the Anchor check whose rule_type is #{rule.type}"
  defp check_name(check, _rule), do: inspect(check)

  defp rule_violation(rule, config, message) do
    %Violation{
      filename: config,
      line: nil,
      trigger: rule_label(rule),
      kind: :fail_closed,
      message: message
    }
  end

  defp fail_closed(filename, message) do
    %Violation{
      filename: filename,
      line: nil,
      trigger: @config_filename,
      kind: :fail_closed,
      message: message
    }
  end

  defp load_failed_message(path, {:read, posix}) do
    "Anchor could not read #{path} (#{inspect(posix)}), so no Anchor rule was checked. " <>
      "Fix: make #{path} a readable file."
  end

  defp load_failed_message(path, {:yaml, message}) do
    "Anchor could not parse #{path} as YAML, so no Anchor rule was checked: #{message}. " <>
      "Fix: correct the YAML syntax in #{path}."
  end

  defp load_failed_message(path, {kind, message}) when kind in [:invalid_rule, :invalid_config] do
    "Anchor rejected #{path}, so no Anchor rule was checked: #{message}. " <>
      "Fix: correct #{path} to match #{@schema_pointer}."
  end

  defp load_failed_message(path, detail) do
    "Anchor could not load #{path} (#{inspect(detail)}), so no Anchor rule was checked. " <>
      "Fix: correct #{path} to match #{@schema_pointer}."
  end
end
