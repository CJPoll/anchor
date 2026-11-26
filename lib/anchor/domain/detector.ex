defmodule Anchor.Domain.Detector do
  @moduledoc """
  The contract of an `ast` rule type's detection — **Domain** (ADR 001,
  DND-8063).

  Each `Anchor.Domain.Checks.*` module implements it (`use
  Anchor.Domain.Detector`): its rule type, what its input needs, and
  `detect/1`, which turns one file's `%Input{}` into `%Violation{}`s with no
  IO and no `Credo.*`. The Credo check of the type (`Anchor.Check.*`,
  Framework) names its detector (`use Anchor.Check.Base, detector: ...`), and
  `Anchor.Managers.Lint` runs the detector it is given.

  Before DND-8063, Lint called `rule_type/0`, `needs_module_graph?/0` and
  `detect_violations/4` on the Credo check module itself: a Manager calling
  the Framework bucket, which ADR 001 forbids, through a dynamic call that
  `mix anchor.graph` fanned out to every check module (five baselined
  `layering` and five `interface` findings per check). Through this contract
  the Manager calls Domain only: the dynamic calls are made here, in this
  module, and `mix anchor.graph` judges each against every project module
  exporting the function, which are the detectors (and, for `rule_type/0`,
  the graph rules), all Domain. A new check adds no finding, and a Framework
  module that implemented this behaviour would be a `layering` finding here.
  Each function that calls a detector types it, in its one `@spec`, as
  `Anchor.Domain.Detector.t()`.

  `run/3` is the detection every caller shares: rules in `enforcement:
  report` are detected apart and their findings marked `:report` (DND-5441);
  a finding both passes made is kept once, enforced
  (`Anchor.Domain.EnforcementPasses.merge/2`, DND-5631); and a raise, throw
  or exit in the detection becomes one `:fail_closed` violation naming the
  check (DND-1310), never escaping.
  """

  alias Anchor.Domain.EnforcementPasses
  alias Anchor.Domain.Failures
  alias Anchor.Domain.RuleSchema
  alias Anchor.Domain.Violation

  defmodule Input do
    @moduledoc """
    One file's detection input, as plain data (DND-8063): the bare AST, the
    rules already selected for the file, the file's name and defining module
    names, the cross-file module graph (`%{}` unless the detector
    `needs_module_graph?/0`), the Credo check params, and the file's lines
    (`nil` unless the detector `needs_lines?/0`). A later input a detector
    needs is a new field here, filled by its caller.
    """

    @enforce_keys [:ast, :rules]
    defstruct ast: nil,
              rules: [],
              filename: nil,
              module_names: [],
              modules_map: %{},
              params: [],
              lines: nil

    @type t :: %__MODULE__{
            ast: Macro.t(),
            rules: [map()],
            filename: String.t() | nil,
            module_names: [String.t()],
            modules_map: map(),
            params: keyword(),
            lines: [{integer(), String.t()}] | nil
          }
  end

  @typedoc "A module implementing this behaviour."
  @type t :: module()

  @doc "The rule type the detector reads."
  @callback rule_type() :: atom()

  @doc "Whether `detect/1` reads `Input.modules_map` (the cross-file module graph)."
  @callback needs_module_graph?() :: boolean()

  @doc "Whether `detect/1` reads `Input.lines`."
  @callback needs_lines?() :: boolean()

  @doc "The violations of one file."
  @callback detect(Input.t()) :: [Violation.t()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Anchor.Domain.Detector

      @impl Anchor.Domain.Detector
      def needs_module_graph?, do: false

      @impl Anchor.Domain.Detector
      def needs_lines?, do: false

      defoverridable needs_module_graph?: 0, needs_lines?: 0
    end
  end

  @doc "The rule type `detector` reads."
  @spec rule_type(Anchor.Domain.Detector.t()) :: atom()
  def rule_type(detector), do: detector.rule_type()

  @doc "Whether `detector` reads the cross-file module graph."
  @spec needs_module_graph?(Anchor.Domain.Detector.t()) :: boolean()
  def needs_module_graph?(detector), do: detector.needs_module_graph?()

  @doc "Whether `detector` reads the file's lines."
  @spec needs_lines?(Anchor.Domain.Detector.t()) :: boolean()
  def needs_lines?(detector), do: detector.needs_lines?()

  @doc """
  Runs `detector` on `input`, splitting its rules by enforcement and
  guarding the detection. `check` names the check in a crash's violation.
  """
  @spec run(t(), Input.t(), module()) :: [Violation.t()]
  def run(detector, %Input{rules: rules} = input, check) do
    case Enum.split_with(rules, &(RuleSchema.enforcement(&1) == :report)) do
      {[], _enforce} ->
        guarded(detector, input, check)

      {report, enforce} ->
        EnforcementPasses.merge(
          some(detector, %{input | rules: enforce}, check),
          detector
          |> guarded(%{input | rules: report}, check)
          |> Enum.map(&report_only/1)
        )
    end
  end

  defp some(_detector, %Input{rules: []}, _check), do: []
  defp some(detector, input, check), do: guarded(detector, input, check)

  @spec guarded(Anchor.Domain.Detector.t(), Input.t(), module()) :: [Violation.t()]
  defp guarded(detector, input, check) do
    detector.detect(input)
  catch
    kind, reason ->
      [Failures.analysis_crash_violation(check, kind, reason, __STACKTRACE__)]
  end

  defp report_only(%Violation{kind: :rule} = violation), do: %{violation | enforcement: :report}
  defp report_only(violation), do: violation
end
