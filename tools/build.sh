#!/usr/bin/env bash
# build.sh [target...]
# build.sh --check-sandbox
#
# Builds this goal inside a sandbox: no network, a read-only system, an empty home, and a process
# space of its own. Only the .lake directory can be written.
#
# Why. The files in Proofs/ and Cuts/ are other people's answers. Lean lets a file run code while it
# is built, so building an answer is running a stranger's code, on a machine that may hold your keys.
# Proving Ground refuses an answer that runs code while it builds, but no such rule is complete for
# Lean. So build answers here, and never with a bare `lake build`. A bare `lake build` in this
# repository builds only the maintainers' library, for that reason.
#
# With no argument it builds everything: the library, the challenges, the answers and the cuts.
# With --check-sandbox it builds nothing, and fails unless the sandbox is really in force.
#
# The arguments given to the sandbox are the ones the Proving Ground checker uses, which are the
# ones Lean's own judge uses. Needs bubblewrap, which means Linux. On another system, build inside
# a container or a virtual machine. Fetch a goal's dependencies and their build cache before you
# use this: that step needs the network, and the dependencies are trusted as far as the goal is.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v bwrap > /dev/null || { echo "bubblewrap (bwrap) is not installed. Do not fall back to a bare lake build for answers you did not write."; exit 2; }
lean="$(lean --print-prefix)"
mkdir -p "$root/.lake"

inside() {
  bwrap --ro-bind / / --tmpfs /home --tmpfs /root --tmpfs /run/user --tmpfs /tmp --dir /tmp/home \
    --dev /dev --proc /proc --clearenv --tmpfs /run --tmpfs /var \
    --ro-bind "$root" "$root" --ro-bind "$lean" "$lean" --bind "$root/.lake" "$root/.lake" \
    --setenv PATH "$lean/bin:/usr/bin:/bin" --setenv LEAN_ABORT_ON_PANIC 1 --setenv HOME /tmp/home \
    --unshare-all --die-with-parent --new-session --chdir "$root" -- "$@"
}

if [ "${1:-}" = "--check-sandbox" ]; then
  # Each line must fail or differ outside a sandbox, so this check can fail.
  inside bash -c '
    set -u
    if touch probe-outside-lake 2> /dev/null; then echo "the goal can be written"; exit 1; fi
    if [ "$HOME" != /tmp/home ]; then echo "the home directory is the machine own"; exit 1; fi
    if [ "$(cat /proc/1/comm)" != bwrap ]; then echo "process 1 is $(cat /proc/1/comm)"; exit 1; fi
    if command -v curl > /dev/null && curl -sS --max-time 8 -o /dev/null https://github.com 2> /dev/null; then echo "the network can be reached"; exit 1; fi
    touch .lake/sandbox-probe && rm .lake/sandbox-probe || { echo ".lake cannot be written"; exit 1; }
    echo "the sandbox is in force: a read-only goal, a home that is not the machine own, a process space of its own, no network"'
  exit $?
fi

if [ "$#" -gt 0 ]; then
  inside lake build "$@"
else
  inside lake build
  inside lake build Problems Proofs Cuts
fi
