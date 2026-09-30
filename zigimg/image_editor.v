module zigimg

// ImageEditor.Box. As in the source, the origin must be within the image;
// clamp only reduces the width and height at the right and bottom boundaries.
pub struct Box {
pub mut:
	x      usize
	y      usize
	width  usize
	height usize
}

pub fn (area Box) clamp(image_width usize, image_height usize) Box {
	mut box := area
	assert box.width <= ~usize(0) - box.x
	assert box.height <= ~usize(0) - box.y
	if box.x + box.width > image_width {
		assert box.x <= image_width
		box.width = image_width - box.x
	}
	if box.y + box.height > image_height {
		assert box.y <= image_height
		box.height = image_height - box.y
	}
	return box
}

pub fn flip_vertically(pixels &PixelStorage, height usize) ! {
	mut image_data := pixels.as_bytes()
	row_size := int(usize(image_data.len) / height)
	mut temp := []u8{len: row_size}
	for image_data.len > row_size {
		mut row1 := unsafe { image_data[..row_size] }
		mut row2 := unsafe { image_data[image_data.len - row_size..] }
		copy(mut temp, row1)
		copy(mut row1, row2)
		copy(mut row2, temp)
		image_data = unsafe { image_data[row_size..image_data.len - row_size] }
	}
}

pub fn crop(image &ImageUnmanaged, area Box) !ImageUnmanaged {
	box := area.clamp(image.width, image.height)
	mut pixels := PixelStorage.init(image.pixel_format(), box.width * box.height)!
	if image.pixel_format().is_indexed() {
		palette := image.pixels.get_palette() or { panic('missing source palette') }
		pixels.resize_palette(usize(palette.len))
		mut destination := pixels.get_palette() or { panic('missing destination palette') }
		assert destination.len == palette.len
		for i, color in palette {
			destination[i] = color
		}
	}
	if box.width != 0 && box.height != 0 && image.width != 0 && image.height != 0 {
		original_data := image.pixels.as_bytes()
		mut cropped_data := pixels.as_bytes()
		pixel_size := usize(image.pixel_format().pixel_stride())
		assert usize(cropped_data.len) == box.width * box.height * pixel_size
		row_byte_width := box.width * pixel_size
		for y := usize(0); y < box.height; y++ {
			start_pixel := box.x * pixel_size + (y + box.y) * image.width * pixel_size
			source := original_data[int(start_pixel)..int(start_pixel + row_byte_width)]
			destination_pixel := y * row_byte_width
			mut destination := unsafe {
				cropped_data[int(destination_pixel)..int(destination_pixel + row_byte_width)]
			}
			copy(mut destination, source)
		}
	}
	return ImageUnmanaged{
		width:  box.width
		height: box.height
		pixels: pixels
	}
}
