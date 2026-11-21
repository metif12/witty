module zigimg

pub struct PixelStorageIterator {
pub mut:
	pixels        &PixelStorage = unsafe { nil }
	current_index uint
	end           uint
}

pub fn PixelStorageIterator.init(pixels &PixelStorage) PixelStorageIterator {
	return PixelStorageIterator{
		// Borrow the storage itself, not a snapshot of its current sum variant.
		// The caller keeps it alive for the duration of iteration.
		pixels: unsafe { pixels }
		end:    pixels.len()
	}
}

pub fn (mut iter PixelStorageIterator) next() ?Colorf32 {
	if iter.current_index >= iter.end {
		return none
	}
	pixels := iter.pixels
	if pixels !is InvalidPixels && iter.current_index >= pixels.len() {
		panic('index out of bounds: index ${iter.current_index}, len ${pixels.len()}')
	}
	index := int(iter.current_index)
	result := match pixels {
		InvalidPixels {
			Colorf32{}
		}
		IndexedStorage1 {
			pixel_iterator_palette_color(pixels.palette, uint(pixels.indices[index]))
		}
		IndexedStorage2 {
			pixel_iterator_palette_color(pixels.palette, uint(pixels.indices[index]))
		}
		IndexedStorage4 {
			pixel_iterator_palette_color(pixels.palette, uint(pixels.indices[index]))
		}
		IndexedStorage8 {
			pixel_iterator_palette_color(pixels.palette, uint(pixels.indices[index]))
		}
		IndexedStorage16 {
			pixel_iterator_palette_color(pixels.palette, uint(pixels.indices[index]))
		}
		Grayscale1Pixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale2Pixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale4Pixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale8Pixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale16Pixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale8AlphaPixels {
			pixels.data[index].to_colorf32()
		}
		Grayscale16AlphaPixels {
			pixels.data[index].to_colorf32()
		}
		Rgb332Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgb555Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgb565Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgb24Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgba32Pixels {
			pixels.data[index].to_colorf32()
		}
		Bgr555Pixels {
			pixels.data[index].to_colorf32()
		}
		Bgr24Pixels {
			pixels.data[index].to_colorf32()
		}
		Bgra32Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgb48Pixels {
			pixels.data[index].to_colorf32()
		}
		Rgba64Pixels {
			pixels.data[index].to_colorf32()
		}
		Colorf32Pixels {
			pixels.data[index]
		}
	}

	iter.current_index++
	return result
}

fn pixel_iterator_palette_color(palette []Rgba32, index uint) Colorf32 {
	if index >= uint(palette.len) {
		panic('index out of bounds: index ${index}, len ${palette.len}')
	}
	return palette[int(index)].to_colorf32()
}
