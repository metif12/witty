module cimgui

$if macos || ios {
	#flag -framework Metal

	fn C.witty_cimgui_metal_init(device voidptr) bool

	fn C.witty_cimgui_metal_shutdown()

	fn C.witty_cimgui_metal_new_frame(descriptor voidptr)

	fn C.witty_cimgui_metal_render(command_buffer voidptr, descriptor voidptr)

	pub fn (ctx Context) metal_init(device voidptr) bool {
		return C.witty_cimgui_metal_init(device)
	}

	pub fn (ctx Context) metal_shutdown() {
		_ = ctx
		C.witty_cimgui_metal_shutdown()
	}

	pub fn (ctx Context) metal_new_frame(descriptor voidptr) {
		_ = ctx
		C.witty_cimgui_metal_new_frame(descriptor)
	}

	pub fn (ctx Context) metal_render(command_buffer voidptr, descriptor voidptr) {
		_ = ctx
		C.witty_cimgui_metal_render(command_buffer, descriptor)
	}
}
