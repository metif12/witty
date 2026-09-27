module input

fn test_binding_source_tag_layouts_and_ordinals() {
	// Trigger.Key is explicitly tagged by its C enum in Ghostty.
	assert sizeof(TriggerKeyTag) == 4
	assert [TriggerKeyTag.physical, .unicode, .catch_all].map(i32(it)) == [i32(0), 1, 2]

	// Action is a source-inferred 83-case tagged union (u7 in Zig).
	assert sizeof(ActionTag) == 1
	mut action_count := 0
	$for enum_value in ActionTag.values {
		assert u8(enum_value.value) == u8(action_count)
		action_count++
	}
	assert action_count == 83
	assert u8(ActionTag.ignore) == 0
	assert u8(ActionTag.crash) == 82

	assert sizeof(SplitDirection) == 1
	assert [SplitDirection.right, .down, .left, .up, .auto_].map(u8(it)) == [u8(0), 1, 2, 3, 4]
	assert sizeof(SplitFocusDirection) == 1
	assert [SplitFocusDirection.previous, .next, .up, .left, .down, .right].map(u8(it)) == [
		u8(0),
		1,
		2,
		3,
		4,
		5,
	]
	assert sizeof(GotoWindow) == 1
	assert [GotoWindow.previous, .next].map(u8(it)) == [u8(0), 1]
	assert sizeof(NavigateSearch) == 1
	assert [NavigateSearch.previous, .next].map(u8(it)) == [u8(0), 1]
	assert sizeof(AdjustSelection) == 1
	assert [AdjustSelection.left, .right, .up, .down, .page_up, .page_down, .home, .end_,
		.beginning_of_line, .end_of_line].map(u8(it)) == [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9]
	assert sizeof(SplitResizeDirection) == 1
	assert [SplitResizeDirection.up, .down, .left, .right].map(u8(it)) == [u8(0), 1, 2, 3]
	assert sizeof(CopyToClipboard) == 1
	assert [CopyToClipboard.plain, .vt, .html, .mixed].map(u8(it)) == [u8(0), 1, 2, 3]
	assert sizeof(WriteScreenAction) == 1
	assert [WriteScreenAction.copy, .paste, .open].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(WriteScreenFormat) == 1
	assert [WriteScreenFormat.plain, .vt, .html].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(InspectorMode) == 1
	assert [InspectorMode.toggle, .show, .hide].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(CloseTabMode) == 1
	assert [CloseTabMode.this, .other, .right].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(CrashThread) == 1
	assert [CrashThread.main_thread, .io, .render].map(u8(it)) == [u8(0), 1, 2]
	assert sizeof(ActionScope) == 1
	assert [ActionScope.app, .surface].map(u8(it)) == [u8(0), 1]

}

fn test_action_scoped_filters_scope_and_preserves_payload() {
	app_action := Action(ActionNewWindow{})
	app_scoped := app_action.scoped(.app) or { panic('new_window must be app-scoped') }
	assert app_scoped.equal(app_action)
	assert app_action.scoped(.surface) == none

	surface_action := Action(ActionGotoTab{ value: 42 })
	surface_scoped := surface_action.scoped(.surface) or {
		panic('goto_tab must be surface-scoped')
	}
	assert surface_scoped.equal(surface_action)
	assert (surface_scoped as ActionGotoTab).value == 42
	assert surface_action.scoped(.app) == none
}

// --- Flags tests ---

fn test_flags_cval_default() {
	f := Flags{}
	assert f.cval() == u8(0b0001)
}

fn test_flags_cval_not_consumed() {
	f := Flags.init(false, false, false, false)
	assert f.cval() == u8(0b0000)
}

fn test_flags_cval_all() {
	f := Flags.init(true, true, false, false)
	assert f.cval() == u8(0b0011)
}

fn test_flags_cval_global() {
	f := Flags.init(true, false, true, false)
	assert f.cval() == u8(0b0101)
}

fn test_flags_cval_performable() {
	f := Flags.init(true, false, false, true)
	assert f.cval() == u8(0b1001)
}

