module zigimg

const image_supported_formats = [Format.bmp, .farbfeld, .gif, .iff, .jpeg, .pam, .pbm, .pcx, .pgm,
	.png, .ppm, .qoi, .ras, .sgi, .tga, .tiff, .xbm]!

pub fn ImageUnmanaged.detect_format_from_memory(buffer []u8) !Format {
	mut stream := ReadStream.init_memory(buffer)
	return image_detect_format(mut stream)
}

pub fn Image.detect_format_from_memory(buffer []u8) !Format {
	return ImageUnmanaged.detect_format_from_memory(buffer)
}

fn image_detect_format(mut stream ReadStream) !Format {
	// The pinned registry seeks before every detector and propagates its errors.
	// A short earlier signature check can therefore prevent a later match.
	for format in image_supported_formats {
		stream.seek_to(0)!
		found := match format {
			.bmp { BMP.format_detect(mut stream)! }
			.farbfeld { Farbfeld.format_detect(mut stream)! }
			.gif { GIF.format_detect(mut stream)! }
			.iff { IFF.format_detect(mut stream)! }
			.jpeg { jpeg_format_detect(mut stream)! }
			.pam { PAM.format_detect(mut stream)! }
			.pbm { PBM.format_detect(mut stream)! }
			.pcx { PCX.format_detect(mut stream)! }
			.pgm { PGM.format_detect(mut stream)! }
			.png { PNG.format_detect(mut stream)! }
			.ppm { PPM.format_detect(mut stream)! }
			.qoi { QOI.format_detect(mut stream)! }
			.ras { RAS.format_detect(mut stream)! }
			.sgi { SGI.format_detect(mut stream)! }
			.tga { TGA.format_detect(mut stream)! }
			.tiff { tiff_format_detect(mut stream)! }
			.xbm { XBM.format_detect(mut stream)! }
		}

		if found { return format }
	}
	return error('Unsupported')
}

// The registry uses the same JPEG codec detector as its read interface.
fn jpeg_format_detect(mut stream ReadStream) !bool {
	return JPEG.format_detect(mut stream)
}

fn tiff_format_detect(mut stream ReadStream) !bool {
	return TIFF.format_detect(mut stream)
}
