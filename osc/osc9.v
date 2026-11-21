module osc

const max_usize_value = u64(~uint(0))

// Parse OSC 9, which could be an iTerm2 notification or a ConEmu extension.
fn parse_osc9(mut parser Parser, _ ?u8) ?Command {
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
					parser.command = ConEmuSleep{
						duration_ms: duration
					}
					return parser.command
				}

				// OSC 9;10 xterm keyboard and output emulation
				`0` {
					if data.len == 2 {
						parser.command = ConEmuXtermEmulation{
							keyboard: true
							output: true
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
							parser.command = ConEmuXtermEmulation{
								keyboard: false
								output: false
							}
							return parser.command
						}
						`1` {
							parser.command = ConEmuXtermEmulation{
								keyboard: true
								output: true
							}
							return parser.command
						}
						`2` {
							parser.command = ConEmuXtermEmulation{
								keyboard: none
								output: false
							}
							return parser.command
						}
						`3` {
							parser.command = ConEmuXtermEmulation{
								keyboard: none
								output: true
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
					terminated := parser.finish_zero_terminated() or { return none }
					comment_data := if terminated.len > 3 {
						terminated[3..].bytestr()
					} else {
						''
					}
					parser.command = ConEmuComment{
						value: comment_data
					}
					return parser.command
				}

				// OSC 9;12 mark prompt start
				`2` {
					parser.command = SemanticPrompt.init(.fresh_line_new_prompt)
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
			terminated := parser.finish_zero_terminated() or { return none }
			msg := if terminated.len > 2 { terminated[2..].bytestr() } else { '' }
			parser.command = ConEmuShowMessageBox{
				value: msg
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
				parser.command = ConEmuChangeTabTitle{
					title: ConEmuTabTitleReset{}
				}
				return parser.command
			}
			terminated := parser.finish_zero_terminated() or { return none }
			val := terminated[2..].bytestr()
			parser.command = ConEmuChangeTabTitle{
				title: val
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

			mut progress := if pstate == .set { ?u8(u8(0)) } else { ?u8(none) }

			// For states that accept a progress value, parse it
			match pstate {
				.remove, .indeterminate {}
				.set, .err_state, .pause {
					if data.len >= 4 && data[3] == `;` {
						// A present value replaces the initial default, including on failure.
						progress = none
						rest := data[4..].bytestr()
						if parsed := parse_unsigned_decimal(rest, max_usize_value) {
							clamped := if parsed > 100 { u8(100) } else { u8(parsed) }
							progress = clamped
						}
					}
				}
			}


			parser.command = ProgressReport{
				state: pstate
				progress: progress
			}
			return parser.command
		}

		// OSC 9;5 wait for input
		`5` {
			parser.command = ConEmuWaitInput{}
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
			terminated := parser.finish_zero_terminated() or { return none }
			val := if terminated.len > 2 { terminated[2..].bytestr() } else { '' }
			parser.command = ConEmuGuiMacro{
				value: val
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
			terminated := parser.finish_zero_terminated() or { return none }
			val := if terminated.len > 2 { terminated[2..].bytestr() } else { '' }
			parser.command = ConEmuRunProcess{
				value: val
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
			terminated := parser.finish_zero_terminated() or { return none }
			val := if terminated.len > 2 { terminated[2..].bytestr() } else { '' }
			parser.command = ConEmuOutputEnvironmentVariable{
				value: val
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
			terminated := parser.finish_zero_terminated() or { return none }
			val := if terminated.len > 2 { terminated[2..].bytestr() } else { '' }
			parser.command = ReportPwd{
				value: val
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
fn make_desktop_notification(mut parser Parser, _ []u8) ?Command {
	data := parser.finish_zero_terminated() or { return none }
	body := data.bytestr()
	parser.command = DesktopNotification{
		body: body
	}
	return parser.command
}
