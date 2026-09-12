module osc

// Tests for OSC 133 semantic prompt parsing.

fn test_osc133_end_input_start_output() {
	mut p := Parser.init(voidptr(0))
	input := '133;C'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_input_start_output
	assert read_aid(cmd.semantic_prompt_options) == none
	assert read_click(cmd.semantic_prompt_options) == none
}

fn test_osc133_end_input_start_output_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Cextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_end_input_start_output_with_options() {
	mut p := Parser.init(voidptr(0))
	input := '133;C;aid=foo'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_input_start_output
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
}

fn test_osc133_fresh_line() {
	mut p := Parser.init(voidptr(0))
	input := '133;L'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line
}

fn test_osc133_fresh_line_extra_contents() {
	// Random
	mut p1 := Parser.init(voidptr(0))
	input1 := '133;Lol'
	for ch in input1.bytes() {
		p1.next(ch)
	}
	assert p1.end(0) == none

	// Options
	mut p2 := Parser.init(voidptr(0))
	input2 := '133;L;aid=foo'
	for ch in input2.bytes() {
		p2.next(ch)
	}
	assert p2.end(0) == none
}

fn test_osc133_fresh_line_new_prompt() {
	mut p := Parser.init(voidptr(0))
	input := '133;A'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	assert read_aid(cmd.semantic_prompt_options) == none
	assert read_click(cmd.semantic_prompt_options) == none
}

fn test_osc133_fresh_line_new_prompt_with_aid() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;aid=14'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == '14'
}

fn test_osc133_fresh_line_new_prompt_with_eq_in_aid() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;aid=a=b'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'a=b'
}

fn test_osc133_fresh_line_new_prompt_with_cl_line() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;cl=line'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	cl := read_click(cmd.semantic_prompt_options) or {
		assert false, 'expected click'
		return
	}
	assert cl == .line
}

fn test_osc133_fresh_line_new_prompt_with_cl_m() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;cl=m'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	cl := read_click(cmd.semantic_prompt_options) or {
		assert false, 'expected click'
		return
	}
	assert cl == .multiple
}

fn test_osc133_fresh_line_new_prompt_with_invalid_cl() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;cl=invalid'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	assert read_click(cmd.semantic_prompt_options) == none
}

fn test_osc133_fresh_line_new_prompt_with_trailing_semicolon() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
}

fn test_osc133_fresh_line_new_prompt_with_bare_key() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;barekey'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	assert read_aid(cmd.semantic_prompt_options) == none
	assert read_click(cmd.semantic_prompt_options) == none
}

fn test_osc133_fresh_line_new_prompt_with_multiple_options() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;aid=foo;cl=line'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
	cl := read_click(cmd.semantic_prompt_options) or {
		assert false, 'expected click'
		return
	}
	assert cl == .line
}

fn test_osc133_fresh_line_new_prompt_default_redraw() {
	mut p := Parser.init(voidptr(0))
	input := '133;A'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	assert read_redraw(cmd.semantic_prompt_options) == none
}

fn test_osc133_fresh_line_new_prompt_with_redraw_0() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;redraw=0'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	rd := read_redraw(cmd.semantic_prompt_options) or {
		assert false, 'expected redraw'
		return
	}
	assert rd == .redraw_false
}

fn test_osc133_fresh_line_new_prompt_with_redraw_1() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;redraw=1'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	rd := read_redraw(cmd.semantic_prompt_options) or {
		assert false, 'expected redraw'
		return
	}
	assert rd == .redraw_true
}

fn test_osc133_fresh_line_new_prompt_with_invalid_redraw() {
	mut p := Parser.init(voidptr(0))
	input := '133;A;redraw=x'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .fresh_line_new_prompt
	assert read_redraw(cmd.semantic_prompt_options) == none
}

fn test_osc133_prompt_start() {
	mut p := Parser.init(voidptr(0))
	input := '133;P'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	assert read_prompt_kind(cmd.semantic_prompt_options) == none
}

