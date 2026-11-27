import Example.Defs
import Example.Outside

/-!
# One named statement per problem

A challenge, a negation, a cut's implication and a closing proof are all written from these names.
Nothing outside this goal's library ever handles the text of a statement.
-/

/-- Exclusive or of two bits has a circuit of at most 4 gates. -/
abbrev Example.xor2_le_4.Statement : Prop := Example.HasSize 2 Example.xor2 4

/-- A size bound stays a size bound when it grows. -/
abbrev Example.size_mono.Statement : Prop :=
  ∀ (n : Nat) (f : List Bool → Bool) (s t : Nat), s ≤ t → Example.HasSize n f s → Example.HasSize n f t

/-- Exclusive or of two bits has a circuit of at most 5 gates. The root of this goal. -/
abbrev Example.xor2_le_5.Statement : Prop := Example.HasSize 2 Example.xor2 5

/-- The conjunction of two bits has a circuit of one gate. -/
abbrev Example.and2_le_1.Statement : Prop := Example.HasSize 2 Example.and2 1

/-- Conjunction and disjunction of two bits always agree. False, and here to be refuted. -/
abbrev Example.and_eq_or.Statement : Prop := ∀ a b : Bool, (a && b) = (a || b)

/-- An outside statement that is true. -/
abbrev Example.outside_easy.Statement : Prop := type_of% @Outside.easy

/-- An outside statement that is false. -/
abbrev Example.outside_wrong.Statement : Prop := type_of% @Outside.wrong
