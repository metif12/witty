@[has_globals]
module macos

import math

// CommandPalette.swift and TerminalCommandPalette.swift: original option order,
// localized title/subtitle search, color match ranking, selection, submission,
// focus restoration. Native AppKit views implement the same event consumers.
fn C.witty_action_id_f64_f64(obj voidptr, selector voidptr, a f64, b f64) voidptr
fn C.witty_action_compare(a voidptr, b voidptr) i64

pub struct NativeCommandOption {
pub:
	title         string
	subtitle      string
	description   string
	action        string
	invoke        fn () = unsafe { nil }
	leading_icon  string
	badge         ?string
	emphasis      bool
	focus_view    voidptr
	leading_color ?voidptr
	sort_key      ?u64
}

@[heap]
struct NativeCommandPalette {
mut:
	surface   &NativeActionSurface = unsafe { nil }
	owner     ObjId
	container ObjId
	tint      ObjId
	field     ObjId
	scroll    ObjId
	document  ObjId
	options   []NativeCommandOption
	filtered  []NativeCommandOption
	query     string
	selected  ?usize
	hovered   ?usize
}

fn palette_state(self ObjId) ?&NativeCommandPalette {
	ptr := C.macos_objc_get_ptr_ivar(self, cstr('palette'))
	if is_nil(ptr) { return none }
	return unsafe { &NativeCommandPalette(ptr) }
}

pub fn sorted_command_options(options []NativeCommandOption) []NativeCommandOption {
	mut result := []NativeCommandOption{}
	for option in options {
		mut position := result.len
		for position > 0 && palette_option_compare(option, result[position - 1]) < 0 { position-- }
		result.insert(position, option)
	}
	return result
}

fn palette_option_compare(a NativeCommandOption, b NativeCommandOption) int {
	order := C.witty_action_compare(nsstring(a.title.replace(':', '\t')), nsstring(b.title.replace(':', '\t')))
	if order != 0 { return int(order) }
	if left := a.sort_key {
		if right := b.sort_key {
			return if left < right {
				-1
			} else if left > right {
				1
			} else {
				0
			}
		}
	}
	return 0
}

fn palette_color_score(color ?voidptr, query string) f64 {
	value := color or { return 0 }
	color_list := msg_id1(get_class('NSColorList'), 'colorListNamed:', nsstring('Apple'))
	if is_nil(color_list) { return 0 }
	names := msg_id(color_list, 'allKeys')
	lower := objc_utf8_string(msg_id(nsstring(query), 'lowercaseString'))
	mut best := 0.0
	for i in 0 .. int(msg_u64(names, 'count')) {
		name := msg_id_u64(names, 'objectAtIndex:', u64(i))
		lowered := objc_utf8_string(msg_id(name, 'lowercaseString'))
		if !lower.contains(lowered) {
			continue
		}
		system := msg_id1(color_list, 'colorWithKey:', msg_id(name, 'capitalizedString'))
		srgb := msg_id1(system, 'colorUsingColorSpace:', msg_id(get_class('NSColorSpace'),
			'sRGBColorSpace'))
		if is_nil(srgb) {
			continue
		}
		actual := msg_id1(value, 'colorUsingColorSpace:', msg_id(get_class('NSColorSpace'),
			'sRGBColorSpace'))
		if is_nil(actual) {
			continue
		}
		r := msg_f64(actual, 'redComponent') - msg_f64(srgb, 'redComponent')
		g := msg_f64(actual, 'greenComponent') - msg_f64(srgb, 'greenComponent')
		b := msg_f64(actual, 'blueComponent') - msg_f64(srgb, 'blueComponent')
		distance := math.sqrt(2 * r * r + 4 * g * g + 3 * b * b)
		if distance < 1.5 { best = math.max(best, 1 - distance / 1.5) }
	}
	return best
}

pub fn filtered_command_options(options []NativeCommandOption, query string) []NativeCommandOption {
	if query.len == 0 { return options.clone() }
	needle := nsstring(query)
	mut result := options.filter(msg_bool1(nsstring(it.title), 'localizedCaseInsensitiveContainsString:', needle)
		|| msg_bool1(nsstring(it.subtitle), 'localizedCaseInsensitiveContainsString:', needle)
		|| palette_color_score(it.leading_color, query) > 0)
	// Stable color ranking preserves the previously sorted option order on ties.
	for i := 1; i < result.len; i++ {
		value := result[i]
		score := palette_color_score(value.leading_color, query)
		mut j := i
		for j > 0 && palette_color_score(result[j - 1].leading_color, query) < score {
			unsafe {
				result[j] = result[j - 1]
			}
			j--
		}
		unsafe {
			result[j] = value
		}
	}
	return result
}

