# Sabotage record — the architecture: section, parsed fail-closed (DND-5437)

- **Domain:** architecture
- **Branch:** dnd-5437
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.Architecture.parse/1`, `Anchor.Domain.Architecture.Selector` (`parse/2`, `matches?/2`)
- **Tests:** `test/anchor/domain/architecture_checks_nothing_test.exs`, `test/anchor/domain/architecture/selector_test.exs`, and `test/anchor/domain/classification_test.exs` (which calls `Selector.matches?/2`: A2 goes red there too)
- **Suite run:** each mutation applied alone to 97cf553 and the command named under
  it run (`mix test <files>`), then the file restored with `git checkout --`.
  The full suite (`mix test`) was green before and after.
- **Merge base:** `origin/main` = 185ecc9; **fix commit:** 97cf553

## Fail-first

The modules are new in this run.

`mix test test/anchor/domain/architecture_checks_nothing_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: the test file does not compile.

```
** (UndefinedFunctionError) function Anchor.Domain.Architecture.key_paths/0 is undefined (module Anchor.Domain.Architecture is not available)
```

`mix test test/anchor/domain/architecture/selector_test.exs` against 185ecc9's `lib/` (and README) with this branch's tests: `15 tests, 15 failures`.

```
  1) test parse/2 keys/0 lists the five selector keys (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:108
     ** (UndefinedFunctionError) function Anchor.Domain.Architecture.Selector.keys/0 is undefined (module Anchor.Domain.Architecture.Selector is not available)
     code: assert Selector.keys() == ~w(behaviour exports_function paths pattern uses_module)

  2) test matches?/2 with paths a recursive glob matches a file nested under it (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:23
     ** (UndefinedFunctionError) function Anchor.Domain.Architecture.Selector.matches?/2 is undefined (module Anchor.Domain.Architecture.Selector is not available)
     code: assert Selector.matches?({:paths, ["lib/**/domain/**/*.ex"]}, @facts)
```


A1: with the "no row" refusal gone, the bucket is still refused (its row reads as `nil`, "must be a list"), but with a message naming the wrong fault; the table row asserts the message's leading key path, so it fails. A6 adds a key the parser would read with no table: the meta-tests fail. M5 covers both `buckets[].role` and `extract_pure_regions_from` (they share `parse_role/2`).

## Mutations

| # | Mutation | Result |
|---|---|---|
| A1 | drop the 'bucket with no calls row' refusal | `36 tests, 1 failure` |
| A2 | paths selectors non-recursive | `28 tests, 7 failures` |
| A3 | accept a match-all pattern selector | `36 tests, 3 failures` |
| A4 | min_modules accepts 0 | `36 tests, 1 failure` |
| A5 | unknown key of the section accepted | `36 tests, 1 failure` |
| A6 | a new section key with no table | `37 tests, 3 failures` |
| A7 | an unknown scope suffix reads as :any | `36 tests, 1 failure` |
| A8 | contexts.depth accepts 0 | `36 tests, 1 failure` |
| A9 | interfaces.exports accepts any non-blank string (a glob) | `36 tests, 1 failure` |
| A10 | duplicate bucket names accepted | `36 tests, 1 failure` |
| M1 | uses_module selector never matches | `15 tests, 1 failure` |
| M2 | behaviour selector never matches | `15 tests, 1 failure` |
| M3 | exports_function selector never matches | `15 tests, 1 failure` |
| M4 | pattern selector never matches | `15 tests, 1 failure` |
| M5 | any role (and any extract_pure_regions_from entry) accepted | `36 tests, 4 failures` |
| M6 | infer accepts a string | `36 tests, 1 failure` |
| M7 | any non-blank effects token accepted | `36 tests, 1 failure` |
| M9 | interfaces.buckets accepts an unknown bucket | `36 tests, 1 failure` |
| M10 | an empty select list accepted | `36 tests, 1 failure` |
| M11 | uses_module selector accepts any string | `36 tests, 2 failures` |
| M12 | behaviour selector accepts any string | `36 tests, 2 failures` |
| M14 | a literal-free paths glob (**) accepted | `36 tests, 2 failures` |
| M15 | roots that is not a list reads as none | `36 tests, 1 failure` |
| M16 | extract_pure_regions_from that is not a list reads as the default | `36 tests, 1 failure` |
| M17 | interfaces accepts an unknown key | `36 tests, 1 failure` |
| M19 | contexts accepts an unknown key | `36 tests, 1 failure` |
| M20 | a calls row may name an unknown bucket | `36 tests, 1 failure` |
| M21 | a bucket name may hold any character | `36 tests, 1 failure` |
| M22 | a selector entry with two keys reads the first | `36 tests, 2 failures` |

