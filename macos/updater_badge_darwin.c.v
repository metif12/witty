module macos

fn update_pill_view() ObjId {
	mut cls := get_class('WittyUpdatePill')
	if is_nil(cls) {
		cls = C.macos_objc_allocate_class_pair(get_class('NSButton'), cstr('WittyUpdatePill'), 0)
		add_method(cls, 'drawRect:', voidptr(update_pill_draw), 'v@:{CGRect={CGPoint=dd}{CGSize=dd}}')
		C.macos_objc_register_class_pair(cls)
	}
	return msg_id_rect(msg_id(cls, 'alloc'), 'initWithFrame:', objc_rect(0, 0, 200, 28))
}

fn update_pill_draw(self ObjId, _cmd Sel, _rect ObjCRect) {
	if g_update_controller == unsafe { nil } { return }
	state := g_update_controller.state
	C.witty_update_draw_text(nsstring(state.text()), update_color(state.foreground_color()), msg_rect(self, 'bounds').width)
}

// UpdateBadge.swift: the source's 14-point symbol, clamped progress ring with
// 2-point round stroke, and checking-only 2.5-second continuous rotation.
fn update_badge_view() ObjId {
	mut cls := get_class('WittyUpdateBadge')
	if is_nil(cls) {
		cls = C.macos_objc_allocate_class_pair(get_class('NSView'), cstr('WittyUpdateBadge'), 0)
		add_method(cls, 'drawRect:', voidptr(update_badge_draw), 'v@:{CGRect={CGPoint=dd}{CGSize=dd}}')
		add_method(cls, 'hitTest:', voidptr(action_passive_hit), '@@:{CGPoint=dd}')
		C.macos_objc_register_class_pair(cls)
	}
	view := msg_id_rect(msg_id(cls, 'alloc'), 'initWithFrame:', objc_rect(8, 7, 14, 14))
	msg_void_bool(view, 'setWantsLayer:', true)
	return view
}

fn update_badge_draw(_self ObjId, _cmd Sel, _rect ObjCRect) {
	if g_update_controller == unsafe { nil } { return }
	state := g_update_controller.state
	mut ring := state.kind == .extracting
	mut progress := state.extraction_progress
	if state.kind == .downloading { if expected := state.expected_length { if expected > 0 { ring = true; progress = f64(state.downloaded) / f64(expected) } } }
	if ring {
		clamped := if progress < 0 { 0 } else if progress > 1 { 1 } else { progress }
		C.witty_update_draw_ring(clamped, msg_id(update_color('primary'), 'CGColor'))
		return
	}
	if icon := state.icon_name() {
		image := msg_id2(get_class('NSImage'), 'imageWithSystemSymbolName:accessibilityDescription:', nsstring(icon), nsstring(state.text()))
		colors := [voidptr(update_color(state.icon_color()))]
		configuration := msg_id1(get_class('NSImageSymbolConfiguration'), 'configurationWithPaletteColors:', C.witty_macos_array(colors.data, 1))
		colored := msg_id1(image, 'imageWithSymbolConfiguration:', configuration)
		msg_void_rect(colored, 'drawInRect:', objc_rect(0, 0, 14, 14))
	}
}
