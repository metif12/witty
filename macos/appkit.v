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
pub type DrawCallback = fn (ctx voidptr, width f64, height f64)
pub type KeyCallback = fn (chars &u8, len int)
pub type ResizeCallback = fn (width f64, height f64)
pub type ReadyCallback = fn ()

// C function declarations.
fn C.vt_app_init()
fn C.vt_app_run()
fn C.vt_create_window(w int, h int, title &char) voidptr
fn C.vt_set_draw_callback(cb DrawCallback)
fn C.vt_set_key_callback(cb KeyCallback)
fn C.vt_set_resize_callback(cb ResizeCallback)
fn C.vt_set_ready_callback(cb ReadyCallback)
fn C.vt_request_display()
fn C.vt_view_width() f64
fn C.vt_view_height() f64
fn C.vt_ct_font_attribute_name() voidptr
fn C.vt_set_userdata(ptr voidptr)
fn C.vt_get_userdata() voidptr
fn C.vt_create_font(name &char, size f64) voidptr
fn C.vt_draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64)

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

pub fn request_display() {
	C.vt_request_display()
}

pub fn view_width() f64 {
	return C.vt_view_width()
}

pub fn view_height() f64 {
	return C.vt_view_height()
}

pub fn ct_font_attribute_name() voidptr {
	return C.vt_ct_font_attribute_name()
}

pub fn set_userdata(ptr voidptr) {
	C.vt_set_userdata(ptr)
}

pub fn get_userdata() voidptr {
	return C.vt_get_userdata()
}

pub fn create_font(name string, size f64) voidptr {
	return C.vt_create_font(name.str, size)
}

pub fn draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64) {
	C.vt_draw_text(ctx, text, text_len, font, x, y, fg_r, fg_g, fg_b)
}
