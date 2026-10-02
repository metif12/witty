module macos

fn C.object_setClass(object ObjId, cls ObjId) ObjId

fn font_fixture_fullscreen(_self ObjId, _cmd Sel) u64 { return u64(1 << 14) }
fn font_fixture_toolbar_name(_self ObjId, _cmd Sel) ObjId { return nsstring('NSToolbarFullScreenWindow') }
fn font_fixture_container_name(_self ObjId, _cmd Sel) ObjId { return nsstring('NSTitlebarContainerView') }

fn test_source_window_title_font_and_native_tab_title_updates() {
	app_init()
	register_window_font_methods(native_window_class())
	first := create_window(640, 480, 'first')
	second := new_tab(640, 480, 'second')
	defer { close_tab(first); close_tab(second) }
	window := msg_id(second, 'window')
	set_native_window_title_font(second, 'Menlo')
	font := window_title_font(window)
	assert !is_nil(font)
	assert msg_f64(font, 'pointSize') == msg_f64(get_class('NSFont'), 'systemFontSize')
	field := window_font_title_field(window)
	assert !is_nil(field)
	assert msg_id(field, 'font') == font
	assert !msg_bool(field, 'usesSingleLineMode')
	msg_void1(window, 'setTitle:', nsstring('changed title'))
	attributed := msg_id(msg_id(window, 'tab'), 'attributedTitle')
	assert objc_utf8_string(msg_id(attributed, 'string')) == 'changed title'
	assert !msg_bool(field, 'usesSingleLineMode')
	set_native_window_title_font(second, 'ThisFontDoesNotExist_WittySourceAudit')
	assert is_nil(window_title_font(window))
	assert is_nil(msg_id(msg_id(window, 'tab'), 'attributedTitle'))
	expected := msg_id_f64(get_class('NSFont'), 'titleBarFontOfSize:', msg_f64(get_class('NSFont'), 'systemFontSize'))
	assert msg_id(field, 'font') == expected
	set_native_window_title_font(second, 'Menlo')
	set_native_window_title_font(second, none)
	assert is_nil(window_title_font(window))
	assert is_nil(msg_id(msg_id(window, 'tab'), 'attributedTitle'))
	assert msg_id(field, 'font') == expected
	// AppKit subclasses still call NSWindow's title setter exactly once.
	cls := C.macos_objc_allocate_class_pair(native_window_class(), cstr('WittyFontObservedWindow'), 0)
	C.macos_objc_register_class_pair(cls)
	probe := msg_id_rect_u64_u64_bool(msg_id(cls, 'alloc'), 'initWithContentRect:styleMask:backing:defer:', objc_rect(0, 0, 640, 480), ns_window_style_titled, ns_backing_store_buffered, false)
	msg_void1(probe, 'setTitle:', nsstring('subclass title'))
	assert objc_utf8_string(msg_id(probe, 'title')) == 'subclass title'
	msg_void(probe, 'release')
}

fn test_source_window_font_fullscreen_toolbar_parent_filter() {
	app_init()
	target_view := create_window(640, 480, 'target')
	other_view := create_window(640, 480, 'other')
	target := msg_id(target_view, 'window')
	other := msg_id(other_view, 'window')
	original_class := C.object_getClass(target)
	full := C.macos_objc_allocate_class_pair(original_class, cstr('WittyFontFullscreenStyleFixture'), 0)
	add_method(full, 'styleMask', voidptr(font_fixture_fullscreen), 'Q@:')
	C.macos_objc_register_class_pair(full)
	toolbar_class := C.macos_objc_allocate_class_pair(get_class('NSWindow'), cstr('WittyFontFullscreenToolbarFixture'), 0)
	add_method(toolbar_class, 'className', voidptr(font_fixture_toolbar_name), '@@:')
	C.macos_objc_register_class_pair(toolbar_class)
	container_class := C.macos_objc_allocate_class_pair(get_class('NSView'), cstr('WittyFontFullscreenContainerFixture'), 0)
	add_method(container_class, 'className', voidptr(font_fixture_container_name), '@@:')
	C.macos_objc_register_class_pair(container_class)
	toolbar := msg_id_rect_u64_u64_bool(msg_id(toolbar_class, 'alloc'), 'initWithContentRect:styleMask:backing:defer:', objc_rect(0, 0, 640, 40), 0, ns_backing_store_buffered, false)
	msg_void_bool(toolbar, 'setReleasedWhenClosed:', false)
	container := msg_id_rect(msg_id(container_class, 'alloc'), 'initWithFrame:', objc_rect(0, 0, 640, 40))
	msg_void1(msg_id(toolbar, 'contentView'), 'addSubview:', container)
	defer {
		C.object_setClass(target, original_class)
		msg_void1(target, 'removeChildWindow:', toolbar)
		msg_void1(other, 'removeChildWindow:', toolbar)
		msg_void(toolbar, 'close')
		msg_void(toolbar, 'release')
		msg_void(container, 'release')
		close_tab(target_view)
		close_tab(other_view)
	}
	msg_void2(target, 'addChildWindow:ordered:', toolbar, ObjId(1))
	C.object_setClass(target, full)
	assert window_font_titlebar_container(target) == container
	C.object_setClass(target, original_class)
	msg_void1(target, 'removeChildWindow:', toolbar)
	msg_void2(other, 'addChildWindow:ordered:', toolbar, ObjId(1))
	C.object_setClass(target, full)
	assert is_nil(window_font_titlebar_container(target))
}
