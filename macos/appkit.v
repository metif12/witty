@[has_globals]
module macos

import os

// AppKit/Metal bindings for Witty, implemented from V through the macOS
// Objective-C runtime bridge that ships with vlib.

#flag darwin -framework AppKit

#flag darwin -framework Foundation

#flag darwin -framework CoreText

#flag darwin -framework CoreFoundation

#flag darwin -framework CoreGraphics

#flag darwin -framework Metal

#flag darwin -framework QuartzCore

#flag darwin -lobjc

#insert "@VEXEROOT/vlib/macos/objc_bridge.h"

#insert "@VMODROOT/macos/appkit_bridge.h"

// Callback types. Each callback receives the view's userdata pointer first.
pub type DrawCallback = fn (userdata voidptr, ctx voidptr, width f64, height f64)

pub type KeyCallback = fn (userdata voidptr, keycode u16, modflags u64, chars &u8, len int, uchars &u8, ulen int, is_repeat bool)

pub type ResizeCallback = fn (userdata voidptr, width f64, height f64)

pub type ReadyCallback = fn ()

pub type PasteCallback = fn (userdata voidptr, text &u8, len int)

pub type ActionCallback = fn (userdata voidptr, action_id int)

pub type MouseCallback = fn (userdata voidptr, event_type int, x f64, y f64, modflags u64)

type ObjId = voidptr

type Sel = voidptr

type ObjCRect = C.macos_rect

type ObjCPoint = C.witty_macos_point

type ObjCSize = C.witty_macos_size

type MetalClearColor = C.witty_macos_clear_color

pub struct C.macos_rect {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
}

struct C.witty_macos_point {
mut:
	x f64
	y f64
}

struct C.witty_macos_size {
mut:
	width  f64
	height f64
}

struct C.witty_macos_clear_color {
mut:
	red   f64
	green f64
	blue  f64
	alpha f64
}

fn C.macos_objc_msg_id0(obj ObjId, selector Sel) ObjId

fn C.macos_objc_msg_id1(obj ObjId, selector Sel, a0 voidptr) ObjId

fn C.macos_objc_msg_id2(obj ObjId, selector Sel, a0 voidptr, a1 voidptr) ObjId

fn C.macos_objc_msg_id3(obj ObjId, selector Sel, a0 voidptr, a1 voidptr, a2 voidptr) ObjId

fn C.macos_objc_msg_id_rect(obj ObjId, selector Sel, rect ObjCRect) ObjId

fn C.macos_objc_msg_id_rect_u64_u64_bool(obj ObjId, selector Sel, rect ObjCRect, a1 u64, a2 u64, a3 bool) ObjId

fn C.macos_objc_msg_id_obj_sel_obj(obj ObjId, selector Sel, a0 voidptr, a1 voidptr, a2 voidptr) ObjId

fn C.macos_objc_msg_id_f64(obj ObjId, selector Sel, a0 f64) ObjId

fn C.macos_objc_msg_id_u64(obj ObjId, selector Sel, a0 u64) ObjId

fn C.macos_objc_msg_void0(obj ObjId, selector Sel)

fn C.macos_objc_msg_void1(obj ObjId, selector Sel, a0 voidptr)

fn C.macos_objc_msg_void2(obj ObjId, selector Sel, a0 voidptr, a1 voidptr)

fn C.macos_objc_msg_void_bool(obj ObjId, selector Sel, a0 bool)

fn C.macos_objc_msg_void_u64(obj ObjId, selector Sel, a0 u64)

fn C.macos_objc_msg_void_f64(obj ObjId, selector Sel, a0 f64)

fn C.macos_objc_msg_void_rect(obj ObjId, selector Sel, rect ObjCRect)

fn C.macos_objc_msg_bool0(obj ObjId, selector Sel) bool

fn C.macos_objc_msg_bool1(obj ObjId, selector Sel, a0 voidptr) bool

fn C.macos_objc_msg_i64(obj ObjId, selector Sel) i64

fn C.macos_objc_msg_u64(obj ObjId, selector Sel) u64

fn C.macos_objc_msg_f64(obj ObjId, selector Sel) f64

fn C.macos_objc_msg_rect(obj ObjId, selector Sel) ObjCRect

fn C.macos_objc_get_class(name &char) ObjId

fn C.macos_objc_get_protocol(name &char) ObjId

fn C.macos_sel_register_name(name &char) Sel

fn C.macos_objc_allocate_class_pair(superclass ObjId, name &char, extra_bytes usize) ObjId

fn C.macos_objc_register_class_pair(cls ObjId)

fn C.macos_class_add_method(cls ObjId, name Sel, imp voidptr, types &char) bool

fn C.macos_class_add_ivar(cls ObjId, name &char, size usize, alignment u8, types &char) bool

fn C.macos_class_add_protocol(cls ObjId, protocol ObjId) bool

fn C.macos_objc_set_ptr_ivar(obj ObjId, name &char, value voidptr)

fn C.macos_objc_get_ptr_ivar(obj ObjId, name &char) voidptr

fn C.macos_set_associated_object(obj ObjId, key voidptr, value ObjId, policy usize)

fn C.macos_get_associated_object(obj ObjId, key voidptr) ObjId

fn C.witty_macos_objc_msg_point0(obj ObjId, selector Sel) ObjCPoint

fn C.witty_macos_objc_msg_point_point_obj(obj ObjId, selector Sel, point ObjCPoint, a1 voidptr) ObjCPoint

fn C.witty_macos_objc_msg_bool2(obj ObjId, selector Sel, a0 voidptr, a1 voidptr) bool

fn C.witty_macos_objc_msg_bool_u64(obj ObjId, selector Sel, a0 u64) bool

fn C.witty_macos_objc_msg_void_size(obj ObjId, selector Sel, size ObjCSize)

fn C.witty_macos_objc_msg_void_clear_color(obj ObjId, selector Sel, color MetalClearColor)

