defmodule Anchor.Domain.Checks.NoDependencyForbiddenFunctionsTest do
  # Function-level targets for `no_direct_dependency` (DND-1267, gap A4 of the
  # DND-1263 design), with DND-1280 folded in.
  #
  # ONE table over every call shape that reaches a function. Each row is a file
  # and the violations it must produce against one rule forbidding
  # `Bad.Mod.f` (any arity), `Bad.Mod.g/2` and `:bad_erl.f`:
  #
  #   * `{:call, "Bad.Mod.f/1", line}` — a resolved call on a forbidden function;
  #   * `{:dynamic, line}` — a call whose module or function a source pass cannot
  #     resolve, and which could reach a forbidden function (reported, never
  #     skipped);
  #   * `[]` — nothing. The negative rows are the same-named function on another
  #     module, another function on the forbidden module, an arity the token
  #     excludes, a local definition, and code that holds but never calls.
  #
  # The table runs in both `match` modes: `match` chooses the module-level
  # dependency set, and a function is reached only by a call, so it must not
  # change a single row.
  #
  # The last describes are DND-1280: the same detection code gave `match: :call`
  # module-level rules two misses (`defdelegate ..., to: M`, and `apply/3`
  # reached through a pipe), plus `Kernel.apply/3` and friends.
  #
  # Sabotage records:
  #   ../../../sabotage_records/dependency_analyzer-20260929-dnd_1267_forbidden_functions.md
  #   ../../../sabotage_records/no_dependency-20260929-dnd_1267_forbidden_functions.md
  use ExUnit.Case, async: true

  alias Anchor.Domain.Checks.NoDependency
  alias Anchor.Domain.FunctionRef
  alias Anchor.Domain.Violation

  @forbidden_functions [
    %FunctionRef{module: Bad.Mod, function: :f, arity: :any},
    %FunctionRef{module: Bad.Mod, function: :g, arity: 2},
    %FunctionRef{module: :bad_erl, function: :f, arity: :any}
  ]

  # {label, source, expected}. A bare body is wrapped in `defmodule W do ... end`,
  # so its first line is file line 2.
  @rows [
    # --- remote calls, resolved through the lexical environment -------------
    {"remote call", "  def a(x), do: Bad.Mod.f(x)", [{:call, "Bad.Mod.f/1", 2}]},
    {"alias", "  alias Bad.Mod\n  def a(x), do: Mod.f(x)", [{:call, "Bad.Mod.f/1", 3}]},
    {"alias as:", "  alias Bad.Mod, as: M\n  def a(x), do: M.f(x)", [{:call, "Bad.Mod.f/1", 3}]},
    {"multi-alias", "  alias Bad.{Mod, Other}\n  def a(x), do: Mod.f(x)",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"require as:", "  require Bad.Mod, as: R\n  def a(x), do: R.f(x)",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"__MODULE__.Sub", {:file, "defmodule Bad do\n  def a(x), do: __MODULE__.Mod.f(x)\nend\n"},
     [{:call, "Bad.Mod.f/1", 2}]},
    {"alias __MODULE__.Sub",
     {:file, "defmodule Bad do\n  alias __MODULE__.Mod\n  def a(x), do: Mod.f(x)\nend\n"},
     [{:call, "Bad.Mod.f/1", 3}]},
    {"a nested defmodule's implicit alias",
     {:file,
      "defmodule Bad do\n  defmodule Mod do\n    def f(x), do: x\n  end\n" <>
        "  def a(x), do: Mod.f(x)\nend\n"}, [{:call, "Bad.Mod.f/1", 5}]},
    {"a zero-arity remote call without parens", "  def a, do: Bad.Mod.f",
     [{:call, "Bad.Mod.f/0", 2}]},
    {"an Erlang module", "  def a(x), do: :bad_erl.f(x)", [{:call, ":bad_erl.f/1", 2}]},
    {"an arity token", "  def a(x, y), do: Bad.Mod.g(x, y)", [{:call, "Bad.Mod.g/2", 2}]},
    {"nested in case and fn",
     "  def a(x) do\n    case x do\n      _ -> Enum.map(x, fn y -> Bad.Mod.f(y) end)\n" <>
       "    end\n  end", [{:call, "Bad.Mod.f/1", 4}]},
    {"a module attribute's value", "  @v Bad.Mod.f(1)", [{:call, "Bad.Mod.f/1", 2}]},
    {"a call inside a quote (the macro emits it)",
     "  defmacro m do\n    quote do\n      Bad.Mod.f(1)\n    end\n  end",
     [{:call, "Bad.Mod.f/1", 4}]},
    # --- imported bare calls -------------------------------------------------
    {"import", "  import Bad.Mod\n  def a(x), do: f(x)", [{:call, "Bad.Mod.f/1", 3}]},
    {"import only:", "  import Bad.Mod, only: [f: 1]\n  def a(x), do: f(x)",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"import except: another", "  import Bad.Mod, except: [h: 1]\n  def a(x), do: f(x)",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"import, arity token", "  import Bad.Mod, only: [g: 2]\n  def a(x), do: g(x, x)",
     [{:call, "Bad.Mod.g/2", 3}]},
    # --- pipes ---------------------------------------------------------------
    {"piped remote call", "  def a(x), do: x |> Bad.Mod.f()", [{:call, "Bad.Mod.f/1", 2}]},
    {"piped remote call counts the piped argument", "  def a(x), do: x |> Bad.Mod.g(1)",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"piped aliased call", "  alias Bad.Mod\n  def a(x), do: x |> Mod.f()",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"a pipe chain", "  def a(x), do: x |> Enum.map(& &1) |> Bad.Mod.g(2)",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"piped imported call", "  import Bad.Mod\n  def a(x), do: x |> f()",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"piped imported call counts the piped argument",
     "  import Bad.Mod, only: [g: 2]\n  def a(x), do: x |> g(1)", [{:call, "Bad.Mod.g/2", 3}]},
    # --- captures ------------------------------------------------------------
    {"capture &M.f/n", "  def a, do: &Bad.Mod.f/2", [{:call, "Bad.Mod.f/2", 2}]},
    {"capture, arity token", "  def a, do: &Bad.Mod.g/2", [{:call, "Bad.Mod.g/2", 2}]},
    {"aliased capture", "  alias Bad.Mod\n  def a, do: &Mod.f/1", [{:call, "Bad.Mod.f/1", 3}]},
    {"capture with arguments &M.f(&1)", "  def a, do: &Bad.Mod.f(&1)",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"capture with arguments, arity token", "  def a, do: &Bad.Mod.g(&1, :x)",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"imported capture &f/1", "  import Bad.Mod\n  def a, do: &f/1", [{:call, "Bad.Mod.f/1", 3}]},
    {"imported capture with arguments", "  import Bad.Mod\n  def a, do: &f(&1)",
     [{:call, "Bad.Mod.f/1", 3}]},
    # --- apply/3 and the other MFA dispatchers -------------------------------
    {"apply/3", "  def a(x), do: apply(Bad.Mod, :f, [x])", [{:call, "Bad.Mod.f/1", 2}]},
    {"aliased apply/3", "  alias Bad.Mod\n  def a(x), do: apply(Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"apply/3, arity token", "  def a(x), do: apply(Bad.Mod, :g, [x, x])",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"apply/3 with runtime arguments (arity unknown)",
     "  def a(args), do: apply(Bad.Mod, :g, args)", [{:call, "Bad.Mod.g", 2}]},
    {"piped apply/3 (M |> apply(:f, args))", "  def a(x), do: Bad.Mod |> apply(:f, [x])",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"Kernel.apply/3", "  def a(x), do: Kernel.apply(Bad.Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 2}]},
    {":erlang.apply/3", "  def a(x), do: :erlang.apply(Bad.Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"Function.capture/3", "  def a, do: Function.capture(Bad.Mod, :f, 1)",
     [{:call, "Bad.Mod.f/1", 2}]},
    {":erlang.make_fun/3", "  def a, do: :erlang.make_fun(Bad.Mod, :f, 1)",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"an MFA passed to spawn/3", "  def a(x), do: spawn(Bad.Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"an MFA passed to Task.start/3", "  def a(x), do: Task.start(Bad.Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 2}]},
    {"an MFA tuple", "  def a(x), do: {Bad.Mod, :f, [x]}", [{:call, "Bad.Mod.f/1", 2}]},
    {"an MFA with an aliased module", "  alias Bad.Mod\n  def a(x), do: spawn(Mod, :f, [x])",
     [{:call, "Bad.Mod.f/1", 3}]},
    # --- defdelegate ---------------------------------------------------------
    {"defdelegate", "  defdelegate f(a), to: Bad.Mod", [{:call, "Bad.Mod.f/1", 2}]},
    {"defdelegate to an alias", "  alias Bad.Mod\n  defdelegate f(a), to: Mod",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"defdelegate as:", "  defdelegate h(a), to: Bad.Mod, as: :f", [{:call, "Bad.Mod.f/1", 2}]},
    {"defdelegate, arity token", "  defdelegate g(a, b), to: Bad.Mod",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"defdelegate with a default argument", "  defdelegate g(a, b \\\\ 1), to: Bad.Mod",
     [{:call, "Bad.Mod.g/2", 2}]},
    {"defdelegate with a default argument reaches every arity it defines",
     "  defdelegate f(a \\\\ 1), to: Bad.Mod",
     [{:call, "Bad.Mod.f/0", 2}, {:call, "Bad.Mod.f/1", 2}]},
    {"defdelegate with an unquote fragment head and as:",
     "  for name <- [:x] do\n    defdelegate unquote(name)(a), to: Bad.Mod, as: :f\n  end",
     [{:call, "Bad.Mod.f", 3}]},
    # --- module attributes bound to a literal module ------------------------
    {"an attribute module", "  @m Bad.Mod\n  def a(x), do: @m.f(x)", [{:call, "Bad.Mod.f/1", 3}]},
    {"an attribute bound to an alias", "  alias Bad.Mod\n  @m Mod\n  def a(x), do: @m.f(x)",
     [{:call, "Bad.Mod.f/1", 4}]},
    {"the latest attribute binding wins", "  @m Other.Mod\n  @m Bad.Mod\n  def a(x), do: @m.f(x)",
     [{:call, "Bad.Mod.f/1", 4}]},
    {"apply/3 on an attribute module", "  @m Bad.Mod\n  def a(x), do: apply(@m, :f, [x])",
     [{:call, "Bad.Mod.f/1", 3}]},
    {"defdelegate to an attribute", "  @t Bad.Mod\n  defdelegate f(a), to: @t",
     [{:call, "Bad.Mod.f/1", 3}]},
    # --- negatives: nothing reaches a forbidden function ---------------------
    {"the same name on another module", "  def a(x), do: Other.Mod.f(x)", []},
    {"the same name on a submodule", "  def a(x), do: Bad.Mod.Sub.f(x)", []},
    {"the same name on the parent module", "  def a(x), do: Bad.f(x)", []},
    {"another function on the module", "  def a(x), do: Bad.Mod.h(x)", []},
    {"an arity the token excludes", "  def a(x), do: Bad.Mod.g(x)", []},
    {"an alias of another module named Mod", "  alias Good.Mod\n  def a(x), do: Mod.f(x)", []},
    {"a local function named f", "  def f(x), do: x\n  def a(x), do: f(x)", []},
    {"the module's own local call",
     {:file, "defmodule Bad.Mod do\n  def f(x), do: x\n  def a(x), do: f(x)\nend\n"}, []},
    {"an import that excludes f", "  import Bad.Mod, except: [f: 1]\n  def a(x), do: f(x)", []},
    {"an import of only another function", "  import Bad.Mod, only: [h: 1]\n  def a(x), do: f(x)",
     []},
    {"an import of another module", "  import Other.Mod\n  def a(x), do: f(x)", []},
    {"a local definition shadows the import",
     "  import Bad.Mod\n  def f(x), do: x\n  def a(x), do: f(x)", []},
    {"a local definition's default-argument arity shadows the import",
     "  import Bad.Mod\n  def f(x \\\\ 1), do: x\n  def a, do: f()", []},
    {"a capture of an excluded arity", "  def a, do: &Bad.Mod.g/1", []},
    {"a capture on another module", "  def a, do: &Other.Mod.f/1", []},
    {"apply/3 on another module", "  def a(x), do: apply(Other.Mod, :f, [x])", []},
    {"apply/3 of another function", "  def a(x), do: apply(Bad.Mod, :h, [x])", []},
    {"apply/3 of an excluded arity", "  def a(x), do: apply(Bad.Mod, :g, [x])", []},
    {"defdelegate to another module", "  defdelegate f(a), to: Other.Mod", []},
    {"defdelegate as another function", "  defdelegate f(a), to: Bad.Mod, as: :h", []},
    {"the module held as a value", "  def a, do: %{m: Bad.Mod}", []},
    # A module next to an atom, with no argument list after it, is not an MFA.
    {"GenServer.call(M, :msg): a process name and a message",
     "  def a, do: GenServer.call(Bad.Mod, :f)", []},
    {"GenServer.call(M, :msg, timeout)", "  def a, do: GenServer.call(Bad.Mod, :f, 5_000)", []},
    {"a map pair %{M => :f}", "  def a, do: %{Bad.Mod => :f}", []},
    {"a 2-tuple {M, :f}", "  def a, do: {Bad.Mod, :f}", []},
    {"a 2-tuple in a function-head pattern", "  def a({Bad.Mod, :f}), do: :ok", []},
    {"an alias alone", "  alias Bad.Mod", []},
    {"a typespec",
     "  @type t :: Bad.Mod.f()\n  @spec a(Bad.Mod.f()) :: :ok\n  def a(_x), do: :ok", []},
    {"a string", ~s|  def a, do: "Bad.Mod.f(x)"|, []},
    {"x |> apply(Bad.Mod, :f) is apply(x, Bad.Mod, :f): Bad.Mod is the function name",
     "  def a(x), do: x |> apply(Bad.Mod, :f)", []},
    {"an anonymous call f.(x)", "  def a(f, x), do: f.(x)", []},
    {"field access without parens", "  def a(m), do: m.f", []},
    {"a dynamic call of another name", "  def a(m, x), do: m.h(x)", []},
    {"a dynamic call of an excluded arity", "  def a(m, x), do: m.g(x)", []},
    {"apply/3 on a dynamic module, another name", "  def a(m, x), do: apply(m, :h, [x])", []},
    {"apply/3 of a dynamic function on another module",
     "  def a(f, x), do: apply(Other.Mod, f, [x])", []},
    {"an attribute bound to another module", "  @m Other.Mod\n  def a(x), do: @m.f(x)", []},
    {"an attribute rebound away from the forbidden module",
     "  @m Bad.Mod\n  @m Other.Mod\n  def a(x), do: @m.f(x)", []},
    {"an unquote fragment's function on another module",
     "  for name <- [:f] do\n    def unquote(name)(x), do: Other.Mod.unquote(name)(x)\n  end",
     []},
    {"a dynamic call inside a quote is macro code",
     "  defmacro m(mod) do\n    quote do\n      unquote(mod).f(1)\n    end\n  end", []},
    # --- dynamic: unresolvable, and could reach a forbidden function ---------
    {"a variable module", "  def a(m, x), do: m.f(x)", [{:dynamic, 2}]},
    {"a variable module, arity token", "  def a(m, x), do: m.g(x, x)", [{:dynamic, 2}]},
    {"an attribute bound to a non-literal value",
     "  @m Application.compile_env(:app, :m)\n  def a(x), do: @m.f(x)", [{:dynamic, 3}]},
    {"an outer module's attribute is not bound in a nested module",
     "  @m Bad.Mod\n  defmodule Inner do\n    def a(x), do: @m.f(x)\n  end", [{:dynamic, 4}]},
    {"an unquote fragment's function on a forbidden module",
     "  for name <- [:f] do\n    def unquote(name)(x), do: Bad.Mod.unquote(name)(x)\n  end",
     [{:dynamic, 3}]},
    {"defdelegate with an unquote fragment head",
     "  for name <- [:f] do\n    defdelegate unquote(name)(x), to: Bad.Mod\n  end",
     [{:dynamic, 3}]},
    {"a call-result module", "  def a(x), do: adapter().f(x)", [{:dynamic, 2}]},
    {"a piped variable-module call", "  def a(m, x), do: x |> m.f()", [{:dynamic, 2}]},
    {"a variable-module capture", "  def a(m), do: &m.f/1", [{:dynamic, 2}]},
    {"apply/3 on a variable module", "  def a(m, x), do: apply(m, :f, [x])", [{:dynamic, 2}]},
    {"apply/3 of a variable function on a forbidden module",
     "  def a(f, x), do: apply(Bad.Mod, f, [x])", [{:dynamic, 2}]},
    {"apply/3 of a variable module and function", "  def a(m, f, x), do: apply(m, f, x)",
     [{:dynamic, 2}]},
    {"piped apply/3 on a variable module", "  def a(m, x), do: m |> apply(:f, [x])",
     [{:dynamic, 2}]},
    {"Kernel.apply/3 on a variable module", "  def a(m, x), do: Kernel.apply(m, :f, [x])",
     [{:dynamic, 2}]},
    {"Function.capture/3 on a variable module", "  def a(m), do: Function.capture(m, :f, 1)",
     [{:dynamic, 2}]},
    {"defdelegate to an unbound attribute", "  defdelegate f(a), to: @t", [{:dynamic, 2}]}
  ]

  for mode <- [:reference, :call] do
    describe "forbidden_functions over every call shape (match: #{mode})" do
      @describetag mode: mode

      test "every row reports exactly its expected violations", %{mode: mode} do
        # Every row is checked and every failing row listed, so one run shows
        # the whole table's state rather than its first failure.
        failures =
          @rows
          |> Enum.map(fn {label, source, expected} ->
            actual = source |> file() |> detect([rule(mode)]) |> Enum.map(&outcome/1)

            if Enum.sort(actual) == Enum.sort(expected),
              do: nil,
              else: "#{label}: want #{inspect(expected)}, got #{inspect(actual)}"
          end)
          |> Enum.reject(&is_nil/1)

        assert failures == [], Enum.join(failures, "\n")
      end
    end
  end

  describe "the violations" do
    test "a resolved call names the function it reached, at its line" do
      source = file("  alias Bad.Mod\n  def a(x), do: Mod.f(x)")

      assert [%Violation{} = violation] = detect(source, [rule(:call)])
      assert violation.message == "Module calls forbidden function Bad.Mod.f/1"
      assert violation.trigger == "Bad.Mod.f/1"
      assert violation.line == 3
    end

    test "a call of unknown arity names the function without an arity" do
      source = file("  def a(args), do: apply(Bad.Mod, :f, args)")

      assert [violation] = detect(source, [rule(:call)])
      assert violation.message == "Module calls forbidden function Bad.Mod.f (arity unknown)"
    end

    test "a dynamic call names what it could reach, and says how to fix it" do
      source = file("  def a(m, x), do: m.f(x)")

      assert [violation] = detect(source, [rule(:call)])

      assert violation.message =~
               "Anchor cannot statically resolve the module or function of this call"

      assert violation.message =~ "Bad.Mod.f, :bad_erl.f"
      assert violation.message =~ "Fix: "
      assert violation.line == 2
    end

    test "the same function called twice is reported once, at its first line" do
      source = file("  def a(x), do: Bad.Mod.f(x)\n  def b(x), do: Bad.Mod.f(x)")

      assert [%Violation{line: 2}] = detect(source, [rule(:call)])
    end

    test "each distinct arity is its own violation" do
      source = file("  def a(x), do: Bad.Mod.f(x)\n  def b(x), do: Bad.Mod.f(x, x)")

      assert source |> detect([rule(:call)]) |> Enum.map(& &1.trigger) |> Enum.sort() ==
               ["Bad.Mod.f/1", "Bad.Mod.f/2"]
    end

    test "a dynamic call site is reported once, not once per rule" do
      source = file("  def a(m, x), do: m.f(x)")

      assert [%Violation{line: 2, message: "Anchor cannot statically resolve" <> _rest}] =
               detect(source, [rule(:call), rule(:reference)])
    end

    test "a call through an unresolvable alias is reported through its directive" do
      source = file("  alias @target, as: T\n  def a(x), do: T.f(x)")

      assert [%Violation{line: 2, trigger: "alias", message: message}] =
               detect(source, [rule(:call)])

      assert message =~ "cannot statically resolve the target of this `alias`"
    end

    test "a dynamic call no applicable rule could be reached by is not reported" do
      only_g = %{
        rule(:call)
        | forbidden_functions: [%FunctionRef{module: Bad.Mod, function: :g, arity: 2}]
      }

      assert detect(file("  def a(m, x), do: m.f(x)"), [only_g]) == []
    end

    test "forbidden_functions and forbidden_modules report side by side" do
      rule = %{rule(:call) | forbidden_modules: [Other.Repo]}
      source = file("  def a(x), do: Bad.Mod.f(Other.Repo.all(x))")

      assert source |> detect([rule]) |> Enum.map(& &1.trigger) |> Enum.sort() ==
               ["Bad.Mod.f/1", "Other.Repo"]
    end

    test "a module-level rule keeps the documented dynamic-dispatch boundary" do
      rule = %{forbidden_modules: [Bad.Mod], forbidden_patterns: [], match: :call}

      assert detect(file("  def a(m, x), do: m.f(x)"), [rule]) == []
    end
  end

  # A `Kernel.*` token must match the usual, bare spelling: `send(pid, msg)` is
  # `Kernel.send/2` while `Kernel` owns it.
  describe "Kernel functions" do
    @kernel_rows [
      {"a bare call", "  def a(pid), do: send(pid, :hi)", [{:call, "Kernel.send/2", 2}]},
      {"a piped bare call", "  def a(pid), do: pid |> send(:hi)", [{:call, "Kernel.send/2", 2}]},
      {"a bare capture", "  def a, do: &send/2", [{:call, "Kernel.send/2", 2}]},
      {"a remote call", "  def a(pid), do: Kernel.send(pid, :hi)", [{:call, "Kernel.send/2", 2}]},
      {"a bare apply/3", "  def a(m), do: apply(m, :f, [])", [{:call, "Kernel.apply/3", 2}]},
      {"a bare macro-backed call, any arity", "  def a, do: spawn(fn -> :ok end)",
       [{:call, "Kernel.spawn/1", 2}]},
      {"a local send/2 shadows Kernel's",
       "  def send(a, b), do: {a, b}\n  def a(pid), do: send(pid, :hi)", []},
      {"import Kernel, except: [send: 2] hands send/2 away",
       "  import Kernel, except: [send: 2]\n  def a(pid), do: send(pid, :hi)", []},
      {"a local apply/3 is not Kernel's dispatcher",
       "  def apply(a, b, c), do: {a, b, c}\n  def a(m), do: apply(m, :f, [])", []}
    ]

    test "every row reports exactly its expected violations" do
      refs =
        for token <- ["Kernel.send/2", "Kernel.apply/3", "Kernel.spawn"] do
          {:ok, ref} = FunctionRef.parse(token)
          ref
        end

      rule = %{rule(:call) | forbidden_functions: refs}

      failures =
        for {label, body, expected} <- @kernel_rows,
            actual = body |> file() |> detect([rule]) |> Enum.map(&outcome/1),
            Enum.sort(actual) != Enum.sort(expected) do
          "#{label}: want #{inspect(expected)}, got #{inspect(actual)}"
        end

      assert failures == [], Enum.join(failures, "\n")
    end
  end

  # DND-1280: the same detection code, module-level, `match: :call`.
  describe "module-level call mode reaches the module through every call shape (DND-1280)" do
    @module_rows [
      {"defdelegate", "  defdelegate f(a), to: Bad.X", 2},
      {"defdelegate to an alias", "  alias Bad.X\n  defdelegate f(a), to: X", 3},
      {"defdelegate as:", "  defdelegate f(a), to: Bad.X, as: :g", 2},
      {"piped apply/3", "  def a(x), do: Bad.X |> apply(:f, [x])", 2},
      {"Kernel.apply/3", "  def a(x), do: Kernel.apply(Bad.X, :f, [x])", 2},
      {":erlang.apply/3", "  def a(x), do: :erlang.apply(Bad.X, :f, [x])", 2},
      {"Function.capture/3", "  def a, do: Function.capture(Bad.X, :f, 1)", 2},
      {":erlang.make_fun/3", "  def a, do: :erlang.make_fun(Bad.X, :f, 1)", 2},
      {"a call on an attribute bound to the module", "  @x Bad.X\n  def a, do: @x.f()", 3},
      {"defdelegate with an unquote fragment head",
       "  for name <- [:f] do\n    defdelegate unquote(name)(a), to: Bad.X\n  end", 3},
      {"an unquote fragment's function",
       "  for name <- [:f] do\n    def unquote(name)(a), do: Bad.X.unquote(name)(a)\n  end", 3}
    ]

    test "every shape reports the module at its line" do
      rule = %{forbidden_modules: [Bad.X], forbidden_patterns: [], match: :call}

      failures =
        for {label, body, line} <- @module_rows,
            outcome = body |> file() |> detect([rule]) |> Enum.map(&{&1.trigger, &1.line}),
            outcome != [{"Bad.X", line}] do
          "#{label}: want #{inspect([{"Bad.X", line}])}, got #{inspect(outcome)}"
        end

      assert failures == [], Enum.join(failures, "\n")
    end

    test "defdelegate to another module is not a dependency on the forbidden one" do
      rule = %{forbidden_modules: [Bad.X], forbidden_patterns: [], match: :call}

      assert detect(file("  defdelegate f(a), to: Other.X"), [rule]) == []
    end
  end

  defp rule(mode) do
    %{
      forbidden_modules: [],
      forbidden_patterns: [],
      forbidden_functions: @forbidden_functions,
      match: mode
    }
  end

  defp file({:file, source}), do: source
  defp file(body), do: "defmodule W do\n#{body}\nend\n"

  defp detect(source, rules),
    do: NoDependency.detect_violations(Code.string_to_quoted!(source), rules)

  defp outcome(%Violation{message: "Anchor cannot statically resolve" <> _rest, line: line}),
    do: {:dynamic, line}

  defp outcome(%Violation{trigger: trigger, line: line}), do: {:call, trigger, line}
end
