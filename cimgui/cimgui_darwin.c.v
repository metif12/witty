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