fn C.witty_macos_is_main_thread() bool

fn C.witty_macos_dispatch_main(fnptr voidptr, ctx voidptr)

fn C.witty_macos_string_task_new(view voidptr, text &char) &C.witty_macos_string_task

fn C.witty_macos_string_task_free(task &C.witty_macos_string_task)

struct C.witty_macos_string_task {
	view voidptr
	text &char
}

fn C.MTLCreateSystemDefaultDevice() ObjId

fn C.vt_ct_font_attribute_name() voidptr

fn C.vt_create_font(name &char, size f64) voidptr

fn C.vt_draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64)

const vt_action_copy = 1
const vt_action_select_all = 2
const vt_action_new_tab = 3
const vt_action_close_tab = 4

const ns_application_activation_policy_regular = u64(0)
const ns_backing_store_buffered = u64(2)
const ns_window_above = u64(1)
const ns_window_tabbing_mode_automatic = u64(1)
const ns_window_style_titled = u64(1 << 0)
const ns_window_style_closable = u64(1 << 1)
const ns_window_style_miniaturizable = u64(1 << 2)
const ns_window_style_resizable = u64(1 << 3)
const ns_window_collection_behavior_full_screen_primary = u64(1 << 7)
const ns_event_modifier_flag_control = u64(1 << 18)
const ns_event_modifier_flag_option = u64(1 << 19)
const ns_event_modifier_flag_command = u64(1 << 20)
const ns_event_modifier_flag_device_independent_mask = u64(0xffff0000)
const objc_assoc_copy_nonatomic = usize(3)
const mtl_pixel_format_bgra8unorm = u64(80)
const mtl_load_action_clear = u64(2)
const mtl_store_action_store = u64(1)
const mtl_gpu_family_apple3 = u64(3003)

__global (
	g_draw_cb            DrawCallback
	g_key_cb             KeyCallback
	g_resize_cb          ResizeCallback
	g_ready_cb           ReadyCallback
	g_paste_cb           PasteCallback
	g_action_cb          ActionCallback
	g_mouse_cb           MouseCallback
	g_app_terminating    bool
	g_classes_registered bool
	g_window             ObjId
	g_delegate           ObjId
	g_base_title_key     int
)

@[inline]
fn nil_obj() ObjId {
	return unsafe { nil }
}

@[inline]
fn is_nil(obj ObjId) bool {
	return obj == unsafe { nil }
}

@[inline]
fn cstr(s string) &char {
	return &char(s.str)
}

@[inline]
fn get_class(name string) ObjId {
	return ObjId(C.macos_objc_get_class(cstr(name)))
}

@[inline]
fn get_protocol(name string) ObjId {
	return C.macos_objc_get_protocol(cstr(name))
}

@[inline]
fn sel(name string) Sel {
	return C.macos_sel_register_name(cstr(name))
}

@[inline]
fn objc_rect(x f64, y f64, width f64, height f64) ObjCRect {
	return ObjCRect{
		x: x
		y: y
		width: width
		height: height
	}
}

@[inline]
fn objc_size(width f64, height f64) ObjCSize {
	return ObjCSize{
		width: width
		height: height
	}
}

@[inline]
fn msg_id(obj ObjId, selector string) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id0(obj, sel(selector))
}

@[inline]
fn msg_id1(obj ObjId, selector string, a0 ObjId) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id1(obj, sel(selector), a0)
}

@[inline]
fn msg_id2(obj ObjId, selector string, a0 ObjId, a1 ObjId) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id2(obj, sel(selector), a0, a1)
}

@[inline]
fn msg_id3(obj ObjId, selector string, a0 ObjId, a1 ObjId, a2 ObjId) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id3(obj, sel(selector), a0, a1, a2)
}

@[inline]
fn msg_id_rect(obj ObjId, selector string, rect ObjCRect) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id_rect(obj, sel(selector), rect)
}

@[inline]
fn msg_id_rect_u64_u64_bool(obj ObjId, selector string, rect ObjCRect, a1 u64, a2 u64, a3 bool) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id_rect_u64_u64_bool(obj, sel(selector), rect, a1, a2, a3)
}

@[inline]
fn msg_id_obj_sel_obj(obj ObjId, selector string, a0 ObjId, a1 Sel, a2 ObjId) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id_obj_sel_obj(obj, sel(selector), a0, a1, a2)
}

@[inline]
fn msg_id_f64(obj ObjId, selector string, a0 f64) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id_f64(obj, sel(selector), a0)
}

@[inline]
fn msg_id_u64(obj ObjId, selector string, a0 u64) ObjId {
	if is_nil(obj) {
		return nil_obj()
	}
	return C.macos_objc_msg_id_u64(obj, sel(selector), a0)
}

@[inline]
fn msg_void(obj ObjId, selector string) {
	if !is_nil(obj) {
		C.macos_objc_msg_void0(obj, sel(selector))
	}
}

@[inline]
fn msg_void1(obj ObjId, selector string, a0 ObjId) {
	if !is_nil(obj) {
		C.macos_objc_msg_void1(obj, sel(selector), a0)
	}
}

@[inline]
fn msg_void2(obj ObjId, selector string, a0 ObjId, a1 ObjId) {
	if !is_nil(obj) {
		C.macos_objc_msg_void2(obj, sel(selector), a0, a1)
	}
}

@[inline]
fn msg_void_bool(obj ObjId, selector string, a0 bool) {
	if !is_nil(obj) {
		C.macos_objc_msg_void_bool(obj, sel(selector), a0)
	}
}

@[inline]
fn msg_void_u64(obj ObjId, selector string, a0 u64) {
	if !is_nil(obj) {
		C.macos_objc_msg_void_u64(obj, sel(selector), a0)
	}
}

@[inline]
fn msg_void_f64(obj ObjId, selector string, a0 f64) {
	if !is_nil(obj) {
		C.macos_objc_msg_void_f64(obj, sel(selector), a0)
	}
}

