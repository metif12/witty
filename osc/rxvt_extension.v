module osc

// Parse OSC 777 - rxvt extensions.
//
// Currently only the "notify" extension is supported, which shows
// a desktop notification with a title and body.
//
// Format: OSC 777 ; notify ; title ; body ST
fn parse_rxvt_extension(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	data_str := data.bytestr()

	// Find the extension name (before first semicolon)
	k := data_str.index_u8(`;`)
	if k < 0 {
		parser.state = .invalid
		return none
	}

	ext := data_str[..k]
	if ext != 'notify' {
		parser.state = .invalid
		return none
	}

	// Find the title (between first and second semicolon)
	rest := data_str[k + 1..]
	t := rest.index_u8(`;`)
	if t < 0 {
		parser.state = .invalid
		return none
	}

	title := rest[..t]
	body := rest[t + 1..]

	parser.command = Command{
		cmd_type: .show_desktop_notification
		terminator: Terminator.init(terminator_ch)
		desktop_notification: DesktopNotification{
			title: title
			body: body
		}
	}
	return parser.command
}
