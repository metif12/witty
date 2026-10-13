module zigimg

import os

// ImageUnmanaged.Format's declaration order in the locked dependency.
pub enum Format as u8 {
	bmp
	farbfeld
	gif
	iff
	jpeg
	pam
	pbm
	pcx
	pgm
	png
	ppm
	qoi
	ras
	sgi
	tga
	tiff
	xbm
}

pub struct FarbfeldEncoderOptions {}

pub struct GifEncoderOptions {}

pub struct IffEncoderOptions {}

pub struct JpegEncoderOptions {}

pub struct RasEncoderOptions {}

pub struct SgiEncoderOptions {}

pub struct TiffEncoderOptions {}

pub struct XbmEncoderOptions {}

// Zig's three identical Netpbm option types need distinct V sum variants.
pub struct PbmEncoderOptions {
pub mut:
	binary bool = true
}

pub struct PgmEncoderOptions {
pub mut:
	binary bool = true
}

pub struct PpmEncoderOptions {
pub mut:
	binary bool = true
}

pub type EncoderOptions = BmpEncoderOptions
	| FarbfeldEncoderOptions
	| GifEncoderOptions
	| IffEncoderOptions
	| JpegEncoderOptions
	| PamEncoderOptions
	| PbmEncoderOptions
	| PcxEncoderOptions
	| PgmEncoderOptions
	| PngEncoderOptions
	| PpmEncoderOptions
	| QoiEncoderOptions
	| RasEncoderOptions
	| SgiEncoderOptions
	| TgaEncoderOptions
	| TiffEncoderOptions
	| XbmEncoderOptions

pub fn (options EncoderOptions) format() Format {
	return match options {
		BmpEncoderOptions { .bmp }
		FarbfeldEncoderOptions { .farbfeld }
		GifEncoderOptions { .gif }
		IffEncoderOptions { .iff }
		JpegEncoderOptions { .jpeg }
		PamEncoderOptions { .pam }
		PbmEncoderOptions { .pbm }
		PcxEncoderOptions { .pcx }
		PgmEncoderOptions { .pgm }
		PngEncoderOptions { .png }
		PpmEncoderOptions { .ppm }
		QoiEncoderOptions { .qoi }
		RasEncoderOptions { .ras }
		SgiEncoderOptions { .sgi }
		TgaEncoderOptions { .tga }
		TiffEncoderOptions { .tiff }
		XbmEncoderOptions { .xbm }
	}
}

pub fn (image ImageUnmanaged) write_to_memory(mut buffer []u8, options EncoderOptions) ![]u8 {
	mut stream := WriteStream.init_memory(mut buffer)
	image.internal_write(mut stream, options)!
	return stream.buffered()
}

pub fn (image Image) write_to_memory(mut buffer []u8, options EncoderOptions) ![]u8 {
	return image.to_unmanaged().write_to_memory(mut buffer, options)
}

fn (image ImageUnmanaged) internal_write(mut stream WriteStream, options EncoderOptions) ! {
	codec := options.format().format_interface()
	codec.write_image(mut stream, image, options)!
}

pub fn (image ImageUnmanaged) write_to_file(file os.File, mut write_buffer []u8, options EncoderOptions) ! {
	mut stream := WriteStream.init_file(file, mut write_buffer)
	image.internal_write(mut stream, options)!
}

pub fn (image ImageUnmanaged) write_to_file_path(path string, mut write_buffer []u8, options EncoderOptions) ! {
	mut file := os.create(path)!
	defer { file.close() }
	image.write_to_file(file, mut write_buffer, options)!
}

pub fn (image Image) write_to_file(file os.File, mut write_buffer []u8, options EncoderOptions) ! {
	image.to_unmanaged().write_to_file(file, mut write_buffer, options)!
}

pub fn (image Image) write_to_file_path(path string, mut write_buffer []u8, options EncoderOptions) ! {
	image.to_unmanaged().write_to_file_path(path, mut write_buffer, options)!
}