fn test_flags_cval_all_set() {
	f := Flags.init(true, true, true, true)
	assert sizeof(Flags) == 1
	assert f.cval() == u8(0b1111)
}

// --- Trigger parse tests ---

fn test_parse_single_character() {
	b := parse_single('a=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.action.tag() == .ignore
}

fn test_parse_single_modifier() {
	b := parse_single('shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.action.tag() == .ignore

	b2 := parse_single('ctrl+a=ignore') or { panic(err.msg()) }
	assert b2.trigger.mods.ctrl() == true
	assert b2.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_parse_multiple_modifiers() {
	b := parse_single('shift+ctrl+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.mods.ctrl() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_parse_key_before_modifier() {
	b := parse_single('a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_parse_physical_keys() {
	b := parse_single('shift+key_a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyPhysical{ key: .key_a })
}

fn test_parse_unicode_keys() {
	b := parse_single('shift+ö=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key.tag() == .unicode
	// ö is U+00F6
	assert (b.trigger.key as TriggerKeyUnicode).codepoint == 0xF6
}

fn test_parse_unconsumed_keys() {
	b := parse_single('unconsumed:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.consumed() == false
}

fn test_parse_unconsumed_physical_keys() {
	b := parse_single('unconsumed:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyPhysical{ key: .key_a })
	assert b.flags.consumed() == false
}

fn test_parse_performable_keys() {
	b := parse_single('performable:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.performable() == true
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
	assert b.trigger.key == TriggerKey(TriggerKeyPhysical{ key: .key_a })
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
	assert b.trigger.key == TriggerKey(TriggerKeyCatchAll{})
}

fn test_parse_catch_all_with_modifiers() {
	b := parse_single('ctrl+catch_all=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.ctrl() == true
	assert b.trigger.key == TriggerKey(TriggerKeyCatchAll{})
}

// --- Plus sign tests ---

fn test_parse_plus_sign() {
	b := parse_single('+=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`+`) })
}

fn test_parse_plus_with_modifier() {
	b := parse_single('ctrl++=ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`+`) })
	assert b.trigger.mods.ctrl() == true
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
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert b.action.tag() == .ignore
}

fn test_parse_equals_with_modifier() {
	b := parse_single('ctrl+==ignore') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert b.trigger.mods.ctrl() == true
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
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert b.action.tag() == .text
	assert (b.action as ActionText).value == '='
}

fn test_parse_text_action_equals_2() {
	b := parse_single('==text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert (b.action as ActionText).value == '=hello'
}

fn test_parse_text_action_equals_ctrl() {
	b := parse_single('ctrl+==text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert b.trigger.mods.ctrl() == true
	assert (b.action as ActionText).value == '=hello'
}

fn test_parse_text_action_equals_after() {
	b := parse_single('=+ctrl=text:=hello') or { panic(err.msg()) }
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`=`) })
	assert b.trigger.mods.ctrl() == true
	assert (b.action as ActionText).value == '=hello'
}

// --- Global trigger tests ---

fn test_parse_global() {
	b := parse_single('global:shift+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.global() == true
}

fn test_parse_global_physical() {
	b := parse_single('global:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyPhysical{ key: .key_a })
	assert b.flags.global() == true
}

fn test_parse_global_unconsumed() {
	b := parse_single('unconsumed:global:a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.global() == true
	assert b.flags.consumed() == false
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
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.all() == true
}

fn test_parse_all_physical() {
	b := parse_single('all:key_a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyPhysical{ key: .key_a })
	assert b.flags.all() == true
}

fn test_parse_all_unconsumed() {
	b := parse_single('unconsumed:all:a+shift=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.shift() == true
	assert b.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert b.flags.all() == true
	assert b.flags.consumed() == false
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
	assert b.trigger.mods.super_() == true
}

fn test_parse_modifier_command() {
	b := parse_single('command+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.super_() == true
}

fn test_parse_modifier_opt() {
	b := parse_single('opt+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.alt() == true
}

fn test_parse_modifier_option() {
	b := parse_single('option+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.alt() == true
}

fn test_parse_modifier_control() {
	b := parse_single('control+a=ignore') or { panic(err.msg()) }
	assert b.trigger.mods.ctrl() == true
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
	assert b.action.tag() == .ignore

	parse_single('a=ignore:A') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_with_string() {
	b := parse_single('a=csi:A') or { panic(err.msg()) }
	assert b.action.tag() == .csi
	assert (b.action as ActionCsi).value == 'A'

	b2 := parse_single('a=esc:A') or { panic(err.msg()) }
	assert b2.action.tag() == .esc
	assert (b2.action as ActionEsc).value == 'A'
}

fn test_cursor_key_action_preserves_both_mode_sequences() {
	a := Action(ActionCursorKey{ value: CursorKey{ normal: '\x1b[A', application: '\x1bOA' } })
	assert a.tag() == .cursor_key
	assert (a as ActionCursorKey).value.normal == '\x1b[A'
	assert (a as ActionCursorKey).value.application == '\x1bOA'
	assert a == Action(ActionCursorKey{ value: CursorKey{ normal: '\x1b[A', application: '\x1bOA' } })
	assert a != Action(ActionCursorKey{ value: CursorKey{ normal: '\x1b[B', application: '\x1bOB' } })
	assert a.hash() == Action(ActionCursorKey{ value: CursorKey{ normal: '\x1b[A', application: '\x1bOA' } }).hash()
}

fn test_action_hash_matches_source() {
	assert Action(ActionIgnore{}).hash() == u64(0xfbe5af10e5f8bd85)
	assert Action(ActionText{ value: 'abc' }).hash() == u64(0x446a0ccfa67b40b6)
	assert Action(ActionCursorKey{ value: CursorKey{ normal: 'n', application: 'app' } }).hash() == u64(0x83c43b380350b294)
	assert Action(ActionIncreaseFontSize{ value: 1.5 }).hash() == u64(0x5df7f994230ca39e)
	assert Action(ActionJumpToPrompt{ value: -2 }).hash() == u64(0x58fdaa6fac1852cd)
	assert Action(ActionMoveTab{ value: -2 }).hash() == u64(0xc553742d08889d48)
	assert Action(ActionResizeSplit{ value: SplitResizeParameter{ direction: .right, amount: 250 } }).hash() == u64(0xd6c681ebcbe9b6f0)
}

fn test_trigger_hash_matches_source() {
	physical := Trigger{
		key: TriggerKeyPhysical{ key: .key_a }
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}
	upper := Trigger{
		key: TriggerKeyUnicode{ codepoint: u32(`A`) }
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}
	lower := Trigger{
		key: TriggerKeyUnicode{ codepoint: u32(`a`) }
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
	}
	catch_all := Trigger{ key: TriggerKeyCatchAll{} }
	assert physical.hash() == u64(0x2ee14028a2f3cedb)
	assert upper.hash() == u64(0x56ae7c44db90aaf3)
	assert upper.hash() == lower.hash()
	assert catch_all.hash() == u64(0x938f13b1d9e2b68f)
}

fn test_trigger_full_unicode_case_folding() {
	assert full_case_fold_entries.len == 1557
	// Unicode 16 full case folding expands sharp S to two codepoints.
	assert folded_codepoint(0x00df) == [u32(`s`), u32(`s`), 0]!
	// Capital dotted I expands to i + combining dot above in non-Turkic mode.
	assert folded_codepoint(0x0130) == [u32(`i`), 0x0307, 0]!
	// Common one-to-one mappings and unmapped values retain fixed width.
	assert folded_codepoint(0x03a3) == [u32(0x03c3), 0, 0]!
	assert folded_codepoint(0x1f642) == [u32(0x1f642), 0, 0]!
}

fn test_parse_action_with_enum() {
	b := parse_single('a=new_split:right') or { panic(err.msg()) }
	assert b.action.tag() == .new_split
	assert (b.action as ActionNewSplit).value == .right
}

fn test_parse_action_with_enum_default() {
	b := parse_single('a=new_split') or { panic(err.msg()) }
	assert b.action.tag() == .new_split
	assert (b.action as ActionNewSplit).value == .auto_
}

fn test_parse_action_with_int() {
	b := parse_single('a=jump_to_prompt:-1') or { panic(err.msg()) }
	assert b.action.tag() == .jump_to_prompt
	assert (b.action as ActionJumpToPrompt).value == -1

	b2 := parse_single('a=jump_to_prompt:10') or { panic(err.msg()) }
	assert (b2.action as ActionJumpToPrompt).value == 10
}

fn test_parse_action_integer_widths_match_source() {
	assert (parse_single('a=jump_to_prompt:-32768')!.action as ActionJumpToPrompt).value == -32768
	assert (parse_single('a=scroll_page_lines:32_767')!.action as ActionScrollPageLines).value == 32767
	parse_single('a=jump_to_prompt:-32769') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_isize_width_matches_source() {
	assert (parse_single('a=move_tab:-9223372036854775808')!.action as ActionMoveTab).value == i64(-9223372036854775807) - 1
	assert (parse_single('a=move_tab:+9_223_372_036_854_775_807')!.action as ActionMoveTab).value == 9223372036854775807
	parse_single('a=move_tab:9223372036854775808') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_with_float() {
	b := parse_single('a=scroll_page_fractional:-0.5') or { panic(err.msg()) }
	assert b.action.tag() == .scroll_page_fractional
	assert (b.action as ActionScrollPageFractional).value == f32(-0.5)

	b2 := parse_single('a=scroll_page_fractional:+0.5') or { panic(err.msg()) }
	assert (b2.action as ActionScrollPageFractional).value == f32(0.5)

	b3 := parse_single('a=scroll_page_fractional:1_2.5') or { panic(err.msg()) }
	assert (b3.action as ActionScrollPageFractional).value == f32(12.5)
	b4 := parse_single('a=scroll_page_fractional:0x1p-1') or { panic(err.msg()) }
	assert (b4.action as ActionScrollPageFractional).value == f32(0.5)
	parse_single('a=scroll_page_fractional:1_.5') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_action_with_tuple() {
	b := parse_single('a=resize_split:up,10') or { panic(err.msg()) }
	assert b.action.tag() == .resize_split
	assert (b.action as ActionResizeSplit).value.direction == .up
	assert (b.action as ActionResizeSplit).value.amount == 10
}

fn test_parse_action_unsigned_widths_match_source() {
	assert (parse_single('a=goto_tab:+18_446_744_073_709_551_615')!.action as ActionGotoTab).value == u64(0xffffffffffffffff)
	assert (parse_single('a=scroll_to_row:-0')!.action as ActionScrollToRow).value == 0
	parse_single('a=goto_tab:18446744073709551616') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
}

fn test_parse_resize_split_u16_width_matches_source() {
	assert (parse_single('a=resize_split:right,65_535')!.action as ActionResizeSplit).value.amount == 65535
	parse_single('a=resize_split:right,65536') or {
		assert err.msg() == 'InvalidFormat'
		return
	}
	assert false
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
	assert elem is ParserElemChain
	assert (elem as ParserElemChain).action.tag() == .new_tab
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
	assert t.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	it.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_sequence_iterator_multi() {
	mut it := SequenceIterator{ input: 'a>b' }
	t1 := it.next() or { panic(err.msg()) }
	assert t1.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	t2 := it.next() or { panic(err.msg()) }
	assert t2.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`b`) })
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
	assert t.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
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
	assert elem is ParserElemBinding
	assert (elem as ParserElemBinding).binding.trigger.mods.ctrl() == true
	assert (elem as ParserElemBinding).binding.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	assert (elem as ParserElemBinding).binding.action.tag() == .ignore
	p.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

fn test_parse_sequence_two() {
	mut p := Parser.init('a>b=ignore') or { panic(err.msg()) }
	e1 := p.next() or { panic(err.msg()) }
	assert e1 is ParserElemLeader
	assert (e1 as ParserElemLeader).trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
	e2 := p.next() or { panic(err.msg()) }
	assert e2 is ParserElemBinding
	assert (e2 as ParserElemBinding).binding.trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`b`) })
	assert (e2 as ParserElemBinding).binding.action.tag() == .ignore
	p.next() or {
		assert err.msg() == 'done'
		return
	}
	assert false
}

// --- Trigger equal tests ---

fn test_trigger_equal_physical() {
	t1 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_up }, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }
	t2 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_up }, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }
	assert t1.equal(t2)
}

fn test_trigger_different_physical() {
	t1 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_up }, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }
	t2 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_down }, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }
	assert !t1.equal(t2)
}

fn test_trigger_different_mods() {
	t1 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_up }, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }
	t2 := Trigger{ key: TriggerKeyPhysical{ key: .arrow_up }, mods: Mods.init(true, false, false, false, false, false, SideInfo{}) }
	assert !t1.equal(t2)
}

fn test_trigger_equal_unicode() {
	t1 := Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }
	t2 := Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }
	assert t1.equal(t2)
}

fn test_trigger_different_unicode() {
	t1 := Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }
	t2 := Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }
	assert !t1.equal(t2)
}

fn test_trigger_different_key_types() {
	t1 := Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }
	t2 := Trigger{ key: TriggerKeyPhysical{ key: .key_a } }
	assert !t1.equal(t2)
}

fn test_trigger_catch_all_equal() {
	t1 := Trigger{ key: TriggerKeyCatchAll{} }
	t2 := Trigger{ key: TriggerKeyCatchAll{} }
	assert t1.equal(t2)
}

fn test_trigger_catch_all_different_mods() {
	t1 := Trigger{ key: TriggerKeyCatchAll{} }
	t2 := Trigger{ key: TriggerKeyCatchAll{}, mods: Mods.init(false, false, true, false, false, false, SideInfo{}) }
	assert !t1.equal(t2)
}

// --- Set tests ---

fn test_set_parse_and_put_typical() {
	mut s := Set{}
	s.parse_and_put('a=new_window') or { panic(err.msg()) }

	// Forward mapping
	entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert entry.value is Leaf
	assert (entry.value as Leaf).action.tag() == .new_window
	assert (entry.value as Leaf).flags == Flags{}

	// Reverse mapping
	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_set_parse_and_put_unconsumed() {
	mut s := Set{}
	s.parse_and_put('unconsumed:a=new_window') or { panic(err.msg()) }

	entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert entry.value is Leaf
	assert (entry.value as Leaf).action.tag() == .new_window
	assert (entry.value as Leaf).flags.consumed() == false

	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_set_parse_and_put_removed() {
	mut s := Set{}
	s.parse_and_put('a=new_window') or { panic(err.msg()) }
	s.parse_and_put('a=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } })
	assert r == none

	t := s.get_trigger(ActionNewWindow{})
	assert t == none
}

fn test_set_parse_and_put_sequence() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert a_entry.value is Leader
	inner := (a_entry.value as Leader).set

	b_entry := inner.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }) or { panic('not found') }
	assert b_entry.value is Leaf
	assert (b_entry.value as Leaf).action.tag() == .new_window
}

fn test_set_parse_and_put_sequence_two_actions() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }
	s.parse_and_put('a>c=new_tab') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert a_entry.value is Leader
	inner := (a_entry.value as Leader).set

	b_entry := inner.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }) or { panic('not found') }
	assert (b_entry.value as Leaf).action.tag() == .new_window

	c_entry := inner.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`c`) } }) or { panic('not found') }
	assert (c_entry.value as Leaf).action.tag() == .new_tab
}

