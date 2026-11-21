module main

import os
import strconv
import zigimg as p

__global (
	parser        = p.FormatParser{
		bytes: []u8{}
		i:     0
	}
	args_state    = p.FormatArgState{
		args_len: 0
	}
	carrier       []u8
	observed_path string
	result_kind   string
	result_value  ?uint
	result_span   []u8
	step          int
)
fn state() string {
	mut result := result_kind
	if result_kind in ['c', 'n', 'a', 'number', 'h', 'b'] {
		result += ':' + if n := result_value { n.str() } else { '-' }
	} else if result_kind in ['u', 'named'] {
		result += ':${uint(result_span.data) - uint(carrier.data)}:${result_span.len}:' +
			result_span.hex()
	}
	return '${step}|${parser.i}:${args_state.next_arg}:${args_state.used_args}:${args_state.args_len}|${carrier.hex()}|${result}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or { eprintln(err) } }
}

fn number(text string) ?uint {
	return if text == '-' { none } else { uint(text.u64()) }
}

fn run(line string) string {
	f := line.split('|')
	carrier = []u8{}
	for i := 0; i < f[0].len; i += 2 {
		carrier << u8(strconv.parse_uint(f[0][i..i + 2], 16, 8) or { panic(err) })
	}
	parser = p.FormatParser{
		bytes: unsafe { carrier }
		i:     uint(f[1].u64())
	}
	args_state = p.FormatArgState{
		next_arg:  uint(f[2].u64())
		used_args: u32(f[3].u64())
		args_len:  uint(f[4].u64())
	}
	result_kind = '-'
	result_value = none
	result_span = []u8{}
	step = -1
	mut out := state()
	for i, action in f[5].split(',') {
		step = i
		a := action.split(':')
		mut status := 'ok'
		match a[0] {
			'p' {
				n := parser.peek(uint(a[1].u64()))
				result_kind = 'c'
				result_value = if v := n { uint(v) } else { none }
			}
			'c' {
				n := parser.char()
				result_kind = 'c'
				result_value = if v := n { uint(v) } else { none }
			}
			'm' {
				n := parser.maybe(u8(a[1].int()))
				result_kind = 'b'
				result_value = uint(int(n))
			}
			'n' {
				result_value = parser.number()
				result_kind = 'n'
			}
			'u' {
				result_span = unsafe { parser.until(u8(a[1].int())) }
				result_kind = 'u'
			}
			's' {
				spec := parser.specifier() or {
					status = err.msg()
					p.FormatSpecifier(p.FormatNone{})
				}
				if status == 'ok' {
					match spec {
						p.FormatNone {
							result_kind = 'none'
						}
						p.FormatNumber {
							result_kind = 'number'
							result_value = spec.value
						}
						p.FormatNamed {
							result_kind = 'named'
							result_span = unsafe { spec.bytes }
						}
					}
				}
			}
			'a' {
				result_value = args_state.next_arg(number(a[1]))
				result_kind = 'a'
			}
			'h' {
				result_kind = 'h'
				result_value = uint(int(args_state.has_unused_args()))
			}
			'x' {
				carrier[a[1].int()] ^= u8(a[2].int())
			}
			'w' {
				result_span[a[1].int()] ^= u8(a[2].int())
			}
			else {
				panic('invalid action')
			}
		}

		out += '~' + status + '|' + state()
	}
	return out
}

fn main() {
	if os.args[1] == '--trap' {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		result := run(os.args[3])
		observed_path = ''
		println(result)
		return
	}
	for line in os.read_lines(os.args[1]) or { panic(err) } {
		println(run(line))
	}
}
