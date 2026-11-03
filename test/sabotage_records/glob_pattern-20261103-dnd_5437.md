# Sabotage record — globs with no literal character (DND-5437)

- **Domain:** glob_pattern
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GlobPattern.literal_free?/2`
- **Tests:** `test/anchor/domain/glob_pattern_test.exs` ("literal_free?/2"), and the literal-free `paths`/`pattern` rows of `architecture_checks_nothing_test.exs`
- **Suite run:** each mutation applied alone to 97cf553 and the command named under
  it run (`mix test <files>`), then the file restored with `git checkout --`.
  The full suite (`mix test`) was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 97cf553

## Fail-first

`literal_free?/2` is new.

`mix test test/anchor/domain/glob_pattern_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: `48 tests, 4 failures`.

```
  1) test literal_free?/2 (DND-5437) a path glob of only wildcards and slashes has no literal (Anchor.Domain.GlobPatternTest)
     test/anchor/domain/glob_pattern_test.exs:307
     ** (UndefinedFunctionError) function Anchor.Domain.GlobPattern.literal_free?/2 is undefined or private
     code: for glob <- ["*", "**", "**/*", "*/**", "**/**/*"],

  2) test literal_free?/2 (DND-5437) the separator is a literal for the other flavour (Anchor.Domain.GlobPatternTest)
     test/anchor/domain/glob_pattern_test.exs:324
     ** (UndefinedFunctionError) function Anchor.Domain.GlobPattern.literal_free?/2 is undefined or private
     code: refute GlobPattern.literal_free?("*.*", "/")
```


## Mutations

| # | Mutation | Result |
|---|---|---|
| M18 | literal_free?/2 ignores the separator (only bare wildcards count) | `84 tests, 6 failures` |

### M18: literal_free?/2 ignores the separator (only bare wildcards count)

- File mutated: `lib/anchor/domain/glob_pattern.ex`
- Command: `mix test test/anchor/domain/glob_pattern_test.exs test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `84 tests, 6 failures`

```
  1) test literal_free?/2 (DND-5437) a module glob of only wildcards and dots has no literal (Anchor.Domain.GlobPatternTest)
     test/anchor/domain/glob_pattern_test.exs:312
     *.*
     code: for glob <- ["*", "*.*", "**.*.*"], do: assert(GlobPattern.literal_free?(glob, "."), glob)
```
