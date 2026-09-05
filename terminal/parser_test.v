module terminal

// Tests for the VT parser (VTParser.next) behavior.
//
// Source: src/terminal/Parser.zig `test "..."` blocks.
//
// Ghostty's `next()` returns `[3]?Action` (exit, transition, entry actions,
// each optionally null). Witty's `next()` returns a flat `[]ParserAction`
// list that only contains the non-null actions produced for that byte (plus
// possibly a single `.none` sentinel from build_csi_action when a colon
// separator is used with a non-'m' final byte).
//
// To translate faithfully we collapse the ghostty triple into "the single
// meaningful action produced by this byte", and assert on its type/contents.

// dispatch_actions filters a next() result down to the "meaningful" actions,
// dropping the `.none` sentinel that witty's build_csi_action can emit.
fn dispatch_actions(actions []ParserAction) []ParserAction {
	mut out := []ParserAction{}
	for a in actions {
		if a.action_type != .none {
			out << a
		}
	}
	return out
}

// ============================================================
// test {} (unnamed): C1 8-bit controls + print + execute
// ============================================================
fn test_c1_sos_st_print_execute() {
	mut p := VTParser{}
	p.next(0x9E) // PM (C1) -> sos_pm_apc_string
	assert p.state == .sos_pm_apc_string
	p.next(0x9C) // ST (C1) -> ground
	assert p.state == .ground

	{
		a := dispatch_actions(p.next(u8(`a`)))
		assert p.state == .ground
		assert a.len == 1
		assert a[0].action_type == .print_action
		assert a[0].char == u32(`a`)
	}

	{
		a := dispatch_actions(p.next(0x19))
		assert p.state == .ground
		assert a.len == 1
		assert a[0].action_type == .execute_action
		assert a[0].byte_val == 0x19
	}
}

// ============================================================
// esc: ESC ( B
// ============================================================
fn test_esc_paren_b() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`(`))

	a := dispatch_actions(p.next(u8(`B`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .esc_dispatch_action
	d := a[0].esc
	assert d.final_byte == u8(`B`)
	assert d.intermediates.len == 1
	assert d.intermediates[0] == u8(`(`)
}

// ============================================================
// csi: ESC [ H
// ============================================================
fn test_csi_esc_bracket_h() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(0x5B)

	a := dispatch_actions(p.next(0x48))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == 0x48
	assert d.params.len == 0
}

// ============================================================
// csi: ESC [ 1 ; 4 H
// ============================================================
fn test_csi_esc_bracket_1_4_h() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(0x5B)
	p.next(0x31) // 1
	p.next(0x3B) // ;
	p.next(0x34) // 4

	a := dispatch_actions(p.next(0x48)) // H
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`H`)
	assert d.params.len == 2
	assert d.params[0] == u16(1)
	assert d.params[1] == u16(4)
}

// ============================================================
// csi: SGR ESC [ 38 : 2 m
// ============================================================
fn test_csi_sgr_38_colon_2_m() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`[`))
	p.next(u8(`3`))
	p.next(u8(`8`))
	p.next(u8(`:`))
	p.next(u8(`2`))

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 2
	assert d.params[0] == u16(38)
	assert d.params_sep.is_set(0)
	assert d.params[1] == u16(2)
	assert !d.params_sep.is_set(1)
}

// ============================================================
// csi: SGR colon followed by semicolon
// ============================================================
fn test_csi_sgr_colon_then_semicolon() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[48:2'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	{
		a := dispatch_actions(p.next(u8(`m`)))
		assert p.state == .ground
		assert a.len == 1
		assert a[0].action_type == .csi_dispatch_action
	}

	p.next(0x1B)
	p.next(u8(`[`))
	{
		a := dispatch_actions(p.next(u8(`H`)))
		assert p.state == .ground
		assert a.len == 1
		assert a[0].action_type == .csi_dispatch_action
	}
}

// ============================================================
// csi: SGR mixed colon and semicolon
// ============================================================
fn test_csi_sgr_mixed_colon_semicolon() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[38:5:1;48:5:0'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
}

// ============================================================
// csi: SGR ESC [ 48 : 2 m  (48:2:240:143:104)
// ============================================================
fn test_csi_sgr_48_colon_full() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[48:2:240:143:104'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 5
	assert d.params[0] == u16(48)
	assert d.params_sep.is_set(0)
	assert d.params[1] == u16(2)
	assert d.params_sep.is_set(1)
	assert d.params[2] == u16(240)
	assert d.params_sep.is_set(2)
	assert d.params[3] == u16(143)
	assert d.params_sep.is_set(3)
	assert d.params[4] == u16(104)
	assert !d.params_sep.is_set(4)
}

// ============================================================
// csi: SGR ESC [4:3m colon
// ============================================================
fn test_csi_sgr_4_colon_3_m() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`[`))
	p.next(u8(`4`))
	p.next(u8(`:`))
	p.next(u8(`3`))

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 2
	assert d.params[0] == u16(4)
	assert d.params_sep.is_set(0)
	assert d.params[1] == u16(3)
	assert !d.params_sep.is_set(1)
}