@[inline]
fn msg_void_rect(obj ObjId, selector string, rect ObjCRect) {
	if !is_nil(obj) {
		C.macos_objc_msg_void_rect(obj, sel(selector), rect)
	}
}

@[inline]
fn msg_void_size(obj ObjId, selector string, size ObjCSize) {
	if !is_nil(obj) {
		C.witty_macos_objc_msg_void_size(obj, sel(selector), size)
	}
}

@[inline]
fn msg_bool(obj ObjId, selector string) bool {
	if is_nil(obj) {
		return false
	}
	return C.macos_objc_msg_bool0(obj, sel(selector))
}

@[inline]
fn msg_bool1(obj ObjId, selector string, a0 ObjId) bool {
	if is_nil(obj) {
		return false
	}
	return C.macos_objc_msg_bool1(obj, sel(selector), a0)
}

@[inline]
fn msg_bool2(obj ObjId, selector string, a0 ObjId, a1 ObjId) bool {
	if is_nil(obj) {
		return false
	}
	return C.witty_macos_objc_msg_bool2(obj, sel(selector), a0, a1)
}

@[inline]
fn msg_bool_u64(obj ObjId, selector string, a0 u64) bool {
	if is_nil(obj) {
		return false
	}
	return C.witty_macos_objc_msg_bool_u64(obj, sel(selector), a0)
}

@[inline]
fn msg_u64(obj ObjId, selector string) u64 {
	if is_nil(obj) {
		return 0
	}
	return C.macos_objc_msg_u64(obj, sel(selector))
}

@[inline]
fn msg_i64(obj ObjId, selector string) i64 {
	if is_nil(obj) {
		return 0
	}
	return C.macos_objc_msg_i64(obj, sel(selector))
}

@[inline]
fn msg_f64(obj ObjId, selector string) f64 {
	if is_nil(obj) {
		return 0
	}
	return C.macos_objc_msg_f64(obj, sel(selector))
}

@[inline]
fn msg_rect(obj ObjId, selector string) ObjCRect {
	if is_nil(obj) {
		return objc_rect(0, 0, 0, 0)
	}
	return C.macos_objc_msg_rect(obj, sel(selector))
}

@[inline]
fn msg_point(obj ObjId, selector string) ObjCPoint {
	if is_nil(obj) {
		return ObjCPoint{}
	}
	return C.witty_macos_objc_msg_point0(obj, sel(selector))
}

@[inline]
fn msg_point_point_obj(obj ObjId, selector string, point ObjCPoint, other ObjId) ObjCPoint {
	if is_nil(obj) {
		return ObjCPoint{}
	}
	return C.witty_macos_objc_msg_point_point_obj(obj, sel(selector), point, other)
}

@[inline]
fn nsstring(s string) ObjId {
	return C.macos_objc_msg_id1(get_class('NSString'), sel('stringWithUTF8String:'), cstr(s))
}

fn objc_utf8_string(obj ObjId) string {
	if is_nil(obj) {
		return ''
	}
	ptr := &char(C.macos_objc_msg_id0(obj, sel('UTF8String')))
	if ptr == unsafe { nil } {
		return ''
	}
	return unsafe { ptr.vstring().clone() }
}

fn shared_app() ObjId {
	return msg_id(get_class('NSApplication'), 'sharedApplication')
}

fn alloc(class_name string) ObjId {
	return msg_id(get_class(class_name), 'alloc')
}

fn new_obj(class_name string) ObjId {
	return msg_id(get_class(class_name), 'new')
}

fn add_method(cls ObjId, name string, imp voidptr, types string) {
	C.macos_class_add_method(cls, sel(name), imp, cstr(types))
}

fn add_ptr_ivar(cls ObjId, name string) {
	C.macos_class_add_ivar(cls, cstr(name), usize(8), u8(3), cstr('^v'))
}

fn register_classes() {
	if g_classes_registered {
		return
	}
	g_classes_registered = true

	mut view_cls := get_class('VTTerminalView')
	if is_nil(view_cls) {
		view_cls = C.macos_objc_allocate_class_pair(get_class('NSView'), cstr('VTTerminalView'), 0)
		add_ptr_ivar(view_cls, 'vtUserdata')
		add_ptr_ivar(view_cls, 'metalDevice')
		add_ptr_ivar(view_cls, 'metalQueue')
		add_ptr_ivar(view_cls, 'metalLayer')
		add_method(view_cls, 'isFlipped', voidptr(vt_view_is_flipped), 'B@:')
		add_method(view_cls, 'acceptsFirstResponder', voidptr(vt_view_accepts_first_responder), 'B@:')
		add_method(view_cls, 'canBecomeKeyView', voidptr(vt_view_can_become_key_view), 'B@:')
		add_method(view_cls, 'drawRect:', voidptr(vt_view_draw_rect), 'v@:{CGRect={CGPoint=dd}{CGSize=dd}}')
		add_method(view_cls, 'keyDown:', voidptr(vt_view_key_down), 'v@:@')
		add_method(view_cls, 'flagsChanged:', voidptr(vt_view_flags_changed), 'v@:@')
		add_method(view_cls, 'mouseDown:', voidptr(vt_view_mouse_down), 'v@:@')
		add_method(view_cls, 'mouseUp:', voidptr(vt_view_mouse_up), 'v@:@')
		add_method(view_cls, 'mouseDragged:', voidptr(vt_view_mouse_dragged), 'v@:@')
		add_method(view_cls, 'rightMouseDown:', voidptr(vt_view_right_mouse_down), 'v@:@')
		add_method(view_cls, 'rightMouseUp:', voidptr(vt_view_right_mouse_up), 'v@:@')
		add_method(view_cls, 'vtFrameDidChange:', voidptr(vt_view_frame_did_change), 'v@:@')
		add_method(view_cls, 'copy:', voidptr(vt_view_copy), 'v@:@')
		add_method(view_cls, 'paste:', voidptr(vt_view_paste), 'v@:@')
		add_method(view_cls, 'selectAll:', voidptr(vt_view_select_all), 'v@:@')
		add_method(view_cls, 'vtNewTab:', voidptr(vt_view_new_tab), 'v@:@')
		add_method(view_cls, 'vtCloseTab:', voidptr(vt_view_close_tab), 'v@:@')
		C.macos_objc_register_class_pair(view_cls)
	}

	mut delegate_cls := get_class('VTAppDelegate')
	if is_nil(delegate_cls) {
		delegate_cls = C.macos_objc_allocate_class_pair(get_class('NSObject'), cstr('VTAppDelegate'), 0)
		proto := get_protocol('NSApplicationDelegate')
		if !is_nil(proto) {
			C.macos_class_add_protocol(delegate_cls, proto)
		}
		add_method(delegate_cls, 'applicationDidFinishLaunching:', voidptr(vt_app_did_finish_launching), 'v@:@')
		add_method(delegate_cls, 'applicationShouldTerminateAfterLastWindowClosed:', voidptr(vt_app_should_terminate_after_last_window_closed), 'B@:@')
		add_method(delegate_cls, 'applicationShouldTerminate:', voidptr(vt_app_should_terminate), 'Q@:@')
		add_method(delegate_cls, 'applicationWillTerminate:', voidptr(vt_app_will_terminate), 'v@:@')
		C.macos_objc_register_class_pair(delegate_cls)
	}
}

