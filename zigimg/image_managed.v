module zigimg

// Image.zig, with GC ownership in place of its last allocator field. This
// layout is not an ABI alias of ImageUnmanaged; wrappers delegate explicitly.
pub struct Image {
pub mut:
	width     uint
	height    uint
	pixels    PixelStorage = InvalidPixels{}
	animation Animation
}

pub fn Image.init() Image {
	return Image{}
}

pub fn (mut image Image) deinit() {
	image.pixels.deinit()
	image.animation.deinit()
}

pub fn Image.from_raw_pixels(width uint, height uint, bytes []u8, format PixelFormat) !Image {
	return (ImageUnmanaged.from_raw_pixels(width, height, bytes, format)!).to_managed()
}

pub fn Image.create(width uint, height uint, format PixelFormat) !Image {
	return (ImageUnmanaged.create(width, height, format)!).to_managed()
}

pub fn (image Image) pixel_format() PixelFormat {
	return image.pixels.pixel_format()
}

pub fn (image Image) raw_bytes() []u8 {
	return image.pixels.as_bytes()
}

pub fn (image Image) row_byte_size() uint {
	size := image.image_byte_size()
	if image.height == 0 { panic('division by zero') }
	return size / image.height
}

pub fn (image Image) image_byte_size() uint {
	return uint(image.raw_bytes().len)
}

pub fn (image Image) is_animation() bool {
	return image.animation.frames.len > 0
}

pub fn (mut image Image) convert(destination_format PixelFormat) ! {
	if image.pixel_format() == destination_format { return }
	image.pixels = PixelFormatConverter.convert(&image.pixels, destination_format)!
}

pub fn (image &Image) flip_vertically() ! {
	flip_vertically(&image.pixels, image.height)!
}

pub fn (image &Image) crop(area Box) !Image {
	unmanaged := image.to_unmanaged()
	return (crop(&unmanaged, area)!).to_managed()
}

pub fn (image &Image) iterator() PixelStorageIterator {
	return PixelStorageIterator.init(&image.pixels)
}

pub fn (image Image) to_unmanaged() ImageUnmanaged {
	return ImageUnmanaged{
		width:     image.width
		height:    image.height
		pixels:    image.pixels.slice(0, image.pixels.len())
		animation: image.animation
	}
}