// ============================================================
// csi: SGR with many blank and colon  (58:2::240:143:104)
// ============================================================
fn test_csi_sgr_many_blank_and_colon() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[58:2::240:143:104'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 6
	assert d.params[0] == u16(58)
	assert d.params_sep.is_set(0)
	assert d.params[1] == u16(2)
	assert d.params_sep.is_set(1)
	assert d.params[2] == u16(0)
	assert d.params_sep.is_set(2)
	assert d.params[3] == u16(240)
	assert d.params_sep.is_set(3)
	assert d.params[4] == u16(143)
	assert d.params_sep.is_set(4)
	assert d.params[5] == u16(104)
	assert !d.params_sep.is_set(5)
}

// ============================================================
// csi: SGR mixed colon and semicolon with blank (Kakoune)
// [;4:3;38;2;175;175;215;58:2::190:80:70
// ============================================================
fn test_csi_sgr_mixed_with_blank() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[;4:3;38;2;175;175;215;58:2::190:80:70'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 14
	assert d.params[0] == u16(0)
	assert !d.params_sep.is_set(0)
	assert d.params[1] == u16(4)
	assert d.params_sep.is_set(1)
	assert d.params[2] == u16(3)
	assert !d.params_sep.is_set(2)
	assert d.params[3] == u16(38)
	assert !d.params_sep.is_set(3)
	assert d.params[4] == u16(2)
	assert !d.params_sep.is_set(4)
	assert d.params[5] == u16(175)
	assert !d.params_sep.is_set(5)
	assert d.params[6] == u16(175)
	assert !d.params_sep.is_set(6)
	assert d.params[7] == u16(215)
	assert !d.params_sep.is_set(7)
	assert d.params[8] == u16(58)
	assert d.params_sep.is_set(8)
	assert d.params[9] == u16(2)
	assert d.params_sep.is_set(9)
	assert d.params[10] == u16(0)
	assert d.params_sep.is_set(10)
	assert d.params[11] == u16(190)
	assert d.params_sep.is_set(11)
	assert d.params[12] == u16(80)
	assert d.params_sep.is_set(12)
	assert d.params[13] == u16(70)
	assert !d.params_sep.is_set(13)
}

// ============================================================
// csi: SGR mixed colon and semicolon setting underline, bg, fg (Kakoune)
// [4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136
// ============================================================
fn test_csi_sgr_mixed_underline_bg_fg() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[4:3;38;2;51;51;51;48;2;170;170;170;58;2;255;97;136'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`m`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`m`)
	assert d.params.len == 17
	assert d.params[0] == u16(4)
	assert d.params_sep.is_set(0)
	assert d.params[1] == u16(3)
	assert !d.params_sep.is_set(1)
	assert d.params[2] == u16(38)
	assert !d.params_sep.is_set(2)
	assert d.params[3] == u16(2)
	assert !d.params_sep.is_set(3)
	assert d.params[4] == u16(51)
	assert !d.params_sep.is_set(4)
	assert d.params[5] == u16(51)
	assert !d.params_sep.is_set(5)
	assert d.params[6] == u16(51)
	assert !d.params_sep.is_set(6)
	assert d.params[7] == u16(48)
	assert !d.params_sep.is_set(7)
	assert d.params[8] == u16(2)
	assert !d.params_sep.is_set(8)
	assert d.params[9] == u16(170)
	assert !d.params_sep.is_set(9)
	assert d.params[10] == u16(170)
	assert !d.params_sep.is_set(10)
	assert d.params[11] == u16(170)
	assert !d.params_sep.is_set(11)
	assert d.params[12] == u16(58)
	assert !d.params_sep.is_set(12)
	assert d.params[13] == u16(2)
	assert !d.params_sep.is_set(13)
	assert d.params[14] == u16(255)
	assert !d.params_sep.is_set(14)
	assert d.params[15] == u16(97)
	assert !d.params_sep.is_set(15)
	assert d.params[16] == u16(136)
	assert !d.params_sep.is_set(16)
}

// ============================================================
// csi: colon for non-m final -> sequence dropped, back to ground
// ============================================================
fn test_csi_colon_for_non_m_final() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[38:2h'.bytes() {
		a := dispatch_actions(p.next(c))
		assert a.len == 0
	}

	assert p.state == .ground
}

// ============================================================
// csi: request mode decrqm  ([?2026$p)
// ============================================================
fn test_csi_request_mode_decrqm() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[?2026\$'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`p`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`p`)
	assert d.intermediates.len == 2
	assert d.params.len == 1
	assert d.intermediates[0] == u8(`?`)
	assert d.intermediates[1] == u8(`$`)
	assert d.params[0] == u16(2026)
}

