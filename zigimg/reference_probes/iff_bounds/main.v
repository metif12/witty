module main

import os
import zigimg

fn main() {
	assert os.args.len == 2
	mut codec := zigimg.IFF{
		format_id: .ilbm
		header:    zigimg.BmhdHeader{
			width:  1
			height: 1
			planes: 1
		}
		pitch:     2
	}
	match os.args[1] {
		'row_stride' {
			codec.header = zigimg.BmhdHeader{
				width:  65535
				height: 1
				planes: 8
			}
			codec.pitch = 8192
			mut chunky := []u8{len: 65535}
			codec.planar_to_chunky([]u8{len: 65536}, mut chunky) or { panic(err) }
		}
		'padding_bit' {
			mut chunky := []u8{len: 1}
			codec.planar_to_chunky([u8(0x40), 0], mut chunky) or { panic(err) }
		}
		'empty_palette' {
			mut stream := zigimg.ReadStream.init_memory([]u8{})
			codec.decode_cmap_chunk(mut stream, zigimg.IffChunkHeader{}) or { panic(err) }
		}
		'ham_bits' {
			codec.header = zigimg.BmhdHeader{
				planes: 5
			}
			codec.cmap_bits = 8
			codec.palette.resize(256)
			codec.reduce_ham_palette()
		}
		else {
			panic('unknown case')
		}
	}

	eprintln('UNEXPECTED: decoder returned')
}
