/-
A deliberately layered example to exercise the collectAxioms BFS provenance.

One real `sorry` hole (`coreHole`), reached by a "clean-looking" headline
theorem only *transitively* through several intermediate lemmas that contain
no `sorry` themselves. This is the case probe (direct-only) misses and
collectAxioms catches — and where Section 2's multi-hop trace earns its keep.
-/

/-- The single real hole. -/
theorem coreHole (a : Nat) : a - a = 0 := by sorry

/-- Intermediate layers — none contains `sorry`; each just builds on the previous. -/
theorem viaLayer1 (a : Nat) : a - a = 0 := coreHole a
theorem viaLayer2 (a : Nat) : a - a = 0 := viaLayer1 a
theorem viaLayer3 (a : Nat) : a - a = 0 := viaLayer2 a

/-- Headline theorem: its own body has no `sorry`, yet it transitively depends
    on `coreHole`. collectAxioms flags it (transitive); probe would not. -/
theorem headlineTransitive (a : Nat) : a - a = 0 := viaLayer3 a
