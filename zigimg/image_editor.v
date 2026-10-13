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
	if box.width > ~usize(0) - box.x {
		panic('integer overflow')
	}
	if box.x + box.width > image_width {
		if box.x > image_width {
			panic('integer overflow')
		}
		box.width = image_width - box.x
	}
	if box.height > ~usize(0) - box.y {
		panic('integer overflow')
	}
	if box.y + box.height > image_height {
		if box.y > image_height {
			panic('integer overflow')
		}
		box.height = image_height - box.y
	}
	return box
}

pub fn flip_vertically(pixels &PixelStorage, height usize) ! {
	mut image_data := pixels.as_bytes()
	if height == 0 { panic('division by zero') }
	row_size := int(usize(image_data.len) / height)
	mut temp := []u8{len: row_size}
	for image_data.len > row_size {
		mut row1 := unsafe { image_data[..row_size] }
		mut row2 := unsafe { image_data[image_data.len - row_size..] }
		copy(mut temp, row1)
		if row_size > image_data.len - row_size { panic('@memcpy arguments alias') }
		copy(mut row1, row2)
		copy(mut row2, temp)
		image_data = unsafe { image_data[row_size..image_data.len - row_size] }
	}
}

fn editor_byte_product(a usize, b usize) usize {
	if b != 0 && a > ~usize(0) / b { panic('integer overflow') }
	return a * b
}

fn editor_byte_sum(a usize, b usize) usize {
	if b > ~usize(0) - a { panic('integer overflow') }
	return a + b
}

fn editor_byte_range(begin usize, end usize, length int) {
	if begin > end { panic('start index ${begin} is larger than end index ${end}') }
	if end > usize(length) { panic('index out of bounds: index ${end}, len ${length}') }
}

pub fn crop(image &ImageUnmanaged, area Box) !ImageUnmanaged {
	box := area.clamp(image.width, image.height)
	mut pixels := PixelStorage.init(image.pixel_format(), image_pixel_count(box.width, box.height))!
	if image.pixel_format().is_indexed() {
		palette := image.pixels.get_palette() or { panic('attempt to use null value') }
		pixels.resize_palette(usize(palette.len))
		mut destination := pixels.get_palette() or { panic('attempt to use null value') }
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
		row_byte_width := editor_byte_product(box.width, pixel_size)
		for y := usize(0); y < box.height; y++ {
			x_bytes := editor_byte_product(box.x, pixel_size)
			row := editor_byte_sum(y, box.y)
			row_pixels := editor_byte_product(row, image.width)
			row_bytes := editor_byte_product(row_pixels, pixel_size)
			start_pixel := editor_byte_sum(x_bytes, row_bytes)
			source_end := editor_byte_sum(start_pixel, row_byte_width)
			editor_byte_range(start_pixel, source_end, original_data.len)
			source := unsafe { original_data[int(start_pixel)..int(source_end)] }
			destination_pixel := editor_byte_product(y, row_byte_width)
			destination_end := editor_byte_sum(destination_pixel, row_byte_width)
			editor_byte_range(destination_pixel, destination_end, cropped_data.len)
			mut destination := unsafe {
				cropped_data[int(destination_pixel)..int(destination_end)]
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