fn vt_view_is_flipped(_self ObjId, _cmd Sel) bool {
	return true
}

fn vt_view_accepts_first_responder(_self ObjId, _cmd Sel) bool {
	return true
}

fn vt_view_can_become_key_view(_self ObjId, _cmd Sel) bool {
	return true
}

fn vt_view_draw_rect(self ObjId, _cmd Sel, _dirty_rect ObjCRect) {
	if g_draw_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(self)
	if is_nil(userdata) {
		return
	}
	ns_context := msg_id(get_class('NSGraphicsContext'), 'currentContext')
	ctx := msg_id(ns_context, 'CGContext')
	bounds := msg_rect(self, 'bounds')
	g_draw_cb(userdata, voidptr(ctx), bounds.width, bounds.height)
}

fn vt_view_key_down(self ObjId, _cmd Sel, event ObjId) {
	flags := msg_u64(event, 'modifierFlags')
	device_flags := flags & ns_event_modifier_flag_device_independent_mask
	cmd_only := (device_flags & ns_event_modifier_flag_command) != 0
		&& (device_flags & (ns_event_modifier_flag_control | ns_event_modifier_flag_option)) == 0
	keycode := u16(msg_u64(event, 'keyCode'))
	if cmd_only && (keycode == 36 || keycode == 76) {
		window := msg_id(self, 'window')
		msg_void1(window, 'toggleFullScreen:', nil_obj())
		return
	}

	if g_key_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(self)
	if is_nil(userdata) {
		return
	}
	chars := objc_utf8_string(msg_id(event, 'characters'))
	uchars := objc_utf8_string(msg_id(event, 'charactersIgnoringModifiers'))
	g_key_cb(userdata, keycode, flags, chars.str, chars.len, uchars.str, uchars.len, msg_bool(event, 'isARepeat'))
}

fn vt_view_flags_changed(_self ObjId, _cmd Sel, _event ObjId) {
}

fn vt_view_mouse_down(self ObjId, _cmd Sel, event ObjId) {
	dispatch_mouse(self, event, 0)
}

fn vt_view_mouse_up(self ObjId, _cmd Sel, event ObjId) {
	dispatch_mouse(self, event, 1)
}

fn vt_view_mouse_dragged(self ObjId, _cmd Sel, event ObjId) {
	dispatch_mouse(self, event, 2)
}

fn vt_view_right_mouse_down(self ObjId, _cmd Sel, event ObjId) {
	dispatch_mouse(self, event, 3)
}

fn vt_view_right_mouse_up(self ObjId, _cmd Sel, event ObjId) {
	dispatch_mouse(self, event, 4)
}

fn dispatch_mouse(view ObjId, event ObjId, event_type int) {
	if g_mouse_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(view)
	if is_nil(userdata) {
		return
	}
	window_point := msg_point(event, 'locationInWindow')
	point := msg_point_point_obj(view, 'convertPoint:fromView:', window_point, nil_obj())
	g_mouse_cb(userdata, event_type, point.x, point.y, msg_u64(event, 'modifierFlags'))
}

fn vt_view_frame_did_change(self ObjId, _cmd Sel, _notification ObjId) {
	if g_app_terminating {
		return
	}
	update_metal_drawable_size(self)
	if g_resize_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(self)
	if is_nil(userdata) {
		return
	}
	bounds := msg_rect(self, 'bounds')
	g_resize_cb(userdata, bounds.width, bounds.height)
}

fn vt_view_copy(self ObjId, _cmd Sel, _sender ObjId) {
	dispatch_action(self, vt_action_copy)
}

fn vt_view_paste(self ObjId, _cmd Sel, _sender ObjId) {
	if g_paste_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(self)
	if is_nil(userdata) {
		return
	}
	pasteboard := msg_id(get_class('NSPasteboard'), 'generalPasteboard')
	text_obj := msg_id1(pasteboard, 'stringForType:', nsstring('public.utf8-plain-text'))
	text := objc_utf8_string(text_obj)
	if text.len > 0 {
		g_paste_cb(userdata, text.str, text.len)
	}
}

fn vt_view_select_all(self ObjId, _cmd Sel, _sender ObjId) {
	dispatch_action(self, vt_action_select_all)
}

fn vt_view_new_tab(self ObjId, _cmd Sel, _sender ObjId) {
	dispatch_action(self, vt_action_new_tab)
}