pub fn (mut surface NativeActionSurface) toggle_command_palette(options []NativeCommandOption) {
	if surface.palette != unsafe { nil } {
		surface.palette.close()
		return
	}
	mut cls := get_class('WittyCommandPaletteOwner')
	if is_nil(cls) {
		cls = C.macos_objc_allocate_class_pair(get_class('NSObject'),
			cstr('WittyCommandPaletteOwner'), 0)
		add_ptr_ivar(cls, 'palette')
		add_method(cls, 'controlTextDidChange:', voidptr(palette_edit), 'v@:@')
		add_method(cls, 'control:textView:doCommandBySelector:', voidptr(palette_command), 'B@:@@:')
		add_method(cls, 'controlTextDidEndEditing:', voidptr(palette_lost_focus), 'v@:@')
		add_method(cls, 'submit:', voidptr(palette_submit), 'v@:@')
		add_method(cls, 'mouseEntered:', voidptr(palette_hover), 'v@:@')
		add_method(cls, 'mouseExited:', voidptr(palette_hover), 'v@:@')
		C.macos_objc_register_class_pair(cls)
	}
	mut container_class := get_class('WittyPaletteContainer')
	if is_nil(container_class) {
		container_class = C.macos_objc_allocate_class_pair(get_class('NSVisualEffectView'),
			cstr('WittyPaletteContainer'), 0)
		add_method(container_class, 'isFlipped', voidptr(action_flipped), 'B@:')
		C.macos_objc_register_class_pair(container_class)
	}
	mut palette := &NativeCommandPalette{
		surface: &surface
		options: options.clone()
	}
	palette.owner = msg_id(alloc('WittyCommandPaletteOwner'), 'init')
	C.macos_objc_set_ptr_ivar(palette.owner, cstr('palette'), voidptr(palette))
	palette.container = msg_id_rect(alloc('WittyPaletteContainer'), 'initWithFrame:', objc_rect(16,
		16, 500, 248))
	msg_void_u64(palette.container, 'setMaterial:', 21)
	msg_void_u64(palette.container, 'setBlendingMode:', 0)
	msg_void_bool(palette.container, 'setWantsLayer:', true)
	msg_void_f64(msg_id(palette.container, 'layer'), 'setCornerRadius:', 10)
	msg_void_f64(msg_id(palette.container, 'layer'), 'setBorderWidth:', 1)
	msg_void1(msg_id(palette.container, 'layer'), 'setBorderColor:', msg_id(msg_id_f64(msg_id(get_class('NSColor'), 'tertiaryLabelColor'), 'colorWithAlphaComponent:', 0.75), 'CGColor'))
	C.witty_macos_msg_void_f32(msg_id(palette.container, 'layer'), sel('setShadowOpacity:'), 0.33)
	msg_void_f64(msg_id(palette.container, 'layer'), 'setShadowRadius:', 32)
	C.witty_action_shadow_offset(msg_id(palette.container, 'layer'), 0, 12)
	msg_void1(palette.container, 'setAppearance:', msg_id1(get_class('NSAppearance'), 'appearanceNamed:', nsstring(if surface.visual_background == 0 {
		'NSAppearanceNameDarkAqua'
	} else if (0.299 * f64((surface.visual_background >> 16) & 255) + 0.587 * f64((surface.visual_background >> 8) & 255) + 0.114 * f64(surface.visual_background & 255)) / 255 > 0.5 {
		'NSAppearanceNameAqua'
	} else {
		'NSAppearanceNameDarkAqua'
	})))
	palette.tint = msg_id(get_class('CALayer'), 'layer')
	msg_void1(palette.tint, 'setCompositingFilter:', nsstring('colorBlendMode'))
	msg_void1(msg_id(palette.container, 'layer'), 'addSublayer:', palette.tint)
	palette.field = msg_id_rect(alloc('NSTextField'), 'initWithFrame:', objc_rect(16, 8, 468, 40))
	msg_void1(palette.field, 'setPlaceholderString:', nsstring('Execute a command…'))
	msg_void_bool(palette.field, 'setBezeled:', false)
	msg_void_bool(palette.field, 'setDrawsBackground:', false)
	msg_void1(palette.field, 'setFont:', msg_id_f64(get_class('NSFont'), 'systemFontOfSize:', 20))
	msg_void1(palette.field, 'setDelegate:', palette.owner)
	msg_void1(palette.container, 'addSubview:', palette.field)
	palette.scroll = msg_id_rect(alloc('NSScrollView'), 'initWithFrame:',
		objc_rect(0, 48, 500, 200))
	msg_void_bool(palette.scroll, 'setHasVerticalScroller:', true)
	msg_void_bool(palette.scroll, 'setDrawsBackground:', false)
	palette.document = msg_id_rect(alloc('WittyActionOverlay'), 'initWithFrame:', objc_rect(0, 0,
		500, 200))
	msg_void1(palette.scroll, 'setDocumentView:', palette.document)
	msg_void1(palette.container, 'addSubview:', palette.scroll)
	surface.palette = palette
	msg_void1(surface.overlay, 'addSubview:', palette.container)
	palette.rebuild()
	palette.layout()
	msg_bool1(view_window(surface.view), 'makeFirstResponder:', palette.field)
}

