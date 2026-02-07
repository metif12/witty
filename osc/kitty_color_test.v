module osc

fn test_osc21_kitty_color_protocol() {
	mut p := Parser.init(unsafe { nil })
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
	mut p := Parser.init(unsafe { nil })
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
				key:       key
			}
		} else if value == '?' {
			items << KittyColorItem{
				item_type: .query
				key:       key
			}
		} else {
			rgb := parse_rgb(value) or { continue }
			items << KittyColorItem{
				item_type: .set
				key:       key
				color:     rgb
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
