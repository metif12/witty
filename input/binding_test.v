module input

// --- Flags tests ---

fn test_flags_cval_default() {
	f := Flags{}
	assert f.cval() == u8(0b0001)
}

fn test_flags_cval_not_consumed() {
	f := Flags{ consumed: false }
	assert f.cval() == u8(0b0000)
}

fn test_flags_cval_all() {
	f := Flags{ all: true }
	assert f.cval() == u8(0b0011)
}

fn test_flags_cval_global() {
	f := Flags{ global: true }
	assert f.cval() == u8(0b0101)
}

fn test_flags_cval_performable() {
	f := Flags{ performable: true }
	assert f.cval() == u8(0b1001)
}

fn test_flags_cval_all_set() {
	f := Flags{ consumed: true, all: true, global: true, performable: true }
	assert f.cval() == u8(0b1111)
}

// --- Trigger parse tests ---

fn test_parse_single_character() {
	b := parse_single('a=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.action.tag == .ignore
}

fn test_parse_single_modifier() {
	b := parse_single('shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.action.tag == .ignore

	b2 := parse_single('ctrl+a=ignore') or { panic(err.msg()) }
	assert b2.trigger.mods.ctrl == true
	assert b2.trigger.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_parse_multiple_modifiers() {
	b := parse_single('shift+ctrl+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.mods.ctrl == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_parse_key_before_modifier() {
	b := parse_single('a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_parse_physical_keys() {
	b := parse_single('shift+key_a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_physical(.key_a)
}

fn test_parse_unicode_keys() {
	b := parse_single('shift+ö=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key.typ == .unicode
	// ö is U+00F6
	assert b.trigger.key.unicode == 0xF6
}

fn test_parse_unconsumed_keys() {
	b := parse_single('unconsumed:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.consumed == false
}

fn test_parse_unconsumed_physical_keys() {
	b := parse_single('unconsumed:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_physical(.key_a)
	assert b.flags.consumed == false
}

fn test_parse_performable_keys() {
	b := parse_single('performable:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.performable == true
}

fn test_parse_invalid_key() {
	parse_single('foo=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_repeated_modifier() {
	parse_single('shift+shift+a=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_multiple_character_keys() {
	parse_single('a+b=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- W3C key name tests ---

fn test_parse_w3c_key() {
	b := parse_single('KeyA=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_physical(.key_a)
}

fn test_parse_w3c_case_sensitive() {
	parse_single('Keya=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- catch_all tests ---

fn test_parse_catch_all() {
	b := parse_single('catch_all=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_catch_all()
}

fn test_parse_catch_all_with_modifiers() {
	b := parse_single('ctrl+catch_all=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.ctrl == true
	assert b.trigger.key == TriggerKey.new_catch_all()
}

// --- Plus sign tests ---

fn test_parse_plus_sign() {
	b := parse_single('+=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`+`))
}

fn test_parse_plus_with_modifier() {
	b := parse_single('ctrl++=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`+`))
	assert b.trigger.mods.ctrl == true
}

fn test_parse_double_plus_invalid() {
	parse_single('++=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Equals sign tests ---

fn test_parse_equals_sign() {
	b := parse_single('==ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.action.tag == .ignore
}

fn test_parse_equals_with_modifier() {
	b := parse_single('ctrl+==ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.trigger.mods.ctrl == true
}

fn test_parse_bare_equals_invalid() {
	parse_single('=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Text action equals sign tests ---

fn test_parse_text_action_equals_1() {
	b := parse_single('==text:=') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.action.tag == .text
	assert b.action.str_param == '='
}

fn test_parse_text_action_equals_2() {
	b := parse_single('==text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.action.str_param == '=hello'
}

fn test_parse_text_action_equals_ctrl() {
	b := parse_single('ctrl+==text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.trigger.mods.ctrl == true
	assert b.action.str_param == '=hello'
}

fn test_parse_text_action_equals_after() {
	b := parse_single('=+ctrl=text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey.new_unicode(u32(`=`))
	assert b.trigger.mods.ctrl == true
	assert b.action.str_param == '=hello'
}

// --- Global trigger tests ---

fn test_parse_global() {
	b := parse_single('global:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.global == true
}

fn test_parse_global_physical() {
	b := parse_single('global:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_physical(.key_a)
	assert b.flags.global == true
}

fn test_parse_global_unconsumed() {
	b := parse_single('unconsumed:global:a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.global == true
	assert b.flags.consumed == false
}

fn test_parse_global_sequence_not_allowed() {
	mut p := Parser.init('global:a>b=ignore') or { panic(err.msg()) }
	p.next() or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- All trigger tests ---

fn test_parse_all() {
	b := parse_single('all:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.all == true
}

fn test_parse_all_physical() {
	b := parse_single('all:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_physical(.key_a)
	assert b.flags.all == true
}

fn test_parse_all_unconsumed() {
	b := parse_single('unconsumed:all:a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift == true
	assert b.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert b.flags.all == true
	assert b.flags.consumed == false
}

fn test_parse_all_sequence_not_allowed() {
	mut p := Parser.init('all:a>b=ignore') or { panic(err.msg()) }
	p.next() or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Modifier alias tests ---

fn test_parse_modifier_cmd() {
	b := parse_single('cmd+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.super_ == true
}

fn test_parse_modifier_command() {
	b := parse_single('command+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.super_ == true
}

fn test_parse_modifier_opt() {
	b := parse_single('opt+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.alt == true
}

fn test_parse_modifier_option() {
	b := parse_single('option+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.alt == true
}

fn test_parse_modifier_control() {
	b := parse_single('control+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.ctrl == true
}

// --- Action parse tests ---

fn test_parse_action_invalid() {
	parse_single('a=nopenopenope') or {
		assert err.msg() == 'InvalidAction'
		return
	}
	assert false
}

fn test_parse_action_no_parameters() {
	b := parse_single('a=ignore') or { panic(err.msg()) }
	assert b.action.tag == .ignore

	parse_single('a=ignore:A') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_with_string() {
	b := parse_single('a=csi:A') or { panic(err.msg()) }
	assert b.action.tag == .csi
	assert b.action.str_param == 'A'

	b2 := parse_single('a=esc:A') or { panic(err.msg()) }
	assert b2.action.tag == .esc
	assert b2.action.str_param == 'A'
}

fn test_parse_action_with_enum() {
	b := parse_single('a=new_split:right') or { panic(err.msg()) }
	assert b.action.tag == .new_split
	assert b.action.enum_param == i32(SplitDirection.right)
}

fn test_parse_action_with_enum_default() {
	b := parse_single('a=new_split') or { panic(err.msg()) }
	assert b.action.tag == .new_split
	assert b.action.enum_param == i32(SplitDirection.auto_)
}

fn test_parse_action_with_int() {
	b := parse_single('a=jump_to_prompt:-1') or { panic(err.msg()) }
	assert b.action.tag == .jump_to_prompt
	assert b.action.int_param == i32(-1)

	b2 := parse_single('a=jump_to_prompt:10') or { panic(err.msg()) }
	assert b2.action.int_param == i32(10)
}

fn test_parse_action_with_float() {
	b := parse_single('a=scroll_page_fractional:-0.5') or { panic(err.msg()) }
	assert b.action.tag == .scroll_page_fractional
	assert b.action.float_param == f32(-0.5)

	b2 := parse_single('a=scroll_page_fractional:+0.5') or { panic(err.msg()) }
	assert b2.action.float_param == f32(0.5)
}

fn test_parse_action_with_tuple() {
	b := parse_single('a=resize_split:up,10') or { panic(err.msg()) }
	assert b.action.tag == .resize_split
	assert b.action.enum_param == i32(SplitResizeDirection.up)
	assert b.action.enum_param2 == i32(10)
}

fn test_parse_action_tuple_missing_param() {
	parse_single('a=resize_split:up') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_tuple_too_many() {
	parse_single('a=resize_split:up,10,12') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_tuple_invalid_type() {
	parse_single('a=resize_split:up,four') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Chain parse tests ---

fn test_parse_chain() {
	mut p := Parser.init('chain=new_tab') or { panic(err.msg()) }
	elem := p.next() or { panic(err.msg()) }
	assert elem.typ == .chain
	assert elem.action.tag == .new_tab
	p.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_parse_chain_no_flags() {
	Parser.init('global:chain=ignore') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Sequence iterator tests ---

fn test_sequence_iterator_single() {
	mut it := SequenceIterator{ input: 'a' }
	t := it.next() or { panic(err.msg()) }
	assert t.key == TriggerKey.new_unicode(u32(`a`))
	it.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_sequence_iterator_multi() {
	mut it := SequenceIterator{ input: 'a>b' }
	t1 := it.next() or { panic(err.msg()) }
	assert t1.key == TriggerKey.new_unicode(u32(`a`))
	t2 := it.next() or { panic(err.msg()) }
	assert t2.key == TriggerKey.new_unicode(u32(`b`))
	it.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_sequence_iterator_empty() {
	mut it := SequenceIterator{ input: '' }
	it.next() or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_sequence_iterator_empty_start() {
	mut it := SequenceIterator{ input: '>a' }
	it.next() or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_sequence_iterator_empty_end() {
	mut it := SequenceIterator{ input: 'a>' }
	t := it.next() or { panic(err.msg()) }
	assert t.key == TriggerKey.new_unicode(u32(`a`))
	it.next() or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Sequence parse tests ---

fn test_parse_sequence_single() {
	mut p := Parser.init('ctrl+a=ignore') or { panic(err.msg()) }
	elem := p.next() or { panic(err.msg()) }
	assert elem.typ == .binding
	assert elem.binding.trigger.mods.ctrl == true
	assert elem.binding.trigger.key == TriggerKey.new_unicode(u32(`a`))
	assert elem.binding.action.tag == .ignore
	p.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_parse_sequence_two() {
	mut p := Parser.init('a>b=ignore') or { panic(err.msg()) }
	e1 := p.next() or { panic(err.msg()) }
	assert e1.typ == .leader
	assert e1.trigger.key == TriggerKey.new_unicode(u32(`a`))
	e2 := p.next() or { panic(err.msg()) }
	assert e2.typ == .binding
	assert e2.binding.trigger.key == TriggerKey.new_unicode(u32(`b`))
	assert e2.binding.action.tag == .ignore
	p.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

// --- Trigger equal tests ---

fn test_trigger_equal_physical() {
	t1 := Trigger{ key: TriggerKey.new_physical(.arrow_up), mods: Mods{ ctrl: true } }
	t2 := Trigger{ key: TriggerKey.new_physical(.arrow_up), mods: Mods{ ctrl: true } }
	assert t1.equal(t2)
}

fn test_trigger_different_physical() {
	t1 := Trigger{ key: TriggerKey.new_physical(.arrow_up), mods: Mods{ ctrl: true } }
	t2 := Trigger{ key: TriggerKey.new_physical(.arrow_down), mods: Mods{ ctrl: true } }
	assert !t1.equal(t2)
}

fn test_trigger_different_mods() {
	t1 := Trigger{ key: TriggerKey.new_physical(.arrow_up), mods: Mods{ ctrl: true } }
	t2 := Trigger{ key: TriggerKey.new_physical(.arrow_up), mods: Mods{ shift: true } }
	assert !t1.equal(t2)
}

fn test_trigger_equal_unicode() {
	t1 := Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }
	t2 := Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }
	assert t1.equal(t2)
}

fn test_trigger_different_unicode() {
	t1 := Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }
	t2 := Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }
	assert !t1.equal(t2)
}

fn test_trigger_different_key_types() {
	t1 := Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }
	t2 := Trigger{ key: TriggerKey.new_physical(.key_a) }
	assert !t1.equal(t2)
}

fn test_trigger_catch_all_equal() {
	t1 := Trigger{ key: TriggerKey.new_catch_all() }
	t2 := Trigger{ key: TriggerKey.new_catch_all() }
	assert t1.equal(t2)
}

fn test_trigger_catch_all_different_mods() {
	t1 := Trigger{ key: TriggerKey.new_catch_all() }
	t2 := Trigger{ key: TriggerKey.new_catch_all(), mods: Mods{ alt: true } }
	assert !t1.equal(t2)
}

// --- Set tests ---

fn test_set_parse_and_put_typical() {
	mut s := Set{}
	s.parse_and_put('a=new_window') or { panic(err.msg()) }

	// Forward mapping
	entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert entry.value.typ == .leaf
	assert entry.value.leaf_action.tag == .new_window
	assert entry.value.leaf_flags == Flags{}

	// Reverse mapping
	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_set_parse_and_put_unconsumed() {
	mut s := Set{}
	s.parse_and_put('unconsumed:a=new_window') or { panic(err.msg()) }

	entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert entry.value.typ == .leaf
	assert entry.value.leaf_action.tag == .new_window
	assert entry.value.leaf_flags.consumed == false

	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_set_parse_and_put_removed() {
	mut s := Set{}
	s.parse_and_put('a=new_window') or { panic(err.msg()) }
	s.parse_and_put('a=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) })
	assert r == none

	t := s.get_trigger(Action.new(.new_window))
	assert t == none
}

fn test_set_parse_and_put_sequence() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert a_entry.value.typ == .leader
	inner := a_entry.value.leader

	b_entry := inner.get(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }) or { panic('not found') }
	assert b_entry.value.typ == .leaf
	assert b_entry.value.leaf_action.tag == .new_window
}

fn test_set_parse_and_put_sequence_two_actions() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }
	s.parse_and_put('a>c=new_tab') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert a_entry.value.typ == .leader
	inner := a_entry.value.leader

	b_entry := inner.get(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }) or { panic('not found') }
	assert b_entry.value.leaf_action.tag == .new_window

	c_entry := inner.get(Trigger{ key: TriggerKey.new_unicode(u32(`c`)) }) or { panic('not found') }
	assert c_entry.value.leaf_action.tag == .new_tab
}

fn test_set_parse_and_put_overwrite_sequence() {
	mut s := Set{}
	s.parse_and_put('a>b=new_tab') or { panic(err.msg()) }
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	inner := a_entry.value.leader

	b_entry := inner.get(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }) or { panic('not found') }
	assert b_entry.value.leaf_action.tag == .new_window
}

fn test_set_parse_and_put_overwrite_leader() {
	mut s := Set{}
	s.parse_and_put('a=new_tab') or { panic(err.msg()) }
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert a_entry.value.typ == .leader
	inner := a_entry.value.leader

	b_entry := inner.get(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }) or { panic('not found') }
	assert b_entry.value.leaf_action.tag == .new_window
}

fn test_set_parse_and_put_unbind_leader() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }
	s.parse_and_put('a>b=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) })
	assert r == none
}

fn test_set_parse_and_put_unbind_not_set() {
	mut s := Set{}
	s.parse_and_put('a>b=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) })
	assert r == none
}

fn test_set_maintains_reverse_mapping() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window))
	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))

	// Should be most recent
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }, Action.new(.new_window))
	trigger2 := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger2.key == TriggerKey.new_unicode(u32(`b`))

	// Removal should find another
	s.remove(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) })
	trigger3 := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger3.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_set_performable_not_in_reverse() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window))
	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))

	// Performable trigger should not replace reverse mapping
	s.put_flags(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) }, Action.new(.new_window), Flags{ performable: true })
	trigger2 := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger2.key == TriggerKey.new_unicode(u32(`a`))

	// Removal of performable should do nothing to reverse
	s.remove(Trigger{ key: TriggerKey.new_unicode(u32(`b`)) })
	trigger3 := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger3.key == TriggerKey.new_unicode(u32(`a`))
}

fn test_set_overriding_updates_reverse() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window))
	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))

	// Override with different action should remove old reverse
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_tab))
	t := s.get_trigger(Action.new(.new_window))
	assert t == none
}

fn test_set_consumed_state() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window))
	entry1 := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert entry1.value.typ == .leaf
	assert entry1.value.leaf_flags.consumed

	s.put_flags(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window), Flags{ consumed: false })
	entry2 := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert !entry2.value.leaf_flags.consumed

	s.put(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }, Action.new(.new_window))
	entry3 := s.get(Trigger{ key: TriggerKey.new_unicode(u32(`a`)) }) or { panic('not found') }
	assert entry3.value.leaf_flags.consumed
}

// --- getEvent tests ---

fn test_set_get_event_physical() {
	mut s := Set{}
	s.parse_and_put('ctrl+quote=new_window') or { panic(err.msg()) }

	// Physical matches on physical
	entry := s.get_event(KeyEvent{ key: .quote, mods: Mods{ ctrl: true } }) or {
		panic('not found')
	}
	assert entry.value.leaf_action.tag == .new_window

	// Physical does not match on UTF-8/codepoint
	r := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods{ ctrl: true }
		utf8: "'"
		unshifted_codepoint: u32(`'`)
	})
	assert r == none
}

fn test_set_get_event_codepoint() {
	mut s := Set{}
	s.parse_and_put("ctrl+'=new_window") or { panic(err.msg()) }

	// Matches on codepoint
	entry := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods{ ctrl: true }
		unshifted_codepoint: u32(`'`)
	}) or { panic('not found') }
	assert entry.value.leaf_action.tag == .new_window

	// Matches on UTF-8
	entry2 := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods{ ctrl: true }
		utf8: "'"
	}) or { panic('not found') }
	assert entry2.value.leaf_action.tag == .new_window

	// Doesn't match on physical
	r := s.get_event(KeyEvent{ key: .key_a, mods: Mods{ ctrl: true } })
	assert r == none
}

fn test_set_get_event_case_folding() {
	mut s := Set{}
	s.parse_and_put('ctrl+A=new_window') or { panic(err.msg()) }

	// Lowercase codepoint
	entry := s.get_event(KeyEvent{
		key: .key_j
		mods: Mods{ ctrl: true }
		unshifted_codepoint: u32(`a`)
	}) or { panic('not found') }
	assert entry.value.leaf_action.tag == .new_window

	// Uppercase codepoint
	entry2 := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods{ ctrl: true }
		unshifted_codepoint: u32(`A`)
	}) or { panic('not found') }
	assert entry2.value.leaf_action.tag == .new_window

	// Negative case for sanity
	r := s.get_event(KeyEvent{ key: .key_j, mods: Mods{ ctrl: true } })
	assert r == none
}

fn test_set_get_event_catch_all_fallback() {
	mut s := Set{}
	s.parse_and_put('catch_all=ignore') or { panic(err.msg()) }

	// Matches unbound key without modifiers
	entry := s.get_event(KeyEvent{ key: .key_a }) or { panic('not found') }
	assert entry.value.leaf_action.tag == .ignore

	// Matches unbound key with modifiers (falls back to catch_all without mods)
	entry2 := s.get_event(KeyEvent{ key: .key_a, mods: Mods{ ctrl: true } }) or {
		panic('not found')
	}
	assert entry2.value.leaf_action.tag == .ignore

	// Specific binding takes precedence over catch_all
	s.parse_and_put('ctrl+b=new_window') or { panic(err.msg()) }
	entry3 := s.get_event(KeyEvent{
		key: .key_b
		mods: Mods{ ctrl: true }
		unshifted_codepoint: u32(`b`)
	}) or { panic('not found') }
	assert entry3.value.leaf_action.tag == .new_window
}

fn test_set_get_event_catch_all_with_mods() {
	mut s := Set{}
	s.parse_and_put('ctrl+catch_all=close_surface') or { panic(err.msg()) }
	s.parse_and_put('catch_all=ignore') or { panic(err.msg()) }

	// Key with ctrl matches catch_all with ctrl modifier
	entry := s.get_event(KeyEvent{ key: .key_a, mods: Mods{ ctrl: true } }) or {
		panic('not found')
	}
	assert entry.value.leaf_action.tag == .close_surface

	// Key without mods matches catch_all without mods
	entry2 := s.get_event(KeyEvent{ key: .key_a }) or { panic('not found') }
	assert entry2.value.leaf_action.tag == .ignore

	// Key with different mods falls back to catch_all without mods
	entry3 := s.get_event(KeyEvent{ key: .key_a, mods: Mods{ alt: true } }) or {
		panic('not found')
	}
	assert entry3.value.leaf_action.tag == .ignore
}

// --- Font size parse tests ---

fn test_parse_increase_font_size() {
	b := parse_single('a=increase_font_size:1.5') or { panic(err.msg()) }
	assert b.action.tag == .increase_font_size
	assert b.action.float_param == f32(1.5)
}

fn test_parse_decrease_font_size() {
	b := parse_single('a=decrease_font_size:2.5') or { panic(err.msg()) }
	assert b.action.tag == .decrease_font_size
	assert b.action.float_param == f32(2.5)
}

fn test_parse_reset_font_size() {
	b := parse_single('a=reset_font_size') or { panic(err.msg()) }
	assert b.action.tag == .reset_font_size
}

fn test_parse_set_font_size() {
	b := parse_single('a=set_font_size:13.5') or { panic(err.msg()) }
	assert b.action.tag == .set_font_size
	assert b.action.float_param == f32(13.5)
}

// --- Copy to clipboard tests ---

fn test_parse_copy_to_clipboard_default() {
	b := parse_single('a=copy_to_clipboard') or { panic(err.msg()) }
	assert b.action.tag == .copy_to_clipboard
	assert b.action.enum_param == i32(CopyToClipboard.mixed)
}

fn test_parse_copy_to_clipboard_explicit() {
	b := parse_single('a=copy_to_clipboard:html') or { panic(err.msg()) }
	assert b.action.tag == .copy_to_clipboard
	assert b.action.enum_param == i32(CopyToClipboard.html)
}

// --- Write screen file tests ---

fn test_parse_write_screen_file_no_format() {
	b := parse_single('a=write_screen_file:copy') or { panic(err.msg()) }
	assert b.action.tag == .write_screen_file
	assert b.action.enum_param == i32(WriteScreenAction.copy)
	assert b.action.enum_param2 == i32(WriteScreenFormat.plain)
}

fn test_parse_write_screen_file_format() {
	b := parse_single('a=write_screen_file:copy,html') or { panic(err.msg()) }
	assert b.action.tag == .write_screen_file
	assert b.action.enum_param == i32(WriteScreenAction.copy)
	assert b.action.enum_param2 == i32(WriteScreenFormat.html)
}

fn test_parse_write_screen_file_invalid() {
	parse_single('a=write_screen_file:') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_write_screen_file_invalid_empty_comma() {
	parse_single('a=write_screen_file:,') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_write_screen_file_invalid_trailing_comma() {
	parse_single('a=write_screen_file:copy,') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_write_screen_file_invalid_extra() {
	parse_single('a=write_screen_file:copy,html,extra') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- SplitFocusDirection parse test ---

fn test_split_focus_direction_parse() {
	assert parse_split_focus_direction('previous')! == .previous
	assert parse_split_focus_direction('next')! == .next
	assert parse_split_focus_direction('up')! == .up
	assert parse_split_focus_direction('left')! == .left
	assert parse_split_focus_direction('down')! == .down
	assert parse_split_focus_direction('right')! == .right
	// Backwards compat
	assert parse_split_focus_direction('top')! == .up
	assert parse_split_focus_direction('bottom')! == .down

	parse_split_focus_direction('') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_split_focus_direction_parse_invalid() {
	parse_split_focus_direction('green') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

// --- Action clone/equal tests ---

fn test_action_equal_void() {
	a := Action.new(.ignore)
	b := Action.new(.ignore)
	assert a.equal(b)
}

fn test_action_equal_string() {
	a := Action.new_str(.text, 'foo')
	b := Action.new_str(.text, 'foo')
	assert a.equal(b)
}

fn test_action_not_equal_tag() {
	a := Action.new(.ignore)
	b := Action.new(.unbind)
	assert !a.equal(b)
}

fn test_set_put_overwrites_sequence() {
	mut s := Set{}
	s.parse_and_put('ctrl+a>b=new_window') or { panic(err.msg()) }
	s.put(Trigger{
		mods: Mods{ ctrl: true }
		key: TriggerKey.new_unicode(u32(`a`))
	}, Action.new(.new_window))

	trigger := s.get_trigger(Action.new(.new_window)) or { panic('not found') }
	assert trigger.key == TriggerKey.new_unicode(u32(`a`))
}
