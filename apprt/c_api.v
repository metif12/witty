// C ABI projections for the embedded runtime. Translated from
// src/apprt/action.zig and the CAPI types in src/apprt/embedded.zig.

module apprt

import input
import terminal
import renderer
import osc

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
	return match data {
		CloseTabMode { capi_action_payload(tag, int(data)) }
		SplitDirection { capi_action_payload(tag, int(data)) }
		Fullscreen { capi_action_payload(tag, int(data)) }
		MoveTab {
			capi_action_payload(tag, CActionMoveTab{ amount: isize(data.amount) })
		}
		GotoTab { capi_action_payload(tag, int(data)) }
		GotoSplit { capi_action_payload(tag, int(data)) }
		GotoWindow { capi_action_payload(tag, int(data)) }
		ResizeSplit {
			capi_action_payload(tag, CActionResizeSplit{
				amount: data.amount
				direction: int(data.direction)
			})
		}
		SizeLimit {
			capi_action_payload(tag, CActionSizeLimit{
				min_width: data.min_width
				min_height: data.min_height
				max_width: data.max_width
				max_height: data.max_height
			})
		}
		InitialSize {
			capi_action_payload(tag, CActionSize{
				width: data.width
				height: data.height
			})
		}
		CellSize {
			capi_action_payload(tag, CActionSize{
				width: data.width
				height: data.height
			})
		}
		terminal.Scrollbar {
			capi_action_payload(tag, CActionScrollbar{
				total: u64(data.total)
				offset: u64(data.offset)
				len: u64(data.len)
			})
		}
		InspectorAction { capi_action_payload(tag, int(data)) }
		DesktopNotificationValue {
			capi_action_payload(tag, CActionTwoStrings{
				first: &char(data.title.str)
				second: &char(data.body.str)
			})
		}
		SetTitle {
			capi_action_payload(tag, CActionString{ value: &char(data.title.str) })
		}
		PromptTitle { capi_action_payload(tag, int(data)) }
		PwdValue { capi_action_payload(tag, CActionString{ value: &char(data.pwd.str) }) }
		terminal.MouseShape { capi_action_payload(tag, int(data)) }
		MouseVisibility { capi_action_payload(tag, int(data)) }
		MouseOverLink {
			capi_action_payload(tag, CActionSlice{
				ptr: data.url.str
				len: usize(data.url.len)
			})
		}
		renderer.Health { capi_action_payload(tag, int(data)) }
		QuitTimer { capi_action_payload(tag, int(data)) }
		FloatWindow { capi_action_payload(tag, int(data)) }
		SecureInput { capi_action_payload(tag, int(data)) }
		KeySequence {
			capi_action_payload(tag, match data {
				input.Trigger {
					CActionKeySequence{
						active:  true
						trigger: trigger_capi(data)
					}
				}
				KeySequenceEnd {
					// Ghostty's `.end` union arm explicitly uses a default C trigger.
					CActionKeySequence{
						active:  false
						trigger: CAPIInputTrigger{}
					}
				}
			})
		}
		KeyTable {
			name := if data is KeyTableActivate { data.name } else { '' }
			capi_action_payload(tag, CActionKeyTable{
				tag: int(data.tag())
				value: CActionSlice{
					ptr: name.str
					len: usize(name.len)
				}
			})
		}
		ColorChange {
			capi_action_payload(tag, CActionColorChange{
				kind: int(data.kind)
				r: data.r
				g: data.g
				b: data.b
			})
		}
		ReloadConfig { capi_action_payload(tag, CActionBool{ value: data.soft }) }
		ConfigChange {
			capi_action_payload(tag, CActionConfigChange{
				config: voidptr(data.config)
			})
		}
		OpenUrl {
			capi_action_payload(tag, CActionTaggedSlice{
				tag: int(data.kind)
				ptr: data.url.str
				len: usize(data.url.len)
			})
		}
		ChildExited {
			capi_action_payload(tag, CActionChildExited{
				exit_code: data.exit_code
				runtime_ms: data.runtime_ms
			})
		}
		osc.ProgressReport {
			progress := data.cval()
			capi_action_payload(tag, CActionProgressReport{
				state: progress.state
				progress: progress.progress
			})
		}
		CommandFinished {
			exit_code := if value := data.exit_code {
				i16(value)
			} else {
				i16(-1)
			}
			capi_action_payload(tag, CActionCommandFinished{
				exit_code: exit_code
				duration: data.duration.duration
			})
		}
		StartSearch {
			capi_action_payload(tag, CActionString{ value: &char(data.needle.str) })
		}
		SearchTotal {
			capi_action_payload(tag, CActionCount{
				value: optional_count_capi(data.total)
			})
		}
		SearchSelected {
			capi_action_payload(tag, CActionCount{
				value: optional_count_capi(data.selected)
			})
		}
		Readonly { capi_action_payload(tag, int(data)) }
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
