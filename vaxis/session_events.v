module vaxis

// The event interception part of pinned Loop.handleEventGeneric. Applications
// receive forwarded events; query responses update the session instead.
pub fn (mut vx Vaxis) handle_input(event InputEvent) ?InputEvent {
	match event {
		Key {
			if event.codepoint == f3 && !vx.queries_done.load() {
				if event.mods.shift() {
					vx.caps.explicit_width = true
					vx.caps.unicode = .unicode
					vx.screen.width_method = .unicode
					return none
				}
				if event.mods.alt() {
					vx.caps.scaled_text = true
					return none
				}
			}
			return InputEvent(event)
		}
		Mouse {
			return InputEvent(vx.translate_mouse(event))
		}
		Winsize {
			$if !windows {
				vx.state.in_band_resize = true
				Tty.reset_winsize_handler()
			}
			return InputEvent(event)
		}
		CapabilityEvent {
			if event.capability == .da1 {
				vx.queries_done.store(true)
				return none
			}
			$if windows {
				return none
			} $else {
				match event.capability {
					.kitty_keyboard { vx.caps.kitty_keyboard = true }
					.kitty_graphics { vx.caps.kitty_graphics = true }
					.rgb { vx.caps.rgb = true }
					.unicode {
						vx.caps.unicode = .unicode
						vx.screen.width_method = .unicode
					}
					.sgr_pixels { vx.caps.sgr_pixels = true }
					.color_scheme_updates { vx.caps.color_scheme_updates = true }
					.multi_cursor { vx.caps.multi_cursor = true }
					.da1 {}
				}
				return none
			}
		}
		else {
			$if windows {
				if event is KeyRelease || event is MouseLeave || event is Paste || event is PasteStart
					|| event is PasteEnd || event is ColorReport || event is ColorScheme {
					return none
				}
			}
			return event
		}
	}
	return none
}
