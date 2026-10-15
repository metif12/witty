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
		'${observed_view.len}:${usize(observed_view.data) - usize(observed_buffer.data)}:${observed_view.hex()}'
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

type Alias0 = f32
type Alias1 = f64

fn converted[T](raw u64) p.FloatDecimal64 {
	mut value := T(0)
	$if T.unaliased_typ is f32 {
		word := u32(raw)
		value = T(unsafe { *(&f32(&word)) })
	} $else {
		value = T(unsafe { *(&f64(&raw)) })
	}
	return p.float_to_decimal[T](value)
}

fn rendered[T](mut buffer []u8, raw u64, options p.FloatRenderOptions) ![]u8 {
	mut value := T(0)
	$if T.unaliased_typ is f32 {
		word := u32(raw)
		value = T(unsafe { *(&f32(&word)) })
	} $else {
		value = T(unsafe { *(&f64(&raw)) })
	}
	return p.render_float[T](mut buffer, value, options)
}

// mode|capacity|offset|extent|rawbits|type|precision|mask
fn record(line string) string {
	f := line.split('|')
	api, cap, offset, extent := f[0].int(), f[1].int(), f[2].int(), f[3].int()
	mut bytes := []u8{len: cap, init: u8(index * 17 + 165)}
	mut buffer := unsafe { bytes[offset..offset + extent] }
	raw := f[4].u64()
	tag := f[5].int()
	value := match tag {
		0 { converted[f32](raw) }
		1 { converted[f64](raw) }
		2 { converted[Alias0](raw) }
		3 { converted[Alias1](raw) }
		else { panic('Invalid float type') }
	}

	precision := if f[6] == '-' { ?usize(none) } else { ?usize(usize(f[6].u64())) }
	options := p.FloatRenderOptions{
		mode:      unsafe { p.FloatRenderMode(api) }
		precision: precision
	}

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
	result = match tag {
		0 {
			rendered[f32](mut buffer, raw, options) or {
				status = err.msg()
				[]u8{}
			}
		}
		1 {
			rendered[f64](mut buffer, raw, options) or {
				status = err.msg()
				[]u8{}
			}
		}
		2 {
			rendered[Alias0](mut buffer, raw, options) or {
				status = err.msg()
				[]u8{}
			}
		}
		3 {
			rendered[Alias1](mut buffer, raw, options) or {
				status = err.msg()
				[]u8{}
			}
		}
		else {
			panic('Invalid float type')
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
		}] ^= u8(f[7].int())
	}
	out += 'caller|' + state() + '~'
	observed_value.mantissa ^= u64(f[7].u64())
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
