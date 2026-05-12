/-
Automatically print all axioms used by every declaration in this project.

Usage:
  lake env lean scripts/PrintAxioms.lean

Discovers all modules whose name starts with `Poc`, then for each
theorem/def/opaque it collects the transitive axiom closure and reports
non-builtin ones.

Reference: https://lean-lang.org/doc/reference/latest/ValidatingProofs/
-/
import Poc

open Lean Elab Command

private def isBuiltinAxiom (n : Name) : Bool :=
  n == ``propext || n == ``Classical.choice || n == ``Quot.sound

run_cmd liftTermElabM do
  let env ← getEnv
  let moduleNames := env.header.moduleNames

  let mut projectModuleIdxs : Std.HashSet Nat := {}
  let mut projectModuleNames : Array Name := #[]
  for h : i in [:moduleNames.size] do
    let m := moduleNames[i]
    if m == `Poc || m.getRoot == `Poc then
      projectModuleIdxs := projectModuleIdxs.insert i
      projectModuleNames := projectModuleNames.push m

  logInfo m!"=== Project modules detected ==="
  for h : i in [:projectModuleNames.size] do
    logInfo m!"  {projectModuleNames[i]}"

  let (moduleLookup, allProjectDecls) :=
    env.constants.fold
      (init := (({} : Std.HashMap Name Name), (#[] : Array Name)))
    fun acc nm ci =>
      let (ml, pa) := acc
      match env.getModuleIdxFor? nm with
      | some idx =>
        if !projectModuleIdxs.contains idx.toNat then acc
        else
          match ci with
          | .thmInfo _ | .defnInfo _ | .opaqueInfo _ | .axiomInfo _ =>
            (ml.insert nm moduleNames[idx.toNat]!, pa.push nm)
          | _ => acc
      | none => acc

  let modOf (nm : Name) : String :=
    moduleLookup[nm]?.map toString |>.getD "(current file)"

  let mut axiomCache : Std.HashMap Name (Array Name) := {}
  for h : i in [:allProjectDecls.size] do
    let nm := allProjectDecls[i]
    let usedAxioms ← Lean.collectAxioms nm
    axiomCache := axiomCache.insert nm usedAxioms

  let mut projSorry := false
  let mut projNonBuiltinCount : Nat := 0
  let mut projAllCustom : Std.HashSet Name := {}

  for h : i in [:allProjectDecls.size] do
    let nm := allProjectDecls[i]
    let usedAxioms := axiomCache[nm]?.getD #[]
    let nonBuiltin := usedAxioms.filter fun a => !isBuiltinAxiom a
    if nonBuiltin.size > 0 then projNonBuiltinCount := projNonBuiltinCount + 1
    if usedAxioms.any (· == ``sorryAx) then projSorry := true
    for h2 : j in [:nonBuiltin.size] do
      projAllCustom := projAllCustom.insert nonBuiltin[j]

  logInfo m!"Total project declarations: {allProjectDecls.size}"
  logInfo m!"With non-builtin axioms: {projNonBuiltinCount} / {allProjectDecls.size}"
  if projSorry then logInfo m!"⚠  `sorryAx` found in project."
  else logInfo m!"✓  No `sorryAx` in project."

  for h : i in [:allProjectDecls.size] do
    let nm := allProjectDecls[i]
    let usedAxioms := axiomCache[nm]?.getD #[]
    let nonBuiltin := usedAxioms.filter fun a => !isBuiltinAxiom a
    if nonBuiltin.size > 0 then
      let mut msg := m!"  [{modOf nm}] {nm}"
      for h2 : j in [:nonBuiltin.size] do
        msg := msg ++ m!"\n    └─ {nonBuiltin[j]}"
      logInfo msg