pub fn (surface &NativeActionSurface) command_palette_is_showing() bool {
	return surface.palette != unsafe { nil }
}

fn (mut palette NativeCommandPalette) layout() {
	width := math.min(500.0, view_width(palette.surface.view) - 32)
	msg_void_rect(palette.container, 'setFrame:', objc_rect((view_width(palette.surface.view) - width) / 2,
		view_height(palette.surface.view) * 0.05, width, if palette.filtered.len == 0 {
			96.0
		} else {
			248.0
		}))
	msg_void_rect(palette.tint, 'setFrame:', msg_rect(palette.container, 'bounds'))
	msg_void1(palette.tint, 'setBackgroundColor:', msg_id(native_color(palette.surface.visual_background, 1), 'CGColor'))
	msg_void_rect(palette.field, 'setFrame:', objc_rect(16, 8, width - 32, 40))
	msg_void_rect(palette.scroll, 'setFrame:', objc_rect(0, 48, width, 200))
}

fn (mut palette NativeCommandPalette) close() {
	if palette.surface.palette == unsafe { nil } { return }
	palette.surface.palette = unsafe { nil }
	msg_bool1(view_window(palette.surface.view), 'makeFirstResponder:', palette.surface.view)
	msg_void(palette.container, 'removeFromSuperview')
	msg_void(palette.container, 'release')
	msg_void(palette.owner, 'release')
}

