module cimgui

#flag -DIMGUI_USE_WCHAR32=1

#flag -DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1

#flag -I@VMODROOT/cimgui

#flag -I@VMODROOT/cimgui/vendor/imgui

#flag -I@VMODROOT/cimgui/vendor/dear_bindings

#flag @VMODROOT/cimgui/lib/libdcimgui_linux.a

#pkgconfig freetype2

#flag -lstdc++

#flag -ldl

// Dear ImGui calls libm, which glibc keeps in a separate library.
#flag -lm

#include "bridge.h"

fn C.witty_cimgui_context_create() voidptr

fn C.witty_cimgui_set_backend_platform(context voidptr, platform int)

fn C.witty_cimgui_inspector_setup(context voidptr, font_data voidptr, font_len int)

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

fn C.witty_cimgui_screen_dockspace(context voidptr, id u32) bool

fn C.witty_cimgui_set_next_window_size_max(context voidptr, width f32, height f32)

fn C.witty_cimgui_begin_window(context voidptr, name &char) bool

fn C.witty_cimgui_begin_window_open(context voidptr, name &char, open &bool) bool

fn C.witty_cimgui_detachable_window(context voidptr, label &char, detached &bool, window_first &bool, dock bool) int

fn C.witty_cimgui_detachable_header(context voidptr, label &char, detached &bool) bool

fn C.witty_cimgui_end_window(context voidptr)

fn C.witty_cimgui_set_window_focus(context voidptr, name &char)

fn C.witty_cimgui_open_popup(context voidptr, name &char)

fn C.witty_cimgui_begin_popup_modal(context voidptr, name &char) bool

fn C.witty_cimgui_end_popup(context voidptr)

fn C.witty_cimgui_close_current_popup(context voidptr)

fn C.witty_cimgui_window_focused(context voidptr) bool

fn C.witty_cimgui_key_pressed(context voidptr, key int) bool

fn C.witty_cimgui_text(context voidptr, value &char)

fn C.witty_cimgui_text_disabled(context voidptr, value &char)

fn C.witty_cimgui_text_wrapped(context voidptr, value &char)

fn C.witty_cimgui_collapsing_header(context voidptr, label &char) bool

fn C.witty_cimgui_collapsing_header_default_open(context voidptr, label &char) bool

fn C.witty_cimgui_separator_text(context voidptr, label &char)

fn C.witty_cimgui_set_next_item_open(context voidptr, open bool)

fn C.witty_cimgui_checkbox(context voidptr, label &char, value &bool) bool

fn C.witty_cimgui_input_text(context voidptr, label &char, value &char, capacity usize) bool

fn C.witty_cimgui_input_u16(context voidptr, label &char, value &u16) bool

fn C.witty_cimgui_color_edit3(context voidptr, label &char, r f32, g f32, b f32, flags int) bool

fn C.witty_cimgui_input_u32(context voidptr, label &char, value &u32) bool

fn C.witty_cimgui_set_next_item_width_for_text(context voidptr, text &char)

fn C.witty_cimgui_begin_combo(context voidptr, label &char, preview &char) bool

fn C.witty_cimgui_end_combo(context voidptr)

fn C.witty_cimgui_selectable(context voidptr, label &char, selected bool) bool

fn C.witty_cimgui_set_item_default_focus(context voidptr)

fn C.witty_cimgui_begin_list_box(context voidptr, label &char) bool

fn C.witty_cimgui_end_list_box(context voidptr)

fn C.witty_cimgui_begin_rows_child(context voidptr, label &char, visible_rows u32) bool

fn C.witty_cimgui_end_child(context voidptr)

fn C.witty_cimgui_tree_node(context voidptr, label &char) bool

fn C.witty_cimgui_tree_node_flags(context voidptr, label &char, flags int) bool

fn C.witty_cimgui_item_rect_min_x(context voidptr) f32

fn C.witty_cimgui_item_rect_min_y(context voidptr) f32

fn C.witty_cimgui_item_rect_max_y(context voidptr) f32

fn C.witty_cimgui_text_line_height(context voidptr) f32

fn C.witty_cimgui_set_cursor_screen_pos(context voidptr, x f32, y f32)

fn C.witty_cimgui_tree_pop(context voidptr)

fn C.witty_cimgui_help_marker(context voidptr, value &char)

fn C.witty_cimgui_indent(context voidptr)

fn C.witty_cimgui_unindent(context voidptr)

fn C.witty_cimgui_color_button(context voidptr, label &char, r f32, g f32, b f32, a f32) bool

