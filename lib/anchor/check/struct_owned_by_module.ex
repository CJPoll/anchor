defmodule Anchor.Check.StructOwnedByModule do
  use Anchor.Check.Base,
    category: :design,
    explanations: [
      check: """
      Only a struct's own module builds it or changes it, so each invariant
      has one home.

      Outside the module that defines a struct, do not build it with
      `%Mod{...}` or `struct/2`, and do not change it with `%Mod{s | ...}`,
      `%{s | ...}`, `Map.put/3`, `Map.merge/2`, `struct/2` or `put_in/2` on a
      value matched as that struct in the same clause. Call a function on the
      struct's module instead. Reading fields and pattern matching are
      allowed; a `defimpl` for a struct is its own code. Test code is exempt
      by selection: select `lib` paths.

      ## Examples

      Avoid:
      ```elixir
      def start(%MyApp.Turn{} = turn), do: %{turn | status: :running}
      ```

      Prefer:
      ```elixir
      def start(%MyApp.Turn{} = turn), do: MyApp.Turn.start(turn)
      ```
      """
    ]

  @doc false
  def rule_type, do: :struct_owned_by_module

  # Thin Framework delegate: detection is the pure Domain module's.
  @doc false
  def detect_violations(_source_file, ast, rules, _context) do
    Anchor.Domain.Checks.StructOwnedByModule.detect_violations(ast, rules)
  end
end
