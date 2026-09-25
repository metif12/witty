module input

fn test_modifier_source_tag_layout_and_ordinals() {
	assert sizeof(Mod) == 1
	assert [Mod.shift, .ctrl, .alt, .super_].map(u8(it)) == [u8(0), 1, 2, 3]
}

// Tests for RemapSet modifier remapping.

fn test_remap_unsided_creates_both() {
	mut set := RemapSet{}
	set.parse('ctrl=super') or { assert false }
	set.finalize()

	// Left ctrl should map to left super
	left_ctrl := Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result_l := set.apply(left_ctrl)
	assert result_l.super_() == true
	assert result_l.ctrl() == false
	assert result_l.sides().super_() == .left

	// Right ctrl should also map to super
	right_ctrl := Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .right, .left, .left))
	result_r := set.apply(right_ctrl)
	assert result_r.super_() == true
	assert result_r.ctrl() == false
	assert result_r.sides().super_() == .left
}

fn test_remap_sided_from_only_maps_that_side() {
	mut set := RemapSet{}
	set.parse('left_alt=ctrl') or { assert false }
	set.finalize()

	left_alt := Mods.init(false, false, true, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_alt)
	assert result.ctrl() == true
	assert result.alt() == false

	// Right alt should NOT be remapped
	right_alt := Mods.init(false, false, true, false, false, false, SideInfo.init(.left, .left, .right, .left))
	result2 := set.apply(right_alt)
	assert result2.alt() == true
}

fn test_remap_sided_to() {
	mut set := RemapSet{}
	set.parse('ctrl=right_super') or { assert false }
	set.finalize()

	left_ctrl := Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_ctrl)
	assert result.super_() == true
	assert result.ctrl() == false
	assert result.sides().super_() == .right
}

fn test_remap_replaces_existing_physical_side() {
	mut set := RemapSet{}
	set.parse('ctrl=super')!
	set.parse('right_ctrl=alt')!
	set.finalize()

	left := set.apply(Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .left, .left, .left)))
	right := set.apply(Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .right, .left, .left)))
	assert left.super_()
	assert right.alt()
	assert !right.super_()
}

fn test_remap_both_sides_specified() {
	mut set := RemapSet{}
	set.parse('left_shift=right_ctrl') or { assert false }
	set.finalize()

	left_shift := Mods.init(true, false, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_shift)
	assert result.ctrl() == true
	assert result.shift() == false
}

fn test_remap_multiple_parses_accumulate() {
	mut set := RemapSet{}
	set.parse('left_ctrl=super') or { assert false }
	set.parse('left_alt=ctrl') or { assert false }
	set.finalize()

	left_ctrl := Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result1 := set.apply(left_ctrl)
	assert result1.super_() == true

	left_alt := Mods.init(false, false, true, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result2 := set.apply(left_alt)
	assert result2.ctrl() == true
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

	assert set.is_remapped(Mods.init(false, true, false, false, false, false, SideInfo{}))
	assert !set.is_remapped(Mods.init(false, false, true, false, false, false, SideInfo{}))
	assert !set.is_remapped(Mods.init(true, false, false, false, false, false, SideInfo{}))
}

fn test_remap_mask_retains_source_packed_lanes() {
	assert sizeof(RemapMask) == 2
	mut mask := RemapMask{}
	mask.update(Mods.init(false, true, false, false, false, false, SideInfo{}))
	assert mask.int() == 0x022
	assert mask.keys() == 0x02
	assert mask.left_sides() == 0x02
	assert mask.right_sides() == 0
	mask.update(Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .right, .left, .left)))
	assert mask.int() == 0x222
}

fn test_remap_aliased_cmd() {
	mut set := RemapSet{}
	set.parse('cmd=ctrl') or { assert false }
	set.finalize()

	left_super := Mods.init(false, false, false, true, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_super)
	assert result.ctrl() == true
}

