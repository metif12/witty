module osc

// Parse OSC 22 - set mouse cursor shape.
//
// OSC 22. Set the mouse shape. There doesn't seem to be a standard
// naming scheme for cursors but it looks like terminals such as Foot
// are moving towards using the W3C CSS cursor names. For OSC parsing,
// we just parse whatever string is given.
fn parse_mouse_shape(mut parser Parser, terminator_ch ?u8) ?Command {
	assert parser.state == .s_22
	data := parser.finish_zero_terminated() or { return none }
	value := data.bytestr()
	parser.command = Command{
		cmd_type: .mouse_shape
		terminator: Terminator.init(terminator_ch)
		str_value: value
	}
	return parser.command
}