fn test_set_parse_and_put_overwrite_sequence() {
	mut s := Set{}
	s.parse_and_put('a>b=new_tab') or { panic(err.msg()) }
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	inner := (a_entry.value as Leader).set

	b_entry := inner.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }) or { panic('not found') }
	assert (b_entry.value as Leaf).action.tag() == .new_window
}

fn test_set_parse_and_put_overwrite_leader() {
	mut s := Set{}
	s.parse_and_put('a=new_tab') or { panic(err.msg()) }
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }

	a_entry := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert a_entry.value is Leader
	inner := (a_entry.value as Leader).set

	b_entry := inner.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }) or { panic('not found') }
	assert (b_entry.value as Leaf).action.tag() == .new_window
}

fn test_set_parse_and_put_unbind_leader() {
	mut s := Set{}
	s.parse_and_put('a>b=new_window') or { panic(err.msg()) }
	s.parse_and_put('a>b=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } })
	assert r == none
}

fn test_set_parse_and_put_unbind_not_set() {
	mut s := Set{}
	s.parse_and_put('a>b=unbind') or { panic(err.msg()) }

	r := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } })
	assert r == none
}

fn test_set_maintains_reverse_mapping() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{})
	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })

	// Should be most recent
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }, ActionNewWindow{})
	trigger2 := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger2.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`b`) })

	// Removal should find another
	s.remove(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } })
	trigger3 := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger3.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_set_performable_not_in_reverse() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{})
	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })

	// Performable trigger should not replace reverse mapping
	s.put_flags(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } }, ActionNewWindow{}, Flags.init(true, false, false, true))
	trigger2 := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger2.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })

	// Removal of performable should do nothing to reverse
	s.remove(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`b`) } })
	trigger3 := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger3.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_set_overriding_updates_reverse() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{})
	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })

	// Override with different action should remove old reverse
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewTab{})
	t := s.get_trigger(ActionNewWindow{})
	assert t == none
}

