module cimgui

#flag -DIMGUI_USE_WCHAR32=1

#flag -DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1

#flag -I@VMODROOT/cimgui

#flag -I@VMODROOT/cimgui/vendor/imgui

#flag -I@VMODROOT/cimgui/vendor/dear_bindings

#flag @VMODROOT/cimgui/lib/libdcimgui_darwin.a

#flag -L/opt/homebrew/lib

#flag -lfreetype

#flag -lc++

#flag -lobjc

#flag -framework Foundation

#flag -framework Metal

#flag -framework QuartzCore

#include "bridge.h"

fn C.witty_cimgui_context_create(font_data voidptr, font_len int) voidptr

fn C.witty_cimgui_context_destroy(context voidptr)

fn C.witty_cimgui_reset_style(context voidptr, scale f32)

fn C.witty_cimgui_set_size(context voidptr, width u32, height u32)

fn C.witty_cimgui_add_mouse_button(context voidptr, button int, down bool)

fn C.witty_cimgui_add_mouse_wheel(context voidptr, x f32, y f32)

fn C.witty_cimgui_add_mouse_pos(context voidptr, x f32, y f32)

fn C.witty_cimgui_add_focus(context voidptr, focused bool)

fn C.witty_cimgui_add_text(context voidptr, text &char)

fn C.witty_cimgui_add_key(context voidptr, key int, down bool)

fn C.witty_cimgui_begin_frame(context voidptr, delta_time f32)

fn C.witty_cimgui_render_frame(context voidptr)

fn C.witty_cimgui_version() &char

fn C.witty_cimgui_config_flags(context voidptr) int

fn C.witty_cimgui_display_width(context voidptr) f32

fn C.witty_cimgui_display_height(context voidptr) f32

fn C.witty_cimgui_delta_time(context voidptr) f32

fn C.witty_cimgui_is_key_down(context voidptr, key int) bool

fn C.witty_cimgui_build_font_atlas(context voidptr) bool

fn C.witty_cimgui_get_id(context voidptr, value &char) u32

fn C.witty_cimgui_dock_node_exists(context voidptr, id u32) bool

fn C.witty_cimgui_dock_node_add(context voidptr, id u32) bool

fn C.witty_cimgui_dock_node_set_main_viewport_size(context voidptr, id u32)

fn C.witty_cimgui_dock_window(context voidptr, name &char, id u32)

fn C.witty_cimgui_dock_finish(context voidptr, id u32)

fn C.witty_cimgui_dock_space_over_main_viewport(context voidptr, id u32) bool

fn C.witty_cimgui_begin_window(context voidptr, name &char) bool

fn C.witty_cimgui_end_window(context voidptr)

fn C.witty_cimgui_set_window_focus(context voidptr, name &char)

fn C.witty_cimgui_text(context voidptr, value &char)

fn C.witty_cimgui_text_disabled(context voidptr, value &char)

fn C.witty_cimgui_text_wrapped(context voidptr, value &char)

fn C.witty_cimgui_collapsing_header(context voidptr, label &char) bool

fn C.witty_cimgui_separator_text(context voidptr, label &char)

fn C.witty_cimgui_text_colored(context voidptr, r f32, g f32, b f32, a f32, value &char)

fn C.witty_cimgui_button(context voidptr, label &char) bool

fn C.witty_cimgui_small_button(context voidptr, label &char) bool

fn C.witty_cimgui_separator(context voidptr)

fn C.witty_cimgui_begin_table(context voidptr, id &char, columns int, flags int) bool

fn C.witty_cimgui_end_table(context voidptr)

fn C.witty_cimgui_table_setup_scroll_freeze(context voidptr, columns int, rows int)

fn C.witty_cimgui_table_setup_column(context voidptr, label &char, flags int, width f32)

fn C.witty_cimgui_table_headers_row(context voidptr)

fn C.witty_cimgui_table_next_row(context voidptr)

fn C.witty_cimgui_table_set_column(context voidptr, column int)

fn C.witty_cimgui_table_set_bg_color(context voidptr, target int, color u32)

fn C.witty_cimgui_push_id_ptr(context voidptr, value voidptr)

