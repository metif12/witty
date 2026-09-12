module osc

// Parse OSC 8 - hyperlinks.
//
// Start a hyperlink (OSC 8)
// Format: OSC 8 ; params ; uri ST
//
// If uri is empty, this ends the hyperlink.
// params is a colon-separated list of key=value pairs.
// The only recognized key is "id".
fn parse_hyperlink(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	data_str := data.bytestr()

	// Find the semicolon separating params from URI
	s := data_str.index_u8(`;`)
	if s < 0 {
		parser.state = .invalid
		return none
	}

	params_str := data_str[..s]
	uri := data_str[s + 1..]

	// Parse key=value pairs from params (colon-separated)
	mut id := ?string(none)
	if params_str.len > 0 {
		kvs := params_str.split(':')
		for kv in kvs {
			eq := kv.index_u8(`=`)
			if eq < 0 {
				break
			}
			key := kv[..eq]
			value := kv[eq + 1..]
			if key == 'id' {
				if value.len > 0 {
					id = value
				}
			}
			// Unknown keys are ignored per spec
		}
	}

	// Empty URI means end hyperlink
	if uri.len == 0 {
		if id != none {
			// Having an id with empty URI is invalid
			parser.state = .invalid
			return none
		}
		parser.command = Command{
			cmd_type: .hyperlink_end
			terminator: Terminator.init(terminator_ch)
		}
		return parser.command
	}

	parser.command = Command{
		cmd_type: .hyperlink_start
		terminator: Terminator.init(terminator_ch)
		hyperlink: HyperlinkStart{
			uri: uri
			id: id
		}
	}
	return parser.command
}
