module main

import os
import encoding.hex
import zigimg as p

__global (
	observed_path   string
	observed_reader = &p.ReadStream(unsafe { nil })
	observed_writer = &p.WriteStream(unsafe { nil })
	observed_rb     = &p.BitReader[p.BigEndian](unsafe { nil })
	observed_rl     = &p.BitReader[p.LittleEndian](unsafe { nil })
	observed_rab    = &p.BitReader[AliasBig](unsafe { nil })
	observed_ral    = &p.BitReader[AliasLittle](unsafe { nil })
	observed_wb     = &p.BitWriter[p.BigEndian](unsafe { nil })
	observed_wl     = &p.BitWriter[p.LittleEndian](unsafe { nil })
	observed_wab    = &p.BitWriter[AliasBig](unsafe { nil })
	observed_wal    = &p.BitWriter[AliasLittle](unsafe { nil })
	observed_input  []u8
	observed_output []u8
	observed_index  int
	observed_count  u16
)
type AliasBig = p.BigEndian
type AliasLittle = p.LittleEndian
type Alias0 = u8
type Alias1 = u16
type Alias2 = u32
type Alias3 = u64
type Alias4 = i8
type Alias5 = i16
type Alias6 = int
type Alias7 = i64
type Alias8 = usize
type Alias9 = isize
type Alias10 = f32
type Alias11 = f64
type AliasBool = bool
type AliasRgb332 = p.Rgb332
type AliasRgb555 = p.Rgb555
type AliasRgb565 = p.Rgb565
type AliasBgr555 = p.Bgr555

fn value_from_bits[T](value u64) T {
	$if T.unaliased_typ is p.Rgb332 {
		return T(p.Rgb332{
			raw: u8(value)
		})
	} $else $if T.unaliased_typ is p.Rgb555 {
		return T(p.Rgb555{
			raw: u16(value)
		})
	} $else $if T.unaliased_typ is p.Rgb565 {
		return T(p.Rgb565{
			raw: u16(value)
		})
	} $else $if T.unaliased_typ is p.Bgr555 {
		return T(p.Bgr555{
			raw: u16(value)
		})
	} $else $if T.unaliased_typ is bool {
		return T(value & 1 != 0)
	} $else $if T.unaliased_typ is f32 {
		word := u32(value)
		return T(unsafe { *(&f32(&word)) })
	} $else $if T.unaliased_typ is f64 {
		return T(unsafe { *(&f64(&value)) })
	} $else {
		return T(value)
	}
}

fn value_bits[T](value T) u64 {
	$if T.unaliased_typ is p.Rgb332 || T.unaliased_typ is p.Rgb565 {
		return u64(value.raw)
	} $else $if T.unaliased_typ is p.Rgb555 || T.unaliased_typ is p.Bgr555 {
		return u64(value.raw & 0x7fff)
	} $else $if T.unaliased_typ is bool {
		return if value { u64(1) } else { u64(0) }
	} $else $if T.unaliased_typ is f32 {
		return unsafe { *(&u32(&value)) }
	} $else $if T.unaliased_typ is f64 {
		return unsafe { *(&u64(&value)) }
	} $else {
		mut result := u64(value)
		if sizeof(T) < 8 { result &= (u64(1) << (sizeof(T) * 8)) - 1 }
		return result
	}
}

fn state() string {
	mut bits := u8(0)
	mut count := u8(0)
	if observed_rb != unsafe { nil } {
		bits = observed_rb.bits
		count = observed_rb.count
	}
	if observed_rl != unsafe { nil } {
		bits = observed_rl.bits
		count = observed_rl.count
	}
	if observed_rab != unsafe { nil } {
		bits = observed_rab.bits
		count = observed_rab.count
	}
	if observed_ral != unsafe { nil } {
		bits = observed_ral.bits
		count = observed_ral.count
	}
	if observed_wb != unsafe { nil } {
		bits = observed_wb.bits
		count = observed_wb.count
	}
	if observed_wl != unsafe { nil } {
		bits = observed_wl.bits
		count = observed_wl.count
	}
	if observed_wab != unsafe { nil } {
		bits = observed_wab.bits
		count = observed_wab.count
	}
	if observed_wal != unsafe { nil } {
		bits = observed_wal.bits
		count = observed_wal.count
	}

	return '${observed_index}|${observed_reader.get_pos()}|${observed_writer.get_pos()}|${bits}:${count}|${observed_count}|${observed_input.hex()}|${observed_output.hex()}'
}

fn observe() {
	if observed_path != '' { os.write_file(observed_path, state()) or {
			eprintln('OBSERVER ERROR: ${err}')} }
}

fn read_action[E, T](mut bits p.BitReader[E], action string) !string {
	if action == 'a' {
		bits.align_to_byte()
		return 'ok'
	}
	if action[0] == `s` {
		bits.reader.seek_to(action[1..].u64())!
		return 'ok'
	}
	num := action[1..].u16()
	if action[0] == `t` {
		value, count := bits.read_bits_tuple[E, T](num)!
		return 'ok:${value_bits(value)}:${count}'
	}
	if action[0] == `r` {
		value := bits.read_bits[E, T](num, &observed_count)!
		return 'ok:${value_bits(value)}:${observed_count}'
	}
	if action[0] == `c` {
		mut copied := bits
		value, count := copied.read_bits_tuple[E, T](num)!
		return 'copy:${value_bits(value)}:${count}:${copied.bits}:${copied.count}'
	}
	value := bits.read_bits_no_eof[E, T](num)!
	return 'ok:${value_bits(value)}'
}