fn C.witty_cimgui_pop_id(context voidptr)

fn C.witty_cimgui_same_line(context voidptr)

fn C.witty_cimgui_new_line(context voidptr)

fn C.witty_cimgui_item_hovered(context voidptr) bool

fn C.witty_cimgui_tooltip(context voidptr, value &char)

fn C.witty_cimgui_cursor_screen_y(context voidptr) f32

fn C.witty_cimgui_mouse_y(context voidptr) f32

fn C.witty_cimgui_metal_init(device voidptr) bool

fn C.witty_cimgui_metal_shutdown()

fn C.witty_cimgui_metal_new_frame(descriptor voidptr)

fn C.witty_cimgui_metal_render(command_buffer voidptr, descriptor voidptr)

pub fn available() bool {
	return true
}

pub fn Context.create(font_data []u8) !Context {
	if font_data.len == 0 {
		return error('inspector font data is empty')
	}
	handle := C.witty_cimgui_context_create(font_data.data, font_data.len)
	if isnil(handle) {
		return error('out of memory creating Dear ImGui context')
	}
	return Context{ handle: handle }
}

pub fn (ctx Context) destroy() {
	C.witty_cimgui_context_destroy(ctx.handle)
}

pub fn (ctx Context) reset_style(scale f32) {
	C.witty_cimgui_reset_style(ctx.handle, scale)
}

pub fn (ctx Context) set_size(width u32, height u32) {
	C.witty_cimgui_set_size(ctx.handle, width, height)
}

pub fn (ctx Context) add_mouse_button(button MouseButton, down bool) {
	C.witty_cimgui_add_mouse_button(ctx.handle, int(button), down)
}

pub fn (ctx Context) add_mouse_wheel(x f32, y f32) {
	C.witty_cimgui_add_mouse_wheel(ctx.handle, x, y)
}

pub fn (ctx Context) add_mouse_pos(x f32, y f32) {
	C.witty_cimgui_add_mouse_pos(ctx.handle, x, y)
}

pub fn (ctx Context) add_focus(focused bool) {
	C.witty_cimgui_add_focus(ctx.handle, focused)
}

pub fn (ctx Context) add_text(value string) {
	C.witty_cimgui_add_text(ctx.handle, value.str)
}

pub fn (ctx Context) add_key(key Key, down bool) {
	C.witty_cimgui_add_key(ctx.handle, int(key), down)
}

pub fn (ctx Context) begin_frame(delta_time f32) {
	C.witty_cimgui_begin_frame(ctx.handle, delta_time)
}

pub fn (ctx Context) render_frame() {
	C.witty_cimgui_render_frame(ctx.handle)
}

pub fn version() string {
	return unsafe { cstring_to_vstring(C.witty_cimgui_version()) }
}

pub fn (ctx Context) config_flags() int {
	return C.witty_cimgui_config_flags(ctx.handle)
}

pub fn (ctx Context) display_size() (f32, f32) {
	return C.witty_cimgui_display_width(ctx.handle), C.witty_cimgui_display_height(ctx.handle)
}

pub fn (ctx Context) delta_time() f32 {
	return C.witty_cimgui_delta_time(ctx.handle)
}

pub fn (ctx Context) is_key_down(key Key) bool {
	return C.witty_cimgui_is_key_down(ctx.handle, int(key))
}

pub fn (ctx Context) build_font_atlas() bool {
	return C.witty_cimgui_build_font_atlas(ctx.handle)
}

pub fn (ctx Context) get_id(value string) u32 {
	return C.witty_cimgui_get_id(ctx.handle, value.str)
}

pub fn (ctx Context) dock_node_exists(id u32) bool {
	return C.witty_cimgui_dock_node_exists(ctx.handle, id)
}

pub fn (ctx Context) dock_node_add(id u32) bool {
	return C.witty_cimgui_dock_node_add(ctx.handle, id)
}

pub fn (ctx Context) dock_node_set_main_viewport_size(id u32) {
	C.witty_cimgui_dock_node_set_main_viewport_size(ctx.handle, id)
}

