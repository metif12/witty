module main

import os
import zigimg
import encoding.hex

__global (
	observed_path    string
	observed_status  string
	observed_scalar  string
	observed_buffer  []u8
	observed_payload []u8
	observed_vectors [][]u8
)

fn state() string {
	mut headers := []string{}
	for bytes in observed_vectors {
		headers << '${usize(bytes.data) - usize(observed_payload.data)},${bytes.len}'
	}
	return observed_scalar + '|' + observed_buffer.hex() + '|' + observed_payload.hex() + '#' +
		headers.join(';')
}

fn observe() {
	if observed_path == '' { return }
	retained := observed_status + '|' + state()
	os.write_file(observed_path, retained) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn vectors(mut payload []u8, profile int) [][]u8 {
	mut out := [][]u8{}
	match profile {
		0 {}
		1 {
			out << unsafe { payload[0..0] }
		}
		2 {
			out << unsafe { payload[..3] }
			out << unsafe { payload[6..6] }
			out << unsafe { payload[1..8] }
		}
		3 {
			out << unsafe { payload[..255] }
			out << unsafe { payload[32..64] }
			out << unsafe { payload[255..256] }
		}
		4 {
			for _ in 0 .. 33 {
				out << unsafe { payload[..1] }
			}
		}
		else {
			panic('Invalid vector profile')
		}
	}

	return out
}

fn view(bytes []u8, buffer []u8) string {
	offset := if buffer.len == 0 { usize(0) } else { usize(bytes.data) - usize(buffer.data) }
	return '${bytes.len}:${offset}:${bytes.hex()}'
}

fn views(prefix []u8, constant []u8, one []u8, buffer []u8, has_one bool) string {
	return view(prefix, buffer) + ';' + view(constant, buffer) + ';' + if has_one {
		view(one, buffer)
	} else {
		'-'
	}
}

// limit|other-limit|u64-count|length|profile|mask|force-slice1
fn record(line string) string {
	f := line.split('|')
	a, b, n := usize(f[0].u64()), usize(f[1].u64()), f[2].u64()
	limit := zigimg.Limit.limited(a)
	mut buffer := []u8{len: f[3].int(), init: u8(index * 17 + 165)}
	mut payload := []u8{len: 256, init: u8(index * 23 + f[5].int())}
	data := vectors(mut payload, f[4].int())
	to_int := if value := limit.to_int() { value.str() } else { 'none' }
	subtract := if value := limit.subtract(b) { value.value.str() } else { 'none' }
	observed_scalar = '${a}|${b}|${n}|${zigimg.Limit.limited64(n).value}|${limit.min(zigimg.Limit.limited(b)).value}|${limit.min_int(b)}|${limit.min_int64(n)}|${zigimg.Limit.count_vec(data).value}|${to_int}|${subtract}|${limit.nonzero()}|${zigimg.Limit.nothing().value}|${zigimg.Limit.unlimited().value}'
	observed_buffer = unsafe { buffer }
	observed_payload = unsafe { payload }
	observed_vectors = unsafe { data }
	mut out := 'setup|' + state() + '~'
	mut prefix := limit.slice(mut buffer)
	constant := limit.slice_const(buffer)
	has_one := buffer.len > 0 || f[6] == '1'
	observed_status = 'slice1'
	mut one := if has_one { limit.slice1(mut buffer) } else { []u8{} }
	out += 'views|' + views(prefix, constant, one, buffer, has_one) + '|' + state() + '~'
	if buffer.len > 0 { buffer[0] ^= u8(f[5].int()) }
	out += 'caller|' + views(prefix, constant, one, buffer, has_one) + '|' + state() + '~'
	if prefix.len > 0 { prefix[prefix.len - 1] ^= 0x33 }
	if one.len > 0 { one[one.len - 1] ^= 0x55 }
	return out + 'borrow|' + views(prefix, constant, one, buffer, has_one) + '|' + state()
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := record(os.args[3])
		observed_path = ''
		println(result)
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(record(line))
	}
}
