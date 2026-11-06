# Sabotage record — the application closure loaded before any test (DND-5690)

- **Domain:** test_preload
- **Branch:** dnd-5690-preload
- **Date:** 2026-11-06
- **Code under test:** `Anchor.TestPreload` (`test/support/test_preload.ex`) and its call in `test/test_helper.exs`
- **Suite run:** `mix test --timeout 2000 --max-cases 2` over `test/anchor/test_boot_test.exs` (rows A, H),
  `test/anchor/test_preload_test.exs` (B, E, F, G, I, J, K, L, F2) or both (C, D, M), each mutation applied alone and
  restored byte-for-byte after its run, through `test-slot`. Line numbers are those of the run's own commit.

Green with no mutation: these two files pass in the run of `35 tests, 0 failures` over them,
`call_tracer_test.exs`, `sabotage_coverage_test.exs` and `test/mix/tasks/anchor_sabotage_coverage_test.exs`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `test_helper.exs` no longer calls `load!(:anchor)` | boot: every module of the closure is loaded | `2 tests, 1 failure` |
| B | `load!/1` ignores the result of `:code.ensure_modules_loaded/1` | load!/1: a module that cannot load refuses | `7 tests, 1 failure` |
| C | `load!/1` asks to load no modules | boot, and load!/1's two tests | `9 tests, 3 failures` |
| D | `closure/2` stops at the app itself (no transitive closure) | boot positive control; load!/1's first test; all four apps/1 tests | `9 tests, 6 failures` |
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

  2) test load!/1 a module that cannot load refuses by name and reason, with a Fix: line (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:71
     Expected exception RuntimeError but nothing was raised
     code: error = assert_raise RuntimeError, fn -> TestPreload.load!(@dep) end
     stacktrace:
       test/anchor/test_preload_test.exs:74: (test)

  3) test load!/1 loads a dependency's module that nothing has called, and says how much it loaded (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:51
     Assertion with == failed
     code:  assert TestPreload.unloaded(@host) == [module]
     left:  [AnchorFixtures.TestPreloadTest.Dep, :application_starter,
             :argparse, :array, :auth, :base64, :calendar, :dets,
             :dets_server, :dets_sup, :dets_utils, :dets_v9, :dict,
             :disk_log, :disk_log_1, :disk_log_server,
             :disk_log_sup, :dist_ac, :dist_util, :edlin_context,
             :edlin_expand, :edlin_type_suggestion,
             :erl_abstract_code, :erl_boot_server, :erl_compile,
             :erl_compile_server, :erl_ddll, :erl_debugger,
             :erl_epmd, :erl_error, :erl_erts_errors,
             :erl_expand_records, :erl_kernel_errors, :erl_pp,
             :erl_reply, :erl_stdlib_errors, :erl_tar,
             :error_logger_file_h, :error_logger_tty_h, :erts_debug,
             :escript, :file_sorter, :gen_fsm, :gen_sctp,
             :gen_tcp_socket, :gen_udp, :gen_udp_socket,
             :global_search, :group_history, :inet6_sctp,
             :inet6_tcp, :inet6_tcp_dist, :inet6_udp, :inet_dns,
             :inet_dns_tsig, :inet_epmd_dist, :inet_epmd_socket,
             :inet_hosts, :inet_res, :inet_sctp, :inet_tcp_dist,
             :io_lib_fread, :json, :local_tcp, :local_udp,
             :log_mf_h, :logger_disk_log_h, :logger_handler, :math,
             :ms_transform, :net, :net_adm, :pg, :pg2, :pool, :qlc,
             :qlc_pt, :ram_file, :random, :raw_file_io_compressed,
             :raw_file_io_deflate, :raw_file_io_delayed,
             :raw_file_io_inflate, :raw_file_io_list, :seq_trace,
             :shell, :shell_default, :shell_docs,
             :shell_docs_markdown, :shell_docs_test, :slave,
             :socket, :sys, :trace, :uri_string, :win32reg,
             :wrap_log_reader, :zip, :zstd]
     right: [AnchorFixtures.TestPreloadTest.Dep]
     stacktrace:
       test/anchor/test_preload_test.exs:59: (test)
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

  2) test apps/1 a required application that is not loaded refuses by name, never reads as empty (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:112
     Expected exception ArgumentError but nothing was raised
     code: error = assert_raise ArgumentError, fn -> TestPreload.apps(@host) end
     stacktrace:
       test/anchor/test_preload_test.exs:115: (test)

  3) test load!/1 loads a dependency's module that nothing has called, and says how much it loaded (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:51
     Assertion with == failed
     code:  assert TestPreload.unloaded(@host) == [module]
     left:  []
     right: [AnchorFixtures.TestPreloadTest.Dep]
     stacktrace:
       test/anchor/test_preload_test.exs:59: (test)

  4) test apps/1 an optional dependency absent from this build is skipped; a present one is in (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:98
     Assertion with in failed
     code:  assert @dep in apps
     left:  :anchor_fixture_preload_dep
     right: [:anchor_fixture_preload_host]
     stacktrace:
       test/anchor/test_preload_test.exs:108: (test)

  5) test apps/1 follows :applications and :included_applications, sorted and each once (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:83
     Assertion with == failed
     code:  assert TestPreload.apps(@host) == Enum.sort([@host, @dep, @extra, :kernel, :stdlib])
     left:  [:anchor_fixture_preload_host]
     right: [:anchor_fixture_preload_dep, :anchor_fixture_preload_extra,
             :anchor_fixture_preload_host, :kernel, :stdlib]
     stacktrace:
       test/anchor/test_preload_test.exs:88: (test)

  6) test apps/1 an :included_applications entry alone is in the closure (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:91
     Assertion with in failed
     code:  assert @extra in TestPreload.apps(@host)
     left:  :anchor_fixture_preload_extra
     right: [:anchor_fixture_preload_host]
     stacktrace:
       test/anchor/test_preload_test.exs:95: (test)
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

## Second run: `modules/1` and an assertion the first run never reached

The review round found `modules/1`'s test had no red, and that no row reached the `modules` half of the boot
positive control or the `refute` in the optional-dependency test.

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| K | `modules/1` keeps duplicates | modules/1: sorted and each once | `7 tests, 1 failure` |
| L | `modules/1` does not sort | modules/1: sorted and each once | `7 tests, 1 failure` |
| M | `modules/1` returns no modules | boot positive control at `:30`, load!/1's two tests, modules/1 | `9 tests, 4 failures` |
| F2 | F, with the helper's `load!` also removed so tests run | apps/1: optional absent skipped (it raises, on the fixture's absent application) | `7 tests, 1 failure` |

