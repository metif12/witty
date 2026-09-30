module zigimg

pub struct PixelStorageIterator {
pub mut:
	pixels        &PixelStorage = unsafe { nil }
	current_index usize
	end           usize
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
	index := int(iter.current_index)
	pixels := iter.pixels
	result := match pixels {
		InvalidPixels { Colorf32{} }
		IndexedStorage1 { pixels.palette[pixels.indices[index]].to_colorf32() }
		IndexedStorage2 { pixels.palette[pixels.indices[index]].to_colorf32() }
		IndexedStorage4 { pixels.palette[pixels.indices[index]].to_colorf32() }
		IndexedStorage8 { pixels.palette[pixels.indices[index]].to_colorf32() }
		IndexedStorage16 { pixels.palette[pixels.indices[index]].to_colorf32() }
		Grayscale1Pixels { pixels.data[index].to_colorf32() }
		Grayscale2Pixels { pixels.data[index].to_colorf32() }
		Grayscale4Pixels { pixels.data[index].to_colorf32() }
		Grayscale8Pixels { pixels.data[index].to_colorf32() }
		Grayscale16Pixels { pixels.data[index].to_colorf32() }
		Grayscale8AlphaPixels { pixels.data[index].to_colorf32() }
		Grayscale16AlphaPixels { pixels.data[index].to_colorf32() }
		Rgb332Pixels { pixels.data[index].to_colorf32() }
		Rgb555Pixels { pixels.data[index].to_colorf32() }
		Rgb565Pixels { pixels.data[index].to_colorf32() }
		Rgb24Pixels { pixels.data[index].to_colorf32() }
		Rgba32Pixels { pixels.data[index].to_colorf32() }
		Bgr555Pixels { pixels.data[index].to_colorf32() }
		Bgr24Pixels { pixels.data[index].to_colorf32() }
		Bgra32Pixels { pixels.data[index].to_colorf32() }
		Rgb48Pixels { pixels.data[index].to_colorf32() }
		Rgba64Pixels { pixels.data[index].to_colorf32() }
		Colorf32Pixels { pixels.data[index] }
	}

	iter.current_index++
	return result
}
