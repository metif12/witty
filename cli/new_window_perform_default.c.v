module cli

// Only the GTK runtime supports the new-window IPC action. The Linux-specific
// file with this basename replaces this fallback on that platform.
fn perform_new_window_ipc(opts NewWindowOptions) !bool {
	_ = opts
	return false
}
