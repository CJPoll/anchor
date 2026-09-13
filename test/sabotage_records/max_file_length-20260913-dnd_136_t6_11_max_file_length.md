# Sabotage record — MaxFileLength detection extracted to Domain (BUG 2 consumer)

- **Domain:** max_file_length
- **Branch:** dnd-136-t6-11-max-file-length
- **Date:** 2026-09-13
- **MR:** (T6.11 / DND-136) https://github.com/CJPoll/anchor — `gh pr create --base main`
- **Code under test:** `Anchor.Domain.Checks.MaxFileLength.detect_violations/4` (the pure Domain detector; the `Anchor.Check.MaxFileLength` shell acquires lines via `Anchor.Check.Source` and delegates to it)
- **Suite run:** `mix test test/anchor/check/max_file_length_test.exs test/anchor/domain/checks/max_file_length_test.exs`

T6.11 (DND-136) extracted the detection out of the `Anchor.Check.MaxFileLength`
Framework shell into the pure `Anchor.Domain.Checks.MaxFileLength` module
(`count_code_lines` / `is_code_line?` / doc-range extraction / `get_max_lines` /
message building). It also closes BUG 2: the maximum is now read from the
**atom** key `:max_lines` that T3 (`Anchor.Config.parse_rule/1`) surfaces, not
the string key `"max_lines"` the parsed rule never carries. Each mutation below
was applied to the Domain module, the suite re-run, the code restored via
`git checkout` (the implementation was committed first). Failure strings are
verbatim, including `left:` / `right:`.

Matrix rows: `test/anchor/check/max_file_length_test.exs` rows #1–9 (the
`check_file/3` acceptance matrix); `test/anchor/domain/checks/max_file_length_test.exs`
exercises the pure detector directly.