pub fn (ctx Context) dock_window(name string, id u32) {
	C.witty_cimgui_dock_window(ctx.handle, name.str, id)
}

pub fn (ctx Context) dock_finish(id u32) {
	C.witty_cimgui_dock_finish(ctx.handle, id)
}

pub fn (ctx Context) dock_space_over_main_viewport(id u32) bool {
	return C.witty_cimgui_dock_space_over_main_viewport(ctx.handle, id)
}

pub fn (ctx Context) begin_window(name string) bool {
	return C.witty_cimgui_begin_window(ctx.handle, name.str)
}

pub fn (ctx Context) end_window() {
	C.witty_cimgui_end_window(ctx.handle)
}

pub fn (ctx Context) set_window_focus(name string) {
	C.witty_cimgui_set_window_focus(ctx.handle, name.str)
}

pub fn (ctx Context) text(value string) {
	C.witty_cimgui_text(ctx.handle, value.str)
}

pub fn (ctx Context) text_disabled(value string) {
	C.witty_cimgui_text_disabled(ctx.handle, value.str)
}

pub fn (ctx Context) text_wrapped(value string) {
	C.witty_cimgui_text_wrapped(ctx.handle, value.str)
}

pub fn (ctx Context) collapsing_header(label string) bool {
	return C.witty_cimgui_collapsing_header(ctx.handle, label.str)
}

pub fn (ctx Context) separator_text(label string) {
	C.witty_cimgui_separator_text(ctx.handle, label.str)
}

pub fn (ctx Context) text_colored(color Color, value string) {
	C.witty_cimgui_text_colored(ctx.handle, color.r, color.g, color.b, color.a, value.str)
}

pub fn (ctx Context) button(label string) bool {
	return C.witty_cimgui_button(ctx.handle, label.str)
}

pub fn (ctx Context) small_button(label string) bool {
	return C.witty_cimgui_small_button(ctx.handle, label.str)
}

pub fn (ctx Context) separator() {
	C.witty_cimgui_separator(ctx.handle)
}

pub fn (ctx Context) begin_table(id string, columns int, flags int) bool {
	return C.witty_cimgui_begin_table(ctx.handle, id.str, columns, flags)
}

pub fn (ctx Context) end_table() {
	C.witty_cimgui_end_table(ctx.handle)
}

pub fn (ctx Context) table_setup_scroll_freeze(columns int, rows int) {
	C.witty_cimgui_table_setup_scroll_freeze(ctx.handle, columns, rows)
}

pub fn (ctx Context) table_setup_column(label string, flags int, width f32) {
	C.witty_cimgui_table_setup_column(ctx.handle, label.str, flags, width)
}

pub fn (ctx Context) table_headers_row() {
	C.witty_cimgui_table_headers_row(ctx.handle)
}

pub fn (ctx Context) table_next_row() {
	C.witty_cimgui_table_next_row(ctx.handle)
}

pub fn (ctx Context) table_set_column(column int) {
	C.witty_cimgui_table_set_column(ctx.handle, column)
}

pub fn (ctx Context) table_set_bg_color(target int, color u32) {
	C.witty_cimgui_table_set_bg_color(ctx.handle, target, color)
}

pub fn (ctx Context) push_id(value voidptr) {
	C.witty_cimgui_push_id_ptr(ctx.handle, value)
}

pub fn (ctx Context) pop_id() {
	C.witty_cimgui_pop_id(ctx.handle)
}

pub fn (ctx Context) same_line() {
	C.witty_cimgui_same_line(ctx.handle)
}

pub fn (ctx Context) new_line() {
	C.witty_cimgui_new_line(ctx.handle)
}

pub fn (ctx Context) item_hovered() bool {
	return C.witty_cimgui_item_hovered(ctx.handle)
}

pub fn (ctx Context) tooltip(value string) {
	C.witty_cimgui_tooltip(ctx.handle, value.str)
}

pub fn (ctx Context) cursor_screen_y() f32 {
	return C.witty_cimgui_cursor_screen_y(ctx.handle)
}

pub fn (ctx Context) mouse_y() f32 {
	return C.witty_cimgui_mouse_y(ctx.handle)
}

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
