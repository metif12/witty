module main

fn test_lib_vt_input_paste_api() {
	assert input_is_safe_paste('echo hello')
	assert !input_is_safe_paste('echo hello\n')
	encoded := input_encode_paste('hello', InputPasteOptions{
		bracketed: true
	})
	assert encoded == ['\x1b[200~', 'hello', '\x1b[201~']!
}

fn test_lib_vt_exports_complete_mouse_shapes() {
	assert MouseShape.context_menu != MouseShape.default_
	assert MouseShape.zoom_out != MouseShape.zoom_in
}
