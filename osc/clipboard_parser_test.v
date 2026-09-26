module osc

fn test_osc52_get_set_clipboard() {
	mut p := Parser.init(unsafe { nil })
	input := '52;s;?'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ClipboardContents
	assert (cmd as ClipboardContents).kind == `s`
	assert (cmd as ClipboardContents).data == '?'
}

fn test_osc52_get_set_clipboard_optional_parameter() {
	mut p := Parser.init(unsafe { nil })
	input := '52;;?'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ClipboardContents
	assert (cmd as ClipboardContents).kind == `c`
	assert (cmd as ClipboardContents).data == '?'
}

fn test_osc52_clear_clipboard() {
	mut p := Parser.init(unsafe { nil })
	input := '52;;'
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(0) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ClipboardContents
	assert (cmd as ClipboardContents).kind == `c`
	assert (cmd as ClipboardContents).data == ''
}

fn test_osc52_allocating_writer_accepts_payload_larger_than_normal_buffer() {
	mut p := Parser.init(voidptr(1))
	input := '52;c;' + 'a'.repeat(max_buf + 1)
	for ch in input.bytes() {
		p.next(ch)
	}
	cmd := p.end(none) or {
		assert false, 'expected command'
		return
	}
	assert cmd is ClipboardContents
	assert (cmd as ClipboardContents).kind == `c`
	assert (cmd as ClipboardContents).data == 'a'.repeat(max_buf + 1)
}

fn test_osc52_without_allocator_falls_back_to_fixed_buffer() {
	mut p := Parser.init(unsafe { nil })
	input := '52;c;' + 'a'.repeat(max_buf + 1)
	for ch in input.bytes() {
		p.next(ch)
	}
	assert p.end(none) == none
}