fn vt_view_close_tab(self ObjId, _cmd Sel, _sender ObjId) {
	dispatch_action(self, vt_action_close_tab)
}

fn dispatch_action(view ObjId, action_id int) {
	if g_action_cb == unsafe { nil } {
		return
	}
	userdata := view_userdata(view)
	if !is_nil(userdata) {
		g_action_cb(userdata, action_id)
	}
}

fn vt_app_did_finish_launching(_self ObjId, _cmd Sel, _notification ObjId) {
	msg_void_bool(shared_app(), 'activateIgnoringOtherApps:', true)
	if g_ready_cb != unsafe { nil } {
		g_ready_cb()
	}
}

fn vt_app_should_terminate_after_last_window_closed(_self ObjId, _cmd Sel, _app ObjId) bool {
	return true
}

fn vt_app_should_terminate(_self ObjId, _cmd Sel, _app ObjId) u64 {
	g_app_terminating = true
	return 1
}

fn vt_app_will_terminate(_self ObjId, _cmd Sel, _notification ObjId) {
	g_app_terminating = true
}

fn display_title_for_input(title string) string {
	if title.len == 0 {
		return 'Witty'
	}
	return abbrev_path(title)
}

fn runtime_title_for_input(title string) string {
	return title
}

fn expand_tilde(path string) string {
	home := os.home_dir()
	if path == '~' {
		return home
	}
	if path.starts_with('~/') {
		return os.join_path(home, path[2..])
	}
	return path
}

fn abbrev_path(path string) string {
	home := os.home_dir()
	if home.len > 0 && path == home {
		return '~'
	}
	if home.len > 0 && path.starts_with(home + '/') {
		return '~/' + path[(home.len + 1)..]
	}
	return path
}

fn url_for_title(title string) ObjId {
	if title.len == 0 {
		return nil_obj()
	}
	expanded := expand_tilde(title)
	if !os.is_dir(expanded) {
		return nil_obj()
	}
	return msg_id1(get_class('NSURL'), 'fileURLWithPath:', nsstring(expanded))
}

fn base_title_key() voidptr {
	return voidptr(&g_base_title_key)
}

fn set_base_title(window ObjId, base string) {
	if is_nil(window) {
		return
	}
	C.macos_set_associated_object(window, base_title_key(), nsstring(base), objc_assoc_copy_nonatomic)
}

fn get_base_title(window ObjId) string {
	if is_nil(window) {
		return ''
	}
	value := C.macos_get_associated_object(window, base_title_key())
	return objc_utf8_string(value)
}

fn window_title_for_base(base string) string {
	if base.len == 0 {
		return 'Witty'
	}
	if base == 'Witty' || base.starts_with('Witty - ') {
		return base
	}
	return 'Witty - ' + base
}

fn refresh_one_tab_label(tab ObjId, tab_count int, index int) {
	mut base := get_base_title(tab)
	url := msg_id(tab, 'representedURL')
	if !is_nil(url) {
		path_obj := msg_id(url, 'path')
		path := objc_utf8_string(path_obj)
		if path.len > 0 {
			base = abbrev_path(path)
		}
	}
	if base.len == 0 {
		base = 'Witty'
	}
	mut label := window_title_for_base(base)
	if tab_count > 1 {
		tab_number := index + 1
		label = label + '  Cmd' + tab_number.str()
	}
	msg_void1(tab, 'setTitle:', nsstring(label))
}

fn refresh_tab_labels(anchor_window ObjId) {
	if is_nil(anchor_window) {
		return
	}
	tabs := msg_id(anchor_window, 'tabbedWindows')
	count := int(msg_u64(tabs, 'count'))
	if is_nil(tabs) || count == 0 {
		refresh_one_tab_label(anchor_window, 1, 0)
		return
	}
	for i in 0 .. count {
		tab := msg_id_u64(tabs, 'objectAtIndex:', u64(i))
		refresh_one_tab_label(tab, count, i)
	}
}

fn configure_window_common(window ObjId, base_title string) {
	if is_nil(window) {
		return
	}
	msg_void_size(window, 'setMinSize:', objc_size(200, 100))
	msg_void_u64(window, 'setTabbingMode:', ns_window_tabbing_mode_automatic)
	msg_void1(window, 'setTabbingIdentifier:', nsstring('Witty.tabs'))
	msg_void_u64(window, 'setCollectionBehavior:', ns_window_collection_behavior_full_screen_primary)
	msg_void_bool(window, 'setTitlebarAppearsTransparent:', false)
	msg_void_bool(window, 'setMovableByWindowBackground:', false)
	set_base_title(window, base_title)
	msg_void1(window, 'setRepresentedURL:', url_for_title(base_title))
}

fn menu_with_title(title string) ObjId {
	return msg_id1(alloc('NSMenu'), 'initWithTitle:', nsstring(title))
}

fn menu_item() ObjId {
	return msg_id(alloc('NSMenuItem'), 'init')
}

fn menu_add_item(menu ObjId, title string, action string, key string) ObjId {
	return msg_id_obj_sel_obj(menu, 'addItemWithTitle:action:keyEquivalent:', nsstring(title), sel(action), nsstring(key))
}

fn menu_add_separator(menu ObjId) {
	msg_void1(menu, 'addItem:', msg_id(get_class('NSMenuItem'), 'separatorItem'))
}

