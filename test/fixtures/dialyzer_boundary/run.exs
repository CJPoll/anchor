# DND-5499 spike runner: what Dialyzer reports for clause reachability.
#
#   cd <anchor checkout> && elixir test/fixtures/dialyzer_boundary/run.exs
#
# Compiles ONLY this directory's fixtures (plus the generated Widened<N>
# modules) into a fresh temporary directory, runs Dialyzer on ONLY those beams
# through its public `:dialyzer.run/1`, prints each warning verbatim under the
# module it belongs to ("no warnings" for a module with none), and prints one
# verdict line per claim. No Mix project, no network, no Dialyzer internals.
#
# Load rules (DND-5499 design): Dialyzer is never pointed at a whole repo and
# no OTP or Elixir PLT is built here. Dialyzer needs a PLT: `plts: []` does not
# mean "none", it falls back to the user's default PLT file ($DIALYZER_PLT or
# the user cache), which may be a full OTP PLT this run would load uncapped and
# misreport. So the runner always builds its own PLT from `erts` only, inside
# the temporary directory, under a 60 s cap; past the cap it stops (run it in CI
# instead).
#
# Exit status: 0 when every claim got a verdict (CONFIRMED or REFUTED), 1 when
# anything could not be measured: a missing fixture, a compile failure, zero
# beams, a compiled module with no source span, a Dialyzer error, the PLT cap,
# or a claim that reads COULD NOT MEASURE (its positive control was not
# reported, or a Dialyzer warning could not be attributed to a fixture module).
# An empty run never reads as "no warnings anywhere".
#
# Sabotage record: test/sabotage_records/dialyzer_boundary-20261103-dnd_5499.md
defmodule AnchorSpike.Runner do
  @fixture_files ["exported.ex", "private.ex", "widened.ex", "dropped.ex"]
  @plt_cap_ms 60_000
  # Widened<N> modules the runner generates. N = 20 is the committed
  # widened.ex (DND-5501 reuses it); the runner checks the file equals the
  # template's output, so the sweep and the committed fixture cannot drift.
  @widened_committed 20
  @widened_generated Enum.to_list(3..19)

  def main(dir) do
    # Random suffix and mkdir!/1 (not mkdir_p!/1): two concurrent runs never
    # share, or delete, one directory; a collision fails loudly.
    suffix = Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
    tmp = Path.join(System.tmp_dir!(), "anchor-dialyzer-spike-#{suffix}")
    File.mkdir!(tmp)
    say("tmp dir: #{tmp}")

    result =
      try do
        run(dir, tmp)
      after
        File.rm_rf!(tmp)
      end

    say("tmp dir removed: #{not File.exists?(tmp)}")

    case result do
      :ok -> :ok
      {:error, reason} -> fail(reason)
    end
  end

  def widened_source(n) do
    calls = Enum.map_join(1..n, ", ", &"kind(:a#{&1})")
    clauses = Enum.map_join(1..n, "\n", &"  defp kind(:a#{&1}), do: #{&1}")

    """
    defmodule AnchorSpike.Widened#{n} do
      def run, do: [#{calls}]

    #{clauses}
      defp kind(:never), do: 0
    end
    """
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  defp analyse(beams, tmp) do
    opts = [analysis_type: :succ_typings, from: :byte_code, files: beams, warnings: []]
    plt = Path.join(tmp, "erts.plt")
    erts_ebin = Path.join(to_string(:code.lib_dir(:erts)), "ebin")

    build = [
      analysis_type: :plt_build,
      output_plt: String.to_charlist(plt),
      files_rec: [String.to_charlist(erts_ebin)]
    ]

    task = Task.async(fn -> :timer.tc(fn -> dialyze(build) end) end)

    case Task.yield(task, @plt_cap_ms) || Task.shutdown(task, :brutal_kill) do
      nil ->
        {:error,
         "erts-only PLT build passed the #{div(@plt_cap_ms, 1000)} s cap; run this script in CI instead"}

      {:ok, {_micros, {:error, reason}}} ->
        {:error, "erts-only PLT build failed: #{reason}"}

      {:ok, {micros, {:ok, _}}} ->
        seconds = Float.round(micros / 1_000_000, 1)
        route = "erts-only PLT (#{erts_ebin}), built in #{seconds} s"

        case dialyze(opts ++ [plts: [String.to_charlist(plt)]]) do
          {:ok, warnings} -> {:ok, warnings, route}
          {:error, reason} -> {:error, "analysis with the erts-only PLT failed: #{reason}"}
        end
    end
  end

  defp attribute(warnings, spans) do
    Enum.group_by(warnings, &owner(&1, spans), &format/1)
  end

  # A Dialyzer warning no fixture module owns could be any claim's evidence
  # (say, a lost "can never match" for AnchorSpike.Exported), so no claim gets
  # a verdict while one exists.
  defp claim_lines(%{unattributed: [_ | _]}, _widened_ns) do
    Enum.map(
      1..4,
      &"Claim #{&1}: COULD NOT MEASURE (a Dialyzer warning owned by no fixture module)"
    )
  end

  defp claim_lines(reports, widened_ns) do
    private_reported = never_match?(reports, AnchorSpike.Private)
    widened_reported = Map.new(widened_ns, &{&1, never_match?(reports, widened_module(&1))})
    widened_control = widened_reported[hd(widened_ns)]

    [
      claim1(reports, private_reported),
      claim2(private_reported, widened_control),
      claim3(widened_reported, widened_ns),
      claim4(reports, private_reported and widened_control)
    ]
  end

  defp claim1(_reports, false),
    do: "Claim 1: COULD NOT MEASURE (positive control failed: AnchorSpike.Private not reported)"

  defp claim1(reports, true) do
    if never_match?(reports, AnchorSpike.Exported),
      do: "Claim 1: REFUTED (AnchorSpike.Exported's unreachable clause is reported)",
      else: "Claim 1: CONFIRMED (no 'can never match' for AnchorSpike.Exported; control reported)"
  end

  # Claim 2's warning is its own evidence; its control is that the run reports
  # an unreachable private clause at all (Widened at the sweep's first N), so a
  # dead run reads COULD NOT MEASURE, never REFUTED.
  defp claim2(true, _control), do: "Claim 2: CONFIRMED (AnchorSpike.Private kind(:c) reported)"

  defp claim2(false, true),
    do: "Claim 2: REFUTED (AnchorSpike.Private kind(:c) not reported; Widened control reported)"

  defp claim2(false, _control),
    do:
      "Claim 2: COULD NOT MEASURE (neither AnchorSpike.Private nor the Widened control reported)"

  defp claim3(reported, ns) do
    per_n =
      Enum.map_join(ns, ", ", &"N=#{&1} #{if reported[&1], do: "reported", else: "not reported"}")

    limit = Enum.find(ns, &(not reported[&1]))
    reported_after_limit = limit && Enum.any?(ns, &(&1 > limit and reported[&1]))

    cond do
      not reported[hd(ns)] ->
        "Claim 3: COULD NOT MEASURE (positive control N=#{hd(ns)} not reported). #{per_n}"

      limit == nil ->
        "Claim 3: REFUTED (reported at every N up to #{List.last(ns)}). #{per_n}"

      reported_after_limit ->
        "Claim 3: REFUTED (not monotone in N). #{per_n}"

      true ->
        "Claim 3: CONFIRMED. Limit observed: #{limit}. #{per_n}"
    end
  end

  defp claim4(_reports, false),
    do:
      "Claim 4: COULD NOT MEASURE (positive controls failed: the run reported no unreachable clause)"

  defp claim4(reports, true) do
    case Map.get(reports, AnchorSpike.Dropped, []) do
      [] -> "Claim 4: CONFIRMED (no warnings for AnchorSpike.Dropped; controls reported)"
      _ -> "Claim 4: REFUTED (AnchorSpike.Dropped has warnings)"
    end
  end

  defp compile(dir, tmp) do
    src = Path.join(tmp, "src")
    ebin = Path.join(tmp, "ebin")
    File.mkdir_p!(src)
    File.mkdir_p!(ebin)

    generated =
      Enum.map(@widened_generated, fn n ->
        path = Path.join(src, "widened_#{n}.ex")
        File.write!(path, widened_source(n))
        path
      end)

    files = Enum.map(@fixture_files, &Path.join(dir, &1)) ++ generated

    with :ok <- check_present(files),
         :ok <- check_widened_committed(dir),
         {:ok, modules, diagnostics} <-
           Kernel.ParallelCompiler.compile_to_path(files, ebin, return_diagnostics: true) do
      beams = Path.wildcard(Path.join(ebin, "*.beam"))
      {:ok, files, modules, beams, diagnostics.compile_warnings ++ diagnostics.runtime_warnings}
    else
      {:error, errors, _warnings} -> {:error, "fixture compile failed: #{inspect(errors)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_present(files) do
    case Enum.reject(files, &File.regular?/1) do
      [] -> :ok
      missing -> {:error, "fixture file(s) missing: #{Enum.join(missing, ", ")}"}
    end
  end

  defp check_widened_committed(dir) do
    committed = File.read!(Path.join(dir, "widened.ex"))

    if String.ends_with?(committed, widened_source(@widened_committed)),
      do: :ok,
      else:
        {:error, "widened.ex is not the template's N=#{@widened_committed} output; regenerate it"}
  end

  # `:dialyzer.run/1` throws `{:dialyzer_error, msg}` on a refusal (seen: a
  # missing default PLT); anything else it raises is printed verbatim too.
  defp dialyze(opts) do
    {:ok, :dialyzer.run(opts)}
  rescue
    e -> {:error, Exception.format(:error, e)}
  catch
    :throw, {:dialyzer_error, msg} -> {:error, String.trim(to_string(msg))}
    kind, reason -> {:error, Exception.format(kind, reason)}
  end

  defp format(warning), do: warning |> :dialyzer.format_warning() |> to_string() |> String.trim()

  defp module_spans(files) do
    Enum.flat_map(files, fn file ->
      file
      |> File.read!()
      |> Code.string_to_quoted!(token_metadata: true, columns: true)
      |> collect_modules(Path.expand(file))
    end)
  end

  defp collect_modules(ast, file) do
    {_ast, acc} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, [{:__aliases__, _, parts}, _]} = node, acc ->
          span = {Module.concat(parts), file, meta[:line], meta[:end][:line]}
          {node, [span | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(acc)
  end

  defp never_match?(reports, module) do
    reports |> Map.get(module, []) |> Enum.any?(&String.contains?(&1, "can never match"))
  end

  defp owner({_tag, {file, location, _}, _msg}, spans),
    do: owner_at(to_string(file), location, spans)

  defp owner({_tag, {file, location}, _msg}, spans),
    do: owner_at(to_string(file), location, spans)

  defp owner_at(file, location, spans) do
    line = line_of(location)
    path = Path.expand(file)

    Enum.find_value(spans, :unattributed, fn {module, span_file, first, last} ->
      if span_file == path and line >= first and line <= last, do: module
    end)
  end

  # The full OTP version (28.2), not just the release (28): read from the
  # release's OTP_VERSION file, falling back to the release when it is absent.
  defp otp_version do
    release = to_string(:erlang.system_info(:otp_release))
    file = Path.join([to_string(:code.root_dir()), "releases", release, "OTP_VERSION"])

    case File.read(file) do
      {:ok, version} -> String.trim(version)
      {:error, _} -> release
    end
  end

  defp print_versions(route) do
    Application.load(:dialyzer)

    say(
      "Versions: OTP #{otp_version()}, Elixir #{System.version()}, " <>
        "Dialyzer #{Application.spec(:dialyzer, :vsn)}. Route: #{route}."
    )
  end

  # The Elixir compiler's own warnings, attributed like Dialyzer's. Not part of
  # any claim's verdict (the claims are about Dialyzer), but F8 must not
  # re-report what the compiler already reports, so they are printed per module.
  defp compiler_reports(diagnostics, spans) do
    Enum.group_by(
      diagnostics,
      &owner_at(to_string(&1.file), &1.position, spans),
      &"#{first_line(&1.message)} (#{Path.relative_to_cwd(to_string(&1.file))}:#{line_of(&1.position)})"
    )
  end

  defp first_line(message), do: message |> String.split("\n") |> hd() |> String.trim()

  defp line_of(position) when is_tuple(position), do: elem(position, 0)
  defp line_of(position), do: position

  defp print_module_lines(modules, reports, label) do
    say("-- #{label}")

    Enum.each(modules, fn module ->
      case Map.get(reports, module, []) do
        [] -> say("#{inspect(module)}: no warnings")
        lines -> Enum.each(lines, &say("#{inspect(module)}: #{&1}"))
      end
    end)

    Enum.each(Map.get(reports, :unattributed, []), &say("(unattributed): #{&1}"))
  end

  defp report(spans, warnings, diagnostics, route) do
    reports = attribute(warnings, spans)
    modules = Enum.map(spans, &elem(&1, 0))

    print_module_lines(
      modules,
      reports,
      "Dialyzer warnings (verbatim, :dialyzer.format_warning/1)"
    )

    print_module_lines(modules, compiler_reports(diagnostics, spans), "Elixir compiler warnings")
    print_versions(route)

    widened_ns = Enum.sort([@widened_committed | @widened_generated])
    lines = claim_lines(reports, widened_ns)
    Enum.each(lines, &say/1)

    case Enum.count(lines, &String.contains?(&1, "COULD NOT MEASURE")) do
      0 -> :ok
      n -> {:error, "#{n} of #{length(lines)} claims could not be measured"}
    end
  end

  defp run(dir, tmp) do
    with {:ok, files, modules, beams, diagnostics} <- compile(dir, tmp),
         :ok <- check_beams(beams, modules),
         spans = module_spans(files),
         :ok <- check_spans(spans, modules),
         {:ok, warnings, route} <- analyse(Enum.map(beams, &String.to_charlist/1), tmp) do
      say(
        "compiled #{length(beams)} beams from #{length(files)} fixture files; Dialyzer ran on those beams only"
      )

      report(spans, warnings, diagnostics, route)
    end
  end

  defp check_beams([], _modules), do: {:error, "0 beams compiled"}

  defp check_beams(beams, modules) when length(beams) == length(modules), do: :ok

  defp check_beams(beams, modules),
    do: {:error, "#{length(modules)} modules compiled but #{length(beams)} beams written"}

  defp check_spans(spans, modules) do
    case modules -- Enum.map(spans, &elem(&1, 0)) do
      [] -> :ok
      missing -> {:error, "no source span for #{inspect(missing)}"}
    end
  end

  defp fail(reason) do
    say("COULD NOT MEASURE: #{reason}")
    System.halt(1)
  end

  # This is a command-line script whose output is its result, so it writes to
  # stdout directly; IO.puts/1 would do the same (Credo's IoPuts check is aimed
  # at library code).
  defp say(line), do: IO.write([line, "\n"])

  defp widened_module(n), do: Module.concat(AnchorSpike, "Widened#{n}")
end

AnchorSpike.Runner.main(__DIR__)
