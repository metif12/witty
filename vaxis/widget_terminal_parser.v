module vaxis

import zigimg

pub struct TerminalPrint {
pub:
	bytes []u8
}

pub struct TerminalControl {
pub:
	value TerminalC0
}

pub struct TerminalEscape {
pub:
	bytes []u8
}

pub struct TerminalSs2 {
pub:
	byte u8
}

pub struct TerminalSs3 {
pub:
	byte u8
}

pub struct TerminalOsc {
pub:
	bytes []u8
}

pub struct TerminalApc {
pub:
	bytes []u8
}

pub type TerminalParseEvent = TerminalPrint
	| TerminalControl
	| TerminalEscape
	| TerminalSs2
	| TerminalSs3
	| TerminalCsi
	| TerminalOsc
	| TerminalApc

// Returned sequence bytes borrow buf until the next parse_reader call.
pub struct TerminalParser {
pub mut:
	buf          []u8
	pending_byte ?u8
}

pub fn (mut parser TerminalParser) parse_reader(mut reader zigimg.ReadStream) !TerminalParseEvent {
	parser.buf.clear()
	for {
		byte := if pending := parser.pending_byte { pending } else { reader.take_byte()! }
		parser.pending_byte = none
		match byte {
			0x1b {
				next := reader.take_byte()!
				match next {
					0x4e {
						return TerminalSs2{
							byte: reader.take_byte()!
						}
					}
					0x4f {
						return TerminalSs3{
							byte: reader.take_byte()!
						}
					}
					0x50, 0x58, 0x5e {
						terminal_skip_until_st(mut reader)!
					}
					0x5b {
						return parser.parse_csi(mut reader)!
					}
					0x5d {
						return parser.parse_osc(mut reader)!
					}
					0x5f {
						return parser.parse_apc(mut reader)!
					}
					0x20...0x2f {
						parser.buf << next
						return parser.parse_escape(mut reader)!
					}
					else {
						parser.buf << next
						return TerminalEscape{
							bytes: parser.borrowed_bytes()
						}
					}
				}
			}
			0x00...0x1a, 0x1c...0x1f {
				return TerminalControl{
					value: unsafe { TerminalC0(byte) }
				}
			}
			else {
				parser.buf << byte
				return parser.parse_ground(mut reader)!
			}
		}
	}
	return error('EndOfStream')
}

fn (parser TerminalParser) borrowed_bytes() []u8 {
	return unsafe { parser.buf.data.vbytes(parser.buf.len) }
}

fn terminal_utf8_length(byte u8) !int {
	return match byte {
		0x00...0x7f { 1 }
		0xc0...0xdf { 2 }
		0xe0...0xef { 3 }
		0xf0...0xf7 { 4 }
		else { return error('Utf8InvalidStartByte') }
	}
}

fn (mut parser TerminalParser) parse_ground(mut reader zigimg.ReadStream) !TerminalParseEvent {
	if parser.buf.len == 0 { panic('Assertion failed') }
	mut scratch := []u8{len: 1}
	first_length := terminal_utf8_length(parser.buf[0])!
	for _ in 1 .. first_length {
		if reader.read_slice_short(mut scratch)! == 0 { return error('EOF') }
		parser.buf << scratch[0]
	}
	for {
		if reader.buffered_len() == 0 {
			return TerminalPrint{
				bytes: parser.borrowed_bytes()
			}
		}
		if reader.read_slice_short(mut scratch)! == 0 { return error('EOF') }
		byte := scratch[0]
		if byte <= 0x1f {
			parser.pending_byte = byte
			return TerminalPrint{
				bytes: parser.borrowed_bytes()
			}
		}
		parser.buf << byte
		length := terminal_utf8_length(byte)!
		for _ in 1 .. length {
			if reader.read_slice_short(mut scratch)! == 0 { return error('EOF') }
			parser.buf << scratch[0]
		}
	}
	return error('EndOfStream')
}

fn (mut parser TerminalParser) parse_escape(mut reader zigimg.ReadStream) !TerminalParseEvent {
	for {
		byte := reader.take_byte()!
		if byte >= 0x20 && byte <= 0x2f {
			continue
		}
		parser.buf << byte
		return TerminalEscape{
			bytes: parser.borrowed_bytes()
		}
	}
	return error('EndOfStream')
}

fn terminal_discard_one(mut reader zigimg.ReadStream) ! {
	reader.discard_all(1)!
}

fn terminal_skip_until_st(mut reader zigimg.ReadStream) ! {
	for {
		if reader.take_byte()! == 0x1b {
			break
		}
	}
}

fn (mut parser TerminalParser) parse_apc(mut reader zigimg.ReadStream) !TerminalParseEvent {
	for {
		byte := reader.take_byte()!
		match byte {
			0x00...0x17, 0x19, 0x1c...0x1f {
				continue
			}
			0x1b {
				terminal_discard_one(mut reader)!
				return TerminalApc{
					bytes: parser.borrowed_bytes()
				}
			}
			else {
				parser.buf << byte
			}
		}
	}
	return error('EndOfStream')
}

fn (mut parser TerminalParser) parse_osc(mut reader zigimg.ReadStream) !TerminalParseEvent {
	for {
		byte := reader.take_byte()!
		match byte {
			0x00...0x06, 0x08...0x17, 0x19, 0x1c...0x1f {
				continue
			}
			0x1b {
				terminal_discard_one(mut reader)!
				return TerminalOsc{
					bytes: parser.borrowed_bytes()
				}
			}
			0x07 {
				return TerminalOsc{
					bytes: parser.borrowed_bytes()
				}
			}
			else {
				parser.buf << byte
			}
		}
	}
	return error('EndOfStream')
}

fn (mut parser TerminalParser) parse_csi(mut reader zigimg.ReadStream) !TerminalParseEvent {
	mut intermediate := ?u8(none)
	mut marker := ?u8(none)
	for {
		byte := reader.take_byte()!
		match byte {
			0x20...0x2f { intermediate = byte }
			0x30...0x3b { parser.buf << byte }
			0x3c...0x3f { marker = byte }
			0x40...0xff {
				return TerminalCsi{
					intermediate:   intermediate
					private_marker: marker
					params:         parser.borrowed_bytes()
					final:          byte
				}
			}
			else { continue }
		}
	}
	return error('EndOfStream')
}
