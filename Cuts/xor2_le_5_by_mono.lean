import Example.Statements

/-- Four gates are enough, and a size bound may grow: so five gates are enough. -/
theorem Example.xor2_le_5_by_mono (h1 : Example.xor2_le_4.Statement) (h2 : Example.size_mono.Statement) :
    Example.xor2_le_5.Statement :=
  h2 2 Example.xor2 4 5 (by decide) h1
