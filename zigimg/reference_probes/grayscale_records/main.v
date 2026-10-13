module main

import os
import strings
import zigimg as p

fn scalar[T](_ T, raw u32) T {
	$if T is f32 {
		return unsafe { *(&f32(&raw)) }
	} $else {
		return T(raw)
	}
}

fn record[T](mut output strings.Builder, value T) {
	$for field in T.fields {
		v := value.$(field.name)
		$if field.typ is f32 {
			raw := unsafe { *(&u32(&v)) }
			output.write_string('${raw},')
		} $else {
			output.write_string('${u32(v)},')
		}
	}
}

fn changed[T](value T, field_index int, raw u32) T {
	mut result := value
	mut index := 0
	$for field in T.fields {
		if index == field_index { result.$(field.name) = scalar(result.$(field.name), raw) }
		index++
	}
	return result
}

fn observe[T](mut output strings.Builder, value T) {
	record(mut output, value)
	record(mut output, value.to_colorf32())
}

fn run[T](mut output strings.Builder, value T, args []u32) {
	mut original := value
	$for field in T.fields {
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

	observe(mut output, original)
	observe(mut output, copy)
	observe(mut output, returned)
}

fn main() {
	if os.args[1] == 'trap' {
		kind := os.args[2].int()
		raw := u8(os.args[3].int())
		result := match kind {
			0 {
				p.Grayscale1{
					value: raw
				}.to_colorf32()
			}
			1 {
				p.Grayscale2{
					value: raw
				}.to_colorf32()
			}
			2 {
				p.Grayscale4{
					value: raw
				}.to_colorf32()
			}
			else {
				panic('invalid kind')
			}
		}

		println('UNEXPECTED ${result.r}')
		return
	}
	contents := os.read_file(os.args[1]) or { panic(err) }
	mut output := strings.new_builder(64 * 1024)
	for line in contents.split_into_lines() {
		fields := line.split('|')
		kind := fields[0].int()
		args := fields[1..].map(u32(it.u64()))
		match kind {
			0 {
				input := p.Grayscale1{
					value: u8(args[3])
				}
				run(mut output, input, args)
			}
			1 {
				input := p.Grayscale2{
					value: u8(args[3])
				}
				run(mut output, input, args)
			}
			2 {
				input := p.Grayscale4{
					value: u8(args[3])
				}
				run(mut output, input, args)
			}
			3 {
				input := p.Grayscale8{
					value: u8(args[3])
				}
				run(mut output, input, args)
			}
			4 {
				input := p.Grayscale16{
					value: u16(args[3])
				}
				run(mut output, input, args)
			}
			5 {
				input := p.Grayscale8Alpha{
					value: u8(args[3])
				}
				run(mut output, input, args)
			}
			6 {
				input := p.Grayscale16Alpha{
					value: u16(args[3])
				}
				run(mut output, input, args)
			}
			7 {
				input := p.Grayscalef32{
					value: scalar(f32(0), args[3])
				}
				run(mut output, input, args)
			}
			8 {
				input := p.Grayscalef32Alpha{
					value: scalar(f32(0), args[3])
				}
				run(mut output, input, args)
			}
			else {
				panic('invalid kind')
			}
		}

		output.write_string('\n')
	}
	print(output.str())
}
