module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	mut codec := zigimg.GIF.init()
	if os.args[1] == 'short_loop_count' {
		codec.application_infos << zigimg.GifApplicationExtension{
			application_identifier: [u8(`N`), `E`, `T`, `S`, `C`, `A`, `P`, `E`]!
			authentification_code:  [u8(`2`), `.`, `0`]!
			data:                   [u8(1)]
		}
		_ = codec.loop_count()
	} else {
		mut bytes := 'GIF89a\x01\x00\x01\x00\x80\x00\x00\x01\x02\x03\x04\x05\x06'.bytes()
		match os.args[1] {
			'plain_text_overflow' {
				bytes << [u8(0x21), 1, 0, 255]
				bytes << []u8{len: 255, init: `A`}
				bytes << [u8(0), 0x3b]
			}
			'graphic_toss' {
				bytes << [u8(0x21), 0xf9, 4, 0, 0, 0]
			}
			'background_index' {
				bytes << '\x21\xf9\x04\x09\x00\x00\x03\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x4c\x01\x00\x3b'.bytes()
			}
			else {
				panic('unknown case')
			}
		}

		mut reader := zigimg.ReadStream.init_memory(bytes)
		_ = zigimg.GIF.read_image(mut reader) or { panic('UNEXPECTED read error: ${err.msg()}') }
	}
	eprintln('UNEXPECTED: decoder returned')
}
