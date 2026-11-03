#!/usr/bin/env bash
# The base branch's judge (DND-5658). Run from the root of a checkout (the
# pull request), it judges that checkout with the Anchor landed on REF:
#
#   bin/ci/base-judge.sh REF
#
# CI never runs the pull request's copy of this file: bin/ci/judge-with-base.sh
# runs the copy landed on REF. It:
#
#   1. resolves REF to a commit in this checkout;
#   2. compiles this checkout under MIX_ENV=dev (the judged beams), after
#      deleting its old anchor beams, so the judge never reads beams an
#      earlier build left (a cached _build) when this compile wrote elsewhere;
#   3. checks REF out in a scratch worktree (the judge; git hooks off) and
#      builds it there, its deps fetched from REF's own mix.lock (never this
#      checkout's deps/);
#   4. runs the judge's `mix anchor.graph --project <this checkout> --base REF`.
#
# So every rule, Enforcement, Baseline, BaselineBase and each rule's narrows?/2
# that judge the pull request's lib/ are the base's code, and the pull
# request's beams, .anchor.yml and baselines are what is judged.
#
# Not caught here (review is the gate): a pull request that edits CI itself
# (.github/workflows/ci.yml, bin/ci/judge-with-base.sh: GitHub runs the pull
# request's workflow), and build-time code a deliberately hostile pull request
# runs earlier in the same CI job. This guards the judge against a change to
# lib/, not against an attacker who controls the job.
#
# Exit codes: 0 the judge passed; 1 the judge found a violation (NEW, STALE,
# GREW, a floor, a fail-closed issue) or crashed (a Mix task that raises
# exits 1); 3 COULD NOT MEASURE: REF does not resolve, this checkout does not
# compile, the judge could not be checked out or built, or the judge exited
# with anything but 0 or 1 (its usage error or COULD NOT MEASURE). A judge
# that could not run is never a pass.
set -uo pipefail

# The app the judge reads, at its own compile path in this checkout. This
# script is anchor's own: the judged project is anchor.
app=anchor

could_not_measure() {
  echo "base-judge: COULD NOT MEASURE: $1" >&2
  echo "base-judge: Fix: $2" >&2
  exit 3
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: bin/ci/base-judge.sh REF" >&2
  could_not_measure "no base ref given" "pass the base branch, e.g. origin/main"
fi

ref=$1
pr=$(pwd -P)

sha=$(git -C "$pr" rev-parse --verify --quiet --end-of-options "${ref}^{commit}") ||
  could_not_measure "$ref does not resolve to a commit in $pr" \
    "fetch the base branch first (git fetch origin <base>)"

rm -rf "$pr/_build/dev/lib/$app" ||
  could_not_measure "could not delete the old beams in $pr/_build/dev/lib/$app" \
    "check the permissions on $pr/_build"

(cd "$pr" && MIX_ENV=dev mix compile) ||
  could_not_measure "$pr does not compile under MIX_ENV=dev" "fix the compile error first"

scratch=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/anchor-base-judge.XXXXXX") ||
  could_not_measure "no scratch directory" "check TMPDIR"
judge="$scratch/judge"

cleanup() {
  git -C "$pr" worktree remove --force "$judge" >/dev/null 2>&1
  rm -rf "$scratch"
  git -C "$pr" worktree prune >/dev/null 2>&1
}
trap cleanup EXIT

git -C "$pr" -c core.hooksPath=/dev/null worktree add --detach --quiet "$judge" "$sha" ||
  could_not_measure "could not check out $ref ($sha) as the judge" \
    "check that $sha is present in this checkout"

echo "base-judge: judging $pr with the anchor landed on $ref ($sha)"

(cd "$judge" && MIX_ENV=dev mix deps.get) ||
  could_not_measure "mix deps.get failed in the judge ($ref)" "check the network and $ref's mix.lock"

(cd "$judge" && MIX_ENV=dev mix compile) ||
  could_not_measure "the anchor landed on $ref does not compile" \
    "fix the base branch; a judge that cannot be built judges nothing"

(cd "$judge" && MIX_ENV=dev mix anchor.graph --project "$pr" --base "$ref")
status=$?

case "$status" in
  0) echo "base-judge: PASS: the anchor landed on $ref passed $pr" ;;
  1) echo "base-judge: FAIL: the anchor landed on $ref refused $pr, or crashed on it; read its output above" >&2 ;;
  *) could_not_measure "the judge exited $status" \
       "read its output above; a change the landed judge cannot read is landed by the owner" ;;
esac

exit "$status"
