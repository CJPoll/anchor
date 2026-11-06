# Sabotage record — the application closure loaded before any test (DND-5690)

- **Domain:** test_preload
- **Branch:** dnd-5690-preload
- **Date:** 2026-11-06
- **Code under test:** `Anchor.TestPreload` (`test/support/test_preload.ex`) and its call in `test/test_helper.exs`
- **Suite run:** `mix test --timeout 2000 --max-cases 2 <the file or files in the table>`, each mutation applied
  alone and restored byte-for-byte after its run, through `test-slot`.

Green with no mutation: `test/anchor/test_boot_test.exs` and `test/anchor/test_preload_test.exs` pass in the
run of `35 tests, 0 failures` over the changed test files.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `test_helper.exs` no longer calls `load!(:anchor)` | boot: every module of the closure is loaded | `2 tests, 1 failure` |
| B | `load!/1` ignores the result of `:code.ensure_modules_loaded/1` | load!/1: a module that cannot load refuses | `7 tests, 1 failure` |
| C | `load!/1` asks to load no modules | boot, and load!/1's two tests | `9 tests, 3 failures` |
| D | `closure/2` stops at the app itself (no transitive closure) | boot positive control, and five of the fixture tests | `9 tests, 6 failures` |
| E | `:included_applications` dropped from the closure | apps/1: an included entry alone is in the closure | `7 tests, 1 failure` |
| F | an optional dependency absent from the build is no longer subtracted | none ran: the helper refuses, naming the absent `:decimal` | no summary, exit 1 |
| G | a present optional dependency is left out of the closure | apps/1: optional absent skipped, present in | `7 tests, 1 failure` |
| H | `apps/1` returns no applications | boot positive control (the other boot test stays green: an empty closure leaves nothing unloaded, which is why the control exists) | `2 tests, 1 failure` |
| I | a required application that is not loaded reads as empty | apps/1: refuses by name | `7 tests, 1 failure` |
| J | `unloaded/1` reports nothing | load!/1: the dependency's module that nothing has called | `7 tests, 1 failure` |

## Failure strings (verbatim)

### A

```
  1) test every module of Anchor's closure is loaded before any test runs (Anchor.TestBootTest)
     test/anchor/test_boot_test.exs:11
     897 module(s) of Anchor's closure are not loaded, so a test loads them on demand through code_server: [Anchor, Anchor.Adapters.BaselineFile, Anchor.Adapters.BeamReader, Anchor.Adapters.BehaviourReader, Anchor.Adapters.CallTracer, Anchor.Adapters.ConfigFile, Anchor.Adapters.CoverageFile, Anchor.Adapters.GitChangeSource, Anchor.Adapters.GitEnv, Anchor.Adapters.GitShow]. Fix: call Anchor.TestPreload.load!(:anchor) in test/test_helper.exs before ExUnit.start/0.
     code: assert unloaded == [],
     stacktrace:
       test/anchor/test_boot_test.exs:14: (test)
```

### B

```
  1) test load!/1 a module that cannot load refuses by name and reason, with a Fix: line (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:71
     Expected exception RuntimeError but nothing was raised
     code: error = assert_raise RuntimeError, fn -> TestPreload.load!(@dep) end
     stacktrace:
       test/anchor/test_preload_test.exs:74: (test)
```

### C

```
  1) test every module of Anchor's closure is loaded before any test runs (Anchor.TestBootTest)
     test/anchor/test_boot_test.exs:11
     894 module(s) of Anchor's closure are not loaded, so a test loads them on demand through code_server: [Anchor, Anchor.Adapters.BaselineFile, Anchor.Adapters.BeamReader, Anchor.Adapters.BehaviourReader, Anchor.Adapters.CallTracer, Anchor.Adapters.ConfigFile, Anchor.Adapters.CoverageFile, Anchor.Adapters.GitChangeSource, Anchor.Adapters.GitEnv, Anchor.Adapters.GitShow]. Fix: call Anchor.TestPreload.load!(:anchor) in test/test_helper.exs before ExUnit.start/0.
     code: assert unloaded == [],
     stacktrace:
       test/anchor/test_boot_test.exs:14: (test)
```