fn install_menu_bar() {
	menu_bar := msg_id(alloc('NSMenu'), 'init')

	app_menu_item := menu_item()
	msg_void1(menu_bar, 'addItem:', app_menu_item)
	app_menu := menu_with_title('Witty')
	menu_add_item(app_menu, 'About Witty', 'orderFrontStandardAboutPanel:', '')
	menu_add_separator(app_menu)
	menu_add_item(app_menu, 'Hide Witty', 'hide:', 'h')
	hide_others := menu_add_item(app_menu, 'Hide Others', 'hideOtherApplications:', 'h')
	msg_void_u64(hide_others, 'setKeyEquivalentModifierMask:', ns_event_modifier_flag_command | ns_event_modifier_flag_option)
	menu_add_item(app_menu, 'Show All', 'unhideAllApplications:', '')
	menu_add_separator(app_menu)
	menu_add_item(app_menu, 'Quit Witty', 'terminate:', 'q')
	msg_void1(app_menu_item, 'setSubmenu:', app_menu)

	file_menu_item := menu_item()
	msg_void1(menu_bar, 'addItem:', file_menu_item)
	file_menu := menu_with_title('File')
	menu_add_item(file_menu, 'New Tab', 'vtNewTab:', 't')
	menu_add_item(file_menu, 'Close Tab', 'vtCloseTab:', 'w')
	msg_void1(file_menu_item, 'setSubmenu:', file_menu)

	edit_menu_item := menu_item()
	msg_void1(menu_bar, 'addItem:', edit_menu_item)
	edit_menu := menu_with_title('Edit')
	menu_add_item(edit_menu, 'Copy', 'copy:', 'c')
	menu_add_item(edit_menu, 'Paste', 'paste:', 'v')
	menu_add_item(edit_menu, 'Select All', 'selectAll:', 'a')
	msg_void1(edit_menu_item, 'setSubmenu:', edit_menu)

	view_menu_item := menu_item()
	msg_void1(menu_bar, 'addItem:', view_menu_item)
	view_menu := menu_with_title('View')
	fullscreen := menu_add_item(view_menu, 'Toggle Full Screen', 'toggleFullScreen:', 'f')
	msg_void_u64(fullscreen, 'setKeyEquivalentModifierMask:', ns_event_modifier_flag_command | ns_event_modifier_flag_control)
	msg_void1(view_menu_item, 'setSubmenu:', view_menu)

	window_menu_item := menu_item()
	msg_void1(menu_bar, 'addItem:', window_menu_item)
	window_menu := menu_with_title('Window')
	menu_add_item(window_menu, 'Minimize', 'performMiniaturize:', 'm')
	menu_add_item(window_menu, 'Zoom', 'performZoom:', '')
	menu_add_separator(window_menu)
	prev_tab := menu_add_item(window_menu, 'Show Previous Tab', 'selectPreviousTab:', '[')
	msg_void_u64(prev_tab, 'setKeyEquivalentModifierMask:', ns_event_modifier_flag_command)
	next_tab := menu_add_item(window_menu, 'Show Next Tab', 'selectNextTab:', ']')
	msg_void_u64(next_tab, 'setKeyEquivalentModifierMask:', ns_event_modifier_flag_command)
	menu_add_separator(window_menu)
	menu_add_item(window_menu, 'Bring All to Front', 'arrangeInFront:', '')
	msg_void1(window_menu_item, 'setSubmenu:', window_menu)

	app := shared_app()
	msg_void1(app, 'setWindowsMenu:', window_menu)
	msg_void1(app, 'setMainMenu:', menu_bar)
}

fn setup_view_notifications(view ObjId) {
	msg_void_bool(view, 'setPostsFrameChangedNotifications:', true)
	center := msg_id(get_class('NSNotificationCenter'), 'defaultCenter')
	msg_id_obj_sel_obj(center, 'addObserver:selector:name:object:', view, sel('vtFrameDidChange:'), nsstring('NSViewFrameDidChangeNotification'))
}

fn setup_view_metal(view ObjId) {
	device := C.MTLCreateSystemDefaultDevice()
	if is_nil(device) {
		return
	}
	queue := msg_id(device, 'newCommandQueue')
	layer := new_obj('CAMetalLayer')
	msg_void1(layer, 'setDevice:', device)
	msg_void_u64(layer, 'setPixelFormat:', mtl_pixel_format_bgra8unorm)
	msg_void_bool(layer, 'setFramebufferOnly:', true)
	screen := msg_id(get_class('NSScreen'), 'mainScreen')
	scale := msg_f64(screen, 'backingScaleFactor')
	msg_void_f64(layer, 'setContentsScale:', if scale > 0 { scale } else { 1.0 })
	C.macos_objc_set_ptr_ivar(view, cstr('metalDevice'), device)
	C.macos_objc_set_ptr_ivar(view, cstr('metalQueue'), queue)
	C.macos_objc_set_ptr_ivar(view, cstr('metalLayer'), layer)
	update_metal_drawable_size(view)
}

fn create_terminal_view(frame ObjCRect) ObjId {
	view := msg_id_rect(alloc('VTTerminalView'), 'initWithFrame:', frame)
	setup_view_metal(view)
	setup_view_notifications(view)
	return view
}

fn update_metal_drawable_size(view ObjId) {
	layer := ObjId(C.macos_objc_get_ptr_ivar(view, cstr('metalLayer')))
	if is_nil(layer) {
		return
	}
	bounds := msg_rect(view, 'bounds')
	mut scale := msg_f64(layer, 'contentsScale')
	if scale <= 0 {
		scale = 1
	}
	msg_void_size(layer, 'setDrawableSize:', objc_size(bounds.width * scale, bounds.height * scale))
}

// V-friendly wrappers.
pub fn app_init() {
	register_classes()
	app := shared_app()
	msg_void_u64(app, 'setActivationPolicy:', ns_application_activation_policy_regular)
	msg_void_bool(get_class('NSWindow'), 'setAllowsAutomaticWindowTabbing:', true)
	install_menu_bar()
	g_delegate = msg_id(alloc('VTAppDelegate'), 'init')
	msg_void1(app, 'setDelegate:', g_delegate)
}

pub fn app_run() {
	msg_void(shared_app(), 'run')
}

