module main

import configpkg
import apprt
import input
import macos
import osc
import renderer
import terminal

// Native consumers of Ghostty.App.action. Core actions are produced by the
// translated embedded runtime; these handlers present the source native state.
fn runtime_native_action(app &apprt.App, state ?&TermState, action apprt.RuntimeAction) bool {
	if action.action == .secure_input {
		data := action.data
		if data is apprt.SecureInput {
			if mut current := state {
				if app.config.macos_auto_secure_input { current.actions.secure_input(int(data)) }
			} else {
				macos.secure_set_global(int(data))
			}
			return true
		}
	}
	current := state or { return false }
	if current.closed || current.actions == unsafe { nil } { return false }
	mut overlay := current.actions
	data := action.data
	match action.action {
		.prompt_title {
            if data is apprt.PromptTitle {
                overlay.prompt_title(data == .tab, if data == .tab && current.controller != unsafe { nil } { current.controller.title_override or { macos.native_window_title(current.view) } } else { overlay.title })
                return true
            }
        }
        .pwd { if data is apprt.PwdValue { overlay.set_pwd(data.pwd,current.native_config.proxy_icon); return true } }
        .scrollbar { if data is terminal.Scrollbar { overlay.set_scrollbar(data.total,data.offset,data.len); return true } }
        .inspector { if data is apprt.InspectorAction { overlay.control_inspector(int(data)); return true } }
        .render_inspector { overlay.render_inspector(); return true }
		.desktop_notification {
			if data is apprt.DesktopNotificationValue {
				overlay.desktop_notification(data.title, data.body)
				return true
			}
		}
		.start_search {
			if data is apprt.StartSearch {
				overlay.start_search(data.needle)
				return true
			}
		}
		.end_search {
			overlay.end_search()
			return true
		}
		.search_total {
			if data is apprt.SearchTotal {
				overlay.search_counts(overlay.search_selected, data.total)
				return true
			}
		}
		.search_selected {
			if data is apprt.SearchSelected {
				overlay.search_counts(data.selected, overlay.search_total)
				return true
			}
		}
		.key_sequence {
			if data is apprt.KeySequence {
				match data {
					input.Trigger { overlay.set_key_sequence(true, data.format()) }
					apprt.KeySequenceEnd { overlay.set_key_sequence(false, '') }
				}

				return true
			}
		}
		.key_table {
			if data is apprt.KeyTable {
				match data {
					apprt.KeyTableActivate { overlay.set_key_table(0, data.name) }
					apprt.KeyTableDeactivate { overlay.set_key_table(1, '') }
					apprt.KeyTableDeactivateAll { overlay.set_key_table(2, '') }
				}

				return true
			}
		}
		.progress_report {
			if data is osc.ProgressReport {
				overlay.set_progress(int(data.state), data.progress)
				return true
			}
		}
		.readonly {
			if data is apprt.Readonly {
				overlay.set_readonly(data == .on)
				return true
			}
		}
		.ring_bell {
			overlay.ring_bell()
			overlay.bell_notification(app.config.bell_features.system(),
				app.config.bell_features.attention())
			return true
		}
		.renderer_health {
			if data is renderer.Health {
				overlay.renderer_health(data == .healthy)
				return true
			}
		}
		.mouse_shape {
			if data is terminal.MouseShape {
				macos.set_cursor_shape(current.view, int(data))
				return true
			}
		}
		.mouse_visibility {
			if data is apprt.MouseVisibility {
				macos.set_cursor_visibility(data == .visible)
				return true
			}
		}
		.mouse_over_link {
			if data is apprt.MouseOverLink {
				overlay.mouse_over_link(data.url)
				return true
			}
		}
		else {}
	}

	return false
}

fn native_begin_key_down(userdata voidptr) {
	if mut state := state_from_userdata(userdata) {
		if !state.closed && state.actions != unsafe { nil } { state.actions.begin_key_down() }
	}
}

fn native_surface_title_changed(userdata voidptr, title string) {
	state := state_from_userdata(userdata) or { return }
	if state.closed || state.controller == unsafe { nil } || state.controller.focused != state {
		return
	}
	value := state.controller.title_override or { title }
	macos.set_view_title(state.view, if state.actions.bell
		&& standalone_runtime().app.config.bell_features.title() {
		'🔔 ${value}'
	} else {
		value
	})
}

fn native_tab_title_changed(userdata voidptr, title ?string) {
	mut state := state_from_userdata(userdata) or { return }
	if state.closed || state.controller == unsafe { nil } { return }
	state.controller.title_override = title
	native_surface_title_changed(userdata, state.actions.title)
}

fn native_action_config(current &TermState,config &configpkg.Config) {
 if current.closed || current.actions == unsafe { nil } { return }
 mut actions := current.actions
 actions.bell_border = config.bell_features.border()
 actions.secure_indication = config.macos_secure_input_indication
 color := config.background
 actions.configure_scroll(config.scrollbar == .never, (0.299*f64(color.r)+0.587*f64(color.g)+0.114*f64(color.b))/255 > 0.5)
 actions.refresh_config()
}
