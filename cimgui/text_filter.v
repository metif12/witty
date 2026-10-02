module cimgui

$if macos || linux {
	#flag @VMODROOT/cimgui/text_filter.o
	#include "@VMODROOT/cimgui/text_filter.h"
}
fn C.witty_cimgui_filter_create(text &char) voidptr
fn C.witty_cimgui_filter_destroy(filter voidptr)
fn C.witty_cimgui_filter_pass(filter voidptr, text &char) bool
fn C.witty_cimgui_filter_set(filter voidptr, text &char)
fn C.witty_cimgui_filter_get(filter voidptr) &char
fn C.witty_cimgui_filter_draw(context voidptr, filter voidptr, label &char)

pub struct TextFilter {
	handle voidptr
}

pub fn TextFilter.create(text string) TextFilter {
	$if macos || linux {
		return TextFilter{
			handle: C.witty_cimgui_filter_create(&char(text.str))
		}
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (filter TextFilter) destroy() {
	$if macos || linux {
		if !isnil(filter.handle) { C.witty_cimgui_filter_destroy(filter.handle) }
	}
}

pub fn (filter TextFilter) pass(text string) bool {
	$if macos || linux {
		return C.witty_cimgui_filter_pass(filter.handle, &char(text.str))
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (filter TextFilter) set(text string) {
	$if macos || linux {
		C.witty_cimgui_filter_set(filter.handle, &char(text.str))
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (filter TextFilter) get() string {
	$if macos || linux {
		return unsafe { cstring_to_vstring(C.witty_cimgui_filter_get(filter.handle)).clone() }
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}

pub fn (ctx Context) draw_text_filter(filter TextFilter, label string) {
	$if macos || linux {
		C.witty_cimgui_filter_draw(ctx.handle, filter.handle, &char(label.str))
	} $else {
		panic('Dear ImGui native library is unavailable on this target')
	}
}
