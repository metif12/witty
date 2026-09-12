module osc

// Parse OSC 52 - clipboard operations.
//
// Set or get clipboard contents. If data is "?", then the current
// clipboard contents are sent to the pty. If data is set, this
// contents is set on the clipboard.
//
// Format: OSC 52 ; Pc ; Pd ST
// Pc is a single character clipboard selection (s, c, p, etc.) or empty (defaults to 'c')
// Pd is the base64-encoded data, "?" for query, or empty to clear.
fn parse_clipboard_operation(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	data_str := data.bytestr()

	if data_str.len == 0 {
		parser.state = .invalid
		return none
	}

	// Check for the clipboard kind separator
	if data_str[0] == `;` {
		// No explicit kind, default to 'c'
		parser.command = Command{
			cmd_type: .clipboard_contents
			terminator: Terminator.init(terminator_ch)
			clipboard: ClipboardContents{
				kind: `c`
				data: data_str[1..]
			}
		}
		return parser.command
	}

	// Explicit kind character
	if data_str.len < 2 {
		parser.state = .invalid
		return none
	}
	if data_str[1] != `;` {
		parser.state = .invalid
		return none
	}

	kind := data_str[0]
	clipboard_data := data_str[2..]

	parser.command = Command{
		cmd_type: .clipboard_contents
		terminator: Terminator.init(terminator_ch)
		clipboard: ClipboardContents{
			kind: kind
			data: clipboard_data
		}
	}
	return parser.command
}