pub fn create_window(w int, h int, title string) voidptr {
	register_classes()
	frame := objc_rect(100, 100, f64(w), f64(h))
	style := ns_window_style_titled | ns_window_style_closable | ns_window_style_miniaturizable | ns_window_style_resizable
	base_title := display_title_for_input(title)

	window := msg_id_rect_u64_u64_bool(alloc('NSWindow'), 'initWithContentRect:styleMask:backing:defer:', frame, style, ns_backing_store_buffered, false)
	g_window = window
	configure_window_common(window, base_title)

	view := create_terminal_view(frame)
	msg_void1(window, 'setContentView:', view)
	msg_void1(window, 'setInitialFirstResponder:', view)
	msg_bool1(window, 'makeFirstResponder:', view)
	msg_void1(window, 'makeKeyAndOrderFront:', nil_obj())
	refresh_tab_labels(window)
	return view
}

pub fn set_draw_callback(cb DrawCallback) {
	g_draw_cb = cb
}

pub fn set_key_callback(cb KeyCallback) {
	g_key_cb = cb
}

pub fn set_resize_callback(cb ResizeCallback) {
	g_resize_cb = cb
}

pub fn set_ready_callback(cb ReadyCallback) {
	g_ready_cb = cb
}

pub fn set_paste_callback(cb PasteCallback) {
	g_paste_cb = cb
}

pub fn set_action_callback(cb ActionCallback) {
	g_action_cb = cb
}

pub fn set_mouse_callback(cb MouseCallback) {
	g_mouse_cb = cb
}

pub fn clipboard_set_text(text string) {
	if text.len == 0 {
		return
	}
	pasteboard := msg_id(get_class('NSPasteboard'), 'generalPasteboard')
	msg_void(pasteboard, 'clearContents')
	msg_bool2(pasteboard, 'setString:forType:', nsstring(text), nsstring('public.utf8-plain-text'))
}

fn request_display_now(view voidptr) {
	if is_nil(view) {
		return
	}
	msg_void_bool(ObjId(view), 'setNeedsDisplay:', true)
}

fn request_display_main_task(ctx voidptr) {
	request_display_now(ctx)
}

pub fn request_display(view voidptr) {
	if is_nil(view) {
		return
	}
	if !C.witty_macos_is_main_thread() {
		C.witty_macos_dispatch_main(voidptr(request_display_main_task), view)
		return
	}
	request_display_now(view)
}

pub fn view_width(view voidptr) f64 {
	if is_nil(view) {
		return 0
	}
	return msg_rect(ObjId(view), 'bounds').width
}

pub fn view_height(view voidptr) f64 {
	if is_nil(view) {
		return 0
	}
	return msg_rect(ObjId(view), 'bounds').height
}

pub fn ct_font_attribute_name() voidptr {
	return C.vt_ct_font_attribute_name()
}

pub fn view_set_userdata(view voidptr, ptr voidptr) {
	obj := ObjId(view)
	if !is_nil(obj) {
		C.macos_objc_set_ptr_ivar(obj, cstr('vtUserdata'), ptr)
	}
}

fn view_userdata(view ObjId) voidptr {
	if is_nil(view) {
		return unsafe { nil }
	}
	return C.macos_objc_get_ptr_ivar(view, cstr('vtUserdata'))
}

pub fn view_get_userdata(view voidptr) voidptr {
	return view_userdata(ObjId(view))
}

pub fn create_font(name string, size f64) voidptr {
	return C.vt_create_font(cstr(name), size)
}

pub fn draw_text(ctx voidptr, text &u8, text_len int, font voidptr, x f64, y f64, fg_r f64, fg_g f64, fg_b f64) {
	C.vt_draw_text(ctx, text, text_len, font, x, y, fg_r, fg_g, fg_b)
}

pub fn new_tab(w int, h int, title string) voidptr {
	register_classes()
	app := shared_app()
	mut anchor := msg_id(app, 'keyWindow')
	if is_nil(anchor) {
		anchor = msg_id(app, 'mainWindow')
	}
	if is_nil(anchor) {
		anchor = g_window
	}
	if is_nil(anchor) {
		return unsafe { nil }
	}

	mut frame := objc_rect(100, 100, f64(w), f64(h))
	anchor_content := msg_id(anchor, 'contentView')
	if !is_nil(anchor_content) {
		bounds := msg_rect(anchor_content, 'bounds')
		if bounds.width > 0 && bounds.height > 0 {
			frame.width = bounds.width
			frame.height = bounds.height
		}
	}

	style := ns_window_style_titled | ns_window_style_closable | ns_window_style_miniaturizable | ns_window_style_resizable
	base_title := display_title_for_input(title)
	window := msg_id_rect_u64_u64_bool(alloc('NSWindow'), 'initWithContentRect:styleMask:backing:defer:', frame, style, ns_backing_store_buffered, false)
	configure_window_common(window, base_title)

	view := create_terminal_view(frame)
	msg_void1(window, 'setContentView:', view)
	msg_void1(window, 'setInitialFirstResponder:', view)
	msg_void2(anchor, 'addTabbedWindow:ordered:', window, ObjId(ns_window_above))
	msg_void1(window, 'makeKeyAndOrderFront:', nil_obj())
	msg_bool1(window, 'makeFirstResponder:', view)
	g_window = anchor
	refresh_tab_labels(window)
	return view
}

pub fn close_tab(view voidptr) {
	if is_nil(view) {
		return
	}
	window := msg_id(ObjId(view), 'window')
	if !is_nil(window) {
		msg_void(window, 'close')
		key_window := msg_id(shared_app(), 'keyWindow')
		if !is_nil(key_window) {
			refresh_tab_labels(key_window)
		} else if !is_nil(g_window) {
			refresh_tab_labels(g_window)
		}
	}
}

pub fn select_tab(offset int) {
	key_window := msg_id(shared_app(), 'keyWindow')
	if is_nil(key_window) {
		return
	}
	if offset > 0 {
		msg_void1(key_window, 'selectNextTab:', nil_obj())
	} else if offset < 0 {
		msg_void1(key_window, 'selectPreviousTab:', nil_obj())
	}
	refresh_tab_labels(key_window)
}

