module main

import os
import strings
import zigimg as p

type AliasU32 = u32
type AliasF32 = f32

fn scalar[T](_ T, raw u64) T {
	$if T.unaliased_typ is f32 {
		bits := u32(raw)
		return T(unsafe { *(&f32(&bits)) })
	} $else $if T.unaliased_typ is f64 {
		return T(unsafe { *(&f64(&raw)) })
	} $else {
		return T(raw)
	}
}

fn record[T](mut output strings.Builder, value T) {
	$for field in T.fields {
		v := value.$(field.name)
		$if field.typ is f32 || field.typ is AliasF32 {
			raw := unsafe { *(&u32(&v)) }
			output.write_string('${raw},')
		} $else $if field.typ is f64 {
			raw := unsafe { *(&u64(&v)) }
			output.write_string('${raw},')
		} $else {
			output.write_string('${u64(v)},')
		}
	}
}

fn changed[T](value T, field_index int, raw u64) T {
	mut result := value
	mut index := 0
	$for field in T.fields {
		if index == field_index { result.$(field.name) = scalar(result.$(field.name), raw) }
		index++
	}
	return result
}

fn observe_plain[T](mut output strings.Builder, value p.Grayscale[T]) {
	record(mut output, value)
	record(mut output, p.Grayscale.to_colorf32(value))
}

fn run_plain[T](mut output strings.Builder, value p.Grayscale[T], args []u64) {
	mut original := value
	$for field in p.Grayscale[T].fields {
		if field.name == 'alpha' && args[0] == 1 {
			original.$(field.name) = scalar(original.$(field.name), args[4])
		}
	}
	mut copy := original
	mut returned := original
	match args[1] {
		0 {}
		1 {
			copy = changed(copy, int(args[2]), args[5])
		}
		2 {
			original = changed(original, int(args[2]), args[5])
		}
		3 {
			copy = changed(copy, int(args[2]), args[5])
			returned = changed(copy, int(args[2]), args[3])
			copy = original
		}
		else {
			panic('invalid operation')
		}
	}

	observe_plain(mut output, original)
	observe_plain(mut output, copy)
	observe_plain(mut output, returned)
}

fn observe_alpha[T](mut output strings.Builder, value p.GrayscaleAlpha[T]) {
	record(mut output, value)
	record(mut output, p.GrayscaleAlpha.to_colorf32(value))
}

fn run_alpha[T](mut output strings.Builder, value p.GrayscaleAlpha[T], args []u64) {
	mut original := value
	$for field in p.GrayscaleAlpha[T].fields {
		if field.name == 'alpha' && args[0] == 1 {
			original.$(field.name) = scalar(original.$(field.name), args[4])
		}
	}
	mut copy := original
	mut returned := original
	match args[1] {
		0 {}
		1 {
			copy = changed(copy, int(args[2]), args[5])
		}
		2 {
			original = changed(original, int(args[2]), args[5])
		}
		3 {
			copy = changed(copy, int(args[2]), args[5])
			returned = changed(copy, int(args[2]), args[3])
			copy = original
		}
		else {
			panic('invalid operation')
		}
	}

	observe_alpha(mut output, original)
	observe_alpha(mut output, copy)
	observe_alpha(mut output, returned)
}

fn main() {
	if os.args[1] == 'omitted' {
		mut output := strings.new_builder(1024)
		{
			value := p.GrayscaleAlpha[u8]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[u16]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[u32]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[u64]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[usize]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[f32]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[f64]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[AliasU32]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		{
			value := p.GrayscaleAlpha[AliasF32]{
				value: 0
			}
			observe_alpha(mut output, value)
			output.write_string('\n')
		}
		print(output.str())
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		kind := fields[0].int()
		alpha := fields[1].int()
		args := fields[2..].map(it.u64())
		match kind {
			0 {
				value := scalar(u8(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[u8]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			1 {
				value := scalar(u16(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[u16]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			2 {
				value := scalar(u32(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[u32]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			3 {
				value := scalar(u64(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[u64]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			4 {
				value := scalar(usize(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[usize]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			5 {
				value := scalar(f32(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[f32]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			6 {
				value := scalar(f64(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[f64]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			7 {
				value := scalar(AliasU32(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[AliasU32]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			8 {
				value := scalar(AliasF32(0), args[3])
				if alpha == 0 {
					input := p.Grayscale[AliasF32]{
						value: value
					}
					run_plain(mut output, input, args)
				} else {
					input := p.GrayscaleAlpha.init(value)
					run_alpha(mut output, input, args)
				}
			}
			else {
				panic('invalid kind')
			}
		}

		output.write_string('\n')
	}
	print(output.str())
}
