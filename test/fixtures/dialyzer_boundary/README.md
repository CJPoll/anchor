# Dialyzer boundary fixtures (DND-5499)

A spike, not a feature. It measures what Dialyzer already reports about clause
reachability, so F8 (`clause_reachability`, DND-5501) reports only what Dialyzer
misses. Nothing here is compiled by `mix`, and nothing ships in `lib/`.

## Run

```bash
elixir test/fixtures/dialyzer_boundary/run.exs
```

No Mix project, no network, about 1.5 s. The runner compiles only these
fixtures (plus the generated `Widened<N>` modules) into a fresh temporary
directory, runs Dialyzer on only those beams through the public
`:dialyzer.run/1`, and removes the directory. Dialyzer refuses to run without a
PLT (`plts: []` falls back to the default PLT file), so the runner builds one
from `erts` only, inside the temporary directory, capped at 60 s (it took
under 1 s). It never builds an OTP or Elixir PLT and never analyses a whole
repo.

It prints Dialyzer's warnings verbatim per module ("no warnings" for a module
with none), the Elixir compiler's warnings per module, the versions and the PLT
route, and one verdict line per claim. It exits 1 when it could not measure
(a missing fixture, a compile failure, zero beams, a Dialyzer error, the PLT
cap): an empty run never reads as "no warnings anywhere". A claim whose
positive control is missing reads COULD NOT MEASURE, never CONFIRMED.

## Fixtures

| File | Module | Shows |
|---|---|---|
| `exported.ex` | `AnchorSpike.Exported`, `AnchorSpike.Caller` | claim 1: an exported clause no caller reaches (`kind(:c)`) |
| `private.ex` | `AnchorSpike.Private` | claim 2: the same clause in a `defp`; the positive control for claim 1 |
| `widened.ex` | `AnchorSpike.Widened20` | claim 3: a `defp` called with 20 distinct atoms plus a `:never` clause no call reaches |
| (generated) | `AnchorSpike.Widened3` .. `Widened19` | claim 3's sweep, from the same template (`AnchorSpike.Runner.widened_source/1`); the runner refuses to run if `widened.ex` drifts from it |
| `dropped.ex` | `AnchorSpike.Dropped` | claim 4: a parameter passed down and dropped |

DND-5501 reuses `exported.ex` and `widened.ex` as its "Dialyzer passes, F8
flags" fixtures.

## Verdict (2026-11-03, OTP 28.2, Elixir 1.19.4, Dialyzer 5.4)

| Claim | Verdict | Evidence |
|---|---|---|
| 1. An exported clause no caller reaches is not reported | CONFIRMED | `AnchorSpike.Exported: no warnings` |
| 2. The same clause in a private function is reported | CONFIRMED | `private.ex:11:8: The pattern 'c' can never match the type 'a' \| 'b'` |
| 3. A large atom union is widened to `atom()` | CONFIRMED, limit 14 | `:never` reported for N = 3..13, not reported for N = 14..20 |
| 4. No absence analysis | CONFIRMED | `AnchorSpike.Dropped: no warnings` |

The limit: Dialyzer keeps a union of up to 13 atoms; at 14 distinct atoms the
call-site type is `atom()` and the `:never` clause stops being reported.

Found beside the claims: the Elixir 1.19 compiler itself warns `this clause of
defp kind/1 is never used` on the private unreachable clause at every N,
including N = 14..20 where Dialyzer is silent. It does not warn on the exported
`kind(:c)`. So for a private function called with literal values, the compiler
already covers what Dialyzer widens away; this spike did not measure private
functions called with non-literal values.
