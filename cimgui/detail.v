module cimgui

$if macos || linux {
	$if !managed_native ? {
		#flag @VMODROOT/cimgui/detail.o
	}
	#include "@VMODROOT/cimgui/detail.h"
}
fn C.witty_cimgui_show_demo(context voidptr, open &bool)
fn C.witty_cimgui_readonly_text(context voidptr, label &char, data &char, length usize)
fn C.witty_cimgui_bindings_list(context voidptr, label &char, count usize) bool

pub fn (ctx Context) show_demo_window(open bool) bool {
	$if macos || linux {
		mut value := open
		C.witty_cimgui_show_demo(ctx.handle, &value)
		return value
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (ctx Context) readonly_text(label string, mut data []u8) {
	$if macos || linux {
		C.witty_cimgui_readonly_text(ctx.handle, &char(label.str), &char(data.data), usize(data.len - 1))
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (ctx Context) begin_bindings_list(label string, count usize) bool {
	$if macos || linux {
		return C.witty_cimgui_bindings_list(ctx.handle, &char(label.str), count)
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}
