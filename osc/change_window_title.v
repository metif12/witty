module osc

// Parse OSC 0 and OSC 2 - change window title.
//
// If title mode 0 is set text is expected to be hex encoded (i.e. utf-8
// with each code unit further encoded with two hex digits).
//
// If title mode 2 is set or the terminal is setup for unconditional
// utf-8 titles text is interpreted as utf-8. Else text is interpreted
// as latin1.
fn parse_change_window_title(mut parser Parser, terminator_ch u8) ?Command {
	data := parser.buffered()
	title := data.bytestr()
	parser.command = Command{
		cmd_type:   .change_window_title
		terminator: init_terminator(terminator_ch)
		str_value:  title
	}
	return parser.command
}