fn test_set_consumed_state() {
	mut s := Set{}
	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{})
	entry1 := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert entry1.value is Leaf
	assert (entry1.value as Leaf).flags.consumed()

	s.put_flags(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{}, Flags.init(false, false, false, false))
	entry2 := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert !(entry2.value as Leaf).flags.consumed()

	s.put(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }, ActionNewWindow{})
	entry3 := s.get(Trigger{ key: TriggerKeyUnicode{ codepoint: u32(`a`) } }) or { panic('not found') }
	assert (entry3.value as Leaf).flags.consumed()
}

// --- getEvent tests ---

fn test_set_get_event_physical() {
	mut s := Set{}
	s.parse_and_put('ctrl+quote=new_window') or { panic(err.msg()) }

	// Physical matches on physical
	entry := s.get_event(KeyEvent{ key: .quote, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }) or {
		panic('not found')
	}
	assert (entry.value as Leaf).action.tag() == .new_window

	// Physical does not match on UTF-8/codepoint
	r := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
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
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		unshifted_codepoint: u32(`'`)
	}) or { panic('not found') }
	assert (entry.value as Leaf).action.tag() == .new_window

	// Matches on UTF-8
	entry2 := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		utf8: "'"
	}) or { panic('not found') }
	assert (entry2.value as Leaf).action.tag() == .new_window

	// Doesn't match on physical
	r := s.get_event(KeyEvent{ key: .key_a, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) })
	assert r == none
}