fn (mut palette NativeCommandPalette) rebuild() {
	palette.filtered = filtered_command_options(palette.options, palette.query)
	children := msg_id(palette.document, 'subviews')
	for i := int(msg_u64(children, 'count')) - 1; i >= 0; i-- {
		msg_void(msg_id_u64(children, 'objectAtIndex:', u64(i)), 'removeFromSuperview')
	}
	width := msg_rect(palette.scroll, 'bounds').width
	height := if palette.filtered.len > 0 { f64(palette.filtered.len) * 46 + 20 } else { 48.0 }
	msg_void_rect(palette.document, 'setFrame:', objc_rect(0, 0, width, height))
	if palette.filtered.len == 0 {
		label := action_label('No matches', objc_rect(16, 12, width - 32, 24))
		msg_void1(palette.document, 'addSubview:', label)
		msg_void(label, 'release')
		return
	}
	for index, option in palette.filtered {
		button := msg_id_rect(alloc('NSButton'), 'initWithFrame:', objc_rect(10, 10 + index * 46,
			width - 20, 42))
		msg_void1(button, 'setTitle:', nsstring((if option.leading_color != none {
			'        '
		} else if option.leading_icon.len > 0 {
			'    '
		} else {
			''
		}) + option.title +
			(if option.subtitle.len > 0 { '\n${option.subtitle}' } else { '' })))
		msg_void_bool(button, 'setBordered:', false)
		msg_void_u64(button, 'setAlignment:', 0)
		msg_void1(button, 'setToolTip:', nsstring(option.description))
		msg_void1(button, 'setTarget:', palette.owner)
		msg_void1(button, 'setAction:', sel('submit:'))
		msg_void_u64(button, 'setTag:', u64(index))
		msg_void_bool(button, 'setWantsLayer:', true)
		msg_void_f64(msg_id(button, 'layer'), 'setCornerRadius:', 5)
		if option.emphasis {
			msg_void1(button, 'setFont:', C.witty_action_id_f64_f64(get_class('NSFont'), sel('systemFontOfSize:weight:'), 13, 0.23))
			msg_void_f64(msg_id(button, 'layer'), 'setBorderWidth:', 1.5)
			msg_void1(msg_id(button, 'layer'), 'setBorderColor:', msg_id(msg_id_f64(msg_id(get_class('NSColor'), 'controlAccentColor'), 'colorWithAlphaComponent:', 0.3), 'CGColor'))
		}
		if selected := palette.selected {
			if index == int(if selected < usize(palette.filtered.len) {
				selected
			} else {
				usize(palette.filtered.len - 1)
			}) {
				msg_void1(msg_id(button, 'layer'), 'setBackgroundColor:', msg_id(msg_id_f64(msg_id(get_class('NSColor'),
					'controlAccentColor'), 'colorWithAlphaComponent:', 0.2), 'CGColor'))
			}
		}
		if color := option.leading_color {
			dot := msg_id_rect(alloc('NSView'), 'initWithFrame:', objc_rect(4, 17, 8, 8))
			msg_void_bool(dot, 'setWantsLayer:', true)
			msg_void_f64(msg_id(dot, 'layer'), 'setCornerRadius:', 4)
			msg_void1(msg_id(dot, 'layer'), 'setBackgroundColor:', msg_id(color, 'CGColor'))
			msg_void1(button, 'addSubview:', dot)
			msg_void(dot, 'release')
		}
		if option.leading_icon.len > 0 {
			image := msg_id2(get_class('NSImage'), 'imageWithSystemSymbolName:accessibilityDescription:', nsstring(option.leading_icon), nil_obj())
			icon := msg_id_rect(alloc('NSImageView'), 'initWithFrame:', objc_rect(if option.leading_color != none {
				20.0
			} else {
				4.0
			}, 13, 16, 16))
			msg_void1(icon, 'setImage:', image)
			msg_void1(icon, 'setContentTintColor:', msg_id(get_class('NSColor'), if option.emphasis {
				'controlAccentColor'
			} else {
				'secondaryLabelColor'
			}))
			msg_void1(button, 'addSubview:', icon)
			msg_void(icon, 'release')
		}
		if badge := option.badge {
			if badge.len > 0 {
				badge_width := action_text_width(badge, 11) + 14
				label := action_label(badge, objc_rect(width - 30 - badge_width, 12, badge_width, 18))
				msg_void1(label, 'setFont:', C.witty_action_id_f64_f64(get_class('NSFont'), sel('systemFontOfSize:weight:'), 11, 0.23))
				msg_void1(label, 'setTextColor:', msg_id(get_class('NSColor'), 'controlAccentColor'))
				msg_void_u64(label, 'setAlignment:', 1)
				msg_void_bool(label, 'setWantsLayer:', true)
				msg_void_f64(msg_id(label, 'layer'), 'setCornerRadius:', 9)
				msg_void1(msg_id(label, 'layer'), 'setBackgroundColor:', msg_id(msg_id_f64(msg_id(get_class('NSColor'), 'controlAccentColor'), 'colorWithAlphaComponent:', 0.15), 'CGColor'))
				msg_void1(button, 'addSubview:', label)
				msg_void(label, 'release')
			}
		}
		tracking := msg_id_rect_u64_obj_obj(alloc('NSTrackingArea'), 'initWithRect:options:owner:userInfo:', msg_rect(button, 'bounds'), 1 | 128, palette.owner, msg_id_u64(get_class('NSNumber'), 'numberWithUnsignedInteger:', u64(index)))
		msg_void1(button, 'addTrackingArea:', tracking)
		msg_void(tracking, 'release')
		msg_void1(palette.document, 'addSubview:', button)
		msg_void(button, 'release')
	}
	palette.repaint_rows()
	palette.layout()
}

