module zigimg

import os

// ImageUnmanaged's locked format registry shares the detector order and resets
// the selected reader to zero before calling its actual codec interface.
pub fn ImageUnmanaged.from_memory(buffer []u8) !ImageUnmanaged {
	mut stream := ReadStream.init_memory(buffer)
	return image_internal_read(mut stream)
}

pub fn ImageUnmanaged.from_file(file os.File, mut read_buffer []u8) !ImageUnmanaged {
	mut stream := ReadStream.init_file(file, mut read_buffer)
	return image_internal_read(mut stream)
}

pub fn ImageUnmanaged.from_file_path(path string, mut read_buffer []u8) !ImageUnmanaged {
	mut file := os.open(path)!
	defer { file.close() }
	return ImageUnmanaged.from_file(file, mut read_buffer)
}

pub fn Image.from_memory(buffer []u8) !Image {
	return (ImageUnmanaged.from_memory(buffer)!).to_managed()
}

pub fn Image.from_file(file os.File, mut read_buffer []u8) !Image {
	return (ImageUnmanaged.from_file(file, mut read_buffer)!).to_managed()
}

pub fn Image.from_file_path(path string, mut read_buffer []u8) !Image {
	return (ImageUnmanaged.from_file_path(path, mut read_buffer)!).to_managed()
}

pub fn ImageUnmanaged.detect_format_from_file(file os.File, mut read_buffer []u8) !Format {
	mut stream := ReadStream.init_file(file, mut read_buffer)
	return image_detect_format(mut stream)
}

pub fn ImageUnmanaged.detect_format_from_file_path(path string, mut read_buffer []u8) !Format {
	mut file := os.open(path)!
	defer { file.close() }
	return ImageUnmanaged.detect_format_from_file(file, mut read_buffer)
}

pub fn Image.detect_format_from_file(file os.File, mut read_buffer []u8) !Format {
	return ImageUnmanaged.detect_format_from_file(file, mut read_buffer)
}

pub fn Image.detect_format_from_file_path(path string, mut read_buffer []u8) !Format {
	return ImageUnmanaged.detect_format_from_file_path(path, mut read_buffer)
}

fn image_internal_read(mut stream ReadStream) !ImageUnmanaged {
	codec := image_find_interface(mut stream)!
	stream.seek_to(0)!
	return codec.read_image(mut stream)
}
