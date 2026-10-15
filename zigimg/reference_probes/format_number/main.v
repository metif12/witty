module main

import os
import strings
import zigimg as p

fn optional(text string) ?usize {
	if text == '-' { return none }
	return usize(text.u64())
}

fn emit_optional(mut out strings.Builder, value ?usize) {
	if n := value {
		out.write_string(u64(n).str())
	} else {
		out.write_u8(`-`)
	}
}

fn emit_number(mut out strings.Builder, n p.NumberFormat) {
	out.write_string('${int(n.mode)},${int(n.letter_case)},')
	emit_optional(mut out, n.precision)
	out.write_u8(`,`)
	emit_optional(mut out, n.width)
	out.write_string(',${int(n.alignment)},${n.fill},')
	if base := n.mode.base() {
		out.write_string('${base}')
	} else {
		out.write_u8(`-`)
	}
	out.write_u8(`;`)
}

fn emit_options(mut out strings.Builder, o p.FormatOptions) {
	emit_optional(mut out, o.precision)
	out.write_u8(`,`)
	emit_optional(mut out, o.width)
	out.write_string(',${int(o.alignment)},${o.fill};')
}

fn changed(n p.NumberFormat, field u8, seed usize) p.NumberFormat {
	mut result := n
	match field {
		0 { result.mode = unsafe { p.NumberMode(seed % 5) } }
		1 { result.letter_case = unsafe { p.FormatCase(seed % 2) } }
		2 { result.precision = if seed % 3 == 0 { none } else { ?usize(seed) } }
		3 { result.width = if seed % 4 == 0 { none } else { ?usize(~usize(0) - seed) } }
		4 { result.alignment = unsafe { p.Alignment(seed % 3) } }
		5 { result.fill = u8(seed) }
		else { panic('invalid field') }
	}

	return result
}

fn changed_options(o p.FormatOptions, field u8, seed usize) p.FormatOptions {
	mut result := o
	match field % 4 {
		0 { result.precision = if seed % 3 == 0 { none } else { ?usize(seed) } }
		1 { result.width = if seed % 4 == 0 { none } else { ?usize(~usize(0) - seed) } }
		2 { result.alignment = unsafe { p.Alignment(seed % 3) } }
		3 { result.fill = u8(seed) }
		else { panic('invalid field') }
	}

	return result
}

fn main() {
	mut out := strings.new_builder(65536)
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		f := line.split('|')
		form := f[0].int()
		operation := f[1].int()
		field := u8(f[2].int())
		mode := unsafe { p.NumberMode(f[3].int()) }
		letter_case := unsafe { p.FormatCase(f[4].int()) }
		mut args := p.FormatOptions{
			precision: optional(f[5])
			width:     optional(f[6])
			alignment: unsafe { p.Alignment(f[7].int()) }
			fill:      u8(f[8].int())
		}
		seed := usize(f[9].u64())
		mut original := match form {
			0 {
				p.NumberFormat{}
			}
			1 {
				p.NumberFormat{
					mode:        mode
					letter_case: letter_case
				}
			}
			2 {
				p.NumberFormat{
					mode:        mode
					letter_case: letter_case
					precision:   args.precision
					width:       args.width
					alignment:   args.alignment
					fill:        args.fill
				}
			}
			3 {
				args.to_number(mode, letter_case)
			}
			4 {
				p.NumberFormat{
					precision: args.precision
					width:     args.width
				}
			}
			else {
				panic('invalid form')
			}
		}

		mut copy := original
		mut returned := original
		emit_number(mut out, original)
		emit_options(mut out, args)
		match operation {
			0 {}
			1 {
				copy = changed(copy, field, seed)
			}
			2 {
				original = changed(original, field, seed)
			}
			3 {
				args = changed_options(args, field, seed)
			}
			4 {
				copy = changed(copy, field, seed)
				returned = changed(copy, (field + 1) % 6, seed + 1)
			}
			5 {
				original = p.NumberFormat{}
			}
			6 {
				args = changed_options(args, field, seed)
				original = args.to_number(unsafe { p.NumberMode(seed % 5) },
					unsafe { p.FormatCase(seed % 2) })
			}
			else {
				panic('invalid operation')
			}
		}

		emit_number(mut out, original)
		emit_number(mut out, copy)
		emit_number(mut out, returned)
		emit_options(mut out, args)
		out.write_u8(`\n`)
	}
	print(out.str())
}
