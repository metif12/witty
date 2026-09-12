module osc

fn test_osc21_kitty_color_protocol() {
	mut p := Parser.init(voidptr(1))
	input := '21;foreground=?;background=rgb:f0/f8/ff'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_color_protocol
	assert cmd.str_value.contains('foreground=?')
	assert cmd.str_value.contains('background=rgb:f0/f8/ff')
}

fn test_osc21_kitty_color_no_key() {
	mut p := Parser.init(voidptr(1))
	input := '21;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_color_protocol
}

fn test_osc21_kitty_color_protocol_without_allocator() {
	mut p := Parser.init(unsafe { nil })
	for ch in '21;foreground=?'.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_osc21_kitty_color_protocol_without_payload_writer() {
	mut p := Parser.init(voidptr(1))
	for ch in '21'.bytes() {
		p.next(ch)
	}
	assert p.end(0x1b) == none
}

fn test_kitty_color_kind_parse_palette() {
	kind := parse_kitty_color_kind('2') or {
		assert false, 'expected kind'
		return
	}
	assert kind.kind == .palette
	assert kind.palette == 2
}

fn test_kitty_color_kind_parse_special() {
	kind := parse_kitty_color_kind('foreground') or {
		assert false, 'expected kind'
		return
	}
	assert kind.kind == .special
	assert kind.special == .foreground
}

fn test_kitty_color_kind_parse_unknown() {
	assert parse_kitty_color_kind('notacolor') == none
}

fn test_kitty_color_kind_matches_zig_unsigned_parsing() {
	kind := parse_kitty_color_kind('1__0') or {
		assert false, 'expected palette key'
		return
	}
	assert kind.kind == .palette
	assert kind.palette == 10
	for invalid in ['2junk', '+2', '-0', '_2', '2_', '256'] {
		assert parse_kitty_color_kind(invalid) == none
	}
}

fn test_kitty_color_value_only_trims_spaces() {
	mut p := Parser.init(voidptr(1))
	for ch in '21;foreground=\t?\t'.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_color_protocol
	assert cmd.kitty_color_items.len == 0
}

// Translated from ghostty "OSC 21: kitty color protocol". Verifies that the
// parsed item list is attached to the Command and each item matches ghostty.
fn test_osc21_kitty_color_protocol_items() {
	mut p := Parser.init(voidptr(1))
	input := '21;foreground=?;background=rgb:f0/f8/ff;cursor=aliceblue;cursor_text;visual_bell=;selection_foreground=#xxxyyzz;selection_background=?;selection_background=#aabbcc;2=?;3=rgbi:1.0/1.0/1.0'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0x1b) or {
		assert false, 'expected command'
		return
	}
	assert cmd.cmd_type == .kitty_color_protocol
	items := cmd.kitty_color_items
	assert items.len == 9

	assert items[0].item_type == .query
	assert items[0].key.kind == .special
	assert items[0].key.special == .foreground

	assert items[1].item_type == .set
	assert items[1].key.kind == .special
	assert items[1].key.special == .background
	assert items[1].color.r == 0xf0
	assert items[1].color.g == 0xf8
	assert items[1].color.b == 0xff

	assert items[2].item_type == .set
	assert items[2].key.kind == .special
	assert items[2].key.special == .cursor
	assert items[2].color.r == 0xf0
	assert items[2].color.g == 0xf8
	assert items[2].color.b == 0xff

	assert items[3].item_type == .reset
	assert items[3].key.kind == .special
	assert items[3].key.special == .cursor_text

	assert items[4].item_type == .reset
	assert items[4].key.kind == .special
	assert items[4].key.special == .visual_bell

	assert items[5].item_type == .query
	assert items[5].key.kind == .special
	assert items[5].key.special == .selection_background

	assert items[6].item_type == .set
	assert items[6].key.kind == .special
	assert items[6].key.special == .selection_background
	assert items[6].color.r == 0xaa
	assert items[6].color.g == 0xbb
	assert items[6].color.b == 0xcc

	assert items[7].item_type == .query
	assert items[7].key.kind == .palette
	assert items[7].key.palette == 2

	assert items[8].item_type == .set
	assert items[8].key.kind == .palette
	assert items[8].key.palette == 3
	assert items[8].color.r == 0xff
	assert items[8].color.g == 0xff
	assert items[8].color.b == 0xff
}

fn test_kitty_color_items_parse() {
	// Test parsing individual items
	data := 'foreground=?;background=rgb:f0/f8/ff;cursor_text;visual_bell='
	mut items := []KittyColorItem{}
	kvs := data.split(';')
	for kv in kvs {
		eq := kv.index_u8(`=`)
		mut k := ''
		mut value := ''
		if eq >= 0 {
			k = kv[..eq]
			value = kv[eq + 1..].trim_space()
		} else {
			k = kv
			value = ''
		}
		if k.len == 0 {
			continue
		}
		key := parse_kitty_color_kind(k) or { continue }
		if value.len == 0 {
			items << KittyColorItem{
				item_type: .reset
				key: key
			}
		} else if value == '?' {
			items << KittyColorItem{
				item_type: .query
				key: key
			}
		} else {
			rgb := parse_rgb(value) or { continue }
			items << KittyColorItem{
				item_type: .set
				key: key
				color: rgb
			}
		}
	}
	assert items.len == 4
	assert items[0].item_type == .query
	assert items[0].key.special == .foreground
	assert items[1].item_type == .set
	assert items[1].key.special == .background
	assert items[1].color.r == 0xf0
	assert items[2].item_type == .reset
	assert items[2].key.special == .cursor_text
	assert items[3].item_type == .reset
	assert items[3].key.special == .visual_bell
}