fn C.witty_cimgui_text_colored(context voidptr, r f32, g f32, b f32, a f32, value &char)

fn C.witty_cimgui_button(context voidptr, label &char) bool

fn C.witty_cimgui_small_button(context voidptr, label &char) bool

fn C.witty_cimgui_separator(context voidptr)

fn C.witty_cimgui_begin_table(context voidptr, id &char, columns int, flags int) bool

fn C.witty_cimgui_end_table(context voidptr)

fn C.witty_cimgui_table_setup_scroll_freeze(context voidptr, columns int, rows int)

fn C.witty_cimgui_table_setup_column(context voidptr, label &char, flags int, width f32)

fn C.witty_cimgui_table_headers_row(context voidptr)

fn C.witty_cimgui_screens_table_headers(context voidptr, help &char)

fn C.witty_cimgui_table_next_row(context voidptr)

fn C.witty_cimgui_table_next_column(context voidptr) bool

fn C.witty_cimgui_table_set_column(context voidptr, column int)

fn C.witty_cimgui_table_set_bg_color(context voidptr, target int, color u32)

fn C.witty_cimgui_selectable_bool(context voidptr, label &char, selected &bool) bool

fn C.witty_cimgui_set_scroll_here_y(context voidptr, ratio f32)

fn C.witty_cimgui_push_id_ptr(context voidptr, value voidptr)

fn C.witty_cimgui_push_id_str(context voidptr, value &char)

fn C.witty_cimgui_push_id_int(context voidptr, value int)

fn C.witty_cimgui_pop_id(context voidptr)

fn C.witty_cimgui_same_line(context voidptr)

fn C.witty_cimgui_new_line(context voidptr)

fn C.witty_cimgui_item_hovered(context voidptr) bool

fn C.witty_cimgui_item_hovered_delay_short(context voidptr) bool

fn C.witty_cimgui_begin_disabled(context voidptr, disabled bool)

fn C.witty_cimgui_end_disabled(context voidptr)

fn C.witty_cimgui_push_item_width_for_text(context voidptr, text &char)

fn C.witty_cimgui_pop_item_width(context voidptr)

fn C.witty_cimgui_align_text_to_frame_padding(context voidptr)

fn C.witty_cimgui_pagelist_scrollbar(context voidptr, total usize, offset usize, len usize) i64

fn C.witty_cimgui_tooltip(context voidptr, value &char)

fn C.witty_cimgui_cursor_screen_y(context voidptr) f32

fn C.witty_cimgui_mouse_y(context voidptr) f32

fn C.witty_cimgui_opengl_init(context voidptr) bool

fn C.witty_cimgui_opengl_shutdown(context voidptr)

fn C.witty_cimgui_opengl_new_frame(context voidptr)

fn C.witty_cimgui_opengl_render(context voidptr)

pub fn available() bool {
	return true
}

pub fn Context.create() !Context {
	handle := C.witty_cimgui_context_create()
	if isnil(handle) {
		return error('out of memory creating Dear ImGui context')
	}
	return Context{ handle: handle }
}

pub fn (ctx Context) set_backend_platform(platform BackendPlatform) {
	C.witty_cimgui_set_backend_platform(ctx.handle, int(platform))
}

