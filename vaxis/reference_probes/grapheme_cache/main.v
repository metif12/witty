module main

import os
import strings
import vaxis as v

__global (
	observed      = &v.GraphemeCache(unsafe { nil })
	observed_path string
)

fn hash(bytes []u8) u64 {
	mut value := u64(14695981039346656037)
	for byte in bytes {
		value = (value ^ u64(byte)) * u64(1099511628211)
	}
	return value
}

fn view(cache &v.GraphemeCache, start int, length int) []u8 {
	return unsafe { (&cache.buf[0] + start).vbytes(length) }
}

fn observe_exit() {
	if observed_path != '' && observed != unsafe { nil } {
		value := hash(view(observed, 0, 8192))
		os.write_file(observed_path, '${u64(observed.idx).str()}|${value:x}\n') or {
			eprintln('OBSERVER ERROR: ${err}')
		}
	}
}

fn pattern(mut cache v.GraphemeCache, seed u8) {
	for i in 0 .. 8192 {
		cache.buf[i] = u8(i * 17 + int(seed))
	}
}

fn num(p []string, index int) usize {
	return usize(p[index].u64())
}

fn trap(name string, path string) {
	mut cache := v.GraphemeCache{}
	pattern(mut cache, 7)
	observed = &cache
	observed_path = path
	at_exit(observe_exit) or { panic('UNEXPECTED: observer registration failed') }
	external := []u8{len: 8193, init: 99}
	match name {
		'trap_overflow1' {
			cache.idx = ~usize(0)
			cache.put(external[..1])
		}
		'trap_overflow2' {
			cache.idx = ~usize(0) - 1
			cache.put(external[..2])
		}
		'trap_large' {
			cache.put(external)
		}
		'trap_large_reset' {
			cache.idx = 17
			cache.put(external)
		}
		'trap_same_end' {
			cache.idx = 8191
			cache.put(view(&cache, 8191, 1))
		}
		'trap_after' {
			cache.idx = 1
			cache.put(view(&cache, 0, 3))
		}
		'trap_before' {
			cache.put(view(&cache, 1, 3))
		}
		'trap_reset' {
			cache.idx = 8191
			cache.put(view(&cache, 0, 2))
		}
		'trap_full' {
			cache.put(view(&cache, 0, 8192))
		}
		'trap_same' {
			cache.put(view(&cache, 0, 1))
		}
		else {
			panic('UNEXPECTED: unknown trap')
		}
	}

	println('UNEXPECTED: operation returned')
}

fn main() {
	if os.args[1].starts_with('trap_') {
		trap(os.args[1], os.args[2])
		return
	}
	input := os.read_file(os.args[1]) or { panic('UNEXPECTED: ${err}') }
	mut out := strings.new_builder(4 * 1024 * 1024)
	for line in input.split_into_lines() {
		if line == '' { continue
		 }
		p := line.split('|')
		mut cache := v.GraphemeCache{}
		seed := u8(num(p, 3))
		pattern(mut cache, seed)
		cache.idx = num(p, 1)
		length := int(num(p, 2))
		start := cache.idx
		match p[0] {
			'E', 'A' {
				mut external := []u8{len: 8192}
				for i in 0 .. external.len {
					external[i] = u8(i * 31 + int(seed))
				}
				source := if p[0] == 'A' {
					view(&cache, int(num(p, 4)), length)
				} else {
					unsafe { external[..length] }
				}
				result := cache.put(source)
				offset := usize(result.data) - usize(&cache.buf[0])
				h := hash(result)
				buf_hash := hash(view(&cache, 0, 8192))
				out.write_string('${p[0]}|${u64(start).str()},${u64(cache.idx).str()},${u64(offset).str()}|${h:x}|${buf_hash:x}\n')
			}
			'B' {
				old := cache.put('abc'.bytes())
				old_offset := usize(old.data) - usize(&cache.buf[0])
				unsafe {
					old[1] = `Q`
				}
				first_hash := hash(old)
				cache.idx = 8192
				wrapped := cache.put('Z'.bytes())
				wrapped_offset := usize(wrapped.data) - usize(&cache.buf[0])
				h := hash(old)
				buf_hash := hash(view(&cache, 0, 8192))
				out.write_string('B|${u64(old_offset).str()},${u64(cache.idx).str()},${u64(wrapped_offset).str()}|${first_hash:x}|${h:x}|${buf_hash:x}\n')
			}
			'C' {
				mut copied := cache
				result := copied.put('xy'.bytes())
				cache.buf[0] = 42
				offset := usize(result.data) - usize(&copied.buf[0])
				h := hash(result)
				old_hash := hash(view(&cache, 0, 8192))
				copy_hash := hash(view(&copied, 0, 8192))
				out.write_string('C|${u64(cache.idx).str()},${u64(copied.idx).str()},${u64(offset).str()}|${h:x}|${old_hash:x}|${copy_hash:x}\n')
			}
			else {
				panic('UNEXPECTED: unknown kind')
			}
		}
	}
	print(out.str())
}