fn test_osc133_prompt_start_with_k_i() {
	mut p := Parser.init(voidptr(0))
	input := '133;P;k=i'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	pk := read_prompt_kind(cmd.semantic_prompt_options) or {
		assert false, 'expected prompt_kind'
		return
	}
	assert pk == .initial
}

fn test_osc133_prompt_start_with_k_r() {
	mut p := Parser.init(voidptr(0))
	input := '133;P;k=r'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	pk := read_prompt_kind(cmd.semantic_prompt_options) or {
		assert false, 'expected prompt_kind'
		return
	}
	assert pk == .right
}

fn test_osc133_prompt_start_with_k_c() {
	mut p := Parser.init(voidptr(0))
	input := '133;P;k=c'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	pk := read_prompt_kind(cmd.semantic_prompt_options) or {
		assert false, 'expected prompt_kind'
		return
	}
	assert pk == .continuation
}

fn test_osc133_prompt_start_with_k_s() {
	mut p := Parser.init(voidptr(0))
	input := '133;P;k=s'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	pk := read_prompt_kind(cmd.semantic_prompt_options) or {
		assert false, 'expected prompt_kind'
		return
	}
	assert pk == .secondary
}

fn test_osc133_prompt_start_with_invalid_k() {
	mut p := Parser.init(voidptr(0))
	input := '133;P;k=x'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .prompt_start
	assert read_prompt_kind(cmd.semantic_prompt_options) == none
}

fn test_osc133_prompt_start_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Pextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_new_command() {
	mut p := Parser.init(voidptr(0))
	input := '133;N'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .new_command
	assert read_aid(cmd.semantic_prompt_options) == none
	assert read_click(cmd.semantic_prompt_options) == none
}

fn test_osc133_new_command_with_aid() {
	mut p := Parser.init(voidptr(0))
	input := '133;N;aid=foo'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .new_command
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
}

fn test_osc133_new_command_with_cl_line() {
	mut p := Parser.init(voidptr(0))
	input := '133;N;cl=line'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .new_command
	cl := read_click(cmd.semantic_prompt_options) or {
		assert false, 'expected click'
		return
	}
	assert cl == .line
}

fn test_osc133_new_command_with_multiple_options() {
	mut p := Parser.init(voidptr(0))
	input := '133;N;aid=foo;cl=line'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .new_command
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
	cl := read_click(cmd.semantic_prompt_options) or {
		assert false, 'expected click'
		return
	}
	assert cl == .line
}

fn test_osc133_new_command_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Nextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_end_prompt_start_input() {
	mut p := Parser.init(voidptr(0))
	input := '133;B'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_prompt_start_input
}

fn test_osc133_end_prompt_start_input_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Bextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_end_prompt_start_input_with_options() {
	mut p := Parser.init(voidptr(0))
	input := '133;B;aid=foo'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_prompt_start_input
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
}

fn test_osc133_end_prompt_start_input_terminate_eol() {
	mut p := Parser.init(voidptr(0))
	input := '133;I'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_prompt_start_input_terminate_eol
}

fn test_osc133_end_prompt_start_input_terminate_eol_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Iextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_end_prompt_start_input_terminate_eol_with_options() {
	mut p := Parser.init(voidptr(0))
	input := '133;I;aid=foo'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_prompt_start_input_terminate_eol
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
}

fn test_osc133_end_command() {
	mut p := Parser.init(voidptr(0))
	input := '133;D'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_command
	assert read_exit_code(cmd.semantic_prompt_options) == none
	assert read_aid(cmd.semantic_prompt_options) == none
	assert read_err(cmd.semantic_prompt_options) == none
}

fn test_osc133_end_command_extra_contents() {
	mut p := Parser.init(voidptr(0))
	input := '133;Dextra'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0) == none
}

fn test_osc133_end_command_with_exit_code_0() {
	mut p := Parser.init(voidptr(0))
	input := '133;D;0'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_command
	ec := read_exit_code(cmd.semantic_prompt_options) or {
		assert false, 'expected exit code'
		return
	}
	assert ec == 0
}