fn test_set_get_event_case_folding() {
	mut s := Set{}
	s.parse_and_put('ctrl+A=new_window') or { panic(err.msg()) }

	// Lowercase codepoint
	entry := s.get_event(KeyEvent{
		key: .key_j
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		unshifted_codepoint: u32(`a`)
	}) or { panic('not found') }
	assert (entry.value as Leaf).action.tag() == .new_window

	// Uppercase codepoint
	entry2 := s.get_event(KeyEvent{
		key: .key_a
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		unshifted_codepoint: u32(`A`)
	}) or { panic('not found') }
	assert (entry2.value as Leaf).action.tag() == .new_window

	// Negative case for sanity
	r := s.get_event(KeyEvent{ key: .key_j, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) })
	assert r == none
}

fn test_set_get_event_catch_all_fallback() {
	mut s := Set{}
	s.parse_and_put('catch_all=ignore') or { panic(err.msg()) }

	// Matches unbound key without modifiers
	entry := s.get_event(KeyEvent{ key: .key_a }) or { panic('not found') }
	assert (entry.value as Leaf).action.tag() == .ignore

	// Matches unbound key with modifiers (falls back to catch_all without mods)
	entry2 := s.get_event(KeyEvent{ key: .key_a, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }) or {
		panic('not found')
	}
	assert (entry2.value as Leaf).action.tag() == .ignore

	// Specific binding takes precedence over catch_all
	s.parse_and_put('ctrl+b=new_window') or { panic(err.msg()) }
	entry3 := s.get_event(KeyEvent{
		key: .key_b
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		unshifted_codepoint: u32(`b`)
	}) or { panic('not found') }
	assert (entry3.value as Leaf).action.tag() == .new_window
}

