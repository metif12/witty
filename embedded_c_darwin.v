module main

import apprt

@[export: 'ghostty_surface_set_display_id']
fn ghostty_surface_set_display_id_c(raw voidptr, display_id u32) {
	if isnil(raw) {
		return
	}
	mut surface := unsafe { &apprt.Surface(raw) }
	apprt.ghostty_surface_set_display_id(mut surface, display_id)
}

@[export: 'ghostty_surface_quicklook_font']
fn ghostty_surface_quicklook_font_c(raw voidptr) voidptr {
	if isnil(raw) {
		return unsafe { nil }
	}
	return apprt.ghostty_surface_quicklook_font(unsafe { &apprt.Surface(raw) })
}

@[export: 'ghostty_surface_quicklook_word']
fn ghostty_surface_quicklook_word_c(raw voidptr, result &TextC) bool {
	if isnil(raw) || isnil(result) {
		return false
	}
	mut value := apprt.CAPIText{}
	mut surface := unsafe { &apprt.Surface(raw) }
	if !apprt.ghostty_surface_quicklook_word(mut surface, mut value) {
		return false
	}
	mut output := unsafe { &TextC(result) }
	return text_to_c(value, mut output)
}

@[export: 'ghostty_inspector_metal_init']
fn ghostty_inspector_metal_init_c(raw voidptr, device voidptr) bool {
	if isnil(raw) || isnil(device) {
		return false
	}
	mut inspector := unsafe { &apprt.TerminalInspector(raw) }
	return apprt.ghostty_inspector_metal_init(mut inspector, device)
}

@[export: 'ghostty_inspector_metal_render']
fn ghostty_inspector_metal_render_c(raw voidptr, command_buffer voidptr, descriptor voidptr) {
	if isnil(raw) || isnil(command_buffer) || isnil(descriptor) {
		return
	}
	mut inspector := unsafe { &apprt.TerminalInspector(raw) }
	apprt.ghostty_inspector_metal_render(mut inspector, command_buffer, descriptor)
}

@[export: 'ghostty_inspector_metal_shutdown']
fn ghostty_inspector_metal_shutdown_c(raw voidptr) bool {
	if isnil(raw) {
		return false
	}
	mut inspector := unsafe { &apprt.TerminalInspector(raw) }
	apprt.ghostty_inspector_metal_shutdown(mut inspector)
	return true
}
