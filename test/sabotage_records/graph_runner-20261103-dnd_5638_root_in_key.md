# Sabotage record — the project root is in the graph artifact's key (DND-5638)

- **Domain:** graph_runner
- **Branch:** dnd-5630-graph-hardening
- **Date:** 2026-11-03
- **Code under test:** `Anchor.Domain.GraphKey.key/5` (now root, beams, sources, config, version) and
  `Anchor.Managers.Graph` (`write_artifact/5`: the root it passes)
- **Suite run:** per mutation, `mix test --timeout 2000 --max-cases 2 test/anchor/domain/graph_key_test.exs
  test/anchor/managers/graph_test.exs`, each mutation applied alone and restored byte-for-byte (sha256
  compared) after its run.

The key covered the beams, the source facts, the config and the version, but not the root. The graph's
facts name source paths relative to the root, so two checkouts with the same build output shared a key while
their paths meant different files. The root is now the key's second framed part. It is the root's real
path as the task gives it: `File.cwd!/0` is `getcwd(3)`'s physical path, symlinks resolved by the kernel,
and the Manager passes it through `Path.expand/1` (a trailing slash or `..` keys the same). Domain does
no IO to resolve a symlink.

## The regression, on the unfixed code

The two files ran `42 tests, 12 failures`: the eleven `GraphKey` tests on the new `key/5`
(`UndefinedFunctionError ... key/5 is undefined or private. Did you mean: * key/4`) and the Manager's:

```
 12) test run/2 graph artifact the key changes with the project root (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:740
     Refute with == failed, both sides are exactly equal
     code: refute key.("/checkout-a") == key.("/checkout-b")
     left: "0839eb03d9608415835e7934bf5cac180b9c6acd15477e248c9d10ef044ef1c3"
```

After: the two files, the task test and the canary run `53 tests, 0 failures`.

## Mutations

| # | Mutation | Tests that failed | Run |
|---|---|---|---|
| A | `key/5` ignores the root | "the same inputs under different roots give different keys", the Manager's root test | `42 tests, 2 failures` |
| B | the root and the version are hashed unframed | "moving bytes between the root and the version changes the key" | `42 tests, 1 failure` |
| C | the Manager passes a constant root | the Manager's root test | `42 tests, 1 failure` |

B first survived: the framing test moved bytes so that the unframed concatenations still differed. It now
uses `("/work", "v1")` against `("work", "v1/")`, whose unframed `version <> root` is `v1/work` for both,
and B fails it.

## Failure strings (verbatim)

### A

```
  1) test root the same inputs under different roots give different keys (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:90
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key("/work/a", @entries, [], "c", "v") == GraphKey.key("/work/b", @entries, [], "c", "v")
     left: "5ca8004a98abf62affcf25b006a3811a2183e415a5a95834bca44c3a650e1119"
```

### B

```
  1) test root moving bytes between the root and the version changes the key (the root is framed) (Anchor.Domain.GraphKeyTest)
     test/anchor/domain/graph_key_test.exs:100
     Refute with == failed, both sides are exactly equal
     code: refute GraphKey.key("/work", [], [], "", "v1") == GraphKey.key("work", [], [], "", "v1/")
     left: "d60826c6091f3051d702910fe94b612aa358bbe3ceed5f70dc4d136d278b7c63"
```

### C

```
  1) test run/2 graph artifact the key changes with the project root (Anchor.Managers.GraphTest)
     test/anchor/managers/graph_test.exs:740
     Refute with == failed, both sides are exactly equal
     code: refute key.("/checkout-a") == key.("/checkout-b")
     left: "e286f6af3a45068580caa6caeb09e9a77951ca4c677be368825e147d09bea47e"
```
