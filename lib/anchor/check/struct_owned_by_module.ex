defmodule Anchor.Check.StructOwnedByModule do
  use Anchor.Check.Base,
    detector: Anchor.Domain.Checks.StructOwnedByModule,
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
end
