module apprt

// ipc.v - Inter-process Communication to a running Ghostty instance
// from a separate process.
// Translated from ghostty/src/apprt/ipc.zig

// IpcTarget identifies the target Ghostty instance for IPC.
// In Zig, this is a tagged union: Target = union(Key) { class: [:0]const u8, detect }
pub type IpcTarget = IpcTargetClass | IpcTargetDetect

// IpcTargetClass opens a new window in a custom instance of Ghostty.
// Sync with: ghostty_ipc_target_tag_e
pub struct IpcTargetClass {
pub:
	class string
}

// IpcTargetDetect auto-detects which instance to open a new window in.
pub struct IpcTargetDetect {}

// IpcTargetKey is synchronized with ghostty_ipc_target_tag_e.
pub enum IpcTargetKey as i32 {
	class
	detect
}

// IpcTargetCValue mirrors ghostty_ipc_target_u. Its only data-bearing member
// is the class pointer; detect has no payload.
pub union IpcTargetCValue {
pub:
	class &char = unsafe { nil }
}

// IpcTargetC mirrors ghostty_ipc_target_s.
pub struct IpcTargetC {
pub:
	key   IpcTargetKey
	value IpcTargetCValue
}

// cval converts a target to its C ABI projection.
pub fn (target IpcTarget) cval() IpcTargetC {
	return match target {
		IpcTargetClass {
			IpcTargetC{
				key: .class
				value: IpcTargetCValue{ class: target.class.str }
			}
		}
		IpcTargetDetect {
			IpcTargetC{
				key: .detect
			}
		}
	}
}

// IpcAction represents an IPC action to perform on a running instance.
// In Zig, this is a tagged union: Action = union(enum) { new_window: NewWindow }
pub struct IpcAction {
pub:
	new_window IpcNewWindow
}

// IpcNewWindow holds the arguments to pass to Ghostty for a new window command.
pub struct IpcNewWindow {
pub:
	// A list of command arguments to launch in the new window. If this is
	// absent, the command configured in the config or the user's default
	// shell should be launched.
	//
	// It is an error for this to be present, but zero length.
	arguments ?[]string
}

// IpcNewWindowC mirrors ghostty_ipc_action_new_window_s.
pub struct IpcNewWindowC {
pub mut:
	// Null-terminated list of C strings, or nil when arguments is absent.
	arguments &&char = unsafe { nil }
}

// deinit releases the pointer list allocated by cval. The strings remain
// owned by IpcNewWindow, matching the source contract.
pub fn (mut value IpcNewWindowC) deinit() {
	if !isnil(value.arguments) {
		unsafe { free(value.arguments) }
		value.arguments = unsafe { nil }
	}
}

// cval creates the null-terminated argv projection used by the C ABI.
pub fn (value &IpcNewWindow) cval() !IpcNewWindowC {
	arguments := value.arguments or { return IpcNewWindowC{} }
	pointer_count := usize(arguments.len) + 1
	if pointer_count > ~usize(0) / sizeof(voidptr) {
		return error('allocation failed')
	}
	bytes := pointer_count * sizeof(voidptr)
	raw := unsafe { malloc(bytes) }
	if isnil(raw) {
		return error('allocation failed')
	}
	mut pointers := &&char(raw)
	unsafe {
		for index, argument in arguments {
			pointers[index] = argument.str
		}
		pointers[arguments.len] = nil
	}
	return IpcNewWindowC{ arguments: pointers }
}

// IpcActionKey is synchronized with ghostty_ipc_action_tag_e.
pub enum IpcActionKey as u32 {
	new_window
}

// IpcActionCValue mirrors ghostty_ipc_action_u. There is currently one action.
pub union IpcActionCValue {
pub:
	new_window IpcNewWindowC
}

// IpcActionC mirrors ghostty_ipc_action_s.
pub struct IpcActionC {
pub:
	key   IpcActionKey
	value IpcActionCValue
}

// cval converts an action to its C ABI projection.
pub fn (action IpcAction) cval() !IpcActionC {
	return IpcActionC{
		key: .new_window
		value: IpcActionCValue{ new_window: action.new_window.cval()! }
	}
}
