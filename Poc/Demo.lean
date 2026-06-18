/-
Demo file: introduces a brand-new direct `sorry` so the probe sorry-audit
flags it inline on this PR's diff (a ::warning annotation on the `sorry` line)
and the Verification Delta comment reports +1.
-/

/-- A freshly-introduced hole — should be annotated inline on the PR diff. -/
theorem demo_new_hole (a b : Nat) : a + b = b + a := by
  sorry