// ============================================================
// csi: change cursor ([3 q)
// ============================================================
fn test_csi_change_cursor() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in '[3 '.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`q`)))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .csi_dispatch_action
	d := a[0].csi
	assert d.final_byte == u8(`q`)
	assert d.intermediates.len == 1
	assert d.params.len == 1
	assert d.intermediates[0] == u8(` `)
	assert d.params[0] == u16(3)
}

// ============================================================
// osc: change window title (BEL terminated)
// ============================================================
fn test_osc_change_window_title() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`]`))
	p.next(u8(`0`))
	p.next(u8(`;`))
	p.next(u8(`a`))
	p.next(u8(`b`))
	p.next(u8(`c`))

	a := dispatch_actions(p.next(0x07)) // BEL
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .osc_dispatch_action
	cmd := a[0].osc
	assert cmd.cmd_type == .change_window_title
	assert cmd.data == 'abc'
}

// ============================================================
// osc: change window title (end in esc)
// ============================================================
fn test_osc_change_window_title_end_in_esc() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`]`))
	p.next(u8(`0`))
	p.next(u8(`;`))
	p.next(u8(`a`))
	p.next(u8(`b`))
	p.next(u8(`c`))

	a := dispatch_actions(p.next(0x1B))
	p.next(u8(`\\`))
	assert p.state == .ground
	assert a.len == 1
	assert a[0].action_type == .osc_dispatch_action
	cmd := a[0].osc
	assert cmd.cmd_type == .change_window_title
	assert cmd.data == 'abc'
}

fn test_osc_color_operation_preserves_bel_terminator() {
	mut p := VTParser{}
	for byte_val in '\x1b]10;?'.bytes() {
		p.next(byte_val)
	}
	a := dispatch_actions(p.next(0x07))
	assert a.len == 1
	assert a[0].osc.cmd_type == .color_operation
	assert a[0].osc.terminator == .bel
}

fn test_osc_kitty_color_preserves_st_terminator() {
	mut p := VTParser{}
	for byte_val in '\x1b]21;foreground=?'.bytes() {
		p.next(byte_val)
	}
	a := dispatch_actions(p.next(0x1b))
	p.next(u8(`\\`))
	assert a.len == 1
	assert a[0].osc.cmd_type == .kitty_color_protocol
	assert a[0].osc.terminator == .st
}

// ============================================================
// csi: too many params -> dropped
// ============================================================
fn test_csi_too_many_params() {
	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`[`))
	for _ in 0 .. 100 {
		p.next(u8(`1`))
		p.next(u8(`;`))
	}
	p.next(u8(`1`))

	a := dispatch_actions(p.next(u8(`C`)))
	assert p.state == .ground
	assert a.len == 0
}

// ============================================================
// csi: sgr with up to our max parameters
// ============================================================
fn test_csi_sgr_up_to_max_params() {
	for max in 1 .. max_params + 1 {
		mut p := VTParser{}
		p.next(0x1B)
		p.next(u8(`[`))

		for _ in 0 .. max - 1 {
			p.next(u8(`1`))
			p.next(u8(`;`))
		}
		p.next(u8(`2`))

		a := dispatch_actions(p.next(u8(`H`)))
		assert p.state == .ground
		assert a.len == 1
		assert a[0].action_type == .csi_dispatch_action
		csi := a[0].csi
		assert csi.params.len == max
		assert csi.params[max - 1] == u16(2)
	}
}

// ============================================================
// csi: sgr beyond our max drops it
// ============================================================
fn test_csi_sgr_beyond_max_drops() {
	max := max_params + 2

	mut p := VTParser{}
	p.next(0x1B)
	p.next(u8(`[`))

	for _ in 0 .. max - 1 {
		p.next(u8(`1`))
		p.next(u8(`;`))
	}
	p.next(u8(`2`))

	a := dispatch_actions(p.next(u8(`H`)))
	assert p.state == .ground
	assert a.len == 0
}

// ============================================================
// dcs: XTGETTCAP  (P+q)
// ============================================================
fn test_dcs_xtgettcap() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in 'P+'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`q`)))
	assert p.state == .dcs_passthrough
	assert a.len == 1
	assert a[0].action_type == .dcs_hook_action
	hook := a[0].dcs
	assert hook.intermediates == [u8(`+`)]
	assert hook.params.len == 0
	assert hook.final_byte == u8(`q`)
}

// ============================================================
// dcs: params  (P1000p)
// ============================================================
fn test_dcs_params() {
	mut p := VTParser{}
	p.next(0x1B)
	for c in 'P1000'.bytes() {
		a := p.next(c)
		assert dispatch_actions(a).len == 0
	}

	a := dispatch_actions(p.next(u8(`p`)))
	assert p.state == .dcs_passthrough
	assert a.len == 1
	assert a[0].action_type == .dcs_hook_action
	hook := a[0].dcs
	assert hook.params == [u16(1000)]
	assert hook.final_byte == u8(`p`)
}