// inspector_setup is the low-level dcimgui binding used by inspector.setup.
// It is separate from context creation because Ghostty invokes setup only
// after the runtime has selected and initialized the context.
pub fn (ctx Context) inspector_setup(font_data []u8) {
	C.witty_cimgui_inspector_setup(ctx.handle, font_data.data, font_data.len)
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

pub fn (ctx Context) screen_dockspace(id u32) bool {
	return C.witty_cimgui_screen_dockspace(ctx.handle, id)
}

pub fn (ctx Context) set_next_window_size_max(width f32, height f32) {
	C.witty_cimgui_set_next_window_size_max(ctx.handle, width, height)
}

pub fn (ctx Context) begin_window(name string) bool {
	return C.witty_cimgui_begin_window(ctx.handle, name.str)
}

pub fn (ctx Context) begin_window_open(name string, open bool) (bool, bool) {
	mut updated := open
	visible := C.witty_cimgui_begin_window_open(ctx.handle, name.str, &updated)
	return visible, updated
}

pub fn (ctx Context) detachable_window(label string, detached bool, window_first bool, dock bool) (int, bool, bool) {
	mut updated_detached := detached
	mut updated_first := window_first
	visible := C.witty_cimgui_detachable_window(ctx.handle, label.str, &updated_detached, &updated_first, dock)
	return visible, updated_detached, updated_first
}

pub fn (ctx Context) detachable_header(label string, detached bool) (bool, bool) {
	mut updated := detached
	open := C.witty_cimgui_detachable_header(ctx.handle, label.str, &updated)
	return open, updated
}

pub fn (ctx Context) end_window() {
	C.witty_cimgui_end_window(ctx.handle)
}

pub fn (ctx Context) set_window_focus(name string) {
	C.witty_cimgui_set_window_focus(ctx.handle, name.str)
}

pub fn (ctx Context) open_popup(name string) {
	C.witty_cimgui_open_popup(ctx.handle, name.str)
}

pub fn (ctx Context) begin_popup_modal(name string) bool {
	return C.witty_cimgui_begin_popup_modal(ctx.handle, name.str)
}

pub fn (ctx Context) end_popup() {
	C.witty_cimgui_end_popup(ctx.handle)
}

pub fn (ctx Context) close_current_popup() {
	C.witty_cimgui_close_current_popup(ctx.handle)
}

pub fn (ctx Context) window_focused() bool {
	return C.witty_cimgui_window_focused(ctx.handle)
}

pub fn (ctx Context) key_pressed(key Key) bool {
	return C.witty_cimgui_key_pressed(ctx.handle, int(key))
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

pub fn (ctx Context) collapsing_header_default_open(label string) bool {
	return C.witty_cimgui_collapsing_header_default_open(ctx.handle, label.str)
}

pub fn (ctx Context) separator_text(label string) {
	C.witty_cimgui_separator_text(ctx.handle, label.str)
}

pub fn (ctx Context) set_next_item_open(open bool) {
	C.witty_cimgui_set_next_item_open(ctx.handle, open)
}

pub fn (ctx Context) checkbox(label string, value bool) (bool, bool) {
	mut updated := value
	changed := C.witty_cimgui_checkbox(ctx.handle, label.str, &updated)
	return changed, updated
}

pub fn (ctx Context) input_text(label string, value string) (bool, string) {
	mut buffer := [512]u8{}
	length := if value.len < buffer.len - 1 { value.len } else { buffer.len - 1 }
	copy(mut buffer[..length], value.bytes()[..length])
	changed := C.witty_cimgui_input_text(ctx.handle, label.str, &char(&buffer[0]), buffer.len)
	return changed, unsafe { cstring_to_vstring(&char(&buffer[0])) }.clone()
}

pub fn (ctx Context) input_u16(label string, value u16) (bool, u16) {
	mut updated := value
	changed := C.witty_cimgui_input_u16(ctx.handle, label.str, &updated)
	return changed, updated
}

pub fn (ctx Context) color_edit3(label string, color Color, flags int) bool {
	return C.witty_cimgui_color_edit3(ctx.handle, label.str, color.r, color.g, color.b, flags)
}

pub fn (ctx Context) input_u32(label string, value u32) (bool, u32) {
	mut updated := value
	changed := C.witty_cimgui_input_u32(ctx.handle, label.str, &updated)
	return changed, updated
}

pub fn (ctx Context) set_next_item_width_for_text(text string) {
	C.witty_cimgui_set_next_item_width_for_text(ctx.handle, text.str)
}

pub fn (ctx Context) begin_combo(label string, preview string) bool {
	return C.witty_cimgui_begin_combo(ctx.handle, label.str, preview.str)
}

pub fn (ctx Context) end_combo() {
	C.witty_cimgui_end_combo(ctx.handle)
}

pub fn (ctx Context) selectable(label string, selected bool) bool {
	return C.witty_cimgui_selectable(ctx.handle, label.str, selected)
}

pub fn (ctx Context) set_item_default_focus() {
	C.witty_cimgui_set_item_default_focus(ctx.handle)
}

pub fn (ctx Context) begin_list_box(label string) bool {
	return C.witty_cimgui_begin_list_box(ctx.handle, label.str)
}

pub fn (ctx Context) end_list_box() {
	C.witty_cimgui_end_list_box(ctx.handle)
}

pub fn (ctx Context) begin_rows_child(label string, visible_rows u32) bool {
	return C.witty_cimgui_begin_rows_child(ctx.handle, label.str, visible_rows)
}

pub fn (ctx Context) end_child() {
	C.witty_cimgui_end_child(ctx.handle)
}

pub fn (ctx Context) tree_node(label string) bool {
	return C.witty_cimgui_tree_node(ctx.handle, label.str)
}

pub fn (ctx Context) tree_node_flags(label string, flags int) bool {
	return C.witty_cimgui_tree_node_flags(ctx.handle, label.str, flags)
}

pub fn (ctx Context) item_rect_min() (f32, f32) {
	return C.witty_cimgui_item_rect_min_x(ctx.handle), C.witty_cimgui_item_rect_min_y(ctx.handle)
}

pub fn (ctx Context) item_rect_max_y() f32 {
	return C.witty_cimgui_item_rect_max_y(ctx.handle)
}

pub fn (ctx Context) text_line_height() f32 {
	return C.witty_cimgui_text_line_height(ctx.handle)
}

pub fn (ctx Context) set_cursor_screen_pos(x f32, y f32) {
	C.witty_cimgui_set_cursor_screen_pos(ctx.handle, x, y)
}

pub fn (ctx Context) tree_pop() {
	C.witty_cimgui_tree_pop(ctx.handle)
}

pub fn (ctx Context) help_marker(value string) {
	C.witty_cimgui_help_marker(ctx.handle, value.str)
}

pub fn (ctx Context) indent() {
	C.witty_cimgui_indent(ctx.handle)
}

pub fn (ctx Context) unindent() {
	C.witty_cimgui_unindent(ctx.handle)
}

pub fn (ctx Context) color_button(label string, color Color) bool {
	return C.witty_cimgui_color_button(ctx.handle, label.str, color.r, color.g, color.b, color.a)
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

pub fn (ctx Context) screens_table_headers(help string) {
	C.witty_cimgui_screens_table_headers(ctx.handle, help.str)
}

pub fn (ctx Context) table_next_row() {
	C.witty_cimgui_table_next_row(ctx.handle)
}

pub fn (ctx Context) table_next_column() bool {
	return C.witty_cimgui_table_next_column(ctx.handle)
}

pub fn (ctx Context) table_set_column(column int) {
	C.witty_cimgui_table_set_column(ctx.handle, column)
}

pub fn (ctx Context) table_set_bg_color(target int, color u32) {
	C.witty_cimgui_table_set_bg_color(ctx.handle, target, color)
}

pub fn (ctx Context) selectable_bool(label string, selected bool) (bool, bool) {
	mut updated := selected
	changed := C.witty_cimgui_selectable_bool(ctx.handle, label.str, &updated)
	return changed, updated
}

pub fn (ctx Context) set_scroll_here_y(ratio f32) {
	C.witty_cimgui_set_scroll_here_y(ctx.handle, ratio)
}

pub fn (ctx Context) push_id(value voidptr) {
	C.witty_cimgui_push_id_ptr(ctx.handle, value)
}

pub fn (ctx Context) push_id_str(value string) {
	C.witty_cimgui_push_id_str(ctx.handle, value.str)
}

pub fn (ctx Context) push_id_int(value int) {
	C.witty_cimgui_push_id_int(ctx.handle, value)
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

pub fn (ctx Context) item_hovered_delay_short() bool {
	return C.witty_cimgui_item_hovered_delay_short(ctx.handle)
}

pub fn (ctx Context) begin_disabled(disabled bool) {
	C.witty_cimgui_begin_disabled(ctx.handle, disabled)
}

pub fn (ctx Context) end_disabled() {
	C.witty_cimgui_end_disabled(ctx.handle)
}

pub fn (ctx Context) push_item_width_for_text(text string) {
	C.witty_cimgui_push_item_width_for_text(ctx.handle, text.str)
}

pub fn (ctx Context) pop_item_width() {
	C.witty_cimgui_pop_item_width(ctx.handle)
}

pub fn (ctx Context) align_text_to_frame_padding() {
	C.witty_cimgui_align_text_to_frame_padding(ctx.handle)
}

pub fn (ctx Context) pagelist_scrollbar(total usize, offset usize, len usize) i64 {
	return C.witty_cimgui_pagelist_scrollbar(ctx.handle, total, offset, len)
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

pub fn (ctx Context) opengl_init() bool {
	return C.witty_cimgui_opengl_init(ctx.handle)
}

pub fn (ctx Context) opengl_shutdown() {
	C.witty_cimgui_opengl_shutdown(ctx.handle)
}

pub fn (ctx Context) opengl_new_frame() {
	C.witty_cimgui_opengl_new_frame(ctx.handle)
}

pub fn (ctx Context) opengl_render() {
	C.witty_cimgui_opengl_render(ctx.handle)
}

// The embedded C API exposes Metal entry points on every target even though
// they are only usable on macOS. Keep that cross-platform API shape while the
// Linux inspector uses the OpenGL methods above.
pub fn (ctx Context) metal_init(device voidptr) bool {
	_ = ctx
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
