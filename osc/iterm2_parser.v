module osc

import ascii

// Parse OSC 1337 - iTerm2 proprietary escape codes.
// https://iterm2.com/documentation-escape-codes.html
//
// Currently supported commands:
// - Copy: clipboard contents (maps to clipboard_contents)
// - CurrentDir: current directory report (maps to report_pwd)
//
// All other commands are recognized but currently unimplemented.

// Iterm2Key identifies the type of iTerm2 OSC 1337 command.
enum Iterm2Key {
	add_annotation
	add_hidden_annotation
	block
	button
	clear_captured_output
	clear_scrollback
	copy
	copy_to_clipboard
	current_dir
	cursor_shape
	custom
	disinter
	end_copy
	file
	file_end
	file_part
	highlight_cursor_line
	multipart_file
	open_url
	pop_key_labels
	push_key_labels
	remote_host
	report_cell_size
	report_variable
	request_attention
	request_upload
	set_background_image_file
	set_badge_format
	set_colors
	set_key_label
	set_mark
	set_profile
	set_user_var
	shell_integration_version
	steal_focus
	unicode_version
	unknown
}

// iterm2_key_names maps iTerm2 key strings to enum values.
// Uses case-insensitive matching to match Ghostty behavior.
fn iterm2_key_from_str(s string) Iterm2Key {
	lower := ascii.lower_string(s)
	return match lower {
		'addannotation' { .add_annotation }
		'addhiddenannotation' { .add_hidden_annotation }
		'block' { .block }
		'button' { .button }
		'clearcapturedoutput' { .clear_captured_output }
		'clearscrollback' { .clear_scrollback }
		'copy' { .copy }
		'copytoclipboard' { .copy_to_clipboard }
		'currentdir' { .current_dir }
		'cursorshape' { .cursor_shape }
		'custom' { .custom }
		'disinter' { .disinter }
		'endcopy' { .end_copy }
		'file' { .file }
		'fileend' { .file_end }
		'filepart' { .file_part }
		'highlightcursorline' { .highlight_cursor_line }
		'multipartfile' { .multipart_file }
		'openurl' { .open_url }
		'popkeylabels' { .pop_key_labels }
		'pushkeylabels' { .push_key_labels }
		'remotehost' { .remote_host }
		'reportcellsize' { .report_cell_size }
		'reportvariable' { .report_variable }
		'requestattention' { .request_attention }
		'requestupload' { .request_upload }
		'setbackgroundimagefile' { .set_background_image_file }
		'setbadgeformat' { .set_badge_format }
		'setcolors' { .set_colors }
		'setkeylabel' { .set_key_label }
		'setmark' { .set_mark }
		'setprofile' { .set_profile }
		'setuservar' { .set_user_var }
		'shellintegrationversion' { .shell_integration_version }
		'stealfocus' { .steal_focus }
		'unicodeversion' { .unicode_version }
		else { .unknown }
	}
}

// parse_iterm2 parses an OSC 1337 iTerm2 command.
fn parse_iterm2(mut parser Parser, terminator_ch ?u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	data_str := data.bytestr()

	// Split on '=' to get key and optional value
	eq_idx := data_str.index_u8(`=`)
	mut key_str := ''
	mut value := ?string(none)
	if eq_idx >= 0 {
		key_str = data_str[..eq_idx]
		value = data_str[eq_idx + 1..]
	} else {
		key_str = data_str
	}

	key := iterm2_key_from_str(key_str)
	if key == .unknown {
		return none
	}

	match key {
		.copy {
			val := value or { return none }

			// Sending a blank entry to clear the clipboard is an OSC 52-ism,
			// make sure that is invalid here.
			if val.len == 0 {
				return none
			}

			// base64 value must be prefixed by a colon
			if val[0] != `:` {
				return none
			}

			b64_data := val[1..]

			// Sending a blank entry to clear the clipboard is an OSC 52-ism,
			// make sure that is invalid here.
			if b64_data.len == 0 {
				return none
			}

			// Sending a '?' to query the clipboard is an OSC 52-ism, make sure
			// that is invalid here.
			if b64_data.len == 1 && b64_data[0] == `?` {
				return none
			}

			// It would be better to check for valid base64 data here, but that
			// would mean parsing the base64 data twice in the "normal" case.
			parser.command = Command{
				cmd_type: .clipboard_contents
				terminator: init_terminator(terminator_ch)
				clipboard: ClipboardContents{
					kind: `c`
					data: b64_data
				}
			}
			return parser.command
		}
		.current_dir {
			val := value or { return none }
			if val.len == 0 {
				return none
			}
			parser.command = Command{
				cmd_type: .report_pwd
				terminator: init_terminator(terminator_ch)
				str_value: val
			}
			return parser.command
		}
		else {
			// Ghostty recognizes but deliberately ignores the remaining iTerm2
			// extensions, returning an invalid command for them.
			return none
		}
	}
}
