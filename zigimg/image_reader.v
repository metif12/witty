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
	format := image_detect_format(mut stream)!
	stream.seek_to(0)!
	return match format {
		.bmp { BMP.read_image(mut stream)! }
		.farbfeld { Farbfeld.read_image(mut stream)! }
		.gif { GIF.read_image(mut stream)! }
		.iff { IFF.read_image(mut stream)! }
		.jpeg { JPEG.read_image(mut stream)! }
		.pam { PAM.read_image(mut stream)! }
		.pbm { PBM.read_image(mut stream)! }
		.pcx { PCX.read_image(mut stream)! }
		.pgm { PGM.read_image(mut stream)! }
		.png { PNG.read_image(mut stream)! }
		.ppm { PPM.read_image(mut stream)! }
		.qoi { QOI.read_image(mut stream)! }
		.ras { RAS.read_image(mut stream)! }
		.sgi { SGI.read_image(mut stream)! }
		.tga { TGA.read_image(mut stream)! }
		.tiff { TIFF.read_image(mut stream)! }
		.xbm { XBM.read_image(mut stream)! }
	}
}
