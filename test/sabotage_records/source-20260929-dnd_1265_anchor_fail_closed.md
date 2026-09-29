# Sabotage record — AST acquisition reports parse errors (DND-1265)

- **Domain:** source
- **Branch:** dnd-1265-anchor-fail-closed
- **Date:** 2026-09-29
- **Code under test:** `Anchor.Check.Source.ast/1` (`parse_error/1`, `line/1`,
  `error_text/2`)
- **Suite run:** `mix test` (the whole suite; 530 tests)
- **Merge base:** `origin/main` = 8cff72b
- **Sibling records (same run):** `config-`, `failures-`, `lint-`, `base-20260929-dnd_1265_anchor_fail_closed.md`

`source` is a new domain word: `Anchor.Check.Source`, the one module allowed to
call Credo's AST acquisition. Its rows live in the Lint and e2e test files,
which cite this record.

## Fail-first run

On 8cff72b, `Source.ast/1` returned `{:__block__, [], []}` for a file that does
not parse. The rows that prove the new `{:error, {line, message}}` shape are the
Lint and e2e unparseable rows; their fail-first strings are in the lint and base
records (`right: []`, and `left: "Module must use MyApp.Base"`).

## Mutations

| # | Mutation | Tests failed | Failure string |
|---|---|---|---|
| S | `line/1` returns `nil` for keyword error metadata | 2 | `Expected truthy, got false` / `code: assert is_integer(violation.line)`; e2e: `code: assert issue.line_no == 2` / `left: nil` / `right: 2` |
| W | drop the token from the parser's message | 1 | `code: assert issue.message =~ "unexpected reserved word: end"` / `left: "Anchor could not parse this file, so no Anchor rule was checked against it: unexpected reserved word: . Fix: correct the syntax error (\`mix compile\` reports it too)."` / `right: "unexpected reserved word: end"` |

W is also what Credo's own parse-error issue says: it keeps the parser's
message and drops the token (`unexpected reserved word: ` with no `end`). That
is why `Source.ast/1` re-derives the error from `Code.string_to_quoted/2` on the
failure path. On Elixir 1.19 the parser's position for a mismatched delimiter is
a keyword list (`[line: 2, column: 9, ...]`), not an integer; S covers that.

No measured zeros.

## Rows that stayed green, and why

- Under S and W, the rows asserting only `"could not parse"` and `"Fix:"` stay
  green: those words do not depend on the line or the token.
- `error_text/2`'s `{prefix, suffix}` clause has no row of its own. The Elixir
  1.19 parser returns a plain message for both fixtures used here, so no test
  reaches it. It is a formatting fallback, not a fail-closed path: a wrong text
  there still produces the issue.

## Traps

- Every run started from a committed tree; the driver restored each file with
  `git checkout -- <file>`, and `git status --short` was clean after each batch.
