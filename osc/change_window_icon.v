module osc

// Parse OSC 1 - change window icon.
//
// Set the icon of the terminal window. The name of the icon is not
// well defined, so this is currently ignored by Ghostty at the time
// of writing this. We just parse it so that we don't get parse errors
// in the log.
fn parse_change_window_icon(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	icon := data.bytestr()
	parser.command = Command{
		cmd_type: .change_window_icon
		terminator: init_terminator(terminator_ch)
		str_value: icon
	}
	return parser.command
}
