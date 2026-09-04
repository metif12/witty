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

pub fn (ctx Context) build_font_atlas() bool {
	return false
}

pub fn (ctx Context) get_id(value string) u32 {
	_ = value
	return 0
}

pub fn (ctx Context) dock_node_exists(id u32) bool {
	_ = id
	return false
}

pub fn (ctx Context) dock_node_add(id u32) bool {
	_ = id
	return false
}

pub fn (ctx Context) dock_node_set_main_viewport_size(id u32) {
	_ = id
}

pub fn (ctx Context) dock_window(name string, id u32) {
	_ = name
	_ = id
}

pub fn (ctx Context) dock_finish(id u32) {
	_ = id
}

pub fn (ctx Context) dock_space_over_main_viewport(id u32) bool {
	_ = id
	return false
}

pub fn (ctx Context) begin_window(name string) bool {
	_ = name
	return false
}

pub fn (ctx Context) end_window() {}

pub fn (ctx Context) set_window_focus(name string) {
	_ = name
}

pub fn (ctx Context) text(value string) {
	_ = value
}

pub fn (ctx Context) text_disabled(value string) {
	_ = value
}

pub fn (ctx Context) text_wrapped(value string) {
	_ = value
}

pub fn (ctx Context) collapsing_header(label string) bool {
	_ = label
	return false
}

pub fn (ctx Context) separator_text(label string) {
	_ = label
}

pub fn (ctx Context) text_colored(color Color, value string) {
	_ = color
	_ = value
}

pub fn (ctx Context) button(label string) bool {
	_ = label
	return false
}

pub fn (ctx Context) small_button(label string) bool {
	_ = label
	return false
}

pub fn (ctx Context) separator() {}

pub fn (ctx Context) begin_table(id string, columns int, flags int) bool {
	_ = id
	_ = columns
	_ = flags
	return false
}

pub fn (ctx Context) end_table() {}

pub fn (ctx Context) table_setup_scroll_freeze(columns int, rows int) {
	_ = columns
	_ = rows
}

pub fn (ctx Context) table_setup_column(label string, flags int, width f32) {
	_ = label
	_ = flags
	_ = width
}

pub fn (ctx Context) table_headers_row() {}

pub fn (ctx Context) table_next_row() {}

pub fn (ctx Context) table_set_column(column int) {
	_ = column
}

pub fn (ctx Context) table_set_bg_color(target int, color u32) {
	_ = target
	_ = color
}

pub fn (ctx Context) push_id(value voidptr) {
	_ = value
}

pub fn (ctx Context) pop_id() {}

pub fn (ctx Context) same_line() {}

pub fn (ctx Context) new_line() {}

pub fn (ctx Context) item_hovered() bool {
	return false
}

pub fn (ctx Context) tooltip(value string) {
	_ = value
}

pub fn (ctx Context) cursor_screen_y() f32 {
	return 0
}

pub fn (ctx Context) mouse_y() f32 {
	return 0
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
