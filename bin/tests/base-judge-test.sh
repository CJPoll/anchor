#!/usr/bin/env bash
# Self-test for bin/ci/judge-with-base.sh and bin/ci/base-judge.sh (DND-5658),
# the CI step that judges a pull request with the anchor landed on its base.
#
#   bin/tests/base-judge-test.sh
#
# Run from anywhere inside an anchor checkout with deps fetched. It copies the
# checkout's tracked files, as they are in the working tree, into a throwaway
# git repo (branch main = the base) and plays pull requests against it:
#
#   T1 a ref that does not resolve: exit 3, COULD NOT MEASURE.
#   T2 a base with no bin/ci/base-judge.sh and a pull request that adds it:
#      exit 0, BOOTSTRAP, nothing built.
#   T10 a base with no bin/ci/base-judge.sh and a pull request that does not
#      add it (a branch cut before the judge, or the script deleted): exit 3.
#   T11 a pull request that removes a base rule (context_acyclic): exit 1,
#      the landed judge names the removed check.
#   T12 a pull request that adds a top-level section the landed judge does
#      not know: exit 3, COULD NOT MEASURE (the owner lands it).
#   T13 a pull request that downgrades a base rule (layering) to `enforcement:
#      report` and grows its baseline: the landed judge runs the base's
#      definition (enforce), so the GREW line fails it: exit 1.
#   T14 a pull request that adds a Managers-to-Framework call and widens the
#      calls matrix in its own .anchor.yml to allow it: the landed judge reads
#      the base's architecture, so layering finds the call: exit 1.
#   T3 a base whose bin/ci/base-judge.sh is a symlink: exit 3, never followed.
#   T4 a base whose anchor does not compile: exit 3, never a pass.
#   T5 the sabotage: a pull request that edits Enforcement to drop STALE and
#      GREW findings, adds a line to the layering baseline, and makes its own
#      bin/ci/base-judge.sh exit 0. Its own `mix anchor.graph --base main`
#      passes (the hole this closes); the landed judge fails it, naming the
#      GREW line.
#   T6 the positive control: an honest pull request (a README line) passes
#      the landed judge.
#   T7 a pull request that adds a rule of a type the landed judge does not
#      know: exit 0, with a FIRST LANDING line naming it (its own --base step
#      judges it).
#   T8 a pull request that does not compile: exit 3, before any judge is built.
#   T9 stale beams: a pull request built once (as a restored CI cache holds
#      _build), then renaming its app so its compile writes elsewhere: the
#      old beams are deleted first, so the judge reads none and the run is not
#      a pass.
#
# T4-T14 build anchor from scratch in throwaway worktrees (several minutes).
# BASE_JUDGE_TEST_ONLY="T2 T5" runs only those cases (sabotage runs); CI runs
# every case. Exit 0 when every case it ran holds, 1 otherwise.
#
# Sabotage record: test/sabotage_records/base_judge-20261103-dnd_5658_ci_base_ratchet.md
# And: test/sabotage_records/base_judge-20261106-dnd_5658_ci_base_ratchet.md (T14)
set -uo pipefail

