import Example.Statements

theorem Example.and_eq_or_neg : ¬ Example.and_eq_or.Statement :=
  fun h => absurd (h true false) (by decide)
