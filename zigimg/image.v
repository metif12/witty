module zigimg

pub const animation_loop_infinite = -1

pub struct AnimationFrame {
pub mut:
	pixels   PixelStorage = InvalidPixels{}
	duration f32
}

pub fn (frame AnimationFrame) deinit() {
	frame.pixels.deinit()
}

pub struct Animation {
pub mut:
	frames     []AnimationFrame
	loop_count i32 = animation_loop_infinite
}

pub fn (mut animation Animation) deinit() {
	// The source skips the shared first frame when releasing pixel allocations.
	if animation.frames.len >= 2 {
		for frame in animation.frames[1..] {
			frame.deinit()
		}
	}
	// GC replaces ArrayList.deinit; post-deinit state is undefined in the source.
}

pub struct ImageUnmanaged {
pub mut:
	width     usize
	height    usize
	pixels    PixelStorage = InvalidPixels{}
	animation Animation
}

pub fn (mut image ImageUnmanaged) deinit() {
	image.pixels.deinit()
	image.animation.deinit()
}

pub fn (image ImageUnmanaged) to_managed() Image {
	return Image{
		width:  image.width
		height: image.height
		// Copy slice headers while retaining the same backing pixel/palette data.
		pixels:    image.pixels.slice(0, image.pixels.len())
		animation: image.animation
	}
}

pub fn ImageUnmanaged.from_raw_pixels_owned(width usize, height usize, bytes []u8, format PixelFormat) !ImageUnmanaged {
	return ImageUnmanaged{
		width:  width
		height: height
		pixels: PixelStorage.init_raw_pixels(bytes, format)!
	}
}

pub fn ImageUnmanaged.from_raw_pixels(width usize, height usize, bytes []u8, format PixelFormat) !ImageUnmanaged {
	return ImageUnmanaged.from_raw_pixels_owned(width, height, bytes.clone(), format)
}

pub fn ImageUnmanaged.create(width usize, height usize, format PixelFormat) !ImageUnmanaged {
	return ImageUnmanaged{
		width:  width
		height: height
		pixels: PixelStorage.init(format, image_pixel_count(width, height))!
	}
}

fn image_pixel_count(width usize, height usize) usize {
	if height != 0 && width > ~usize(0) / height {
		panic('integer overflow')
	}
	return width * height
}

pub fn (image ImageUnmanaged) pixel_format() PixelFormat {
	return image.pixels.pixel_format()
}

pub fn (image ImageUnmanaged) raw_bytes() []u8 {
	return image.pixels.as_bytes()
}

pub fn (image ImageUnmanaged) image_byte_size() usize {
	return usize(image.raw_bytes().len)
}

pub fn (image ImageUnmanaged) row_byte_size() usize {
	assert image.height != 0
	return image.image_byte_size() / image.height
}

pub fn (image ImageUnmanaged) is_animation() bool {
	return image.animation.frames.len > 0
}

pub fn (image &ImageUnmanaged) flip_vertically() ! {
	flip_vertically(&image.pixels, image.height)!
}

pub fn (image &ImageUnmanaged) crop(area Box) !ImageUnmanaged {
	return crop(image, area)
}

pub fn (image &ImageUnmanaged) iterator() PixelStorageIterator {
	return PixelStorageIterator.init(&image.pixels)
}

pub fn (mut image ImageUnmanaged) convert(destination_format PixelFormat) ! {
	// GC replaces freeing the old storage. Animation frames are not converted.
	image.convert_no_free(destination_format)!
}

pub fn (mut image ImageUnmanaged) convert_no_free(destination_format PixelFormat) ! {
	if image.pixel_format() == destination_format { return }
	image.pixels = PixelFormatConverter.convert(&image.pixels, destination_format)!
}