fn test_remap_aliased_option() {
	mut set := RemapSet{}
	set.parse('option=shift') or { assert false }
	set.finalize()

	left_alt := Mods.init(false, false, true, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_alt)
	assert result.shift() == true
}

fn test_remap_aliased_control() {
	mut set := RemapSet{}
	set.parse('control=super') or { assert false }
	set.finalize()

	left_ctrl := Mods.init(false, true, false, false, false, false, SideInfo.init(.left, .left, .left, .left))
	result := set.apply(left_ctrl)
	assert result.super_() == true
}

// Tests for Mods methods.

fn test_mods_empty() {
	m := Mods{}
	assert m.empty()

	m2 := Mods.init(true, false, false, false, false, false, SideInfo{})
	assert !m2.empty()
	assert !Mods.init(false, false, false, false, true, false, SideInfo{}).empty()
	assert !Mods.init(false, false, false, false, false, true, SideInfo{}).empty()
	assert !Mods.init(false, false, false, false, false, false, SideInfo.init(.right, .left, .left, .left)).empty()
}

fn test_mods_equal() {
	m1 := Mods.init(true, true, false, false, false, false, SideInfo{})
	m2 := Mods.init(true, true, false, false, false, false, SideInfo{})
	assert m1.equal(m2)

	m3 := Mods.init(true, false, false, false, false, false, SideInfo{})
	assert !m1.equal(m3)

	assert !Mods.init(false, false, false, false, true, false, SideInfo{}).equal(Mods{})
	assert !Mods.init(false, false, false, false, false, true, SideInfo{}).equal(Mods{})
	assert !Mods.init(true, false, false, false, false, false, SideInfo.init(.right, .left, .left, .left)).equal(Mods.init(true, false, false, false, false, false, SideInfo.init(.left, .left, .left, .left)))
	// The source's packed side fields default to left and encode as zero.
	assert Mods.init(true, false, false, false, false, false, SideInfo{}).equal(Mods.init(true, false, false, false, false, false, SideInfo.init(.left, .left, .left, .left)))
}

fn test_mods_binding() {
	m := Mods.init(true, true, false, false, true, true, SideInfo{})
	b := m.binding()
	assert b.shift() == true
	assert b.ctrl() == true
	assert b.caps_lock() == false
	assert b.num_lock() == false
}

fn test_mods_unset() {
	m := Mods.init(true, true, true, false, false, false, SideInfo{})
	other := Mods.init(false, true, false, false, false, false, SideInfo{})
	result := m.unset(other)
	assert result.shift() == true
	assert result.ctrl() == false
	assert result.alt() == true
}

fn test_mods_without_locks() {
	m := Mods.init(true, false, false, false, true, true, SideInfo{})
	result := m.without_locks()
	assert result.shift() == true
	assert result.caps_lock() == false
	assert result.num_lock() == false
}

fn test_mods_ctrl_or_super() {
	// Darwin checks super; every other platform checks ctrl.
	sup := Mods.init(false, false, false, true, false, false, SideInfo{})
	ctrl := Mods.init(false, true, false, false, false, false, SideInfo{})
	$if darwin {
		assert sup.ctrl_or_super()
		assert !ctrl.ctrl_or_super()
	} $else {
		assert ctrl.ctrl_or_super()
		assert !sup.ctrl_or_super()
	}
}

fn test_ctrl_or_super_mods_fn() {
	m := ctrl_or_super_mods(Mods{})
	// Darwin sets super; every other platform sets ctrl.
	$if darwin {
		assert m.super_()
		assert !m.ctrl()
	} $else {
		assert m.ctrl()
		assert !m.super_()
	}
}

fn test_mods_keys_int() {
	m := Mods.init(true, true, false, false, false, false, SideInfo{})
	assert m.keys_int() == 3

	m2 := Mods.init(false, false, true, true, false, false, SideInfo{})
	assert m2.keys_int() == 12
}