fn test_set_get_event_catch_all_with_mods() {
	mut s := Set{}
	s.parse_and_put('ctrl+catch_all=close_surface') or { panic(err.msg()) }
	s.parse_and_put('catch_all=ignore') or { panic(err.msg()) }

	// Key with ctrl matches catch_all with ctrl modifier
	entry := s.get_event(KeyEvent{ key: .key_a, mods: Mods.init(false, true, false, false, false, false, SideInfo{}) }) or {
		panic('not found')
	}
	assert (entry.value as Leaf).action.tag() == .close_surface

	// Key without mods matches catch_all without mods
	entry2 := s.get_event(KeyEvent{ key: .key_a }) or { panic('not found') }
	assert (entry2.value as Leaf).action.tag() == .ignore

	// Key with different mods falls back to catch_all without mods
	entry3 := s.get_event(KeyEvent{ key: .key_a, mods: Mods.init(false, false, true, false, false, false, SideInfo{}) }) or {
		panic('not found')
	}
	assert (entry3.value as Leaf).action.tag() == .ignore
}

// --- Font size parse tests ---

fn test_parse_increase_font_size() {
	b := parse_single('a=increase_font_size:1.5') or { panic(err.msg()) }
	assert b.action.tag() == .increase_font_size
	assert (b.action as ActionIncreaseFontSize).value == f32(1.5)
}

