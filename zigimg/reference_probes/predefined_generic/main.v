module main

import os
import strings
import zigimg as p

fn choose[T](colors p.Colors[T], index int) T {
	return match index {
		0 { colors.red }
		1 { colors.green }
		2 { colors.blue }
		3 { colors.white }
		4 { colors.black }
		5 { colors.cyan }
		6 { colors.magenta }
		7 { colors.yellow }
		else { panic('invalid color') }
	}
}

fn record[T](mut out strings.Builder, value T) {
	$for field in T.fields {
		v := value.$(field.name)
		$if field.typ is f32 {
			out.write_string('${raw(v)},')
		} $else $if field.typ is [4]u32 {
			for element in v {
				out.write_string('${element},')
			}
		} $else {
			out.write_string('${v},')
		}
	}
	out.write_string('|')
}

fn changed[T](value T, replacement T) T {
	$if T.unaliased_typ is Snapshot {
		mut result := value
		result.channel_bits[0] = replacement.channel_bits[0]
		return result
	} $else {
		return replacement
	}
}

fn run[T](mut out strings.Builder, index int, replacement int, operation int) {
	colors := p.predefined_colors[T]()
	mut original := choose(colors, index)
	mut copy := original
	mut returned := original
	other := choose(colors, replacement)
	match operation {
		0 {}
		1 {
			copy = changed(copy, other)
		}
		2 {
			original = changed(original, other)
		}
		3 {
			copy = changed(copy, other)
			returned = changed(copy, original)
			copy = original
		}
		else {
			panic('invalid operation')
		}
	}

	record(mut out, original)
	record(mut out, copy)
	record(mut out, returned)
	record(mut out, choose(colors, index))
}

fn main() {
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut out := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		index := fields[1].int()
		replacement := fields[2].int()
		operation := fields[3].int()
		match fields[0].int() {
			0 { run[p.Rgb24](mut out, index, replacement, operation) }
			1 { run[p.Rgba32](mut out, index, replacement, operation) }
			2 { run[p.Bgr24](mut out, index, replacement, operation) }
			3 { run[p.Bgra32](mut out, index, replacement, operation) }
			4 { run[p.Rgb48](mut out, index, replacement, operation) }
			5 { run[p.Rgba64](mut out, index, replacement, operation) }
			6 { run[p.Colorf32](mut out, index, replacement, operation) }
			7 { run[p.Rgb332](mut out, index, replacement, operation) }
			8 { run[p.Rgb555](mut out, index, replacement, operation) }
			9 { run[p.Bgr555](mut out, index, replacement, operation) }
			10 { run[p.Rgb565](mut out, index, replacement, operation) }
			11 { run[Encoded](mut out, index, replacement, operation) }
			12 { run[Swizzled](mut out, index, replacement, operation) }
			13 { run[Snapshot](mut out, index, replacement, operation) }
			14 { run[Marked](mut out, index, replacement, operation) }
			15 { run[RgbAlias](mut out, index, replacement, operation) }
			16 { run[FloatAlias](mut out, index, replacement, operation) }
			else { panic('invalid kind') }
		}

		out.write_string('\n')
	}
	print(out.str())
}
