theorem add_comm_nat (a b : Nat) : a + b = b + a := Nat.add_comm a b

theorem add_zero_nat (a : Nat) : a + 0 = a := Nat.add_zero a

theorem mul_comm_nat (a b : Nat) : a * b = b * a := by sorry

theorem sub_self_nat (a : Nat) : a - a = 0 := by sorry

theorem add_assoc_nat (a b c : Nat) : a + (b + c) = (a + b) + c := by sorry

theorem zero_add_nat (a : Nat) : 0 + a = a := Nat.zero_add a