### A1: drop the 'bucket with no calls row' refusal

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     calls / a bucket with no row: wrong message (want it to start with "architecture.calls has no row for bucket \"managers\"" and hold Fix:): architecture.calls.managers must be a list of buckets, got: nil. Fix: list the buckets it may call, e.g. [domain, "managers:other_context"] ([] for none)
     code: assert failures == [], Enum.join(failures, "\n")
```

### A2: paths selectors non-recursive

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture/selector_test.exs test/anchor/domain/classification_test.exs`
- Result: `28 tests, 7 failures`

```
  1) test classify/2 a module listed in interfaces.exports is an interface module (Anchor.Domain.ClassificationTest)
     test/anchor/domain/classification_test.exs:114
     match (=) failed
     code:  assert {:ok, %Classification{bucket: "domain", interface?: true}} =
              Classification.classify(facts(MyApp.Accounts.Api, "lib/a/domain/api.ex"), arch)
     left:  {:ok, %Anchor.Domain.Classification{bucket: "domain", interface?: true}}
     right: {:error, {:unclassified, MyApp.Accounts.Api}}
```

### A3: accept a match-all pattern selector

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 3 failures`

```
  1) test buckets[].select[].pattern: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].select[].pattern / a match-all *: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     buckets[].select[].pattern / a match-all **: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     buckets[].select[].pattern / a match-all *.*: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A4: min_modules accepts 0

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test buckets[].min_modules: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].min_modules / 0: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A5: unknown key of the section accepted

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test architecture: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     architecture / unknown key bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A6: a new section key with no table

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `37 tests, 3 failures`

```
  1) test every key path has a table with a refused row and an accepted row (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:61
     ** (FunctionClauseError) no function clause matching in Anchor.Domain.ArchitectureChecksNothingTest.table/1

     The following arguments were given to Anchor.Domain.ArchitectureChecksNothingTest.table/1:

         # 1
         "strict"

     code: for key_path <- Architecture.key_paths() do
```