fn test_parse_decrease_font_size() {
	b := parse_single('a=decrease_font_size:2.5') or { panic(err.msg()) }
	assert b.action.tag() == .decrease_font_size
	assert (b.action as ActionDecreaseFontSize).value == f32(2.5)
}

fn test_parse_reset_font_size() {
	b := parse_single('a=reset_font_size') or { panic(err.msg()) }
	assert b.action.tag() == .reset_font_size
}

fn test_parse_set_font_size() {
	b := parse_single('a=set_font_size:13.5') or { panic(err.msg()) }
	assert b.action.tag() == .set_font_size
	assert (b.action as ActionSetFontSize).value == f32(13.5)
}

// --- Copy to clipboard tests ---

fn test_parse_copy_to_clipboard_default() {
	b := parse_single('a=copy_to_clipboard') or { panic(err.msg()) }
	assert b.action.tag() == .copy_to_clipboard
	assert (b.action as ActionCopyToClipboard).value == .mixed
}

fn test_parse_copy_to_clipboard_explicit() {
	b := parse_single('a=copy_to_clipboard:html') or { panic(err.msg()) }
	assert b.action.tag() == .copy_to_clipboard
	assert (b.action as ActionCopyToClipboard).value == .html
}

// --- Write screen file tests ---

fn test_parse_write_screen_file_no_format() {
	b := parse_single('a=write_screen_file:copy') or { panic(err.msg()) }
	assert b.action.tag() == .write_screen_file
	assert (b.action as ActionWriteScreenFile).value.action == .copy
	assert (b.action as ActionWriteScreenFile).value.emit == .plain
}

fn test_parse_write_screen_file_format() {
	b := parse_single('a=write_screen_file:copy,html') or { panic(err.msg()) }
	assert b.action.tag() == .write_screen_file
	assert (b.action as ActionWriteScreenFile).value.action == .copy
	assert (b.action as ActionWriteScreenFile).value.emit == .html
}

