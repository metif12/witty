// C ABI projections for the embedded runtime. Translated from
// src/apprt/action.zig and the CAPI types in src/apprt/embedded.zig.

module apprt

import input

// CAPITarget mirrors ghostty_target_s.
pub struct CAPITarget {
pub:
	tag    int
	target voidptr
}

// CAPIAction mirrors ghostty_action_s. The action union is 24 bytes and
// eight-byte aligned on the 64-bit targets supported by the embedded API.
pub struct CAPIAction {
pub mut:
	tag    int
	action [3]u64
}

// CAPIInputTrigger mirrors ghostty_input_trigger_s.
pub struct CAPIInputTrigger {
pub:
	tag  int
	key  u32
	mods u32
}

// CAPIClipboardContentC mirrors ghostty_clipboard_content_s.
pub struct CAPIClipboardContentC {
pub:
	mime &char = unsafe { nil }
	data &char = unsafe { nil }
}

struct CActionString {
	value &char
}

struct CActionTwoStrings {
	first  &char
	second &char
}

struct CActionSlice {
	ptr &u8
	len usize
}

struct CActionTaggedSlice {
	tag int
	ptr &u8
	len usize
}

struct CActionResizeSplit {
	amount    u16
	direction int
}

struct CActionMoveTab {
	amount isize
}

struct CActionSizeLimit {
	min_width  u32
	min_height u32
	max_width  u32
	max_height u32
}

struct CActionSize {
	width  u32
	height u32
}

struct CActionScrollbar {
	total  u64
	offset u64
	len    u64
}

struct CActionKeySequence {
	active  bool
	trigger CAPIInputTrigger
}

struct CActionKeyTable {
	tag   int
	value CActionSlice
}

struct CActionColorChange {
	kind int
	r    u8
	g    u8
	b    u8
}

struct CActionBool {
	value bool
}

struct CActionConfigChange {
	config voidptr
}

struct CActionChildExited {
	exit_code  u32
	runtime_ms u64
}

struct CActionProgressReport {
	state    int
	progress i8
}

struct CActionCommandFinished {
	exit_code i16
	duration  u64
}

struct CActionCount {
	value isize
}

// capi converts an internal action target to the public C target. Surface
// targets inside core use CoreSurface pointers; the bridge retains the public
// embedded Surface pointer so that is what the host receives.
pub fn (target Target) capi() CAPITarget {
	return match target {
		AppTarget { CAPITarget{} }
		SurfaceTarget {
			mut surface := target.surface
			if !isnil(surface) {
				core_surface := unsafe { &CoreSurface(surface) }
				if !isnil(core_surface.runtime_surface) {
					surface = core_surface.runtime_surface
				}
			}
			CAPITarget{
				tag: 1
				target: surface
			}
		}
	}
}

