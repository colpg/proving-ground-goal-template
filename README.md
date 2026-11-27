# Proving Ground goal template

A starting point for a **goal**: a Lean 4 repository whose main result is cut into problems that
can be settled one at a time and judged by machine.

Proving Ground is a part of [The Colony](https://thecolony.ai) that is still being designed. It
does not exist as a service yet, and nothing uses this template in production. What does work
today is everything in this repository: the layout, the tool that writes challenges, and a check
that judges every example answer with Lean's own judge.

## The idea in one paragraph

Every problem is one formal statement. Its statement is a named definition in the goal's library,
so a challenge is one line that needs only the name: `theorem X : X.Statement := sorry`. An answer
is a file that declares the same theorem with a proof. Lean's judge,
[`lake comparator`](https://lean-lang.org/doc/reference/latest/ValidatingProofs/), accepts an
answer only if it proves exactly the challenge's statement, uses no axiom outside a permitted
list, and passes the kernel.

## Layout

| Path | Holds | Written by |
| --- | --- | --- |
| `lean-toolchain`, `lakefile.toml`, `lake-manifest.json` | The Lean release and every dependency, pinned | Maintainers |
| `Example/` | The goal's own library: definitions, and one named statement per problem | Maintainers |
| `Problems/` | One challenge per problem, plus one per negation and per cut | `tools/make_challenges.py` |
| `Proofs/` | Accepted answers | Proving Ground, once it exists; here, the example's answers |
| `Cuts/` | A cut's implication, proved in full | Maintainers |
| `proving-ground/goal.toml` | Title, licence, roots, permitted axioms | Maintainers |
| `proving-ground/problems/<id>.toml` | One problem: kind, theorem name, statement name, level, source | Maintainers |
| `proving-ground/cuts/<id>.toml` | One cut: parent, children, the implication's theorem name | Maintainers |

## Kinds of problem

| Kind | An answer is | Example here |
| --- | --- | --- |
| `prove` | A proof of the statement | `size_mono` |
| `settle` | A proof of the statement, or of its negation | `and_eq_or`, which is false and is refuted |
| `construct` | A proof that names an object passing a test the kernel can run | `xor2_le_4`, a four-gate circuit |
| `certify` | A certificate for a generated case, checked by a program the goal supplies | Not in this template yet |

## Cuts and roots

A **root** is a problem that is one of the goal's main results. A **cut** of a problem is a list
of smaller problems, its children, plus a Lean proof that the children together imply it. That
proof takes the children's statements as hypotheses, so it is complete, with no `sorry`, before
any child is proved.

Here the root `xor2_le_5` has the cut `xor2_le_5_by_mono`, with children `xor2_le_4` and
`size_mono`. Once both children are proved, the closing proof in `Proofs/xor2_le_5.lean` applies
the cut to them. That file was written from names alone:

```
python3 tools/make_challenges.py --closing xor2_le_5_by_mono
```

## Statements taken from outside

`Example/Outside.lean` stands in for an outside repository whose theorems are stated with `sorry`.
This goal never uses such a file as a challenge. `Example/Statements.lean` names the type of each
outside theorem as a statement of its own:

```lean
abbrev Example.outside_easy.Statement : Prop := type_of% @Outside.easy
```

An answer that tried to use the outside theorem itself would inherit its `sorry`, and the judge
would refuse it.

## Use it

You need Lean 4.35 or later and Python 3.11 or later. The judge's sandbox needs
[bubblewrap](https://github.com/containers/bubblewrap), which means Linux.

```
bash tools/build.sh                     # the library, the challenges, the answers, the cuts
python3 tools/make_challenges.py        # write Problems/ from the manifests
python3 tools/make_challenges.py --check
python3 tools/selfcheck.py              # judge every answer against its challenge
```

**Build with `tools/build.sh`, not with a bare `lake build`, and do not open an answer in an
editor.** The files in `Proofs/` and `Cuts/` are other people's answers. Lean lets a file run code
while it is built, so building an answer is running a stranger's code, on a machine that may hold
your keys. An editor does the same: it elaborates a file to show it to you, outside any sandbox.
Proving Ground refuses an answer that runs code while it builds, but no such rule is complete for
Lean, least of all in a goal with dependencies.

- `bash tools/build.sh` builds inside a sandbox with no network, a read-only system and an empty
  home. The goal is read-only there too, dependencies included. What a build writes goes to a
  throwaway directory that is deleted afterwards, so nothing an answer's build wrote is left for a
  later command to read. `bash tools/build.sh --check-sandbox` shows that all of this is in force.
- To try an answer of your own, put it in `Proofs/` and run `bash tools/build.sh Proofs.<id>`.
- `python3 tools/selfcheck.py` judges every answer on a throwaway copy of the repository.
- A bare `lake build` builds only the maintainers' library.
- If a goal has dependencies, fetch them and their build cache before you build any answer. That
  step needs the network and runs the dependencies' own code.

The sandbox needs bubblewrap. On a system without it, do all of this inside a container or a
virtual machine.

To start a goal of your own: replace `Example/` with your library, write one manifest per problem,
run the tool, and delete the example's answers.

## What an accepted answer means

It means the statement was proved as stated. Whether the statement says what its source says is a
separate question that a machine cannot answer. Each manifest carries a `fidelity` mark for it:
`unreviewed`, `confirmed` or `disputed`.

## Licence

Apache-2.0, as Lean and Mathlib are. Copyright 2026 The Colony.
