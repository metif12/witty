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

// IpcAction represents an IPC action to perform on a running instance.
// In Zig, this is a tagged union: Action = union(enum) { new_window: NewWindow }
pub type IpcAction = IpcNewWindow

// IpcNewWindow holds the arguments to pass to Ghostty for a new window command.
pub struct IpcNewWindow {
pub:
	// A list of command arguments to launch in the new window. If this is
	// empty, the command configured in the config or the user's default
	// shell should be launched.
	//
	// It is an error for this to be non-empty, but zero length.
	arguments []string
}
