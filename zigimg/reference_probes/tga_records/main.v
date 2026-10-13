module main

import os
import zigimg as p

__global (
	observed_codec  = &p.TGA(unsafe { nil })
	observed_stream = &p.ReadStream(unsafe { nil })
	observed_word   = &u8(unsafe { nil })
	observed_path   string
)

fn bytes[T](value T) string {
	return unsafe { (&u8(&value)).vbytes(int(sizeof(T))).hex() }
}

fn observe() {
	mut out := ''
	if observed_word != unsafe { nil } {
		out = '${*observed_word}'
	} else {
		out = '${observed_stream.get_pos()}|${bytes(observed_codec.header)}|${observed_codec.id.data.hex()}'
		if extension := observed_codec.extension {
			out += '|${bytes(extension)}'
		} else {
			out += '|-'
		}
	}
	os.write_file(observed_path, out) or { eprintln('OBSERVER ERROR: ${err}') }
}

fn narrow(field string, value u8) {
	mut flags := p.TGAImageType{
		raw: 165
	}
	mut descriptor := p.TGADescriptor{
		raw: 165
	}
	if field == 'pad1' {
		observed_word = &flags.raw
		flags.set_pad1(value)
	} else {
		observed_word = &descriptor.raw
		if field == 'attributes' {
			descriptor.set_num_attributes_bit(value)
		} else if field == 'pad' {
			descriptor.set_pad(value)
		} else {
			panic('unknown field')
		}
	}
	eprintln('UNEXPECTED: narrow mutation returned')
}

fn decode(path string) {
	input := os.read_bytes(path) or { panic(err) }
	mut stream := p.ReadStream.init_memory(input)
	mut codec := p.TGA{
		extension: p.TGAExtension{
			extension_size: 123
		}
	}
	observed_codec = &codec
	observed_stream = &stream
	if _ := codec.read(mut stream) {
		eprintln('UNEXPECTED: decoder returned')
	} else {
		eprintln('UNEXPECTED: recoverable ${err}')
	}
}

fn records() {
	println('DEFAULT|${bytes(p.TGAImageType{})}|${bytes(p.TGADescriptor{})}|${bytes(p.TGAColorMapSpec{})}|${bytes(p.TGAImageSpec{})}|${bytes(p.TGAHeader{})}|${bytes(p.TGAExtensionComment{})}|${bytes(p.TGAExtensionSoftwareVersion{})}|${bytes(p.TGAExtensionTimestamp{})}|${bytes(p.TGAExtensionJobTime{})}|${bytes(p.TGAExtensionRatio{})}|${bytes(p.TGAExtension{})}|${bytes(p.TGAFooter{})}')
	for seed in [u16(0), 1, 255, 256, 32768, 65535] {
		mut header := p.TGAHeader{
			id_length:      u8(seed)
			has_color_map:  1
			image_type:     p.TGAImageType{
				raw: u8(seed)
			}
			color_map_spec: p.TGAColorMapSpec{
				first_entry_index: seed
				length:            seed
				bit_depth:         u8(seed)
			}
			image_spec:     p.TGAImageSpec{
				origin_x:      seed
				origin_y:      seed
				width:         seed
				height:        seed
				bit_per_pixel: u8(seed)
				descriptor:    p.TGADescriptor{
					raw: u8(seed)
				}
			}
		}
		header_copy := header
		header.image_type.set_run_length(true)
		header.color_map_spec.length = 17
		header.image_spec.descriptor.set_top_to_bottom(true)
		header.image_spec.width = 7
		println('HEADER|${seed}|${bytes(header_copy)}|${bytes(header)}')
		mut extension := p.TGAExtension{
			extension_size:          seed
			timestamp:               p.TGAExtensionTimestamp{
				month:  seed
				day:    seed
				year:   seed
				hour:   seed
				minute: seed
				second: seed
			}
			job_time:                p.TGAExtensionJobTime{
				hours:   seed
				minutes: seed
				seconds: seed
			}
			software_version:        p.TGAExtensionSoftwareVersion{
				number: seed
				letter: u8(seed)
			}
			key_color:               p.Bgra32{
				b: u8(seed)
				g: u8(seed)
				r: u8(seed)
				a: u8(seed)
			}
			pixel_aspect:            p.TGAExtensionRatio{
				numerator:   seed
				denominator: seed
			}
			gamma_value:             p.TGAExtensionRatio{
				numerator:   seed
				denominator: seed
			}
			color_correction_offset: u32(seed) * 65537
			postage_stamp_offset:    u32(seed) * 65537
			scanline_offset:         u32(seed) * 65537
			attributes:              unsafe { p.TGAAttributeType(seed % 5) }
		}
		for i in 0 .. 40 {
			extension.author_name[i] = u8(u32(seed) + u32(i))
			extension.job_id[i] = u8(u32(seed) + u32(i) + 1)
			extension.software_id[i] = u8(u32(seed) + u32(i) + 2)
		}
		for row in 0 .. 4 {
			for col in 0 .. 80 {
				extension.author_comment.lines[row][col] = u8(u32(seed) + u32(row * 80 + col))
			}
		}
		extension_copy := extension
		extension.author_name[0] = 17
		extension.author_comment.lines[3][79] = 18
		extension.timestamp.year = 19
		extension.job_id[39] = 20
		extension.job_time.seconds = 21
		extension.software_id[39] = 22
		extension.software_version.letter = 23
		extension.key_color.a = 24
		extension.pixel_aspect.denominator = 25
		extension.gamma_value.numerator = 26
		extension.scanline_offset = 27
		extension.attributes = .useful_alpha_channel
		println('EXTENSION|${seed}|${bytes(extension_copy)}|${bytes(extension)}')
		mut footer := p.TGAFooter{
			extension_offset: u32(seed) * 65537
			dev_area_offset:  u32(seed) * 65537
		}
		for i in 0 .. 16 {
			footer.signature[i] = u8(u32(seed) + u32(i))
		}
		footer_copy := footer
		footer.extension_offset = 17
		footer.signature[15] = 18
		footer.dot = 19
		footer.null_value = 20
		println('FOOTER|${seed}|${bytes(footer_copy)}|${bytes(footer)}')
	}
	mut image_id := [u8(1), 2, 3]
	mut options := p.TgaEncoderOptions{}
	println('OPTIONS_DEFAULT|${options.rle_compressed}|${options.top_to_bottom_image}|${options.color_map_depth}|${options.image_id.len}|${options.author_name.len}|${bytes(options.author_comment)}|${bytes(options.timestamp)}|${options.job_id.len}|${bytes(options.job_time)}|${options.software_id.len}|${bytes(options.software_version)}')
	options.rle_compressed = false
	options.top_to_bottom_image = false
	options.color_map_depth = 16
	options.image_id = image_id
	options.author_name = 'author'
	options.author_comment.lines[1][79] = 42
	options.timestamp.year = 2026
	options.job_id = 'job'
	options.job_time.seconds = 17
	options.software_id = 'software'
	options.software_version.number = 123
	options.software_version.letter = `v`
	copied := options
	image_id[0] = 9
	options.image_id = options.image_id[..1]
	options.author_name = 'new'
	options.author_comment.lines[1][79] = 43
	options.timestamp.year = 2027
	options.job_id = 'new'
	options.job_time.seconds = 18
	options.software_id = 'new'
	options.software_version.number = 124
	println('OPTIONS_COPY|${copied.rle_compressed}|${copied.top_to_bottom_image}|${copied.color_map_depth}|${copied.image_id.hex()}|${copied.author_name}|${bytes(copied.author_comment)}|${bytes(copied.timestamp)}|${copied.job_id}|${bytes(copied.job_time)}|${copied.software_id}|${bytes(copied.software_version)}|${options.image_id.hex()}|${options.author_name}|${bytes(options.author_comment)}|${bytes(options.timestamp)}|${options.job_id}|${bytes(options.job_time)}|${options.software_id}|${bytes(options.software_version)}')
}

