#!/usr/bin/env bash
# CI's entry to the base branch's judge (DND-5658). Run from the root of the
# pull request's checkout:
#
#   bin/ci/judge-with-base.sh REF
#
# It runs bin/ci/base-judge.sh AS IT IS ON REF, never this checkout's copy, so
# a change to the judge's code in lib/ (or to the script that builds and runs
# it) is judged by the landed code, not by itself. This file and
# .github/workflows/ci.yml are the pull request's own (GitHub runs the pull
# request's workflow), so a pull request that edits them is not caught here:
# review is the gate for those. Keep this file to finding and starting the
# landed copy.
#
# Bootstrap: a REF that has no bin/ci/base-judge.sh predates the separated
# judge (the pull request that adds it is the only one). That prints a
# BOOTSTRAP line and exits 0; the pull request's own `mix anchor.graph --base`
# step still judges it. Once the script is on REF, every later pull request is
# judged by REF's copy.
#
# Exit codes: base-judge.sh's own (0, 1, 3); 0 with BOOTSTRAP as above; 3
# COULD NOT MEASURE when REF does not resolve, its tree cannot be listed, or
# its bin/ci/base-judge.sh is not a regular file (a symlink is never
# followed).
set -uo pipefail

could_not_measure() {
  echo "judge-with-base: COULD NOT MEASURE: $1" >&2
  echo "judge-with-base: Fix: $2" >&2
  exit 3
}

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "usage: bin/ci/judge-with-base.sh REF" >&2
  could_not_measure "no base ref given" "pass the base branch, e.g. origin/main"
fi

ref=$1
script=bin/ci/base-judge.sh

sha=$(git rev-parse --verify --quiet --end-of-options "${ref}^{commit}") ||
  could_not_measure "$ref does not resolve to a commit" \
    "fetch the base branch first (git fetch origin <base>)"

listing=$(git ls-tree "$sha" -- "$script") ||
  could_not_measure "could not list $script at $ref ($sha)" "check the checkout's git objects"

if [ -z "$listing" ]; then
  echo "judge-with-base: BOOTSTRAP: $ref ($sha) has no $script, so no landed judge exists" \
    "yet; this pull request is judged by its own mix anchor.graph --base step only."
  exit 0
fi

mode=${listing%% *}
case "$mode" in
  100644 | 100755) ;;
  *) could_not_measure "$script at $ref is not a regular file (mode $mode)" \
       "land $script on $ref as a regular file" ;;
esac

scratch=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/anchor-judge-entry.XXXXXX") ||
  could_not_measure "no scratch directory" "check TMPDIR"
trap 'rm -rf "$scratch"' EXIT

git cat-file blob "$sha:$script" >"$scratch/base-judge.sh" ||
  could_not_measure "could not read $script at $ref" "check the checkout's git objects"

bash "$scratch/base-judge.sh" "$ref"
