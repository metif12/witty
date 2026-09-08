module osc

// Parse OSC 9, which could be an iTerm2 notification or a ConEmu extension.
fn parse_osc9(mut parser Parser, terminator_ch ?u8) ?Command {
	mut data := parser.buffered()

	if data.len == 0 {
		// No data: fall through to iTerm2 notification
		return make_desktop_notification(mut parser, data)
	}

	// Check first to see if this is a ConEmu OSC
	// https://conemu.github.io/en/AnsiEscapeCodes.html#ConEmu_specific_OSC
	match data[0] {
		// Check for OSC 9;1 9;10 9;11 9;12
		`1` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			match data[1] {
				// OSC 9;1 sleep
				`;` {
					mut duration := u16(100)
					if data.len > 2 {
						rest := data[2..].bytestr()
						if parsed := parse_unsigned_decimal(rest, 65535) {
							duration = if parsed > 10000 { u16(10000) } else { u16(parsed) }
						}
					}
					parser.command = Command{
						cmd_type: .conemu_sleep
						duration_ms: duration
					}
					return parser.command
				}

				// OSC 9;10 xterm keyboard and output emulation
				`0` {
					if data.len == 2 {
						parser.command = Command{
							cmd_type: .conemu_xterm_emulation
							xterm_keyboard: true
							xterm_output: true
						}
						return parser.command
					}
					if data.len < 4 {
						return make_desktop_notification(mut parser, data)
					}
					if data[2] != `;` {
						return make_desktop_notification(mut parser, data)
					}
					match data[3] {
						`0` {
							parser.command = Command{
								cmd_type: .conemu_xterm_emulation
								xterm_keyboard: false
								xterm_output: false
							}
							return parser.command
						}
						`1` {
							parser.command = Command{
								cmd_type: .conemu_xterm_emulation
								xterm_keyboard: true
								xterm_output: true
							}
							return parser.command
						}
						`2` {
							parser.command = Command{
								cmd_type: .conemu_xterm_emulation
								xterm_keyboard: none
								xterm_output: false
							}
							return parser.command
						}
						`3` {
							parser.command = Command{
								cmd_type: .conemu_xterm_emulation
								xterm_keyboard: none
								xterm_output: true
							}
							return parser.command
						}
						else {
							return make_desktop_notification(mut parser, data)
						}
					}
				}

				// OSC 9;11 comment
				`1` {
					if data.len < 3 {
						return make_desktop_notification(mut parser, data)
					}
					if data[2] != `;` {
						return make_desktop_notification(mut parser, data)
					}
					comment_data := if data.len > 3 {
						data[3..].bytestr()
					} else {
						''
					}
					parser.command = Command{
						cmd_type: .conemu_comment
						str_value: comment_data
					}
					return parser.command
				}

				// OSC 9;12 mark prompt start
				`2` {
					parser.command = Command{
						cmd_type: .semantic_prompt
						semantic_prompt_action: .fresh_line_new_prompt
					}
					return parser.command
				}
				else {
					return make_desktop_notification(mut parser, data)
				}
			}
		}

		// OSC 9;2 show message box
		`2` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			msg := if data.len > 2 { data[2..].bytestr() } else { '' }
			parser.command = Command{
				cmd_type: .conemu_show_message_box
				str_value: msg
			}
			return parser.command
		}

		// OSC 9;3 change tab title
		`3` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			if data.len == 2 {
				parser.command = Command{
					cmd_type: .conemu_change_tab_title
					tab_title: ConEmuTabTitle{
						kind: .reset
					}
				}
				return parser.command
			}
			val := data[2..].bytestr()
			parser.command = Command{
				cmd_type: .conemu_change_tab_title
				tab_title: ConEmuTabTitle{
					kind: .value
					value: val
				}
			}
			return parser.command
		}

		// OSC 9;4 progress report
		`4` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			if data.len < 3 {
				return make_desktop_notification(mut parser, data)
			}
			mut pstate := ProgressState.remove
			match data[2] {
				`0` {
					pstate = .remove
				}
				`1` {
					pstate = .set
				}
				`2` {
					pstate = .err_state
				}
				`3` {
					pstate = .indeterminate
				}
				`4` {
					pstate = .pause
				}
				else {
					return make_desktop_notification(mut parser, data)
				}
			}

			mut progress := ?u8(none)

			// For states that accept a progress value, parse it
			match pstate {
				.remove, .indeterminate {}
				.set, .err_state, .pause {
					if data.len >= 4 && data[3] == `;` {
						rest := data[4..].bytestr()
						if parsed := parse_unsigned_decimal(rest, max_u64) {
							clamped := if parsed > 100 { u8(100) } else { u8(parsed) }
							progress = clamped
						}
					}
				}
			}

			// Special case: set state with no progress defaults to 0
			if pstate == .set && progress == none {
				progress = u8(0)
			}

			parser.command = Command{
				cmd_type: .conemu_progress_report
				progress_state: pstate
				progress: progress
			}
			return parser.command
		}

		// OSC 9;5 wait for input
		`5` {
			parser.command = Command{
				cmd_type: .conemu_wait_input
			}
			return parser.command
		}

		// OSC 9;6 guimacro
		`6` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			val := if data.len > 2 { data[2..].bytestr() } else { '' }
			parser.command = Command{
				cmd_type: .conemu_guimacro
				str_value: val
			}
			return parser.command
		}

		// OSC 9;7 run process
		`7` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			val := if data.len > 2 { data[2..].bytestr() } else { '' }
			parser.command = Command{
				cmd_type: .conemu_run_process
				str_value: val
			}
			return parser.command
		}

		// OSC 9;8 output environment variable
		`8` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			val := if data.len > 2 { data[2..].bytestr() } else { '' }
			parser.command = Command{
				cmd_type: .conemu_output_environment_variable
				str_value: val
			}
			return parser.command
		}

		// OSC 9;9 current working directory
		`9` {
			if data.len < 2 {
				return make_desktop_notification(mut parser, data)
			}
			if data[1] != `;` {
				return make_desktop_notification(mut parser, data)
			}
			val := if data.len > 2 { data[2..].bytestr() } else { '' }
			parser.command = Command{
				cmd_type: .report_pwd
				str_value: val
			}
			return parser.command
		}
		else {
			return make_desktop_notification(mut parser, data)
		}
	}

	return make_desktop_notification(mut parser, data)
}

// make_desktop_notification creates a show_desktop_notification command
// from the given data. This is the iTerm2 notification fallback.
fn make_desktop_notification(mut parser Parser, data []u8) Command {
	body := data.bytestr()
	parser.command = Command{
		cmd_type: .show_desktop_notification
		desktop_notification: DesktopNotification{
			body: body
		}
	}
	return parser.command
}
