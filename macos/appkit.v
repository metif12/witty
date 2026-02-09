module macos

// AppKit/CoreText bindings for Witty.
// V on macOS compiles with -x objective-c automatically,
// so the .m file is compiled as part of the V build.

#flag darwin -framework AppKit
#flag darwin -framework CoreText
#flag darwin -framework CoreFoundation
#flag darwin -framework CoreGraphics
#flag darwin -framework Metal
#flag darwin -framework QuartzCore
#include "@VMODROOT/macos/appkit.m"

// Callback types matching the C typedefs in appkit.m.
// Each callback receives the view's userdata pointer as its first argument.
pub type DrawCallback = fn (userdata voidptr, ctx voidptr, width f64, height f64)
pub type KeyCallback = fn (userdata voidptr, keycode u16, modflags u64, chars &u8, len int, uchars &u8, ulen int, is_repeat bool)
pub type ResizeCallback = fn (userdata voidptr, width f64, height f64)
pub type ReadyCallback = fn ()
pub type PasteCallback = fn (userdata voidptr, text &u8, len int)
pub type ActionCallback = fn (userdata voidptr, action_id int)
pub type MouseCallback = fn (userdata voidptr, event_type int, x f64, y f64, modflags u64)

// C function declarations.
fn C.vt_app_init()
fn C.vt_app_run()
fn C.vt_create_window(w int, h int, title &char) voidptr
fn C.vt_set_draw_callback(cb DrawCallback)
fn C.vt_set_key_callback(cb KeyCallback)
fn C.vt_set_resize_callback(cb ResizeCallback)
fn C.vt_set_ready_callback(cb ReadyCallback)
fn C.vt_set_paste_callback(cb PasteCallback)
fn C.vt_set_action_callback(cb ActionCallback)
fn C.vt_set_mouse_callback(cb MouseCallback)
fn C.vt_clipboard_set_text(text &u8, len int)
fn C.vt_request_display(view voidptr)
fn C.vt_view_width(view voidptr) f64
fn C.vt_view_height(view voidptr) f64
fn C.vt_ct_font_attribute_name() voidptr
fn C.vt_view_set_userdata(view voidptr, ptr voidptr)
fn C.vt_view_get_userdata(view voidptr) voidptr
fn C.vt_create_font(name &char, size f64) voidptr
fn C.vt_draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64)
fn C.vt_new_tab(w int, h int, title &char) voidptr
fn C.vt_close_tab(view voidptr)
fn C.vt_select_tab(offset int)
fn C.vt_tab_count() int

// Metal C function declarations.
fn C.vt_metal_activate_layer(view voidptr)
fn C.vt_metal_device(view voidptr) voidptr
fn C.vt_metal_queue(view voidptr) voidptr
fn C.vt_metal_layer(view voidptr) voidptr
fn C.vt_metal_next_drawable(layer voidptr) voidptr
fn C.vt_metal_drawable_texture(drawable voidptr) voidptr
fn C.vt_metal_create_command_buffer(queue voidptr) voidptr
fn C.vt_metal_create_render_pass(texture voidptr, r f64, g f64, b f64, a f64) voidptr
fn C.vt_metal_create_encoder(cmd_buf voidptr, pass voidptr) voidptr
fn C.vt_metal_end_encoding(encoder voidptr)
fn C.vt_metal_present_and_commit(cmd_buf voidptr, drawable voidptr)
fn C.vt_metal_release(ptr voidptr)
fn C.vt_metal_max_texture_size(device voidptr) u32
fn C.vt_metal_has_unified_memory(device voidptr) bool

// V-friendly wrappers.
pub fn app_init() {
	C.vt_app_init()
}

pub fn app_run() {
	C.vt_app_run()
}

pub fn create_window(w int, h int, title string) voidptr {
	return C.vt_create_window(w, h, title.str)
}

pub fn set_draw_callback(cb DrawCallback) {
	C.vt_set_draw_callback(cb)
}

pub fn set_key_callback(cb KeyCallback) {
	C.vt_set_key_callback(cb)
}

pub fn set_resize_callback(cb ResizeCallback) {
	C.vt_set_resize_callback(cb)
}

pub fn set_ready_callback(cb ReadyCallback) {
	C.vt_set_ready_callback(cb)
}

pub fn set_paste_callback(cb PasteCallback) {
	C.vt_set_paste_callback(cb)
}

pub fn set_action_callback(cb ActionCallback) {
	C.vt_set_action_callback(cb)
}

pub fn set_mouse_callback(cb MouseCallback) {
	C.vt_set_mouse_callback(cb)
}

pub fn clipboard_set_text(text string) {
	C.vt_clipboard_set_text(text.str, text.len)
}

pub fn request_display(view voidptr) {
	C.vt_request_display(view)
}

pub fn view_width(view voidptr) f64 {
	return C.vt_view_width(view)
}

pub fn view_height(view voidptr) f64 {
	return C.vt_view_height(view)
}

pub fn ct_font_attribute_name() voidptr {
	return C.vt_ct_font_attribute_name()
}

pub fn view_set_userdata(view voidptr, ptr voidptr) {
	C.vt_view_set_userdata(view, ptr)
}

pub fn view_get_userdata(view voidptr) voidptr {
	return C.vt_view_get_userdata(view)
}

pub fn create_font(name string, size f64) voidptr {
	return C.vt_create_font(name.str, size)
}

pub fn draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64) {
	C.vt_draw_text(ctx, text, text_len, font, x, y, fg_r, fg_g, fg_b)
}

pub fn new_tab(w int, h int, title string) voidptr {
	return C.vt_new_tab(w, h, title.str)
}

pub fn close_tab(view voidptr) {
	C.vt_close_tab(view)
}

pub fn select_tab(offset int) {
	C.vt_select_tab(offset)
}

pub fn tab_count() int {
	return C.vt_tab_count()
}

// Metal wrappers.
pub fn metal_activate_layer(view voidptr) {
	C.vt_metal_activate_layer(view)
}

pub fn metal_device(view voidptr) voidptr {
	return C.vt_metal_device(view)
}

pub fn metal_queue(view voidptr) voidptr {
	return C.vt_metal_queue(view)
}

pub fn metal_layer(view voidptr) voidptr {
	return C.vt_metal_layer(view)
}

pub fn metal_next_drawable(layer voidptr) voidptr {
	return C.vt_metal_next_drawable(layer)
}

pub fn metal_drawable_texture(drawable voidptr) voidptr {
	return C.vt_metal_drawable_texture(drawable)
}

pub fn metal_create_command_buffer(queue voidptr) voidptr {
	return C.vt_metal_create_command_buffer(queue)
}

pub fn metal_create_render_pass(texture voidptr, r f64, g f64, b f64, a f64) voidptr {
	return C.vt_metal_create_render_pass(texture, r, g, b, a)
}

pub fn metal_create_encoder(cmd_buf voidptr, pass voidptr) voidptr {
	return C.vt_metal_create_encoder(cmd_buf, pass)
}

pub fn metal_end_encoding(encoder voidptr) {
	C.vt_metal_end_encoding(encoder)
}

pub fn metal_present_and_commit(cmd_buf voidptr, drawable voidptr) {
	C.vt_metal_present_and_commit(cmd_buf, drawable)
}

pub fn metal_release(ptr voidptr) {
	C.vt_metal_release(ptr)
}

pub fn metal_max_texture_size(device voidptr) u32 {
	return C.vt_metal_max_texture_size(device)
}

pub fn metal_has_unified_memory(device voidptr) bool {
	return C.vt_metal_has_unified_memory(device)
}
