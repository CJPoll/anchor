# Credo configuration for the Anchor library itself.
#
# This is the real, project-local config (distinct from `.credo.example.exs`,
# which is the copy-paste template shipped to *consumers* of Anchor). It exists
# so that `mix credo --strict` is a meaningful, green gate for this repo.
#
# Scope note (ticket DND-121 / T1 "safety net"): T1 is a tests-and-config-only
# ticket and MUST NOT modify production modules. Several stricter Credo checks
# currently flag pre-existing style debt in `lib/` (missing @moduledoc tags,
# trailing whitespace, deep nesting, predicate-name conventions, etc.). Those
# checks are intentionally left OUT of the enabled set below rather than being
# satisfied by editing production code. A later cleanup ticket can re-enable
# them once `lib/` is groomed. Everything that the current tree already
# satisfies stays enabled so the gate keeps real signal.
#
# ----------------------------------------------------------------------------
# Self-check bootstrap (DND-139 / T8): put Anchor's OWN compiled beams on the
# code path so the `Anchor.Check.*` checks enabled below are dogfooded on
# Anchor's own tree.
#
# `mix credo` neither compiles the current project nor runs `loadpaths` for it,
# so the project's own ebin is NOT on the code path when Credo evaluates this
# file and validates the enabled-check list (`Code.ensure_compiled/1`). Without
# this, `Anchor.Check.NoDependency` / `MustUseModule` are silently dropped as
# "undefined checks". `.credo.exs` is `Code.eval_string`'d with full Elixir
# evaluation, so we append the already-compiled ebin (produced by the
# `mix compile` that precedes `mix credo` in the green-bar) — the real compiled
# modules with their full Domain closure, no source recompilation. Guarded on
# existence so a not-yet-compiled tree degrades to a dropped-check warning
# rather than a crash.
anchor_ebin = Path.join(["_build", to_string(Mix.env()), "lib", "anchor", "ebin"])
if File.dir?(anchor_ebin), do: Code.append_path(String.to_charlist(anchor_ebin))

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: true,
      color: true,
      checks: %{
        enabled: [
          # Consistency — the current tree already conforms to these.
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # Anchor's OWN architecture checks, dogfooded on Anchor's own tree
          # (ticket DND-139 / T8). Running `mix credo` inside this project
          # compiles `lib/` first, so the `Anchor.Check.*` modules are loaded
          # and available to Credo — the earlier "self-reference / undefined
          # check" concern does not materialize. The rules these read live in
          # `.anchor.yml` at the repo root:
          #
          #   * NoDependency  — Domain stays pure (Rules 1 & 2 in .anchor.yml).
          #   * MustUseModule — every check shell uses Anchor.Check.Base (Rule 3).
          #
          # Only the ARCHITECTURE checks are enabled. The STYLE checks
          # (SingleControlFlow, AlphabetizedFunctions, MaxFileLength,
          # CaseOnBareArg, NoComparisonInIf, NoDiscardingArrowInWith,
          # NoTupleMatchInHead, StructGetterConvention,
          # ModulePatternRestrictions, NoTransitiveDependency) are STAGED, not
          # enabled: Anchor's own `lib/` does not yet conform to all of them,
          # and T8 must not groom production modules to force compliance. A
          # later cleanup ticket can enable each style check once the tree
          # passes it. Consumers see the full menu in `.credo.example.exs`.
          #
          # CI note: anchor has no CI pipeline, so `mix credo --strict` (this
          # local gate) IS the enforcement point. Wiring these into an actual
          # CI job is a recommended owner follow-up, deferred here because no
          # pipeline exists to wire into.
          {Anchor.Check.NoDependency, []},
          {Anchor.Check.MustUseModule, []},

          # Readability — checks the current tree already satisfies.
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.MaxLineLength, [max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.WithSingleClause, []},

          # Refactoring opportunities the current tree already satisfies.
          {Credo.Check.Refactor.DoubleBooleanNegation, []},
          {Credo.Check.Refactor.FilterReject, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MapMap, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.RejectReject, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},

          # Warnings — genuine-bug catchers; keep all the tree already passes.
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.IExPry, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.OperationOnSameValues, []},
          {Credo.Check.Warning.OperationWithConstantResult, []},
          {Credo.Check.Warning.RaiseInsideRescue, []},
          {Credo.Check.Warning.SpecWithStruct, []},
          {Credo.Check.Warning.UnsafeExec, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedFileOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedPathOperation, []},
          {Credo.Check.Warning.UnusedRegexOperation, []},
          {Credo.Check.Warning.UnusedStringOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []},
          {Credo.Check.Warning.WrongTestFileExtension, []}
        ],
        disabled: [
          # Deferred pending a `lib/` style-cleanup ticket (see scope note
          # above); T1 must not touch production modules to satisfy them.
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.FilterFilter, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []}
        ]
      }
    }
  ]
}
