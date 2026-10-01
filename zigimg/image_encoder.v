module zigimg

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
pub:
	binary bool = true
}

pub struct PgmEncoderOptions {
pub:
	binary bool = true
}

pub struct PpmEncoderOptions {
pub:
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
	match options {
		BmpEncoderOptions {
			BMP.write_image(mut stream, image, options)!
		}
		FarbfeldEncoderOptions {
			Farbfeld.write_image(mut stream, image)!
		}
		GifEncoderOptions {
			GIF.write_image(mut stream, image)!
		}
		IffEncoderOptions {
			IFF.write_image(mut stream, image)!
		}
		JpegEncoderOptions {
			// JPEG.writeImage in the source is private and succeeds without output.
		}
		PamEncoderOptions {
			PAM.write_image(mut stream, image, options)!
		}
		PbmEncoderOptions {
			PBM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: options.binary })!
		}
		PcxEncoderOptions {
			PCX.write_image(mut stream, image, options)!
		}
		PgmEncoderOptions {
			PGM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: options.binary })!
		}
		PngEncoderOptions {
			PNG.write_image(mut stream, image, options)!
		}
		PpmEncoderOptions {
			PPM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: options.binary })!
		}
		QoiEncoderOptions {
			QOI.write_image(mut stream, image, options)!
		}
		RasEncoderOptions {
			RAS.write_image(mut stream, image)!
		}
		SgiEncoderOptions {
			SGI.write_image(mut stream, image)!
		}
		TgaEncoderOptions {
			TGA.write_image(mut stream, image, options)!
		}
		TiffEncoderOptions {
			TIFF.write_image(mut stream, image, options)!
		}
		XbmEncoderOptions {
			XBM.write_image(mut stream, image)!
		}
	}
}
