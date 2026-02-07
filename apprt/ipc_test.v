module apprt

// Test IpcTarget sumtype with class variant.
fn test_ipc_target_class() {
	t := IpcTarget(IpcTargetClass{ class: 'my-ghostty' })
	match t {
		IpcTargetClass {
			assert t.class == 'my-ghostty'
		}
		IpcTargetDetect {
			assert false
		}
	}
}

// Test IpcTarget sumtype with detect variant.
fn test_ipc_target_detect() {
	t := IpcTarget(IpcTargetDetect{})
	match t {
		IpcTargetDetect {
			assert true
		}
		IpcTargetClass {
			assert false
		}
	}
}

// Test IpcNewWindow with arguments.
fn test_ipc_new_window_with_args() {
	nw := IpcNewWindow{ arguments: ['bash', '-c', 'echo hello'] }
	assert nw.arguments.len == 3
	assert nw.arguments[0] == 'bash'
}

// Test IpcNewWindow with empty arguments.
fn test_ipc_new_window_no_args() {
	nw := IpcNewWindow{ arguments: [] }
	assert nw.arguments.len == 0
}

// Test IpcAction type alias wraps IpcNewWindow.
fn test_ipc_action() {
	a := IpcAction(IpcNewWindow{ arguments: ['ls'] })
	assert a.arguments.len == 1
	assert a.arguments[0] == 'ls'
}