### A7: an unknown scope suffix reads as :any

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     calls / an unknown scope suffix: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A8: contexts.depth accepts 0

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test contexts.depth: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     contexts.depth / 0: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 0, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A9: interfaces.exports accepts any non-blank string (a glob)

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test interfaces.exports: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     interfaces.exports / a glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     interfaces.exports / a match-all glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     interfaces.exports / an Erlang module: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     interfaces.exports / blank: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     interfaces.exports / lower case: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### A10: duplicate bucket names accepted

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test buckets[].name: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].name / duplicate: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M1: uses_module selector never matches

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture/selector_test.exs`
- Result: `15 tests, 1 failure`

```
  1) test matches?/2 with uses_module a module that uses the named module matches (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:56
     Expected truthy, got false
     code: assert Selector.matches?({:uses_module, GenServer}, facts(uses: [Ecto.Schema, GenServer]))
     arguments:

         # 1
         {:uses_module, GenServer}

         # 2
         %{
           exports: [],
           module: MyApp.Domain.X,
           behaviours: [],
           uses: [Ecto.Schema, GenServer],
           app: :my_app,
           source_file: "lib/a/domain/x/y.ex"
         }
```

### M2: behaviour selector never matches

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture/selector_test.exs`
- Result: `15 tests, 1 failure`

```
  1) test matches?/2 with behaviour a module declaring the behaviour matches (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:66
     Expected truthy, got false
     code: assert Selector.matches?({:behaviour, Supervisor}, facts(behaviours: [Supervisor]))
     arguments:

         # 1
         {:behaviour, Supervisor}

         # 2
         %{
           exports: [],
           module: MyApp.Domain.X,
           behaviours: [Supervisor],
           uses: [],
           app: :my_app,
           source_file: "lib/a/domain/x/y.ex"
         }
```

### M3: exports_function selector never matches

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture/selector_test.exs`
- Result: `15 tests, 1 failure`

```
  1) test matches?/2 with exports_function a module exporting name/arity matches (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:76
     Expected truthy, got false
     code: assert Selector.matches?(
             {:exports_function, {:__aggregate__, 0}},
             facts(exports: [__aggregate__: 0])
           )
     arguments:

         # 1
         {:exports_function, {:__aggregate__, 0}}

         # 2
         %{
           exports: [__aggregate__: 0],
           module: MyApp.Domain.X,
           behaviours: [],
           uses: [],
           app: :my_app,
           source_file: "lib/a/domain/x/y.ex"
         }
```

### M4: pattern selector never matches

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture/selector_test.exs`
- Result: `15 tests, 1 failure`

```
  1) test matches?/2 with exports_function a module exporting name/arity matches (Anchor.Domain.Architecture.SelectorTest)
     test/anchor/domain/architecture/selector_test.exs:76
     Expected truthy, got false
     code: assert Selector.matches?(
             {:exports_function, {:__aggregate__, 0}},
             facts(exports: [__aggregate__: 0])
           )
     arguments:

         # 1
         {:exports_function, {:__aggregate__, 0}}

         # 2
         %{
           exports: [__aggregate__: 0],
           module: MyApp.Domain.X,
           behaviours: [],
           uses: [],
           app: :my_app,
           source_file: "lib/a/domain/x/y.ex"
         }
```

### M5: any role (and any extract_pure_regions_from entry) accepted

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 4 failures`

```
  1) test the parsed struct bucket/2 and bucket_names/1 read the buckets in file order (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:129
     match (=) failed
     code:  assert %Bucket{role: :managers} = Architecture.bucket(architecture, "managers")
     left:  %Anchor.Domain.Architecture.Bucket{role: :managers}
     right: %Anchor.Domain.Architecture.Bucket{
              name: "managers",
              role: :domain,
              selectors: [pattern: "*.Managers.*"],
              min_modules: 1,
              infer: true
            }
```

### M6: infer accepts a string

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test buckets[].infer: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].infer / "yes": LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M7: any non-blank effects token accepted

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test effects: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     effects / "Req.": LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     effects / "Mod.fun/x": LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     effects / a glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M9: interfaces.buckets accepts an unknown bucket

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test interfaces.buckets: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     interfaces.buckets / an unknown bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M10: an empty select list accepted

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test buckets[].select: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].select / []: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M11: uses_module selector accepts any string

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 2 failures`

```
  1) test roots[].uses_module: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     roots[].uses_module / blank: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     roots[].uses_module / a glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     roots[].uses_module / an Erlang module: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M12: behaviour selector accepts any string

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 2 failures`

```
  1) test roots[].behaviour: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     roots[].behaviour / a glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M14: a literal-free paths glob (**) accepted

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 2 failures`

```
  1) test roots[].paths: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     roots[].paths / a match-all ["**"]: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     roots[].paths / a match-all **/* beside a real glob: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     roots[].paths / a match-all *: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M15: roots that is not a list reads as none

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test roots: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     roots / not a list: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M16: extract_pure_regions_from that is not a list reads as the default

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test extract_pure_regions_from: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     extract_pure_regions_from / not a list: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M17: interfaces accepts an unknown key

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test interfaces: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     interfaces / unknown key bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M19: contexts accepts an unknown key

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test contexts: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     contexts / unknown key dept: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M20: a calls row may name an unknown bucket

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test calls: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     calls / an unknown target bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     calls / a suffix on an unknown bucket: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}, ...], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M21: a bucket name may hold any character

- File mutated: `lib/anchor/domain/architecture.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 1 failure`

```
  1) test buckets[].name: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].name / uppercase Domain: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     buckets[].name / digits: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```

### M22: a selector entry with two keys reads the first

- File mutated: `lib/anchor/domain/architecture/selector.ex`
- Command: `mix test test/anchor/domain/architecture_checks_nothing_test.exs`
- Result: `36 tests, 2 failures`

```
  1) test buckets[].select: every refusal is refused with its key path and Fix:, positives load (Anchor.Domain.ArchitectureChecksNothingTest)
     test/anchor/domain/architecture_checks_nothing_test.exs:52
     buckets[].select / an entry with two selector keys: LOADED: %Anchor.Config{rules: [], path: nil, architecture: %Anchor.Domain.Architecture{context_depth: 2, buckets: [%Anchor.Domain.Architecture.Bucket{...}], ...}}
     code: assert failures == [], Enum.join(failures, "\n")
```
