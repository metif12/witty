module osc

fn test_kitty_color_source_tag_layouts_and_ordinals() {
	assert sizeof(KittyColorSpecial) == 1
	assert u8(KittyColorSpecial.foreground) == 0
	assert u8(KittyColorSpecial.background) == 1
	assert u8(KittyColorSpecial.selection_foreground) == 2
	assert u8(KittyColorSpecial.selection_background) == 3
	assert u8(KittyColorSpecial.cursor) == 4
	assert u8(KittyColorSpecial.cursor_text) == 5
	assert u8(KittyColorSpecial.visual_bell) == 6
	assert u8(KittyColorSpecial.second_transparent_background) == 7
}

fn test_kitty_color_protocol_kind_string() {
	assert KittyColorKind(KittyColorSpecial.foreground).str() == 'foreground'
	assert KittyColorKind(u8(42)).str() == '42'
}

fn test_osc21_kitty_color_protocol() {
	mut p := Parser.init(voidptr(1))
	defer { p.deinit() }

	input := '21;foreground=?;background=rgb:f0/f8/ff;cursor=aliceblue;cursor_text;visual_bell=;selection_foreground=#xxxyyzz;selection_background=?;selection_background=#aabbcc;2=?;3=rgbi:1.0/1.0/1.0'
	for ch in input.bytes() {
		p.next(ch)
	}

	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd is KittyColorOSC
	list := (cmd as KittyColorOSC).list
	assert list.len == 9
	{
		item := list[0]
		assert item is KittyColorQuery
		assert (item as KittyColorQuery).key == KittyColorKind(KittyColorSpecial.foreground)
	}
	{
		item := list[1]
		assert item is KittyColorSet
		set := item as KittyColorSet
		assert set.key == KittyColorKind(KittyColorSpecial.background)
		assert set.color.r == 0xf0
		assert set.color.g == 0xf8
		assert set.color.b == 0xff
	}
	{
		item := list[2]
		assert item is KittyColorSet
		set := item as KittyColorSet
		assert set.key == KittyColorKind(KittyColorSpecial.cursor)
		assert set.color.r == 0xf0
		assert set.color.g == 0xf8
		assert set.color.b == 0xff
	}
	{
		item := list[3]
		assert item is KittyColorReset
		assert (item as KittyColorReset).key == KittyColorKind(KittyColorSpecial.cursor_text)
	}
	{
		item := list[4]
		assert item is KittyColorReset
		assert (item as KittyColorReset).key == KittyColorKind(KittyColorSpecial.visual_bell)
	}
	{
		item := list[5]
		assert item is KittyColorQuery
		assert (item as KittyColorQuery).key == KittyColorKind(KittyColorSpecial.selection_background)
	}
	{
		item := list[6]
		assert item is KittyColorSet
		set := item as KittyColorSet
		assert set.key == KittyColorKind(KittyColorSpecial.selection_background)
		assert set.color.r == 0xaa
		assert set.color.g == 0xbb
		assert set.color.b == 0xcc
	}
	{
		item := list[7]
		assert item is KittyColorQuery
		assert (item as KittyColorQuery).key == KittyColorKind(u8(2))
	}
	{
		item := list[8]
		assert item is KittyColorSet
		set := item as KittyColorSet
		assert set.key == KittyColorKind(u8(3))
		assert set.color.r == 0xff
		assert set.color.g == 0xff
		assert set.color.b == 0xff
	}
}

fn test_osc21_kitty_color_protocol_without_allocator() {
	mut p := Parser.init(unsafe { nil })
	defer { p.deinit() }

	input := '21;foreground=?'
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc21_kitty_color_protocol_double_reset() {
	mut p := Parser.init(voidptr(1))
	defer { p.deinit() }

	input := '21;foreground=?;background=rgb:f0/f8/ff;cursor=aliceblue;cursor_text;visual_bell=;selection_foreground=#xxxyyzz;selection_background=?;selection_background=#aabbcc;2=?;3=rgbi:1.0/1.0/1.0'
	for ch in input.bytes() {
		p.next(ch)
	}

	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd is KittyColorOSC

	p.reset()
	p.reset()
}

fn test_osc21_kitty_color_protocol_reset_after_invalid() {
	mut p := Parser.init(voidptr(1))
	defer { p.deinit() }

	input := '21;foreground=?;background=rgb:f0/f8/ff;cursor=aliceblue;cursor_text;visual_bell=;selection_foreground=#xxxyyzz;selection_background=?;selection_background=#aabbcc;2=?;3=rgbi:1.0/1.0/1.0'
	for ch in input.bytes() {
		p.next(ch)
	}

	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd is KittyColorOSC

	p.reset()

	assert p.state == .start
	p.next(`X`)
	assert p.state == .invalid

	p.reset()
}

fn test_osc21_kitty_color_protocol_no_key() {
	mut p := Parser.init(voidptr(1))
	defer { p.deinit() }

	input := '21;'
	for ch in input.bytes() {
		p.next(ch)
	}

	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd is KittyColorOSC
	assert (cmd as KittyColorOSC).list.len == 0
}

fn test_osc21_kitty_color_protocol_without_payload_writer() {
	mut p := Parser.init(voidptr(1))
	for ch in '21'.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_kitty_color_kind_parse_palette() {
	kind := parse_kitty_color_kind('2') or { panic('expected kind') }
	assert kind == KittyColorKind(u8(2))
}

fn test_kitty_color_kind_parse_special() {
	kind := parse_kitty_color_kind('foreground') or { panic('expected kind') }
	assert kind == KittyColorKind(KittyColorSpecial.foreground)
}

fn test_kitty_color_kind_parse_unknown() {
	assert parse_kitty_color_kind('notacolor') == none
}

fn test_kitty_color_kind_matches_zig_unsigned_parsing() {
	kind := parse_kitty_color_kind('1__0') or { panic('expected palette key') }
	assert kind == KittyColorKind(u8(10))
	for invalid in ['2junk', '+2', '-0', '_2', '2_', '256'] {
		assert parse_kitty_color_kind(invalid) == none
	}
}

fn test_kitty_color_value_only_trims_spaces() {
	mut p := Parser.init(voidptr(1))
	for ch in '21;foreground=\t?\t'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or { panic('expected command') }
	assert cmd is KittyColorOSC
	assert (cmd as KittyColorOSC).list.len == 0
}
