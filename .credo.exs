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

          # NOTE: Anchor's own checks (NoDependency, MustUseModule, ...) are
          # deliberately NOT enabled here. Credo validates the enabled-check
          # list while Anchor's own modules are not yet loaded (self-reference
          # chicken-and-egg), so listing them only yields "undefined check"
          # warnings; and without a `.anchor.yml` they would be no-ops anyway.
          # Consumers enable them via `.credo.example.exs`, where Anchor is a
          # loaded dependency.

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