here=$(cd "$(dirname "$0")/../.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/anchor-base-judge-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

failures=0
only=${BASE_JUDGE_TEST_ONLY:-}
ran=0
want() {
  if [ -z "$only" ] || [[ " $only " == *" $1 "* ]]; then
    ran=$((ran + 1))
    return 0
  fi
  return 1
}
pass() { echo "ok   $1"; }
fail() {
  echo "FAIL $1" >&2
  failures=$((failures + 1))
}

# expect NAME WANT_STATUS WANT_TEXT STATUS OUTPUT_FILE
expect() {
  local name=$1 want=$2 text=$3 got=$4 out=$5
  if [ "$got" -ne "$want" ]; then
    fail "$name: exit $got, wanted $want; output:"
    sed 's/^/    /' "$out" >&2
  elif ! grep -qF -- "$text" "$out"; then
    fail "$name: output lacks: $text; output:"
    sed 's/^/    /' "$out" >&2
  else
    pass "$name"
  fi
}

repo="$work/repo"
mkdir -p "$repo"
(cd "$here" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$repo"
git -C "$repo" init -q -b main
git -C "$repo" config user.email self-test@example.invalid
git -C "$repo" config user.name base-judge-self-test
git -C "$repo" add -A
git -C "$repo" commit -qm "base"

# A pull request: a worktree of a new branch off `from`, with the caller's
# deps (gitignored, so not in the copy).
pull_request() {
  local name=$1 from=$2
  git -C "$repo" worktree add -q -b "$name" "$work/$name" "$from"
  if [ -d "$here/deps" ]; then cp -a "$here/deps" "$work/$name/deps"; fi
  echo "$work/$name"
}

# A base branch off main, changed by the command in $2 and committed.
base_branch() {
  local name=$1 change=$2 dir="$work/$1"
  git -C "$repo" worktree add -q -b "$name" "$dir" main
  (cd "$dir" && eval "$change" && git add -A && git commit -qm "$name")
}

entry() { (cd "$1" && bash bin/ci/judge-with-base.sh "$2") >"$3" 2>&1; }

if want T1; then
  pr=$(pull_request t1 main)
  entry "$pr" no-such-ref "$work/t1.out"
  expect "T1 an unresolvable ref is COULD NOT MEASURE" 3 \
    "COULD NOT MEASURE: no-such-ref" $? "$work/t1.out"
fi

if want T2; then
  base_branch old-base "git rm -q bin/ci/base-judge.sh"
  pr=$(pull_request t2 main)
  entry "$pr" old-base "$work/t2.out"
  expect "T2 a base with no landed judge is BOOTSTRAP" 0 "BOOTSTRAP: old-base" $? "$work/t2.out"
  if [ -e "$pr/_build" ]; then fail "T2 bootstrap built something"; fi
fi

if want T3; then
  base_branch link-base \
    "rm bin/ci/base-judge.sh && ln -s judge-with-base.sh bin/ci/base-judge.sh"
  pr=$(pull_request t3 main)
  entry "$pr" link-base "$work/t3.out"
  expect "T3 a symlinked landed judge is COULD NOT MEASURE" 3 \
    "is not a regular file (mode 120000)" $? "$work/t3.out"
fi

if want T4; then
  base_branch broken-base "printf 'defmodule Broken do\n  def x, do:\nend\n' > lib/broken.ex"
  pr=$(pull_request t4 main)
  entry "$pr" broken-base "$work/t4.out"
  expect "T4 a base that does not compile is COULD NOT MEASURE" 3 \
    "the anchor landed on broken-base does not compile" $? "$work/t4.out"
fi

if want T5; then
  pr=$(pull_request t5 main)
  enforcement="$pr/lib/anchor/domain/enforcement.ex"
  perl -0pi -e 's/\{standing \+\+ stale_findings \+\+ base_findings\(entries, base, context\), held\}/{standing ++ Enum.take(stale_findings, 0) ++ Enum.take(base_findings(entries, base, context), 0), held}/' \
    "$enforcement"
  if ! grep -qF "Enum.take(stale_findings, 0)" "$enforcement"; then
    fail "T5 setup: the Enforcement sabotage did not apply (its line moved?)"
  fi
  echo "layering|SelfTest.Grown|entry" >>"$pr/.anchor/baselines/layering.txt"
  # The pull request's own copy of the judge script waves everything through:
  # only the copy landed on main may run.
  printf '#!/usr/bin/env bash\necho "base-judge: PASS (own copy)"\nexit 0\n' \
    >"$pr/bin/ci/base-judge.sh"
  (cd "$pr" && git commit -qam "sabotage: drop GREW, grow the baseline, pass the judge")

  (cd "$pr" && MIX_ENV=dev mix anchor.graph --base main) >"$work/t5-own.out" 2>&1
  expect "T5 the pull request's own judge passes its own sabotage (the hole)" 0 \
    "anchor.graph:" $? "$work/t5-own.out"

  entry "$pr" main "$work/t5.out"
  expect "T5 the landed judge refuses the grown baseline" 1 \
    "layering|SelfTest.Grown|entry was added to .anchor/baselines/layering.txt since main." \
    $? "$work/t5.out"
fi

if want T6; then
  pr=$(pull_request t6 main)
  echo "Self-test line." >>"$pr/README.md"
  (cd "$pr" && git commit -qam "an honest change")
  entry "$pr" main "$work/t6.out"
  expect "T6 an honest pull request passes the landed judge" 0 \
    "base-judge: PASS: the anchor landed on main passed" $? "$work/t6.out"
fi

if want T7; then
  pr=$(pull_request t7 main)
  perl -0pi -e 's/^rules:\n/rules:\n  - type: no_such_graph_rule\n    id: brand_new\n    paths: ["lib\/**\/*.ex"]\n/m' \
    "$pr/.anchor.yml"
  if ! grep -qF "no_such_graph_rule" "$pr/.anchor.yml"; then
    fail "T7 setup: the new rule was not added to .anchor.yml"
  fi
  (cd "$pr" && git commit -qam "a rule type the landed judge does not know")
  entry "$pr" main "$work/t7.out"
  expect "T7 a rule type new in the pull request is a FIRST LANDING, not a refusal" 0 \
    'NOTE: FIRST LANDING of rule 1 (id: "brand_new", no_such_graph_rule)' $? "$work/t7.out"
fi

if want T8; then
  pr=$(pull_request t8 main)
  printf 'defmodule Broken do\n  def x, do:\nend\n' >"$pr/lib/broken.ex"
  (cd "$pr" && git add -A && git commit -qm "a pull request that does not compile")
  entry "$pr" main "$work/t8.out"
  expect "T8 a pull request that does not compile is COULD NOT MEASURE" 3 \
    "does not compile under MIX_ENV=dev" $? "$work/t8.out"
  if grep -qF "judging $pr" "$work/t8.out"; then fail "T8 built the judge first"; fi
fi

if want T9; then
  pr=$(pull_request t9 main)
  (cd "$pr" && MIX_ENV=dev mix compile) >"$work/t9-build.out" 2>&1 ||
    fail "T9 setup: the pull request did not build at main"
  if [ ! -d "$pr/_build/dev/lib/anchor/ebin" ]; then fail "T9 setup: no prebuilt ebin"; fi
  perl -0pi -e 's/app: :anchor,/app: :anchor_renamed,/' "$pr/mix.exs"
  if ! grep -qF "app: :anchor_renamed," "$pr/mix.exs"; then fail "T9 setup: app not renamed"; fi
  (cd "$pr" && git commit -qam "the compile writes elsewhere")
  entry "$pr" main "$work/t9.out"
  status=$?
  if [ "$status" -eq 0 ]; then
    fail "T9 the judge passed on stale beams; output:"
    sed 's/^/    /' "$work/t9.out" >&2
  else
    expect "T9 stale beams are never read: the judge measures nothing" 3 \
      "COULD NOT MEASURE" "$status" "$work/t9.out"
  fi
fi

if want T10; then
  if ! git -C "$repo" rev-parse --verify --quiet old-base >/dev/null; then
    base_branch old-base "git rm -q bin/ci/base-judge.sh"
  fi
  pr=$(pull_request t10 old-base)
  echo "Self-test line." >>"$pr/README.md"
  (cd "$pr" && git commit -qam "a change on a base with no landed judge")
  entry "$pr" old-base "$work/t10.out"
  expect "T10 no landed judge and none added is COULD NOT MEASURE" 3 \
    "has no bin/ci/base-judge.sh and this pull request does not add one" $? "$work/t10.out"
fi

if want T11; then
  pr=$(pull_request t11 main)
  perl -0pi -e 's/  - type: context_acyclic\n    id: context_acyclic\n.*?\n\n/\n/s' "$pr/.anchor.yml"
  if grep -qF "id: context_acyclic" "$pr/.anchor.yml"; then
    fail "T11 setup: the context_acyclic rule was not removed"
  fi
  (cd "$pr" && git commit -qam "remove a base rule")
  entry "$pr" main "$work/t11.out"
  expect "T11 a removed base rule fails the landed judge" 1 \
    'rule "context_acyclic" (context_acyclic) is in .anchor.yml at main and not in this change' \
    $? "$work/t11.out"
fi

if want T12; then
  pr=$(pull_request t12 main)
  printf 'brand_new_section:\n  enabled: true\n' >>"$pr/.anchor.yml"
  (cd "$pr" && git commit -qam "a top-level section the landed judge does not know")
  entry "$pr" main "$work/t12.out"
  expect "T12 an unknown top-level section is COULD NOT MEASURE" 3 \
    "COULD NOT MEASURE: the judge exited 3" $? "$work/t12.out"
fi

if want T13; then
  pr=$(pull_request t13 main)
  perl -0pi -e 's/(    id: layering\n)/$1    enforcement: report\n/' "$pr/.anchor.yml"
  if ! grep -qF "enforcement: report" "$pr/.anchor.yml"; then
    fail "T13 setup: the layering rule was not downgraded"
  fi
  echo "layering|SelfTest.Grown|entry" >>"$pr/.anchor/baselines/layering.txt"
  (cd "$pr" && git commit -qam "downgrade a base rule and grow its baseline")
  entry "$pr" main "$work/t13.out"
  expect "T13 a downgraded base rule is judged as the base defines it" 1 \
    "layering|SelfTest.Grown|entry was added to .anchor/baselines/layering.txt since main." \
    $? "$work/t13.out"
fi

if want T14; then
  pr=$(pull_request t14 main)
  cat >"$pr/lib/anchor/check/self_test_pure.ex" <<'ELIXIR'
defmodule Anchor.Check.SelfTestPure do
  @moduledoc false
  def one, do: 1
end
ELIXIR
  cat >"$pr/lib/anchor/managers/self_test_leak.ex" <<'ELIXIR'
defmodule Anchor.Managers.SelfTestLeak do
  @moduledoc false
  def one, do: Anchor.Check.SelfTestPure.one()
end
ELIXIR
  perl -pi -e 's/^    managers: \[managers, adapters, domain\]$/    managers: [managers, adapters, domain, framework]/' "$pr/.anchor.yml"
  if ! grep -qF "managers: [managers, adapters, domain, framework]" "$pr/.anchor.yml"; then
    fail "T14 setup: the calls matrix was not widened"
  fi
  (cd "$pr" && git add -A && git commit -qm "a forbidden call, allowed by a wider calls matrix")
  entry "$pr" main "$work/t14.out"
  expect "T14 a widened calls matrix is judged by the base's architecture" 1 \
    '(id: "layering", layering) Anchor.Managers.SelfTestLeak' \
    $? "$work/t14.out"
fi

if [ "$ran" -eq 0 ]; then
  echo "base-judge-test: COULD NOT MEASURE: BASE_JUDGE_TEST_ONLY=\"$only\" names no case" >&2
  exit 3
fi

if [ "$failures" -ne 0 ]; then
  echo "base-judge-test: $failures case(s) failed" >&2
  exit 1
fi
echo "base-judge-test: $ran case(s) passed${only:+ (only: $only)}"