fn (palette &NativeCommandPalette) repaint_rows() {
	children := msg_id(palette.document, 'subviews')
	for i in 0 .. int(msg_u64(children, 'count')) {
		button := msg_id_u64(children, 'objectAtIndex:', u64(i))
		if !msg_bool1(button, 'isKindOfClass:', get_class('NSButton')) { continue }
		selected := if index := palette.selected {
			i == int(if index < usize(palette.filtered.len) {
				index
			} else {
				usize(palette.filtered.len - 1)
			})
		} else {
			false
		}
		hovered := if index := palette.hovered { i == int(index) } else { false }
		color := if selected {
			msg_id_f64(msg_id(get_class('NSColor'), 'controlAccentColor'), 'colorWithAlphaComponent:', 0.2)
		} else if hovered {
			msg_id_f64(msg_id(get_class('NSColor'), 'secondaryLabelColor'), 'colorWithAlphaComponent:', 0.2)
		} else {
			nil_obj()
		}
		msg_void1(msg_id(button, 'layer'), 'setBackgroundColor:', msg_id(color, 'CGColor'))
		if palette.filtered[i].emphasis {
			msg_void_f64(msg_id(button, 'layer'), 'setBorderWidth:', if selected {
				0.0
			} else {
				1.5
			})
		}
	}
}

fn palette_hover(self ObjId, cmd Sel, event ObjId) {
	mut palette := palette_state(self) or { return }
	index := usize(msg_u64(msg_id(msg_id(event, 'trackingArea'), 'userInfo'), 'unsignedIntegerValue'))
	if cmd == sel('mouseEntered:') {
		palette.hovered = index
	} else if previous := palette.hovered {
		if previous == index { palette.hovered = none }
	}
	palette.repaint_rows()
}

fn palette_edit(self ObjId, _cmd Sel, _notification ObjId) {
	mut palette := palette_state(self) or { return }
	palette.query = objc_utf8_string(msg_id(palette.field, 'stringValue'))
	if palette.query.len > 0 {
		if palette.selected == none { palette.selected = usize(0) }
	} else if value := palette.selected {
		if value == 0 { palette.selected = none }
	}
	palette.rebuild()
}

fn palette_command(self ObjId, _cmd Sel, _control ObjId, _text ObjId, command Sel) bool {
	mut palette := palette_state(self) or { return false }
	if command == sel('cancelOperation:') {
		palette.close()
		return true
	}
	if command == sel('insertNewline:') {
		palette.activate(palette.selected)
		return true
	}
	if command in [sel('moveUp:'), sel('moveDown:')] {
		count := palette.filtered.len
		if count == 0 { return true }
		if command == sel('moveUp:') {
			current := palette.selected or { usize(count) }
			palette.selected = if current == 0 { usize(count - 1) } else { current - 1 }
		} else {
			current := palette.selected or { ~usize(0) }
			palette.selected = if current >= usize(count - 1) { usize(0) } else { current + 1 }
		}
		palette.rebuild()
		if row := palette.selected {
			if row < usize(count) {
				C.witty_action_scroll_rect(palette.document, 0, f64(row) * 46 + 10, msg_rect(palette.scroll,
					'bounds').width, 42)
			}
		}
		return true
	}
	return false
}

fn palette_lost_focus(self ObjId, _cmd Sel, _notification ObjId) {
	if mut palette := palette_state(self) { palette.close() }
}

fn palette_submit(self ObjId, _cmd Sel, sender ObjId) {
	if mut palette := palette_state(self) { palette.activate(usize(msg_u64(sender, 'tag'))) }
}

fn (mut palette NativeCommandPalette) activate(selected ?usize) {
	mut value := ?NativeCommandOption(none)
	if index := selected {
		if palette.filtered.len > 0 {
			final_index := if index < usize(palette.filtered.len) {
				int(index)
			} else {
				palette.filtered.len - 1
			}
			value = palette.filtered[final_index]
		}
	}
	palette.close()
	if option := value {
		if !is_nil(option.focus_view) {
			if palette.surface.callbacks.present != unsafe { nil } {
				palette.surface.callbacks.present(palette.surface.userdata, option.focus_view)
			} else {
				present_view(option.focus_view)
			}
		} else if option.invoke != unsafe { nil } {
			option.invoke()
		} else {
			palette.surface.perform(option.action)
		}
	}
}

fn C.witty_action_scroll_rect(view voidptr, x f64, y f64, width f64, height f64)
