module main

import os
import zigimg as p

__global (
	observed_path     string
	observed_status   string
	observed_buffer   []u8
	observed_view     []u8
	observed_has_view bool
	observed_config   string
	observed_value    p.FloatDecimal64
	observed_copy     p.FloatDecimal64
)

fn scalar(value p.FloatDecimal64) string {
	return '${value.mantissa},${value.exponent},${int(value.sign)}'
}

fn state() string {
	view := if observed_has_view {
		'${observed_view.len}:${uint(observed_view.data) - uint(observed_buffer.data)}:${observed_view.hex()}'
	} else {
		'-'
	}
	return observed_config + '|' + observed_buffer.hex() + '|' + view + '|' +
		scalar(observed_value) + ';' + scalar(observed_copy)
}

fn observe() {
	if observed_path != '' {
		os.write_file(observed_path, observed_status + '|' + state()) or {
			eprintln('OBSERVER ERROR: ${err}')
		}
	}
}

// api|capacity|offset|extent|mantissa|exponent|sign|precision|mask
fn record(line string) string {
	f := line.split('|')
	api, cap, offset, extent := f[0].int(), f[1].int(), f[2].int(), f[3].int()
	mut bytes := []u8{len: cap, init: u8(index * 17 + 165)}
	mut buffer := unsafe { bytes[offset..offset + extent] }
	value := p.FloatDecimal64{
		mantissa: f[4].u64()
		exponent: f[5].int()
		sign:     f[6] == '1'
	}
	precision := if f[7] == '-' { ?uint(none) } else { ?uint(uint(f[7].u64())) }
	observed_config = line.replace('|', ',')
	observed_value = value
	observed_copy = value
	observed_buffer = unsafe { bytes }
	observed_view = []u8{}
	observed_has_view = false
	mut out := 'ready|' + state() + '~'
	observed_status = 'format'
	mut status := 'ok'
	mut result := []u8{}
	if api == 0 {
		result = p.format_float_scientific(mut buffer, value, precision) or {
			status = err.msg()
			[]u8{}
		}
	} else {
		result = p.format_float_decimal(mut buffer, value, precision) or {
			status = err.msg()
			[]u8{}
		}
	}
	if status == 'ok' {
		observed_view = unsafe { result }
		observed_has_view = true
	}
	out += status + '|' + state() + '~'
	if cap > 0 {
		bytes[if offset < cap {
			offset
		} else {
			cap - 1
		}] ^= u8(f[8].int())
	}
	out += 'caller|' + state() + '~'
	observed_value.mantissa ^= u64(f[8].u64())
	out += 'argument|' + state()
	return out
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		out := record(os.args[3])
		observed_path = ''
		println(out)
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line))
	}
}
