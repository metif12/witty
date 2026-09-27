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
	arguments := nw.arguments or { panic('expected arguments') }
	assert arguments.len == 3
	assert arguments[0] == 'bash'
}

// Test IpcNewWindow with absent arguments.
fn test_ipc_new_window_no_args() {
	nw := IpcNewWindow{}
	assert nw.arguments == none
}

// Test IpcAction retains the source union boundary around IpcNewWindow.
fn test_ipc_action() {
	a := IpcAction{
		new_window: IpcNewWindow{ arguments: ['ls'] }
	}
	arguments := a.new_window.arguments or { panic('expected arguments') }
	assert arguments.len == 1
	assert arguments[0] == 'ls'
}

fn test_ipc_target_cval() {
	class_target := IpcTarget(IpcTargetClass{ class: 'my-ghostty' }).cval()
	assert class_target.key == .class
	unsafe {
		assert cstring_to_vstring(class_target.value.class) == 'my-ghostty'
	}
	detect_target := IpcTarget(IpcTargetDetect{}).cval()
	assert detect_target.key == .detect
	unsafe {
		assert isnil(detect_target.value.class)
	}
}

fn test_ipc_new_window_cval_preserves_optional_arguments() {
	none_value := IpcNewWindow{}
	mut none_c := none_value.cval()!
	assert isnil(none_c.arguments)
	none_c.deinit()

	empty_value := IpcNewWindow{ arguments: []string{} }
	mut empty_c := empty_value.cval()!
	assert !isnil(empty_c.arguments)
	unsafe {
		assert isnil(empty_c.arguments[0])
	}
	empty_c.deinit()

	args_value := IpcNewWindow{ arguments: ['echo', 'hello'] }
	mut action_c := IpcAction{ new_window: args_value }.cval()!
	assert action_c.key == .new_window
	mut args_c := unsafe { action_c.value.new_window }
	unsafe {
		assert cstring_to_vstring(args_c.arguments[0]) == 'echo'
		assert cstring_to_vstring(args_c.arguments[1]) == 'hello'
		assert isnil(args_c.arguments[2])
	}
	args_c.deinit()
}

fn test_ipc_c_projection_sizes() {
	assert sizeof(IpcTargetKey) == 4
	assert int(IpcTargetKey.class) == 0
	assert int(IpcTargetKey.detect) == 1
	assert sizeof(IpcActionKey) == 4
	assert u32(IpcActionKey.new_window) == 0
	assert sizeof(IpcTargetCValue) == sizeof(voidptr)
	assert sizeof(IpcActionCValue) == sizeof(voidptr)
	assert sizeof(IpcTargetC) == if sizeof(voidptr) == 8 { 16 } else { 8 }
	assert sizeof(IpcActionC) == if sizeof(voidptr) == 8 { 16 } else { 8 }
}