fn test_action_format_string_escapes_utf8() {
	a := Action(ActionText{ value: '👻' })
	assert a.format() == 'text:\\xf0\\x9f\\x91\\xbb'
}

fn test_action_format_all_parameter_shapes() {
	assert Action(ActionNewWindow{}).format() == 'new_window'
	assert Action(ActionIncreaseFontSize{ value: 1.5 }).format() == 'increase_font_size:1.5'
	assert Action(ActionJumpToPrompt{ value: -2 }).format() == 'jump_to_prompt:-2'
	assert Action(ActionGotoTab{ value: 4 }).format() == 'goto_tab:4'
	assert Action(ActionNewSplit{ value: .auto_ }).format() == 'new_split:auto'
	assert Action(ActionAdjustSelection{ value: .end_ }).format() == 'adjust_selection:end'
	assert Action(ActionCrash{ value: .main_thread }).format() == 'crash:main'
	assert Action(ActionResizeSplit{ value: SplitResizeParameter{ direction: .up, amount: 10 } }).format() == 'resize_split:up,10'
	assert Action(ActionWriteScreenFile{ value: WriteScreen{ action: .copy, emit: .html } }).format() == 'write_screen_file:copy,html'
}

fn test_move_tab_is_signed_and_formats() {
	b := parse_single('a=move_tab:-1') or { panic(err.msg()) }
	assert b.action.tag() == .move_tab
	assert (b.action as ActionMoveTab).value == -1
	assert b.action.format() == 'move_tab:-1'
}

fn test_set_format_entries_flattens_sequences_and_chains() {
	mut set := Set{}
	set.parse_and_put('ctrl+a>b=new_window') or { panic(err.msg()) }
	set.parse_and_put('chain=text:👻') or { panic(err.msg()) }
	assert set.format_entries() == [
		'ctrl+a>b=new_window',
		'chain=text:\\xf0\\x9f\\x91\\xbb',
	]
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
	a := Action(ActionIgnore{})
	b := Action(ActionIgnore{})
	assert a.equal(b)
}

fn test_action_equal_string() {
	a := Action(ActionText{ value: 'foo' })
	b := Action(ActionText{ value: 'foo' })
	assert a.equal(b)
}

fn test_action_not_equal_tag() {
	a := Action(ActionIgnore{})
	b := Action(ActionUnbind{})
	assert !a.equal(b)
}

fn test_set_put_overwrites_sequence() {
	mut s := Set{}
	s.parse_and_put('ctrl+a>b=new_window') or { panic(err.msg()) }
	s.put(Trigger{
		mods: Mods.init(false, true, false, false, false, false, SideInfo{})
		key: TriggerKeyUnicode{ codepoint: u32(`a`) }
	}, ActionNewWindow{})

	trigger := s.get_trigger(ActionNewWindow{}) or { panic('not found') }
	assert trigger.key == TriggerKey(TriggerKeyUnicode{ codepoint: u32(`a`) })
}

fn test_set_value_generic_leaf() {
	action := Action(ActionNewWindow{})
	value := SetValue(Leaf{
		action: action
		flags:  Flags.init(true, false, true, false)
	})
	leaf := value.generic() or { panic('leaf must have a generic view') }
	assert leaf.flags.global()
	assert leaf.actions is GenericLeafActionsSingle
	assert leaf.actions_slice().len == 1
	assert leaf.actions_slice()[0].equal(action)
}

fn test_set_value_generic_chained_leaf() {
	actions := [Action(ActionNewWindow{}), ActionNewTab{}]
	value := SetValue(LeafChained{
		actions: actions
		flags:   Flags.init(true, false, false, true)
	})
	leaf := value.generic() or { panic('chained leaf must have a generic view') }
	assert leaf.flags.performable()
	assert leaf.actions is GenericLeafActionsMany
	assert leaf.actions_slice().len == 2
	assert leaf.actions_slice()[0].equal(actions[0])
	assert leaf.actions_slice()[1].equal(actions[1])

	leader := SetValue(Leader{})
	assert leader.generic() == none
}
