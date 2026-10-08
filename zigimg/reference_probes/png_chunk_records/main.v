module main

import zigimg

struct Output {
mut:
	stream zigimg.WriteStream
	calls  usize
}

struct Adapter {
mut:
	output &Output = unsafe { nil }
	label  u8      = 7
}

pub fn (mut adapter Adapter) write_int[T, E](value T, endian E) ! {
	adapter.output.calls++
	adapter.output.stream.write_int(value, endian)!
}

pub fn (mut adapter Adapter) write_all(bytes []u8) ! {
	adapter.output.calls++
	adapter.output.stream.write_all(bytes)!
}

pub fn (mut adapter Adapter) write(bytes []u8) !usize {
	adapter.output.calls++
	return adapter.output.stream.write(bytes)
}

type ByteAlias = u8
type Bytes0 = []u8
type Bytes1 = [1]u8
type Bytes4 = [4]ByteAlias
type Bytes16 = [16]u8
type AdapterAlias = Adapter
type RecordAlias = zigimg.PngChunkWriter[Bytes4, AdapterAlias]

fn byte_hash(bytes []u8) u64 {
	mut result := u64(14695981039346656037)
	for byte in bytes {
		result = (result ^ byte) * u64(1099511628211)
	}
	return result
}

fn buffer_bytes[B](mut buffer B) []u8 {
	$if B.unaliased_typ is []u8 {
		return unsafe { buffer[..] }
	} $else {
		return unsafe { (&u8(&buffer)).vbytes(int(sizeof(B))) }
	}
}

fn from_local[B, W](buffer B, underlying W, seed u8) zigimg.PngChunkWriter[B, W] {
	mut local := unsafe { buffer }
	mut bytes := buffer_bytes(mut local)
	for i in 0 .. bytes.len {
		bytes[i] = u8(i * 37 + int(seed) * 19)
	}
	writer := zigimg.png_chunk_writer_with_buffer(local, underlying, [u8(`I`), `D`, `A`, `T`]!)
	for i in 0 .. bytes.len {
		bytes[i] = 0xff
	}
	return writer
}

fn run[B, W](buffer B, underlying W, mut output Output, mut destination []u8, seed u8, form u8) ! {
	mut writer := from_local(buffer, underlying, seed)
	if form == 0 {
		writer = zigimg.png_chunk_writer_with_buffer(buffer, underlying, [u8(`I`), `D`, `A`, `T`]!)
	}
	mut bytes := buffer_bytes(mut writer.buf)
	if form == 0 {
		for i in 0 .. bytes.len {
			bytes[i] = u8(i * 37 + int(seed) * 19)
		}
	}
	size := bytes.len
	initial_end := writer.end
	writer.end = usize(size)
	mut copied := writer
	copied.unbuffered_writer.label = 17
	copied.section_id = [u8(`t`), `E`, `X`, `t`]!
	mut copied_bytes := buffer_bytes(mut copied.buf)
	if size != 0 {
		bytes[0] = seed ^ 0x50
		copied_bytes[size - 1] = seed ^ 0xa0
	}
	before := byte_hash(bytes)
	copied_before := byte_hash(copied_bytes)
	copied.flush()!
	copied_end := copied.end
	original_end_after_copy := writer.end
	writer.flush()!
	println('R|${size}|${seed}|${form}|${initial_end}|${original_end_after_copy}|${copied_end}|${writer.unbuffered_writer.label}|${copied.unbuffered_writer.label}|${before:016x}|${copied_before:016x}|${output.stream.get_pos()}|${output.calls}|${byte_hash(destination):016x}')
}

fn selected[B, W](buffer B, underlying W, mut output Output, mut destination []u8, seed u8, form u8) ! {
	run(buffer, underlying, mut output, mut destination, seed, form)!
}

fn alias_record() ! {
	mut destination := []u8{len: 32, init: 0xa5}
	mut output := Output{
		stream: zigimg.WriteStream.init_memory(mut destination)
	}
	mut writer := RecordAlias{
		unbuffered_writer: AdapterAlias(Adapter{
			output: &output
		})
		section_id:        [u8(`I`), `D`, `A`, `T`]!
		buf:               Bytes4([ByteAlias(1), 2, 3, 4]!)
	}
	before := writer.end
	writer.unbuffered_writer.label = 29
	writer.buf[0] = ByteAlias(9)
	writer.end = 2
	writer.section_id = [u8(`t`), `E`, `X`, `t`]!
	mut copied := writer
	copied.buf[0] = ByteAlias(8)
	copied.section_id[0] = `a`
	copied.flush()!
	println('A|${before}|${writer.end}|${copied.end}|${writer.buf[0]}|${copied.buf[0]}|${writer.section_id[0]}|${copied.section_id[0]}|${byte_hash(destination):016x}')
}

fn pointer_writer() ! {
	mut destination := []u8{len: 32, init: 0xa5}
	mut output := Output{
		stream: zigimg.WriteStream.init_memory(mut destination)
	}
	mut adapter := Adapter{
		output: &output
	}
	mut writer := zigimg.PngChunkWriter[Bytes4, &Adapter]{
		unbuffered_writer: &adapter
		section_id:        [u8(`I`), `D`, `A`, `T`]!
		buf:               Bytes4([ByteAlias(1), 2, 3, 4]!)
		end:               2
	}
	mut copied := writer
	copied.unbuffered_writer.label = 42
	copied.buf[0] = ByteAlias(9)
	copied.end = 1
	copied.flush()!
	println('P|${writer.unbuffered_writer.label}|${copied.unbuffered_writer.label}|${writer.buf[0]}|${copied.buf[0]}|${writer.end}|${copied.end}|${output.stream.get_pos()}|${byte_hash(destination):016x}')
}

fn main() {
	for size in [0, 1, 4, 16, 16384] {
		for seed in 0 .. 16 {
			for form in 0 .. 2 {
				mut destination := []u8{len: size * 2 + 32, init: 0xa5}
				mut output := Output{
					stream: zigimg.WriteStream.init_memory(mut destination)
				}
				underlying := Adapter{
					output: &output
				}
				match size {
					0 {
						buffer := Bytes0{}
						selected(buffer, underlying, mut output, mut destination, u8(seed),
							u8(form))!
					}
					1 {
						buffer := Bytes1{}
						selected(buffer, underlying, mut output, mut destination, u8(seed),
							u8(form))!
					}
					4 {
						buffer := Bytes4{}
						selected(buffer, AdapterAlias(underlying), mut output, mut destination,
							u8(seed), u8(form))!
					}
					16 {
						buffer := Bytes16{}
						selected(buffer, underlying, mut output, mut destination, u8(seed),
							u8(form))!
					}
					16384 {
						buffer := zigimg.PngChunkBuffer16K{}
						selected(buffer, underlying, mut output, mut destination, u8(seed),
							u8(form))!
					}
					else {}
				}
			}
		}
	}
	alias_record()!
	pointer_writer()!
	mut destination := []u8{len: 32, init: 0xa5}
	mut output := Output{
		stream: zigimg.WriteStream.init_memory(mut destination)
	}
	factory := zigimg.png_chunk_writer(Adapter{ output: &output }, 'IDAT')
	println('F|${factory.end}|${sizeof(factory.buf)}|${factory.section_id[..].bytestr()}|${factory.unbuffered_writer.label}')
}