pub fn tab_count() int {
	key_window := msg_id(shared_app(), 'keyWindow')
	if is_nil(key_window) {
		return 1
	}
	tabs := msg_id(key_window, 'tabbedWindows')
	if is_nil(tabs) {
		return 1
	}
	count := int(msg_u64(tabs, 'count'))
	if count <= 0 {
		return 1
	}
	return count
}

fn set_view_title_now(view voidptr, title string) {
	if is_nil(view) {
		return
	}
	window := msg_id(ObjId(view), 'window')
	if is_nil(window) {
		return
	}
	base_title := runtime_title_for_input(title)
	set_base_title(window, base_title)
	msg_void1(window, 'setRepresentedURL:', url_for_title(base_title))
	refresh_tab_labels(window)
}

fn set_view_title_main_task(ctx voidptr) {
	if ctx == unsafe { nil } {
		return
	}
	task := unsafe { &C.witty_macos_string_task(ctx) }
	view := task.view
	title := if task.text == unsafe { nil } {
		''
	} else {
		unsafe { task.text.vstring().clone() }
	}
	C.witty_macos_string_task_free(task)
	set_view_title_now(view, title)
}

pub fn set_view_title(view voidptr, title string) {
	if is_nil(view) {
		return
	}
	if !C.witty_macos_is_main_thread() {
		task := C.witty_macos_string_task_new(view, cstr(title))
		if task != unsafe { nil } {
			C.witty_macos_dispatch_main(voidptr(set_view_title_main_task), task)
		}
		return
	}
	set_view_title_now(view, title)
}

// Metal wrappers.
pub fn metal_activate_layer(view voidptr) {
	if is_nil(view) {
		return
	}
	layer := metal_layer(view)
	if is_nil(layer) {
		return
	}
	msg_void_bool(ObjId(view), 'setWantsLayer:', true)
	msg_void1(ObjId(view), 'setLayer:', ObjId(layer))
	update_metal_drawable_size(ObjId(view))
}

pub fn metal_device(view voidptr) voidptr {
	if is_nil(view) {
		return unsafe { nil }
	}
	return C.macos_objc_get_ptr_ivar(ObjId(view), cstr('metalDevice'))
}

pub fn metal_queue(view voidptr) voidptr {
	if is_nil(view) {
		return unsafe { nil }
	}
	return C.macos_objc_get_ptr_ivar(ObjId(view), cstr('metalQueue'))
}

pub fn metal_layer(view voidptr) voidptr {
	if is_nil(view) {
		return unsafe { nil }
	}
	return C.macos_objc_get_ptr_ivar(ObjId(view), cstr('metalLayer'))
}

// metal_layer_surface_size returns the drawable dimensions derived from the
// layer bounds and its backing scale. CAMetalLayer's drawableSize is updated
// from these same values by update_metal_drawable_size.
pub fn metal_layer_surface_size(layer voidptr) (f64, f64) {
	if is_nil(layer) {
		return 0, 0
	}
	bounds := msg_rect(ObjId(layer), 'bounds')
	scale := msg_f64(ObjId(layer), 'contentsScale')
	return bounds.width * scale, bounds.height * scale
}

pub fn metal_next_drawable(layer voidptr) voidptr {
	return msg_id(ObjId(layer), 'nextDrawable')
}

pub fn metal_drawable_texture(drawable voidptr) voidptr {
	return msg_id(ObjId(drawable), 'texture')
}

pub fn metal_create_command_buffer(queue voidptr) voidptr {
	return msg_id(ObjId(queue), 'commandBuffer')
}

pub fn metal_create_render_pass(texture voidptr, r f64, g f64, b f64, a f64) voidptr {
	if is_nil(texture) {
		return unsafe { nil }
	}
	desc := msg_id(get_class('MTLRenderPassDescriptor'), 'renderPassDescriptor')
	attachments := msg_id(desc, 'colorAttachments')
	attachment := msg_id_u64(attachments, 'objectAtIndexedSubscript:', 0)
	msg_void1(attachment, 'setTexture:', ObjId(texture))
	msg_void_u64(attachment, 'setLoadAction:', mtl_load_action_clear)
	msg_void_u64(attachment, 'setStoreAction:', mtl_store_action_store)
	C.witty_macos_objc_msg_void_clear_color(attachment, sel('setClearColor:'), MetalClearColor{
		red: r
		green: g
		blue: b
		alpha: a
	})
	return desc
}

pub fn metal_create_encoder(cmd_buf voidptr, pass voidptr) voidptr {
	if is_nil(cmd_buf) || is_nil(pass) {
		return unsafe { nil }
	}
	return msg_id1(ObjId(cmd_buf), 'renderCommandEncoderWithDescriptor:', ObjId(pass))
}

pub fn metal_end_encoding(encoder voidptr) {
	msg_void(ObjId(encoder), 'endEncoding')
}

pub fn metal_present_and_commit(cmd_buf voidptr, drawable voidptr) {
	if is_nil(cmd_buf) || is_nil(drawable) {
		return
	}
	msg_void1(ObjId(cmd_buf), 'presentDrawable:', ObjId(drawable))
	msg_void(ObjId(cmd_buf), 'commit')
}

pub fn metal_release(ptr voidptr) {
	// Objects returned by these wrappers are autoreleased or owned by AppKit.
}

pub fn metal_max_texture_size(device voidptr) u32 {
	if is_nil(device) {
		return 16384
	}
	if msg_bool_u64(ObjId(device), 'supportsFamily:', mtl_gpu_family_apple3) {
		return 16384
	}
	return 8192
}

pub fn metal_has_unified_memory(device voidptr) bool {
	if is_nil(device) {
		return true
	}
	return msg_bool(ObjId(device), 'hasUnifiedMemory')
}