fn write_action[E, T](mut bits p.BitWriter[E], action string) !string {
	if action == 'f' {
		bits.flush_bits()!
		return 'ok'
	}
	if action[0] == `s` {
		bits.writer.seek_to(action[1..].u64())!
		return 'ok'
	}
	f := action[1..].split(':')
	if action[0] == `c` {
		mut copied := bits
		copied.write_bits[E, T](value_from_bits[T](f[1].u64()), f[0].u16())!
		return 'copy:${copied.bits}:${copied.count}'
	}
	bits.write_bits[E, T](value_from_bits[T](f[1].u64()), f[0].u16())!
	return 'ok'
}

fn run[E, T](f []string) {
	mut input := hex.decode(f[6]) or { panic(err) }
	mut output := []u8{len: f[5].int(), init: 0xa5}
	mut reader := p.ReadStream.init_memory(input)
	mut writer := p.WriteStream.init_memory(mut output)
	observed_reader = &reader
	observed_writer = &writer
	observed_input = unsafe { input[..] }
	observed_output = unsafe { output[..] }
	mut results := []string{}
	if f[2] == '0' {
		if f[7].u64() > 0 { reader.seek_to(f[7].u64()) or { panic(err) } }
		mut bits := p.BitReader[E]{
			reader: &reader
			bits:   f[3].u8()
			count:  f[4].u8()
		}
		$if E is p.BigEndian {
			observed_rb = &bits
		} $else $if E is p.LittleEndian {
			observed_rl = &bits
		} $else $if E is AliasBig {
			observed_rab = &bits
		} $else $if E is AliasLittle {
			observed_ral = &bits
		}

		for index, action in f[8].split(',') {
			observed_index = index
			observed_count = 777
			if action == 'm' {
				if input.len > 0 { input[0] ^= 85 }
				results << 'ok|' + state()
				continue
			}
			status := read_action[E, T](mut bits, action) or { err.msg() }
			results << status + '|' + state()
		}
	} else {
		if f[7].u64() > 0 { writer.seek_to(f[7].u64()) or { panic(err) } }
		mut bits := p.BitWriter[E]{
			writer: &writer
			bits:   f[3].u8()
			count:  f[4].u8()
		}
		$if E is p.BigEndian {
			observed_wb = &bits
		} $else $if E is p.LittleEndian {
			observed_wl = &bits
		} $else $if E is AliasBig {
			observed_wab = &bits
		} $else $if E is AliasLittle {
			observed_wal = &bits
		}

		for index, action in f[8].split(',') {
			observed_index = index
			observed_count = 777
			status := write_action[E, T](mut bits, action) or { err.msg() }
			results << status + '|' + state()
		}
	}
	println(results.join('~'))
}

fn dispatch[E](f []string) {
	match f[1].int() {
		0 { run[E, u8](f) }
		1 { run[E, u16](f) }
		2 { run[E, u32](f) }
		3 { run[E, u64](f) }
		4 { run[E, i8](f) }
		5 { run[E, i16](f) }
		6 { run[E, int](f) }
		7 { run[E, i64](f) }
		8 { run[E, usize](f) }
		9 { run[E, isize](f) }
		10 { run[E, f32](f) }
		11 { run[E, f64](f) }
		12 { run[E, Alias0](f) }
		13 { run[E, Alias1](f) }
		14 { run[E, Alias2](f) }
		15 { run[E, Alias3](f) }
		16 { run[E, Alias4](f) }
		17 { run[E, Alias5](f) }
		18 { run[E, Alias6](f) }
		19 { run[E, Alias7](f) }
		20 { run[E, Alias8](f) }
		21 { run[E, Alias9](f) }
		22 { run[E, Alias10](f) }
		23 { run[E, Alias11](f) }
		24 { run[E, bool](f) }
		25 { run[E, AliasBool](f) }
		26 { run[E, p.Rgb332](f) }
		27 { run[E, p.Rgb555](f) }
		28 { run[E, p.Rgb565](f) }
		29 { run[E, p.Bgr555](f) }
		30 { run[E, AliasRgb332](f) }
		31 { run[E, AliasRgb555](f) }
		32 { run[E, AliasRgb565](f) }
		33 { run[E, AliasBgr555](f) }
		else { panic('invalid type') }
	}
}

fn line_case(line string) {
	observed_index = 0
	observed_count = 777
	observed_rb = unsafe { nil }
	observed_rl = unsafe { nil }
	observed_rab = unsafe { nil }
	observed_ral = unsafe { nil }
	observed_wb = unsafe { nil }
	observed_wl = unsafe { nil }
	observed_wab = unsafe { nil }
	observed_wal = unsafe { nil }

	f := line.split('|')
	match f[0].int() {
		0 { dispatch[p.LittleEndian](f) }
		1 { dispatch[p.BigEndian](f) }
		2 { dispatch[AliasLittle](f) }
		3 { dispatch[AliasBig](f) }
		else { panic('invalid endian') }
	}
}

fn main() {
	if os.args[1] == '--corpus' {
		for line in os.read_lines(os.args[2]) or { panic(err) } {
			line_case(line)
		}
	} else {
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		line_case(os.args[3])
	}
}
