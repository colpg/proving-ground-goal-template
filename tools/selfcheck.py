#!/usr/bin/env python3
"""selfcheck.py [--no-sandbox]

Judges every answer in this repository against its challenge with Lean's own judge,
`lake comparator --paranoid`, and fails unless every one is accepted.

It first checks that the challenge files match the manifests, then asks make_challenges.py for the
list of jobs: one per file in Proofs/ and Cuts/. An answer counts as accepted only when the judge
exits with 0 AND prints its closing line; an exit code alone is not believed.

Each answer is judged by a call of its own to tools/build.sh --judge. That runs the judge inside a
sandbox in which the goal and its dependencies are read-only, and the one thing a build can write
is a throwaway directory. So no answer is judged in a directory that another answer's build could
write, and nothing an answer's build wrote is left in this repository. The judge's own sandbox is
not used for this: it lets a build write all of .lake, and the next answer's judge would then run
`lake` on what was left there.

With --no-sandbox the judge runs here with no sandbox at all. That is only for files you wrote
yourself, on a machine where the sandbox cannot start. Continuous integration never does it.

Runs tools/build.sh, which needs bubblewrap; writes judge_jobs.json and one temporary file. Needs
Python 3.11 and Lean 4.35 or later."""
import json, os, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
BARE = "--no-sandbox" in sys.argv[1:]
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
    judge = ["lake", "comparator", "--paranoid", "--inadvisably-no-sandbox", "--config", cfg] if BARE else ["bash", os.path.join("tools", "build.sh"), "--judge", cfg]
    r = subprocess.run(judge, capture_output=True, text=True)
    os.unlink(cfg)
    out = r.stdout + r.stderr
    ok = r.returncode == 0 and "Your solution is okay!" in out
    lines = [l for l in out.split("\n") if l.strip() and not l.startswith("Exporting")]
    tell = next((l for l in lines if l.startswith("error:") or "bwrap" in l), lines[-1] if lines else "")
    print("%-8s %-42s %3.0fs  %s" % ("accepted" if ok else "REFUSED", j["label"], time.time() - t0, "" if ok else "exit %d: %s" % (r.returncode, tell[:120])), flush=True)
    bad += not ok
print("%d of %d answers accepted" % (len(jobs) - bad, len(jobs)))
sys.exit(1 if bad else 0)
