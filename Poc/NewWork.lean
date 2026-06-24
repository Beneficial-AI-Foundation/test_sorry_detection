/-
New work introduced in this PR, to demonstrate the verification-delta comment.
Adds two sorry-tainted theorems that aren't in the baseline:
  * `freshDirect`     — a direct `sorry`
  * `freshTransitive` — no direct `sorry`, but depends on `freshDirect`
The delta should report both as newly introduced.
-/

/-- A brand-new direct hole. -/
theorem freshDirect (a : Nat) : a + 1 = 1 + a := by sorry

/-- Looks clean (no `sorry` in its body) but transitively depends on `freshDirect`. -/
theorem freshTransitive (a : Nat) : a + 1 = 1 + a := freshDirect a
