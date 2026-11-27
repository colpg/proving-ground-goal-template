import Example.Statements

theorem Example.size_mono : Example.size_mono.Statement := by
  intro n f s t hst h
  obtain ⟨gs, out, hlen, hc⟩ := h
  exact ⟨gs, out, Nat.le_trans hlen hst, hc⟩
