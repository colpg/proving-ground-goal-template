#!/usr/bin/env python3
"""selfcheck.py [extra arguments for `lake comparator`]

Judges every answer in this repository against its challenge with Lean's own judge,
`lake comparator --paranoid`, and fails unless every one is accepted.

It first checks that the challenge files match the manifests, then asks make_challenges.py for the
list of jobs: one per file in Proofs/ and Cuts/. An answer counts as accepted only when the judge
exits with 0 AND prints its closing line; an exit code alone is not believed.

It works on a throwaway copy of this repository, and deletes the copy when it has finished. The
judge builds each answer in a sandbox, but that sandbox can write the goal's .lake directory, and
an answer's build could leave something there for the next command you run outside any sandbox.
Nothing the judge builds is left in your own copy. Pass --in-place to skip the copy, on a machine
that is thrown away afterwards.

On a machine where the judge's sandbox cannot start, and only for files you wrote yourself, pass
--inadvisably-no-sandbox. Continuous integration never does.

Runs `lake`; in the copy it writes judge_jobs.json and one temporary file. Needs Python 3.11 and
Lean 4.35 or later."""
import json, os, shutil, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if "--in-place" in sys.argv: sys.argv.remove("--in-place")
else:
    tmp = tempfile.mkdtemp(prefix="pg-selfcheck-"); copy = os.path.join(tmp, "goal")
    try:
        shutil.copytree(ROOT, copy, symlinks=True, ignore=shutil.ignore_patterns(".git"))
        r = subprocess.run([sys.executable, os.path.join(copy, "tools", "selfcheck.py"), "--in-place"] + sys.argv[1:])
    finally: shutil.rmtree(tmp, ignore_errors=True)
    sys.exit(r.returncode)
os.chdir(ROOT)
TOOL = [sys.executable, os.path.join("tools", "make_challenges.py")]
for step in (["--check"], ["--jobs", "judge_jobs.json"]):
    r = subprocess.run(TOOL + step)
    if r.returncode != 0: sys.exit("make_challenges.py %s failed" % step[0])
jobs = json.load(open("judge_jobs.json", encoding="utf-8"))
if not jobs: sys.exit("no answers to judge: that is a failure of this check, not a pass")
bad = 0
for j in jobs:
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({k: j[k] for k in ("challenge_module", "solution_module", "theorem_names", "permitted_axioms")}, f); cfg = f.name
    t0 = time.time()
    r = subprocess.run(["lake", "comparator", "--paranoid", "--config", cfg] + sys.argv[1:], capture_output=True, text=True)
    os.unlink(cfg)
    out = r.stdout + r.stderr
    ok = r.returncode == 0 and "Your solution is okay!" in out
    lines = [l for l in out.split("\n") if l.strip() and not l.startswith("Exporting")]
    tell = next((l for l in lines if l.startswith("error:") or "bwrap" in l), lines[-1] if lines else "")
    print("%-8s %-42s %3.0fs  %s" % ("accepted" if ok else "REFUSED", j["label"], time.time() - t0, "" if ok else "exit %d: %s" % (r.returncode, tell[:120])), flush=True)
    bad += not ok
print("%d of %d answers accepted" % (len(jobs) - bad, len(jobs)))
sys.exit(1 if bad else 0)
