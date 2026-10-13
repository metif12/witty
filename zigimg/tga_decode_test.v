module zigimg

import os

fn test_tga_raw_rle_packets_cross_file_buffer_boundaries() {
	path := os.join_path(os.temp_dir(), 'witty-tga-raw-${os.getpid()}.bin')
	defer { os.rm(path) or {} }
	mut bytes := tga_header_bytes(TGAHeader{
		image_type: TGAImageType{
			raw: 11
		}
		image_spec: TGAImageSpec{
			width:         128
			height:        1
			bit_per_pixel: 8
			descriptor:    TGADescriptor{
				raw: 32
			}
		}
	})
	bytes << u8(127)
	for value in 0 .. 128 {
		bytes << u8(value)
	}
	for _ in 0 .. 8 {
		bytes << [u8(255), 9]
	}
	os.write_file_array(path, bytes)!
	for capacity in [26, 31, 64, 128, 512] {
		mut file := os.open(path)!
		mut buffer := []u8{len: capacity, init: u8(165)}
		mut stream := ReadStream.init_file(file, mut buffer)
		mut codec := TGA{}
		pixels := codec.read(mut stream)!
		for i, byte in pixels.as_bytes() {
			assert byte == u8(i)
		}
		stream.seek_to(0)!
		assert codec.read(mut stream)!.as_bytes() == pixels.as_bytes()
		file.close()
	}
}

fn test_tga_raw_packet_reports_short_file_read_without_using_unused_capacity() {
	path := os.join_path(os.temp_dir(), 'witty-tga-short-${os.getpid()}.bin')
	defer { os.rm(path) or {} }
	mut bytes := tga_header_bytes(TGAHeader{
		image_type: TGAImageType{
			raw: 11
		}
		image_spec: TGAImageSpec{
			width:         1
			height:        1
			bit_per_pixel: 8
			descriptor:    TGADescriptor{
				raw: 32
			}
		}
	})
	bytes << u8(127)
	bytes << []u8{len: 7, init: u8(9)}
	os.write_file_array(path, bytes)!
	mut file := os.open(path)!
	defer { file.close() }
	mut buffer := []u8{len: 64, init: u8(165)}
	mut stream := ReadStream.init_file(file, mut buffer)
	mut codec := TGA{}
	assert codec.read(mut stream)!.as_bytes() == [u8(9)]
	assert stream.get_pos() == 26
}