fn main() {
	if os.args.len > 1 {
		if os.args[1] == '--lengths' {
			e := p.TGAExtension{}
			println('${e.author_name.len},${e.job_id.len},${e.software_id.len},${e.author_comment.lines[0].len}')
			return
		}
		observed_path = os.args[2]
		at_exit(observe) or { panic(err) }
		if os.args[1] == '--narrow' {
			narrow(os.args[3], u8(os.args[4].int()))
		} else if os.args[1] == '--decode' {
			decode(os.args[3])
		} else {
			panic('unknown mode')
		}
		return
	}
	for raw in 0 .. 256 {
		for field in 0 .. 5 {
			count := if field == 4 { 16 } else { 2 }
			for n in 0 .. count {
				mut x := p.TGAImageType{
					raw: u8(raw)
				}
				copied := x
				match field {
					0 { x.set_indexed(n != 0) }
					1 { x.set_truecolor(n != 0) }
					2 { x.set_pad0(n != 0) }
					3 { x.set_run_length(n != 0) }
					else { x.set_pad1(u8(n)) }
				}

				println('I|${raw}|${field}|${n}|${x.raw}|${x.indexed()}|${x.truecolor()}|${x.pad0()}|${x.run_length()}|${x.pad1()}|${copied.raw}')
			}
		}
		for field in 0 .. 4 {
			for n in 0 .. ([16, 2, 2, 4][field]) {
				mut x := p.TGADescriptor{
					raw: u8(raw)
				}
				copied := x
				match field {
					0 { x.set_num_attributes_bit(u8(n)) }
					1 { x.set_right_to_left(n != 0) }
					2 { x.set_top_to_bottom(n != 0) }
					else { x.set_pad(u8(n)) }
				}

				println('D|${raw}|${field}|${n}|${x.raw}|${x.num_attributes_bit()}|${x.right_to_left()}|${x.top_to_bottom()}|${x.pad()}|${copied.raw}')
			}
		}
		for map_type in [u8(0), 1, 2, 255] {
			for depth in 0 .. 256 {
				header := p.TGAHeader{
					has_color_map:  map_type
					image_type:     p.TGAImageType{
						raw: u8(raw)
					}
					color_map_spec: p.TGAColorMapSpec{
						bit_depth: u8(depth)
					}
				}
				println('VALID|${raw}|${map_type}|${depth}|${header.is_valid()}')
			}
		}
	}
	records()
}
