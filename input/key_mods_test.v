module input

// Tests for RemapSet modifier remapping.

fn test_remap_unsided_creates_both() {
	mut set := RemapSet{}
	set.parse('ctrl=super') or { assert false }
	set.finalize()

	// Left ctrl should map to left super
	left_ctrl := Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .left }
	}
	result_l := set.apply(left_ctrl)
	assert result_l.super_ == true
	assert result_l.ctrl == false
	assert result_l.sides.super == .left

	// Right ctrl should also map to super
	right_ctrl := Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .right }
	}
	result_r := set.apply(right_ctrl)
	assert result_r.super_ == true
	assert result_r.ctrl == false
	assert result_r.sides.super == .left
}

fn test_remap_sided_from_only_maps_that_side() {
	mut set := RemapSet{}
	set.parse('left_alt=ctrl') or { assert false }
	set.finalize()

	left_alt := Mods{
		alt: true
		sides: SideInfo{ alt: .left }
	}
	result := set.apply(left_alt)
	assert result.ctrl == true
	assert result.alt == false

	// Right alt should NOT be remapped
	right_alt := Mods{
		alt: true
		sides: SideInfo{ alt: .right }
	}
	result2 := set.apply(right_alt)
	assert result2.alt == true
}

fn test_remap_sided_to() {
	mut set := RemapSet{}
	set.parse('ctrl=right_super') or { assert false }
	set.finalize()

	left_ctrl := Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .left }
	}
	result := set.apply(left_ctrl)
	assert result.super_ == true
	assert result.ctrl == false
	assert result.sides.super == .right
}

fn test_remap_replaces_existing_physical_side() {
	mut set := RemapSet{}
	set.parse('ctrl=super')!
	set.parse('right_ctrl=alt')!
	set.finalize()

	left := set.apply(Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .left }
	})
	right := set.apply(Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .right }
	})
	assert left.super_
	assert right.alt
	assert !right.super_
}

fn test_remap_both_sides_specified() {
	mut set := RemapSet{}
	set.parse('left_shift=right_ctrl') or { assert false }
	set.finalize()

	left_shift := Mods{
		shift: true
		sides: SideInfo{ shift: .left }
	}
	result := set.apply(left_shift)
	assert result.ctrl == true
	assert result.shift == false
}

fn test_remap_multiple_parses_accumulate() {
	mut set := RemapSet{}
	set.parse('left_ctrl=super') or { assert false }
	set.parse('left_alt=ctrl') or { assert false }
	set.finalize()

	left_ctrl := Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .left }
	}
	result1 := set.apply(left_ctrl)
	assert result1.super_ == true

	left_alt := Mods{
		alt: true
		sides: SideInfo{ alt: .left }
	}
	result2 := set.apply(left_alt)
	assert result2.ctrl == true
}

fn test_remap_error_missing_assignment() {
	mut set := RemapSet{}
	set.parse('ctrl') or {
		assert true
		return
	}
	assert false
}

fn test_remap_error_empty_string() {
	mut set := RemapSet{}
	set.parse('') or {
		assert true
		return
	}
	assert false
}

fn test_remap_error_invalid_modifier() {
	mut set := RemapSet{}
	set.parse('invalid=ctrl') or {
		assert true
		return
	}
	assert false
}

fn test_remap_error_invalid_target() {
	mut set := RemapSet{}
	set.parse('ctrl=invalid') or {
		assert true
		return
	}
	assert false
}

fn test_remap_error_invalid_side() {
	mut set := RemapSet{}
	set.parse('middle_ctrl=super') or {
		assert true
		return
	}
	assert false
}

fn test_remap_rejects_translated_v_identifier() {
	mut set := RemapSet{}
	set.parse('super_=ctrl') or {
		assert err.msg().contains('invalid modifier')
		return
	}
	assert false
}

