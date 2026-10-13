module zigimg

// These callback types translate FormatInterface.zig. GC owns image storage in
// the V API, so callbacks omit the source allocator argument.
pub type FormatDetectFn = fn (mut ReadStream) !bool

pub type ReadImageFn = fn (mut ReadStream) !ImageUnmanaged

pub type WriteImageFn = fn (mut WriteStream, ImageUnmanaged, EncoderOptions) !

pub type FormatInterfaceFn = fn () FormatInterface

pub struct FormatInterface {
pub:
	format_detect FormatDetectFn @[required]
	read_image    ReadImageFn    @[required]
	write_image   WriteImageFn   @[required]
}

// SupportedFormats declaration order in the locked source. Keeping factories
// makes codec interfaces available to callers and to the live image registry.
const image_format_interfaces = [
	BMP.format_interface,
	Farbfeld.format_interface,
	GIF.format_interface,
	IFF.format_interface,
	JPEG.format_interface,
	PAM.format_interface,
	PBM.format_interface,
	PCX.format_interface,
	PGM.format_interface,
	PNG.format_interface,
	PPM.format_interface,
	QOI.format_interface,
	RAS.format_interface,
	SGI.format_interface,
	TGA.format_interface,
	TIFF.format_interface,
	XBM.format_interface,
]!

pub fn (format Format) format_interface() FormatInterface {
	return image_format_interfaces[int(format)]()
}

fn image_find_interface(mut stream ReadStream) !FormatInterface {
	for factory in image_format_interfaces {
		codec := factory()
		stream.seek_to(0)!
		if codec.format_detect(mut stream)! { return codec }
	}
	return error('Unsupported')
}

pub fn BMP.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: BMP.format_detect
		read_image:    BMP.read_image
		write_image:   bmp_interface_write
	}
}

fn bmp_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	BMP.write_image(mut stream, image, BmpEncoderOptions{})!
}

pub fn Farbfeld.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: Farbfeld.format_detect
		read_image:    Farbfeld.read_image
		write_image:   farbfeld_interface_write
	}
}

fn farbfeld_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	Farbfeld.write_image(mut stream, image)!
}

pub fn GIF.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: GIF.format_detect
		read_image:    GIF.read_image
		write_image:   gif_interface_write
	}
}

fn gif_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	GIF.write_image(mut stream, image)!
}

pub fn IFF.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: IFF.format_detect
		read_image:    IFF.read_image
		write_image:   iff_interface_write
	}
}

fn iff_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	IFF.write_image(mut stream, image)!
}

pub fn JPEG.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: JPEG.format_detect
		read_image:    JPEG.read_image
		write_image:   jpeg_interface_write
	}
}

fn jpeg_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	// Both writeImage bodies are empty in the pinned source.
	_ = stream
	_ = image
	_ = options
}

pub fn PAM.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PAM.format_detect
		read_image:    PAM.read_image
		write_image:   pam_interface_write
	}
}

fn pam_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	PAM.write_image(mut stream, image, options)!
}

pub fn PBM.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PBM.format_detect
		read_image:    PBM.read_image
		write_image:   pbm_interface_write
	}
}

fn pbm_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	binary := match options {
		PbmEncoderOptions { options.binary }
		PgmEncoderOptions { options.binary }
		PpmEncoderOptions { options.binary }
		else { false }
	}

	PBM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: binary })!
}

pub fn PCX.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PCX.format_detect
		read_image:    PCX.read_image
		write_image:   pcx_interface_write
	}
}

fn pcx_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	PCX.write_image(mut stream, image, PcxEncoderOptions{})!
}

pub fn PGM.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PGM.format_detect
		read_image:    PGM.read_image
		write_image:   pgm_interface_write
	}
}

fn pgm_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	binary := match options {
		PbmEncoderOptions { options.binary }
		PgmEncoderOptions { options.binary }
		PpmEncoderOptions { options.binary }
		else { false }
	}

	PGM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: binary })!
}

pub fn PNG.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PNG.format_detect
		read_image:    PNG.read_image
		write_image:   png_interface_write
	}
}

fn png_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	// The source accesses the union arm before validating the image.
	assert options is PngEncoderOptions
	PNG.write_image(mut stream, image, options as PngEncoderOptions)!
}

pub fn PPM.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: PPM.format_detect
		read_image:    PPM.read_image
		write_image:   ppm_interface_write
	}
}

fn ppm_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	binary := match options {
		PbmEncoderOptions { options.binary }
		PgmEncoderOptions { options.binary }
		PpmEncoderOptions { options.binary }
		else { false }
	}

	PPM.write_image(mut stream, image, NetpbmEncoderOptions{ binary: binary })!
}

pub fn QOI.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: QOI.format_detect
		read_image:    QOI.read_image
		write_image:   qoi_interface_write
	}
}

fn qoi_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	selected := if options is QoiEncoderOptions { options } else { QoiEncoderOptions{} }
	QOI.write_image(mut stream, image, selected)!
}

pub fn RAS.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: RAS.format_detect
		read_image:    RAS.read_image
		write_image:   ras_interface_write
	}
}

fn ras_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	RAS.write_image(mut stream, image)!
}

pub fn SGI.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: SGI.format_detect
		read_image:    SGI.read_image
		write_image:   sgi_interface_write
	}
}

fn sgi_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	SGI.write_image(mut stream, image)!
}

pub fn TGA.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: TGA.format_detect
		read_image:    TGA.read_image
		write_image:   tga_interface_write
	}
}

fn tga_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	// The source accesses the union arm before validating the image.
	assert options is TgaEncoderOptions
	TGA.write_image(mut stream, image, options as TgaEncoderOptions)!
}

pub fn TIFF.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: TIFF.format_detect
		read_image:    TIFF.read_image
		write_image:   tiff_interface_write
	}
}

fn tiff_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	// Both writeImage bodies are empty in the pinned source.
	_ = stream
	_ = image
	_ = options
}

pub fn XBM.format_interface() FormatInterface {
	return FormatInterface{
		format_detect: XBM.format_detect
		read_image:    XBM.read_image
		write_image:   xbm_interface_write
	}
}

fn xbm_interface_write(mut stream WriteStream, image ImageUnmanaged, options EncoderOptions) ! {
	_ = options
	XBM.write_image(mut stream, image)!
}
