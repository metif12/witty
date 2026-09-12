module apprt

// none.v - No-op application runtime implementation.
// Translated from ghostty/src/apprt/none.zig

// NoneApp is the no-op app runtime. Always returns false for IPC
// as there is no apprt to communicate with.
pub struct NoneApp {}

// perform_ipc always returns false as there is no apprt to communicate with.
pub fn (a NoneApp) perform_ipc(target IpcTarget, action IpcAction) !bool {
	_ = target
	_ = action
	return false
}

// NoneSurface is the no-op surface runtime.
pub struct NoneSurface {}
