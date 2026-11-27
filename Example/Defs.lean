/-!
# The goal's own library: definitions

Every statement of this goal is read against this file and Lean's core library. So this file is the
whole of what a person has to read to know what a problem says.

A circuit is a list of gates. The wires are numbered: first the `n` inputs, then one wire per gate
in order. A gate reads wires by number; a wire that does not exist reads `false`.
-/

namespace Example

/-- The operations a gate can perform. `not` reads its first wire only. -/
inductive Op where
  | and
  | or
  | not
  deriving DecidableEq, Repr

/-- A gate: an operation and the two wires it reads. -/
structure Gate where
  op : Op
  a : Nat
  b : Nat
  deriving DecidableEq, Repr

/-- The value of a gate, given the values of the wires before it. -/
def Gate.eval (g : Gate) (w : List Bool) : Bool :=
  match g.op with
  | .and => w.getD g.a false && w.getD g.b false
  | .or => w.getD g.a false || w.getD g.b false
  | .not => !(w.getD g.a false)

/-- All wire values of a circuit on an input: the input bits, then one value per gate. -/
def run (gs : List Gate) (x : List Bool) : List Bool :=
  gs.foldl (fun w g => w ++ [g.eval w]) x

/-- The `n` low bits of `k`, least significant first: the `k`-th input of length `n`. -/
def bits (n k : Nat) : List Bool :=
  (List.range n).map fun i => k.testBit i

/-- The circuit `gs`, read at wire `out`, agrees with `f` on every input of length `n`. -/
def Computes (n : Nat) (gs : List Gate) (out : Nat) (f : List Bool → Bool) : Prop :=
  ∀ k, k < 2 ^ n → (run gs (bits n k)).getD out false = f (bits n k)

instance (n : Nat) (gs : List Gate) (out : Nat) (f : List Bool → Bool) : Decidable (Computes n gs out f) := by
  unfold Computes; infer_instance

/-- Some circuit with at most `s` gates computes `f` on inputs of length `n`. Every gate counts. -/
def HasSize (n : Nat) (f : List Bool → Bool) (s : Nat) : Prop :=
  ∃ (gs : List Gate) (out : Nat), gs.length ≤ s ∧ Computes n gs out f

/-- Exclusive or of the first two input bits. -/
def xor2 (x : List Bool) : Bool := x.getD 0 false != x.getD 1 false

/-- Conjunction of the first two input bits. -/
def and2 (x : List Bool) : Bool := x.getD 0 false && x.getD 1 false

end Example
