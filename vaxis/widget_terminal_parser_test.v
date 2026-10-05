module vaxis

import zigimg

fn test_terminal_parser_borrows_sequence_bytes_and_retains_control_pending_byte() {
	mut reader := zigimg.ReadStream.init_memory('\x1bA\x1bBword\x07'.bytes())
	mut parser := TerminalParser{ buf: []u8{cap: 128} }
	first := parser.parse_reader(mut reader)!
	match first {
		TerminalEscape {
			assert first.bytes == [u8(`A`)]
			second := parser.parse_reader(mut reader)!
			assert second is TerminalEscape
			assert first.bytes == [u8(`B`)]
		}
		else {
			assert false
		}
	}
	printed := parser.parse_reader(mut reader)!
	match printed {
		TerminalPrint {
			assert printed.bytes.bytestr() == 'word'
		}
		else {
			assert false
		}
	}
	assert parser.pending_byte == ?u8(7)
	assert reader.get_pos() == 9
	control := parser.parse_reader(mut reader)!
	match control {
		TerminalControl {
			assert control.value == .bel
		}
		else {
			assert false
		}
	}
	assert parser.pending_byte == none
}

fn test_terminal_parser_preserves_escape_skip_and_partial_utf8_behavior() {
	mut reader := zigimg.ReadStream.init_memory('\x1bPdiscard\x1bQ\x1b !A\x1b]0;name\x1b'.bytes())
	mut parser := TerminalParser{}
	skipped := parser.parse_reader(mut reader)!
	match skipped {
		TerminalPrint {
			assert skipped.bytes.bytestr() == 'Q'
		}
		else {
			assert false
		}
	}
	parsed_escape := parser.parse_reader(mut reader)!
	match parsed_escape {
		TerminalEscape {
			assert parsed_escape.bytes == [u8(` `), `A`]
		}
		else {
			assert false
		}
	}
	mut osc_failed := false
	parser.parse_reader(mut reader) or {
		osc_failed = true
		assert err.msg() == 'EndOfStream'
	}
	assert osc_failed && parser.buf.bytestr() == '0;name'
	mut partial := zigimg.ReadStream.init_memory([u8(0xe2), 0x82])
	mut failed := false
	parser.parse_reader(mut partial) or {
		failed = true
		assert err.msg() == 'EOF'
	}
	assert failed && parser.buf == [u8(0xe2), 0x82]
	mut invalid := zigimg.ReadStream.init_memory([u8(0x80)])
	failed = false
	parser.parse_reader(mut invalid) or {
		failed = true
		assert err.msg() == 'Utf8InvalidStartByte'
	}
	assert failed && parser.buf == [u8(0x80)]
}

fn test_terminal_csi_iterator_lookahead_restores_index_but_updates_flags() {
	mut iter := TerminalCsi{ params: '12::3;'.bytes(), final: `m` }.iterator[u16]()
	first_value := iter.next()
	assert first_value == ?u16(12)
	assert iter.idx == 3 && iter.next_is_sub && !iter.is_empty
	one_available := iter.has_at_least(1)
	assert one_available
	assert iter.idx == 3 && iter.next_is_sub && iter.is_empty
	three_available := iter.has_at_least(3)
	assert !three_available
	assert iter.idx == 3 && !iter.next_is_sub && !iter.is_empty
	empty_value := iter.next()
	assert empty_value == ?u16(0)
	assert iter.next_is_sub && iter.is_empty
	three_value := iter.next()
	assert three_value == ?u16(3)
	end_value := iter.next()
	assert end_value == none
	mut invalid := TerminalCsi{ params: '1x;2'.bytes(), final: `m` }.iterator[u16]()
	invalid_value := invalid.next()
	assert invalid_value == none && invalid.idx == 2
	invalid_empty := invalid.next()
	assert invalid_empty == ?u16(0) && invalid.is_empty
	last_value := invalid.next()
	assert last_value == ?u16(2)
}
