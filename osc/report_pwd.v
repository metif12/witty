module osc

// Parse OSC 7 - report current working directory.
//
// OSC 7. Reports the current working directory of the shell. This is
// a moderately flawed escape sequence but one that many major terminals
// support so we also support it. To understand the flaws, read through
// this terminal-wg issue: https://gitlab.freedesktop.org/terminal-wg/specifications/-/issues/20
fn parse_report_pwd(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	value := data.bytestr()
	parser.command = Command{
		cmd_type: .report_pwd
		terminator: init_terminator(terminator_ch)
		str_value: value
	}
	return parser.command
}