### D

```
  1) test the closure it checks holds Anchor, its dependencies and what they need (Anchor.TestBootTest)
     test/anchor/test_boot_test.exs:23
     Assertion with == failed
     code:  assert [:anchor, :bunt, :credo, :kernel] -- apps == []
     left:  [:bunt, :credo, :kernel]
     right: []
     stacktrace:
       test/anchor/test_boot_test.exs:27: (test)
```

### E

```
  1) test apps/1 an :included_applications entry alone is in the closure (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:91
     Assertion with in failed
     code:  assert @extra in TestPreload.apps(@host)
     left:  :anchor_fixture_preload_extra
     right: [:anchor_fixture_preload_host, :kernel, :stdlib]
     stacktrace:
       test/anchor/test_preload_test.exs:95: (test)
```

### F

The helper's own refusal, before any test: `mix test` exits 1 with no summary. A real optional dependency of
this build (`:decimal`) is absent, so the unmutated subtraction is load-bearing on every run.

```
** (ArgumentError) application :decimal is not loaded, so its modules cannot be listed. Fix: load it before preloading (Application.load(:decimal)), or check the name: it must be an application in this build.
    (anchor 0.1.0) test/support/test_preload.ex:108: Anchor.TestPreload.spec!/2
    (anchor 0.1.0) test/support/test_preload.ex:79: Anchor.TestPreload.closure/2
    (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
    (anchor 0.1.0) test/support/test_preload.ex:33: Anchor.TestPreload.apps/1
    (anchor 0.1.0) test/support/test_preload.ex:45: Anchor.TestPreload.load!/1
    test/test_helper.exs:6: (file)
```

### G

```
  1) test apps/1 an optional dependency absent from this build is skipped; a present one is in (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:98
     Assertion with in failed
     code:  assert @dep in apps
     left:  :anchor_fixture_preload_dep
     right: [:anchor_fixture_preload_host, :kernel, :stdlib]
     stacktrace:
       test/anchor/test_preload_test.exs:108: (test)
```

### H

```
  1) test the closure it checks holds Anchor, its dependencies and what they need (Anchor.TestBootTest)
     test/anchor/test_boot_test.exs:23
     Assertion with == failed
     code:  assert [:anchor, :bunt, :credo, :kernel] -- apps == []
     left:  [:anchor, :bunt, :credo, :kernel]
     right: []
     stacktrace:
       test/anchor/test_boot_test.exs:27: (test)
```

### I

```
  1) test apps/1 a required application that is not loaded refuses by name, never reads as empty (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:112
     Expected exception ArgumentError but nothing was raised
     code: error = assert_raise ArgumentError, fn -> TestPreload.apps(@host) end
     stacktrace:
       test/anchor/test_preload_test.exs:115: (test)
```

### J

```
  1) test load!/1 loads a dependency's module that nothing has called, and says how much it loaded (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:51
     Assertion with == failed
     code:  assert TestPreload.unloaded(@host) == [module]
     left:  []
     right: [AnchorFixtures.TestPreloadTest.Dep]
     stacktrace:
       test/anchor/test_preload_test.exs:59: (test)
```

## Rows that stayed green

- Under H, `every module of Anchor's closure is loaded` stays green: that test alone cannot tell an empty closure
  from a loaded one. The positive control beside it is what fails.
- Under A, the positive control stays green: it reads the closure, not what is loaded.

## Traps

- `:application.load/1` takes a repeated key's first value, so the fixture's `props` come before its defaults.
  Written the other way round, `modules: []` won and every module list was empty.
- No test forces `Enum.uniq/1` out of `modules/1` beyond `modules/1`'s own table row; no mutation was run on it.
