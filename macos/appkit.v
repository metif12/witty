module macos

// AppKit/CoreText bindings for vterminal.
// V on macOS compiles with -x objective-c automatically,
// so the .m file is compiled as part of the V build.

#flag darwin -framework AppKit
#flag darwin -framework CoreText
#flag darwin -framework CoreFoundation
#flag darwin -framework CoreGraphics
#include "@VMODROOT/macos/appkit.m"

// Callback types matching the C typedefs in appkit.m.
// Each callback receives the view's userdata pointer as its first argument.
pub type DrawCallback = fn (userdata voidptr, ctx voidptr, width f64, height f64)
pub type KeyCallback = fn (userdata voidptr, keycode u16, modflags u64, chars &u8, len int, uchars &u8, ulen int, is_repeat bool)
pub type ResizeCallback = fn (userdata voidptr, width f64, height f64)
pub type ReadyCallback = fn ()

// C function declarations.
fn C.vt_app_init()
fn C.vt_app_run()
fn C.vt_create_window(w int, h int, title &char) voidptr
fn C.vt_set_draw_callback(cb DrawCallback)
fn C.vt_set_key_callback(cb KeyCallback)
fn C.vt_set_resize_callback(cb ResizeCallback)
fn C.vt_set_ready_callback(cb ReadyCallback)
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
