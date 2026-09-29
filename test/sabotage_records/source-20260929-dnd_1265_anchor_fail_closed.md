# Sabotage record — AST acquisition reports parse errors (DND-1265)

- **Domain:** source
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Source.ast/1` (`parse_error/1`, `line/1`,
  `error_text/2`)
- **Suite run:** `mix test` (the whole suite, 530 tests)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `failures-`, `lint-`, `base-20260929-dnd_1265_anchor_fail_closed.md`

`source` is a new domain word: `Anchor.Check.Source`, the one module allowed to
call Credo's AST acquisition.

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| S | `line/1` returns `nil` for keyword error metadata | 2 | `Expected truthy, got false` / `code: assert is_integer(violation.line)`; e2e: `assert issue.line_no == 2` / `left: nil` / `right: 2` |
| W | drop the token from the parser's message | 1 | `assert issue.message =~ "unexpected reserved word: end"` / `left: "Anchor could not parse this file, so no Anchor rule was checked against it: unexpected reserved word: . Fix: correct the syntax error (\`mix compile\` reports it too)."` |

W is also what Credo's own parse-error issue says: it keeps the parser's
message and drops the token (`unexpected reserved word: ` with no `end`). That
is why `Source.ast/1` re-derives the error from `Code.string_to_quoted/2` on the
failure path. On Elixir 1.19 the parser's position for a mismatched delimiter is
a keyword list (`[line: 2, column: 9, ...]`), not an integer; S covers that.

No measured zeros.