fn test_remap_parse_cli_maps_parser_errors_to_invalid_value() {
	mut set := RemapSet{}
	for value in ['ctrl', 'invalid=ctrl', 'ctrl=invalid', 'middle_ctrl=super'] {
		set.parse_cli(value) or {
			assert err.msg() == 'invalid value'
			continue
		}
		assert false, 'expected invalid value for ${value}'
	}
}

fn test_remap_is_remapped_checks_mask() {
	mut set := RemapSet{}
	set.parse('ctrl=super') or { assert false }
	set.finalize()

	assert set.is_remapped(Mods{ ctrl: true })
	assert !set.is_remapped(Mods{ alt: true })
	assert !set.is_remapped(Mods{ shift: true })
}

fn test_remap_aliased_cmd() {
	mut set := RemapSet{}
	set.parse('cmd=ctrl') or { assert false }
	set.finalize()

	left_super := Mods{
		super_: true
		sides: SideInfo{ super: .left }
	}
	result := set.apply(left_super)
	assert result.ctrl == true
}

fn test_remap_aliased_option() {
	mut set := RemapSet{}
	set.parse('option=shift') or { assert false }
	set.finalize()

	left_alt := Mods{
		alt: true
		sides: SideInfo{ alt: .left }
	}
	result := set.apply(left_alt)
	assert result.shift == true
}

fn test_remap_aliased_control() {
	mut set := RemapSet{}
	set.parse('control=super') or { assert false }
	set.finalize()

	left_ctrl := Mods{
		ctrl: true
		sides: SideInfo{ ctrl: .left }
	}
	result := set.apply(left_ctrl)
	assert result.super_ == true
}

// Tests for Mods methods.

fn test_mods_empty() {
	m := Mods{}
	assert m.empty()

	m2 := Mods{ shift: true }
	assert !m2.empty()
	assert !Mods{ caps_lock: true }.empty()
	assert !Mods{ num_lock: true }.empty()
	assert !Mods{ sides: SideInfo{ shift: .right } }.empty()
}

fn test_mods_equal() {
	m1 := Mods{ shift: true, ctrl: true }
	m2 := Mods{ shift: true, ctrl: true }
	assert m1.equal(m2)

	m3 := Mods{ shift: true }
	assert !m1.equal(m3)

	assert !Mods{ caps_lock: true }.equal(Mods{})
	assert !Mods{ num_lock: true }.equal(Mods{})
	assert !Mods{ shift: true, sides: SideInfo{ shift: .right } }.equal(Mods{
		shift: true
		sides: SideInfo{ shift: .left }
	})
	// The source's packed side fields default to left and encode as zero.
	assert Mods{ shift: true }.equal(Mods{
		shift: true
		sides: SideInfo{ shift: .left }
	})
}

fn test_mods_binding() {
	m := Mods{
		shift: true
		ctrl: true
		caps_lock: true
		num_lock: true
	}
	b := m.binding()
	assert b.shift == true
	assert b.ctrl == true
	assert b.caps_lock == false
	assert b.num_lock == false
}

fn test_mods_unset() {
	m := Mods{ shift: true, ctrl: true, alt: true }
	other := Mods{ ctrl: true }
	result := m.unset(other)
	assert result.shift == true
	assert result.ctrl == false
	assert result.alt == true
}

fn test_mods_without_locks() {
	m := Mods{
		shift: true
		caps_lock: true
		num_lock: true
	}
	result := m.without_locks()
	assert result.shift == true
	assert result.caps_lock == false
	assert result.num_lock == false
}

fn test_mods_ctrl_or_super() {
	// On macOS, ctrl_or_super checks super
	m := Mods{ super_: true }
	assert m.ctrl_or_super()

	m2 := Mods{ ctrl: true }
	assert !m2.ctrl_or_super()
}

fn test_ctrl_or_super_mods_fn() {
	m := ctrl_or_super_mods(Mods{})
	// On macOS, should set super
	assert m.super_
}

fn test_mods_keys_int() {
	m := Mods{ shift: true, ctrl: true }
	assert m.keys_int() == 3

	m2 := Mods{ alt: true, super_: true }
	assert m2.keys_int() == 12
}
