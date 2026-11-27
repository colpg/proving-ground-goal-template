/-!
# A stand-in for an outside statement set

A real goal would depend on an outside repository pinned to a commit. Its theorems are stated there
with `sorry` for a proof. This goal never uses such a file as a challenge: `Example.Statements`
names the TYPE of each outside theorem as a statement of its own, so the outside `sorry` cannot
reach an answer.
-/

theorem Outside.easy : (2 : Nat) + 2 = 4 := sorry

theorem Outside.wrong : (2 : Nat) + 2 = 5 := sorry