fn test_osc133_end_command_with_exit_code_and_aid() {
	mut p := Parser.init(voidptr(0))
	input := '133;D;12;aid=foo'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .semantic_prompt
	assert cmd.semantic_prompt_action == .end_command
	aid := read_aid(cmd.semantic_prompt_options) or {
		assert false, 'expected aid'
		return
	}
	assert aid == 'foo'
	ec := read_exit_code(cmd.semantic_prompt_options) or {
		assert false, 'expected exit code'
		return
	}
	assert ec == 12
}

// Direct Option.read tests (self-contained, no OSC parser needed)

fn test_option_read_aid() {
	assert (read_aid('aid=test123') or { '' }) == 'test123'
	assert (read_aid('cl=line;aid=myaid;k=i') or { '' }) == 'myaid'
	assert read_aid('cl=line;k=i') == none
	assert (read_aid('aid=') or { 'X' }) == ''
	assert (read_aid('k=i;aid=last') or { '' }) == 'last'
	assert (read_aid('aid=first;k=i') or { '' }) == 'first'
	assert read_aid('') == none
	assert read_aid('aid') == none
	assert (read_aid(';;aid=value;;') or { '' }) == 'value'
}

fn test_option_read_cl() {
	assert (read_click('cl=line') or { Click.line }) == .line
	assert (read_click('cl=m') or { Click.line }) == .multiple
	assert (read_click('cl=v') or { Click.line }) == .conservative_vertical
	assert (read_click('cl=w') or { Click.line }) == .smart_vertical
	assert read_click('cl=invalid') == none
	assert read_click('aid=foo') == none
}

fn test_option_read_prompt_kind() {
	assert (read_prompt_kind('k=i') or { PromptKind.initial }) == .initial
	assert (read_prompt_kind('k=r') or { PromptKind.initial }) == .right
	assert (read_prompt_kind('k=c') or { PromptKind.initial }) == .continuation
	assert (read_prompt_kind('k=s') or { PromptKind.initial }) == .secondary
	assert read_prompt_kind('k=x') == none
	assert read_prompt_kind('k=ii') == none
	assert read_prompt_kind('k=') == none
}

fn test_option_read_err() {
	assert (read_err('err=some_error') or { '' }) == 'some_error'
	assert read_err('aid=foo') == none
}

fn test_option_read_redraw() {
	assert $sizeof(Redraw) == 1
	assert u8(Redraw.redraw_true) == 0
	assert u8(Redraw.redraw_false) == 1
	assert u8(Redraw.last) == 2

	assert (read_redraw('redraw=1') or { Redraw.last }) == .redraw_true
	assert (read_redraw('redraw=0') or { Redraw.last }) == .redraw_false
	assert (read_redraw('redraw=last') or { Redraw.redraw_true }) == .last
	assert read_redraw('redraw=2') == none
	assert read_redraw('redraw=10') == none
	assert read_redraw('redraw=') == none
}

fn test_option_read_special_key() {
	assert (read_special_key('special_key=1') or { false }) == true
	assert (read_special_key('special_key=0') or { true }) == false
	assert read_special_key('special_key=x') == none
}

fn test_option_read_click_events() {
	assert (read_click_events('click_events=1') or { false }) == true
	assert (read_click_events('click_events=0') or { true }) == false
	assert read_click_events('click_events=yes') == none
}

fn test_option_read_exit_code() {
	assert (read_exit_code('42') or { -999 }) == 42
	assert (read_exit_code('0') or { -999 }) == 0
	assert (read_exit_code('-1') or { -999 }) == -1
	assert (read_exit_code('+1') or { -999 }) == 1
	assert (read_exit_code('1__0') or { -999 }) == 10
	assert (read_exit_code('2147483647') or { -999 }) == 2147483647
	assert read_exit_code('2147483648') == none
	assert read_exit_code('-2147483649') == none
	assert read_exit_code('abc') == none
	assert (read_exit_code('127;aid=foo') or { -999 }) == 127
}
