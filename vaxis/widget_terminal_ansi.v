module vaxis

import zigimg

// widgets.terminal.ansi is flattened under Terminal* names.
pub enum TerminalC0 as u8 {
	nul = 0
	soh
	stx
	etx
	eot
	enq
	ack
	bel
	bs
	ht
	lf
	vt
	ff
	cr
	so
	si
	dle
	dc1
	dc2
	dc3
	dc4
	nak
	syn
	etb
	can
	em
	sub
	esc
	fs
	gs
	rs
	us
}

pub struct TerminalCsi {
pub mut:
	intermediate   ?u8
	private_marker ?u8
	final          u8   @[required]
	params         []u8 @[required]
}

pub fn (seq TerminalCsi) has_intermediate(value u8) bool {
	return if intermediate := seq.intermediate { value == intermediate } else { false }
}

pub fn (seq TerminalCsi) has_private_marker(value u8) bool {
	return if marker := seq.private_marker { value == marker } else { false }
}

pub fn (seq TerminalCsi) iterator[T]() TerminalParamIterator[T] {
	return TerminalParamIterator[T]{
		bytes: seq.params
	}
}

fn (seq TerminalCsi) format_text() string {
	mut text := 'CSI '
	if marker := seq.private_marker { text += marker.ascii_str() + ' ' }
	text += seq.params.bytestr() + ' '
	if intermediate := seq.intermediate { text += intermediate.ascii_str() + ' ' }
	text += seq.final.ascii_str()
	return text
}

pub fn (seq TerminalCsi) format(mut writer zigimg.WriteStream) ! {
	writer.write_all(seq.format_text().bytes())!
}

pub struct TerminalParamIterator[T] {
pub mut:
	bytes       []u8 @[required]
	idx         usize
	next_is_sub bool
	is_empty    bool
}

pub fn (mut iter TerminalParamIterator[T]) next() ?T {
	iter.next_is_sub = false
	iter.is_empty = false
	start := iter.idx
	mut value := T(0)
	for iter.idx < usize(iter.bytes.len) {
		byte := iter.bytes[int(iter.idx)]
		match byte {
			`0`...`9` {
				value = terminal_param_step(value, byte - `0`)
				last := iter.idx == usize(iter.bytes.len - 1)
				iter.idx = widget_checked_add(iter.idx, 1)
				if last { return value }
			}
			`:`, `;` {
				iter.next_is_sub = byte == `:`
				iter.is_empty = iter.idx == start
				iter.idx = widget_checked_add(iter.idx, 1)
				return value
			}
			else {
				iter.idx = widget_checked_add(iter.idx, 1)
				return none
			}
		}
	}
	return none
}

pub fn (mut iter TerminalParamIterator[T]) has_at_least(count usize) bool {
	start := iter.idx
	defer { iter.idx = start }
	mut seen := usize(0)
	for {
		if _ := iter.next() {
			seen = widget_checked_add(seen, 1)
			if seen >= count { return true }
		} else {
			return seen >= count
		}
	}
	return false
}

fn terminal_param_step[T](value T, digit u8) T {
	$if T.unaliased_typ is u8 || T.unaliased_typ is u16 || T.unaliased_typ is u32 || T.unaliased_typ is u64 || T.unaliased_typ is usize {
		limit := if sizeof(T) == 8 {
			u64(0xffffffffffffffff)
		} else {
			(u64(1) << (sizeof(T) * 8)) - 1
		}
		if u64(value) > limit / 10 { panic('integer overflow') }
		product := u64(value) * 10
		if product > limit - u64(digit) { panic('integer overflow') }
		return T(product + digit)
	} $else $if T.unaliased_typ is i16 || T.unaliased_typ is int || T.unaliased_typ is i64 || T.unaliased_typ is isize {
		limit := if sizeof(T) == 8 {
			u64(0x7fffffffffffffff)
		} else {
			(u64(1) << (sizeof(T) * 8 - 1)) - 1
		}
		if u64(value) > limit / 10 { panic('integer overflow') }
		product := u64(value) * 10
		if product > limit - u64(digit) { panic('integer overflow') }
		return T(product + digit)
	} $else {
		$compile_error('TerminalParamIterator requires a translated source integer type capable of representing u8')
	}
	return T(0)
}