| # | Mutation | Tests failed | Failure string (verbatim excerpt) |
|---|----------|--------------|-----------------------------------|
| A | **BUG 2 revert** — read the maximum from the string key instead of the atom key (`Map.get(rule, :max_lines)` → `Map.get(rule, "max_lines")`), so every configured `max_lines` falls back to the 400 default | 10 (shell #3,#5,#6,#7,#8,#9 + domain flag/atom-key/count/@doc-false rows) | domain `reads :max_lines from the atom key`: `code: assert [%Violation{}] = detect(module_with_defs(10), %{type: :max_file_length, max_lines: 10})` `left: [%Anchor.Domain.Violation{}]` `right: []`; shell #3: `code: assert [issue] = issues` `left: [issue]` `right: []` |
| B | **Strictly-greater → `>=`** (`code_line_count > max_lines` → `code_line_count >= max_lines`) | 6 (shell #2,#5,#6,#8 + domain default-boundary,count,@doc-false boundaries) | shell #2 (exactly 400): `code: assert [] == check(module_with_defs(398), %{type: :max_file_length})` `left: []` `right: [%Credo.Issue{... message: "File contains 400 lines of code (maximum allowed: 400)...", ...}]`; domain default boundary: `code: assert detect(module_with_defs(398), %{type: :max_file_length}) == []` `left: [%Anchor.Domain.Violation{... message: "File contains 400 lines of code (maximum allowed: 400)..."}]` `right: []` |
| C | **Default 400 → 500** (`@default_max_lines 400` → `@default_max_lines 500`) | 2 (shell #1 + domain default) | shell #1: `code: assert [issue] = issues` `left: [issue]` `right: []`; domain default: `code: assert [%Violation{message: message}] = detect(module_with_defs(399), %{type: :max_file_length})` `left: [%Anchor.Domain.Violation{message: message}]` `right: []` |
| D | **Count blank/whitespace lines** (`trimmed == "" -> false` → `trimmed == "" -> true`) | 4 (shell #5,#7 + domain count,@doc-false) | shell #5: `code: assert [] == check(text, %{type: :max_file_length, max_lines: 3})` `left: []` `right: [%Credo.Issue{... message: "File contains 53 lines of code (maximum allowed: 3)...", ...}]`; shell #7 message: `left: "File contains 6 lines of code (maximum allowed: 2)..."` `right: "File contains 3 lines of code (maximum allowed: 2)"` |
| E | **Corrupt the trigger** (`trigger: filename` → `trigger: "wrong-" <> filename`; keeps the binding live so the suite still compiles under `--warnings-as-errors`) | 2 (shell #1 + domain flag row) | domain: `code: assert violation.trigger == "lib/big.ex"` `left: "wrong-lib/big.ex"` `right: "lib/big.ex"`; shell #1: `code: assert issue.trigger == @filename` `left: "wrong-lib/my_app/some_module.ex"` `right: "lib/my_app/some_module.ex"` |
| F | **Report line 2 instead of 1** (`line: 1` → `line: 2`) | 2 (shell #1 + domain flag row) | domain: `code: assert violation.line == 1` `left: 2` `right: 1`; shell #1: `code: assert issue.line_no == 1` `left: 2` `right: 1` |
| G | **Count full-line `#` comments** (`String.starts_with?(trimmed, "#") -> false` → `... -> true`) | 3 (shell #6,#9 + domain count) | shell #6: `code: assert [] == check(text, %{type: :max_file_length, max_lines: 3})` `left: []` `right: [%Credo.Issue{... message: "File contains 33 lines of code (maximum allowed: 3)...", ...}]`; shell #9 message: `left: "File contains 37 lines of code (maximum allowed: 5)..."` `right: "File contains 12 lines of code (maximum allowed: 5)"` |
| H | **Disable @moduledoc/@doc/@typedoc range collection** (`when doc_type in [:moduledoc, :doc, :typedoc] ->` → `when doc_type in [:none_such] ->`, so heredoc bodies are counted as code) | 2 (shell #7 + domain count) | shell #7: `code: assert [] == check(text, %{type: :max_file_length, max_lines: 10})` `left: []` `right: [%Credo.Issue{... message: "File contains 15 lines of code (maximum allowed: 10)...", ...}]` |

## What each mutation proves

- **A** is the BUG 2 fix itself: the maximum must be read from the atom key T3
  surfaces. Reverting to the string key discards every configured `max_lines`,
  so each small file falls back to the 400 default and no longer triggers. The
  domain `reads :max_lines from the atom key` test is the discriminating pair —
  the atom-keyed rule flags, the same-value string-keyed rule does not.
- **B** protects the strictly-greater boundary — row #2 (exactly 400 → `[]`) and
  every boundary-tight exclusion row (#5/#6/#8 assert `[]` at the exact code-line
  count) go red because equal now flags.
- **C** protects the 400 default value: only the two default-path rows (#1 and
  the domain default test) depend on it.
- **D / G / H** protect the three exclusion classes — blank/whitespace lines,
  full-line `#` comments, and `@moduledoc`/`@doc`/`@typedoc` heredoc bodies. Each
  reddens both the boundary `[]` rows and the message-count rows (#9's `12 lines
  of code`), which is why the message carries the code-line count per ADR 002.
- **E / F** protect the two remaining violation fields — `trigger` (the filename)
  and `line` (always 1).

## Trap encountered (ADR 002 catalogue)

The first attempt at **E** set `trigger: nil` directly, which left the `filename`
argument of `build_violation/3` unused. Under this project's
`--warnings-as-errors` compile that is a **compile failure**, not a test failure:
`mix test` printed `variable "filename" is unused ... Compilation failed due to
warnings while using the --warnings-as-errors option` and ran zero tests. A
mutation that stops the suite compiling proves nothing about the tests; the
re-done mutation (`"wrong-" <> filename`) keeps the binding live so the suite
runs and the trigger assertions are what fail.

## Measured zeros

None. Every mutation reddened at least one row. Each asserted property of the
9-row matrix — over/at/under both the 400 default and a configured maximum, the
three exclusion classes (blank, comment, doc-body) plus `@doc false`, the
code-line count carried in the message, and the `line`/`trigger` fields — is
protected by at least one mutation above.

## Note on the inherited doc-range approximation

`extract_doc_range/2` over-approximates a heredoc's span by one line
(`base_line + lines_in_doc + 1`), inherited unchanged from the pre-refactor
shell. In row #7 this over-extended range can swallow the first code line
immediately after a heredoc's closing delimiter, so the test source places a
blank line between the `@doc` heredoc close and the following `def`. This keeps
the real code-line count exact (3) without changing the inherited behavior;
tightening the approximation is out of scope for this extraction ticket.