// capi converts every ActionValue alternative to ghostty_action_s. The union
// bytes are populated from small C-layout structs, matching each cval method in
// Ghostty's action.zig.
pub fn (runtime_action RuntimeAction) capi() CAPIAction {
	tag := int(runtime_action.action)
	data := runtime_action.data
	return match runtime_action.action {
		.close_tab { capi_action_payload(tag, int(data.close_tab)) }
		.new_split { capi_action_payload(tag, int(data.new_split)) }
		.toggle_fullscreen { capi_action_payload(tag, int(data.toggle_fullscreen)) }
		.move_tab {
			capi_action_payload(tag, CActionMoveTab{ amount: isize(data.move_tab.amount) })
		}
		.goto_tab { capi_action_payload(tag, int(data.goto_tab)) }
		.goto_split { capi_action_payload(tag, int(data.goto_split_)) }
		.goto_window { capi_action_payload(tag, int(data.goto_window_)) }
		.resize_split {
			capi_action_payload(tag, CActionResizeSplit{
				amount: data.resize_split_.amount
				direction: int(data.resize_split_.direction)
			})
		}
		.size_limit {
			capi_action_payload(tag, CActionSizeLimit{
				min_width: data.size_limit_.min_width
				min_height: data.size_limit_.min_height
				max_width: data.size_limit_.max_width
				max_height: data.size_limit_.max_height
			})
		}
		.initial_size {
			capi_action_payload(tag, CActionSize{
				width: data.initial_size_.width
				height: data.initial_size_.height
			})
		}
		.cell_size {
			capi_action_payload(tag, CActionSize{
				width: data.cell_size_.width
				height: data.cell_size_.height
			})
		}
		.scrollbar {
			capi_action_payload(tag, CActionScrollbar{
				total: u64(data.scrollbar_.total)
				offset: u64(data.scrollbar_.offset)
				len: u64(data.scrollbar_.len)
			})
		}
		.inspector { capi_action_payload(tag, int(data.inspector_)) }
		.desktop_notification {
			capi_action_payload(tag, CActionTwoStrings{
				first: &char(data.desktop_notification.title.str)
				second: &char(data.desktop_notification.body.str)
			})
		}
		.set_title {
			capi_action_payload(tag, CActionString{ value: &char(data.set_title_.title.str) })
		}
		.prompt_title { capi_action_payload(tag, int(data.prompt_title_)) }
		.pwd { capi_action_payload(tag, CActionString{ value: &char(data.pwd_.pwd.str) }) }
		.mouse_shape { capi_action_payload(tag, int(data.mouse_shape_)) }
		.mouse_visibility { capi_action_payload(tag, int(data.mouse_visibility_)) }
		.mouse_over_link {
			capi_action_payload(tag, CActionSlice{
				ptr: data.mouse_over_link_.url.str
				len: usize(data.mouse_over_link_.url.len)
			})
		}
		.renderer_health { capi_action_payload(tag, int(data.renderer_health_)) }
		.quit_timer { capi_action_payload(tag, int(data.quit_timer_)) }
		.float_window { capi_action_payload(tag, int(data.float_window_)) }
		.secure_input { capi_action_payload(tag, int(data.secure_input_)) }
		.key_sequence {
			trigger := if data.key_sequence_.active {
				trigger_capi(data.key_sequence_.trigger)
			} else {
				// Ghostty's `.end` union arm explicitly uses a default C trigger.
				CAPIInputTrigger{}
			}
			capi_action_payload(tag, CActionKeySequence{
				active: data.key_sequence_.active
				trigger: trigger
			})
		}
		.key_table {
			name := data.key_table_.name
			capi_action_payload(tag, CActionKeyTable{
				tag: int(data.key_table_.tag)
				value: CActionSlice{
					ptr: name.str
					len: usize(name.len)
				}
			})
		}
		.color_change {
			capi_action_payload(tag, CActionColorChange{
				kind: int(data.color_change_.kind)
				r: data.color_change_.r
				g: data.color_change_.g
				b: data.color_change_.b
			})
		}
		.reload_config { capi_action_payload(tag, CActionBool{ value: data.reload_config_.soft }) }
		.config_change {
			capi_action_payload(tag, CActionConfigChange{
				config: voidptr(data.config_change_.config)
			})
		}
		.open_url {
			capi_action_payload(tag, CActionTaggedSlice{
				tag: int(data.open_url_.kind)
				ptr: data.open_url_.url.str
				len: usize(data.open_url_.url.len)
			})
		}
		.show_child_exited {
			capi_action_payload(tag, CActionChildExited{
				exit_code: data.show_child_exited_.exit_code
				runtime_ms: data.show_child_exited_.runtime_ms
			})
		}
		.progress_report {
			progress := data.progress_report_.cval()
			capi_action_payload(tag, CActionProgressReport{
				state: progress.state
				progress: progress.progress
			})
		}
		.command_finished {
			exit_code := if value := data.command_finished_.exit_code {
				i16(value)
			} else {
				i16(-1)
			}
			capi_action_payload(tag, CActionCommandFinished{
				exit_code: exit_code
				duration: data.command_finished_.duration.duration
			})
		}
		.start_search {
			capi_action_payload(tag, CActionString{ value: &char(data.start_search_.needle.str) })
		}
		.search_total {
			capi_action_payload(tag, CActionCount{
				value: optional_count_capi(data.search_total_.total)
			})
		}
		.search_selected {
			capi_action_payload(tag, CActionCount{
				value: optional_count_capi(data.search_selected_.selected)
			})
		}
		.readonly { capi_action_payload(tag, int(data.readonly_)) }
		else { CAPIAction{ tag: tag } }
	}
}

// Ghostty uses @intCast for present search counts, so values outside the
// signed pointer-width C representation are a checked-cast failure rather
// than wrapping into a negative sentinel.
fn optional_count_capi(value ?usize) isize {
	if count := value {
		assert count <= (~usize(0) >> 1)
		return isize(count)
	}
	return -1
}

fn capi_action_payload[T](tag int, value T) CAPIAction {
	mut result := CAPIAction{ tag: tag }
	$if sizeof ( T ) > 24 {
		$compile_error('C action payload exceeds ghostty_action_u')
	}
	unsafe {
		vmemcpy(&result.action[0], &value, sizeof(T))
	}
	return result
}

fn trigger_capi(trigger input.Trigger) CAPIInputTrigger {
	key := match trigger.key.typ {
		.physical { u32(trigger.key.physical) }
		.unicode { trigger.key.unicode }
		.catch_all { u32(0) }
	}
	return CAPIInputTrigger{
		tag: int(trigger.key.typ)
		key: key
		mods: u32(trigger.mods.int())
	}
}
