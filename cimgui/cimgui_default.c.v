module cimgui

pub fn available() bool {
	return false
}

pub fn Context.create(font_data []u8) !Context {
	_ = font_data
	return error('Dear ImGui native library is unavailable on this target')
}

pub fn (ctx Context) destroy() {}

pub fn (ctx Context) reset_style(scale f32) {
	_ = scale
}

pub fn (ctx Context) set_size(width u32, height u32) {
	_ = width
	_ = height
}

pub fn (ctx Context) add_mouse_button(button MouseButton, down bool) {
	_ = button
	_ = down
}

pub fn (ctx Context) add_mouse_wheel(x f32, y f32) {
	_ = x
	_ = y
}

pub fn (ctx Context) add_mouse_pos(x f32, y f32) {
	_ = x
	_ = y
}

pub fn (ctx Context) add_focus(focused bool) {
	_ = focused
}

pub fn (ctx Context) add_text(value string) {
	_ = value
}

pub fn (ctx Context) add_key(key Key, down bool) {
	_ = key
	_ = down
}

pub fn (ctx Context) begin_frame(delta_time f32) {
	_ = delta_time
}

pub fn (ctx Context) render_frame() {}

pub fn version() string {
	return ''
}

pub fn (ctx Context) config_flags() int {
	return 0
}

pub fn (ctx Context) display_size() (f32, f32) {
	return 0, 0
}

pub fn (ctx Context) delta_time() f32 {
	return 0
}

pub fn (ctx Context) is_key_down(key Key) bool {
	_ = key
	return false
}

pub fn (ctx Context) metal_init(device voidptr) bool {
	_ = device
	return false
}

pub fn (ctx Context) metal_shutdown() {}

pub fn (ctx Context) metal_new_frame(descriptor voidptr) {
	_ = descriptor
}

pub fn (ctx Context) metal_render(command_buffer voidptr, descriptor voidptr) {
	_ = command_buffer
	_ = descriptor
}