### Failure strings (verbatim)

### K

```
  1) test modules/1 every listed application's modules, sorted and each once (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:123
     Assertion with == failed
     code:  assert TestPreload.modules([@dep, @extra]) == Enum.sort([@dep_module, @extra_module, @no_beam])
     left:  [AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Extra,
             AnchorFixtures.TestPreloadTest.NoBeam]
     right: [AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Extra,
             AnchorFixtures.TestPreloadTest.NoBeam]
     stacktrace:
       test/anchor/test_preload_test.exs:127: (test)
```

### L

```
  1) test modules/1 every listed application's modules, sorted and each once (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:123
     Assertion with == failed
     code:  assert TestPreload.modules([@dep, @extra]) == Enum.sort([@dep_module, @extra_module, @no_beam])
     left:  [AnchorFixtures.TestPreloadTest.NoBeam,
             AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Extra]
     right: [AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Extra,
             AnchorFixtures.TestPreloadTest.NoBeam]
     stacktrace:
       test/anchor/test_preload_test.exs:127: (test)
```

### M

```
  1) test the closure it checks holds Anchor, its dependencies and what they need (Anchor.TestBootTest)
     test/anchor/test_boot_test.exs:23
     Assertion with == failed
     code:  assert [Anchor.Managers.Lint, Bunt, Credo, :gen_server] -- modules == []
     left:  [Anchor.Managers.Lint, Bunt, Credo, :gen_server]
     right: []
     stacktrace:
       test/anchor/test_boot_test.exs:30: (test)

  2) test load!/1 a module that cannot load refuses by name and reason, with a Fix: line (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:71
     Expected exception RuntimeError but nothing was raised
     code: error = assert_raise RuntimeError, fn -> TestPreload.load!(@dep) end
     stacktrace:
       test/anchor/test_preload_test.exs:74: (test)

  3) test load!/1 loads a dependency's module that nothing has called, and says how much it loaded (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:51
     Assertion with == failed
     code:  assert TestPreload.unloaded(@host) == [module]
     left:  []
     right: [AnchorFixtures.TestPreloadTest.Dep]
     stacktrace:
       test/anchor/test_preload_test.exs:59: (test)

  4) test modules/1 every listed application's modules, sorted and each once (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:123
     Assertion with == failed
     code:  assert TestPreload.modules([@dep, @extra]) == Enum.sort([@dep_module, @extra_module, @no_beam])
     left:  []
     right: [AnchorFixtures.TestPreloadTest.Dep,
             AnchorFixtures.TestPreloadTest.Extra,
             AnchorFixtures.TestPreloadTest.NoBeam]
     stacktrace:
       test/anchor/test_preload_test.exs:127: (test)
```

### F2

```
  1) test apps/1 an optional dependency absent from this build is skipped; a present one is in (Anchor.TestPreloadTest)
     test/anchor/test_preload_test.exs:98
     ** (ArgumentError) application :anchor_fixture_preload_extra is not loaded, so its modules cannot be listed. Fix: load it before preloading (Application.load(:anchor_fixture_preload_extra)), or check the name: it must be an application in this build.
     code: apps = TestPreload.apps(@host)
     stacktrace:
       (anchor 0.1.0) test/support/test_preload.ex:111: Anchor.TestPreload.spec!/2
       (anchor 0.1.0) test/support/test_preload.ex:82: Anchor.TestPreload.closure/2
       (elixir 1.19.4) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
       (anchor 0.1.0) test/support/test_preload.ex:36: Anchor.TestPreload.apps/1
       test/anchor/test_preload_test.exs:106: (test)
```

### Rows that stayed green

- Under F2 the `refute @extra in apps` line is never reached: the closure raises on the absent application first,
  which is the louder form of the same failure.
