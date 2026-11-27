#!/usr/bin/env bash
# build.sh [target...]
# build.sh --judge CONFIG
# build.sh --check-sandbox
#
# Builds this goal inside a sandbox, and keeps nothing that an answer's build wrote.
#
# Why. The files in Proofs/ and Cuts/ are other people's answers. Lean lets a file run code while it
# is built, so building an answer is running a stranger's code, on a machine that may hold your keys.
# Proving Ground refuses an answer that runs code while it builds, but no such rule is complete for
# Lean, least of all in a goal with dependencies. So:
#
#   - Build answers here, and never with a bare `lake build`. A bare `lake build` in this repository
#     builds only the maintainers' library, for that reason.
#   - Do not open a file from Proofs/ or Cuts/ in an editor. The editor elaborates the file to show
#     it to you, outside any sandbox, and that runs it.
#
# What the sandbox is. No network, a read-only system, an empty home, and a process space of its
# own. It is used in two steps.
#
#   1. The library. The maintainers' own library is built first, by itself, into the goal's real
#      .lake directory. In this step Proofs/ and Cuts/ are hidden: the sandbox shows them as empty
#      directories, so no answer can be built here whatever the lakefile says, and a library that
#      imports an answer fails to build. Lake also writes a few small files into the dependencies
#      the first time it builds on them, and this is when it does.
#   2. The answers. For the challenges, the answers and the cuts the goal is read-only, its .lake
#      directory and its dependencies included. The one directory a build can write is a throwaway
#      one, put where .lake/build would be and deleted when this script ends. It starts as a copy
#      of what step 1 built. So a build cannot change a dependency, or anything that a later
#      command outside the sandbox would read.
#
# With no argument it builds everything: the library, then the challenges, the answers and the
# cuts. To try an answer of your own, put it in Proofs/ and name its module: build.sh Proofs.<id>
#
# With --judge it judges one answer. CONFIG is a file for Lean's own judge, `lake comparator`, and
# the judge runs inside step 2's sandbox, in a throwaway build directory of its own. The judge has
# a sandbox of its own, and it is switched off here because this one is stricter: the judge's lets
# a build write all of .lake. Each answer is judged by a separate call, so no answer is judged in
# a directory that another answer's build could write.
#
# With --check-sandbox it builds nothing, and fails unless the sandbox of step 2 is really in force.
#
# The arguments given to the sandbox are the ones the Proving Ground checker uses, which are the
# ones Lean's own judge uses. Needs bubblewrap, which means Linux. On another system, build inside
# a container or a virtual machine. Fetch a goal's dependencies and their build cache before you
# build any answer: that step needs the network, and it runs the dependencies' own code.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v bwrap > /dev/null || { echo "bubblewrap (bwrap) is not installed. Do not fall back to a bare lake build for answers you did not write."; exit 2; }
lean="$(lean --print-prefix)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$root/.lake/build" "$work/build"

sandbox() {
  # The arguments before `--` say what can be written, and what is hidden. The rest is the command.
  local extra=()
  while [ "$1" != "--" ]; do extra+=("$1"); shift; done
  shift
  bwrap --ro-bind / / --tmpfs /home --tmpfs /root --tmpfs /run/user --tmpfs /tmp --dir /tmp/home \
    --dev /dev --proc /proc --clearenv --tmpfs /run --tmpfs /var \
    --ro-bind "$root" "$root" --ro-bind "$lean" "$lean" "${extra[@]}" \
    --setenv PATH "$lean/bin:/usr/bin:/bin" --setenv LEAN_ABORT_ON_PANIC 1 --setenv HOME /tmp/home \
    --unshare-all --die-with-parent --new-session --chdir "$root" -- "$@"
}
library() {
  # Step 1: the real .lake can be written, and the answers cannot be seen.
  local hide=()
  for d in Proofs Cuts; do
    if [ -d "$root/$d" ]; then hide+=(--tmpfs "$root/$d"); fi
  done
  sandbox --bind "$root/.lake" "$root/.lake" "${hide[@]}" -- "$@"
}
inside() {
  # Step 2: nothing of the goal can be written but a throwaway build directory.
  sandbox --bind "$work/build" "$root/.lake/build" -- "$@"
}

if [ "${1:-}" = "--check-sandbox" ]; then
  # Each line must fail or differ outside a sandbox, so this check can fail.
  inside bash -c '
    set -u
    if touch probe-in-the-goal 2> /dev/null; then echo "the goal can be written"; exit 1; fi
    if touch .lake/probe 2> /dev/null; then echo ".lake can be written outside its build directory"; exit 1; fi
    if [ -d .lake/packages ] && touch .lake/packages/probe 2> /dev/null; then echo "the dependencies can be written"; exit 1; fi
    if [ "$HOME" != /tmp/home ]; then echo "the home directory is the machine own"; exit 1; fi
    if [ "$(cat /proc/1/comm)" != bwrap ]; then echo "process 1 is $(cat /proc/1/comm)"; exit 1; fi
    if command -v curl > /dev/null && curl -sS --max-time 8 -o /dev/null https://github.com 2> /dev/null; then echo "the network can be reached"; exit 1; fi
    touch .lake/build/sandbox-probe || { echo "the build directory cannot be written"; exit 1; }
    echo "the sandbox is in force: a read-only goal and dependencies, a home that is not the machine own, a process space of its own, no network"'
  if [ -e "$root/.lake/build/sandbox-probe" ]; then echo "what the sandbox wrote reached the goal's own build directory"; exit 1; fi
  echo "and nothing it wrote reached the goal's own build directory"
  # In step 1 the answers must not be there to build.
  library bash -c '
    for d in Proofs Cuts; do
      if [ -d "$d" ] && [ -n "$(ls -A "$d")" ]; then echo "the first step can see the files in $d"; exit 1; fi
    done
    echo "and the first step cannot see an answer"'
  exit $?
fi

library lake build
cp -a "$root/.lake/build/." "$work/build/"

if [ "${1:-}" = "--judge" ]; then
  config="${2:?--judge needs a configuration file for the judge}"
  cp "$config" "$work/build/judge.json"
  inside lake comparator --paranoid --inadvisably-no-sandbox --config .lake/build/judge.json
  exit $?
fi

if [ "$#" -gt 0 ]; then
  inside lake build "$@"
else
  libs=()
  for d in Problems Proofs Cuts; do
    if compgen -G "$root/$d/*.lean" > /dev/null; then libs+=("$d"); fi
  done
  if [ "${#libs[@]}" -gt 0 ]; then inside lake build "${libs[@]}"; fi
fi
echo "built inside the sandbox; the library is in .lake/build, and nothing an answer wrote while it was built was kept"
