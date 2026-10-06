module main

import os
import strconv
import strings
import vaxis as v

__global (
	observed      = v.CellScale{}
	observed_path string
)

fn observe_exit() {
	if observed_path != '' {
		os.write_file(observed_path, snapshot(observed)) or { eprintln('OBSERVER ERROR: ${err}') }
	}
}

fn snapshot(value v.CellScale) string {
	return '${value.bits()},${value.scale()},${value.numerator()},${value.denominator()},${u8(value.vertical_alignment())},${u8(value.eql(v.CellScale{}))}'
}

fn number(p []string, i int) u64 {
	return strconv.parse_uint(p[i], 10, 64) or { panic(err) }
}

fn raw_alignment(value u64) v.VerticalAlignment {
	return v.CellScale.from_bits(value << 11).vertical_alignment()
}

fn record(p []string, id int) string {
	mut out := strings.new_builder(256)
	out.write_string('${id}|')
	if p[0] == 'D' {
		out.write_string(snapshot(v.CellScale{}))
	} else if p[0] == 'A' {
		out.write_string('${u8(v.VerticalAlignment.from_int(number(p, 1)))}')
	} else if p[0] == 'C' {
		value := v.CellScale.init(number(p, 1), number(p, 2), number(p, 3),
			raw_alignment(number(p, 4)))
		out.write_string(snapshot(value))
	} else if p[0] == 'R' {
		value := v.CellScale.from_bits(number(p, 1))
		copied := value
		out.write_string('${snapshot(value)}|${u8(value.eql(copied))}')
	} else {
		mut value := v.CellScale.from_bits(number(p, 1))
		original := value
		value.set_scale(number(p, 2))
		out.write_string(snapshot(value) + '|')
		value.set_numerator(number(p, 3))
		out.write_string(snapshot(value) + '|')
		value.set_denominator(number(p, 4))
		out.write_string(snapshot(value) + '|')
		value.set_vertical_alignment(raw_alignment(number(p, 5)))
		out.write_string(snapshot(value) + '|')
		mut cell := v.Cell{
			scale: value
		}
		copied_cell := cell
		cell.scale.set_scale(original.scale())
		cell.scale.set_numerator(original.numerator())
		cell.scale.set_denominator(original.denominator())
		cell.scale.set_vertical_alignment(original.vertical_alignment())
		out.write_string('${snapshot(cell.scale)}|${u8(copied_cell.scale.eql(value))},${u8(cell.scale.eql(original))}')
	}
	out.write_u8(`\n`)
	return out.str()
}

fn trap(name string, path string) {
	observed = v.CellScale.init(5, 11, 13, .bottom)
	observed_path = path
	at_exit(observe_exit) or { panic(err) }
	raw := strconv.parse_uint(name.all_after_last('_'), 10, 64) or { panic(err) }
	if name.starts_with('set_scale') {
		observed.set_scale(raw)
	} else if name.starts_with('set_numerator') {
		observed.set_numerator(raw)
	} else if name.starts_with('set_denominator') {
		observed.set_denominator(raw)
	} else if name.starts_with('set_alignment') {
		observed.set_vertical_alignment(unsafe { v.VerticalAlignment(raw) })
	} else if name.starts_with('init_scale') {
		observed = v.CellScale.init(raw, 1, 1, .top)
	} else if name.starts_with('init_numerator') {
		observed = v.CellScale.init(1, raw, 1, .top)
	} else if name.starts_with('init_denominator') {
		observed = v.CellScale.init(1, 1, raw, .top)
	} else if name.starts_with('init_alignment') {
		observed = v.CellScale.init(1, 1, 1, unsafe { v.VerticalAlignment(raw) })
	} else if name.starts_with('enum') {
		observed.set_vertical_alignment(v.VerticalAlignment.from_int(raw))
	} else {
		observed = v.CellScale.from_bits(raw)
	}
	panic('UNEXPECTED returning trap')
}

fn main() {
	if os.args.len > 2 && os.args[1] == '--trap' {
		trap(os.args[2], os.args[3])
		return
	}
	input := os.read_file(os.args[1]) or { panic(err) }
	mut id := 0
	for line in input.split_into_lines() {
		if line == '' {
			continue
		}
		print(record(line.split('|'), id))
		id++
	}
}
