module zigimg

// color.PixelStorage, using V-owned arrays in place of allocator slices.
pub struct InvalidPixels {}

pub struct Grayscale1Pixels {
pub mut:
	data []Grayscale1
}

pub struct Grayscale2Pixels {
pub mut:
	data []Grayscale2
}

pub struct Grayscale4Pixels {
pub mut:
	data []Grayscale4
}

pub struct Grayscale8Pixels {
pub mut:
	data []Grayscale8
}

pub struct Grayscale16Pixels {
pub mut:
	data []Grayscale16
}

pub struct Grayscale8AlphaPixels {
pub mut:
	data []Grayscale8Alpha
}

pub struct Grayscale16AlphaPixels {
pub mut:
	data []Grayscale16Alpha
}

pub struct Rgb332Pixels {
pub mut:
	data []Rgb332
}

pub struct Rgb555Pixels {
pub mut:
	data []Rgb555
}

pub struct Rgb565Pixels {
pub mut:
	data []Rgb565
}

pub struct Rgb24Pixels {
pub mut:
	data []Rgb24
}

pub struct Rgba32Pixels {
pub mut:
	data []Rgba32
}

pub struct Bgr555Pixels {
pub mut:
	data []Bgr555
}

pub struct Bgr24Pixels {
pub mut:
	data []Bgr24
}

pub struct Bgra32Pixels {
pub mut:
	data []Bgra32
}

pub struct Rgb48Pixels {
pub mut:
	data []Rgb48
}

pub struct Rgba64Pixels {
pub mut:
	data []Rgba64
}

pub struct Colorf32Pixels {
pub mut:
	data []Colorf32
}

pub struct IndexedStorage1 {
pub mut:
	palette []Rgba32 @[required]
	indices []u8     @[required]
}

pub fn IndexedStorage1.init(pixel_count usize) IndexedStorage1 {
	return IndexedStorage1.init_palette_size(pixel_count, 2)
}

pub fn IndexedStorage1.init_palette_size(pixel_count usize, palette_size usize) IndexedStorage1 {
	if palette_size > 2 { panic('reached unreachable code') }
	mut palette := []Rgba32{len: 2}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage1{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []u8{len: int(pixel_count)}
	}
}

pub fn (mut storage IndexedStorage1) resize_palette(size usize) {
	if size > 2 { panic('reached unreachable code') }
	// Source resizes the slice, retaining the full original allocation.
	unsafe {
		storage.palette.len = int(size)
	}
}

pub struct IndexedStorage2 {
pub mut:
	palette []Rgba32 @[required]
	indices []u8     @[required]
}

pub fn IndexedStorage2.init(pixel_count usize) IndexedStorage2 {
	return IndexedStorage2.init_palette_size(pixel_count, 4)
}

pub fn IndexedStorage2.init_palette_size(pixel_count usize, palette_size usize) IndexedStorage2 {
	if palette_size > 4 { panic('reached unreachable code') }
	mut palette := []Rgba32{len: 4}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage2{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []u8{len: int(pixel_count)}
	}
}

pub fn (mut storage IndexedStorage2) resize_palette(size usize) {
	if size > 4 { panic('reached unreachable code') }
	// Source resizes the slice, retaining the full original allocation.
	unsafe {
		storage.palette.len = int(size)
	}
}

pub struct IndexedStorage4 {
pub mut:
	palette []Rgba32 @[required]
	indices []u8     @[required]
}

pub fn IndexedStorage4.init(pixel_count usize) IndexedStorage4 {
	return IndexedStorage4.init_palette_size(pixel_count, 16)
}

pub fn IndexedStorage4.init_palette_size(pixel_count usize, palette_size usize) IndexedStorage4 {
	if palette_size > 16 { panic('reached unreachable code') }
	mut palette := []Rgba32{len: 16}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage4{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []u8{len: int(pixel_count)}
	}
}

pub fn (mut storage IndexedStorage4) resize_palette(size usize) {
	if size > 16 { panic('reached unreachable code') }
	// Source resizes the slice, retaining the full original allocation.
	unsafe {
		storage.palette.len = int(size)
	}
}

pub struct IndexedStorage8 {
pub mut:
	palette []Rgba32 @[required]
	indices []u8     @[required]
}

pub fn IndexedStorage8.init(pixel_count usize) IndexedStorage8 {
	return IndexedStorage8.init_palette_size(pixel_count, 256)
}

pub fn IndexedStorage8.init_palette_size(pixel_count usize, palette_size usize) IndexedStorage8 {
	if palette_size > 256 { panic('reached unreachable code') }
	mut palette := []Rgba32{len: 256}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage8{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []u8{len: int(pixel_count)}
	}
}

pub fn (mut storage IndexedStorage8) resize_palette(size usize) {
	if size > 256 { panic('reached unreachable code') }
	// Source resizes the slice, retaining the full original allocation.
	unsafe {
		storage.palette.len = int(size)
	}
}

pub struct IndexedStorage16 {
pub mut:
	palette []Rgba32 @[required]
	indices []u16    @[required]
}

pub fn IndexedStorage16.init(pixel_count usize) IndexedStorage16 {
	return IndexedStorage16.init_palette_size(pixel_count, 65536)
}

pub fn IndexedStorage16.init_palette_size(pixel_count usize, palette_size usize) IndexedStorage16 {
	if palette_size > 65536 { panic('reached unreachable code') }
	mut palette := []Rgba32{len: 65536}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage16{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []u16{len: int(pixel_count)}
	}
}

pub fn (mut storage IndexedStorage16) resize_palette(size usize) {
	if size > 65536 { panic('reached unreachable code') }
	// Source resizes the slice, retaining the full original allocation.
	unsafe {
		storage.palette.len = int(size)
	}
}

pub type PixelStorage = InvalidPixels
	| IndexedStorage1
	| IndexedStorage2
	| IndexedStorage4
	| IndexedStorage8
	| IndexedStorage16
	| Grayscale1Pixels
	| Grayscale2Pixels
	| Grayscale4Pixels
	| Grayscale8Pixels
	| Grayscale16Pixels
	| Grayscale8AlphaPixels
	| Grayscale16AlphaPixels
	| Rgb332Pixels
	| Rgb555Pixels
	| Rgb565Pixels
	| Rgb24Pixels
	| Rgba32Pixels
	| Bgr555Pixels
	| Bgr24Pixels
	| Bgra32Pixels
	| Rgb48Pixels
	| Rgba64Pixels
	| Colorf32Pixels

pub fn PixelStorage.init(format PixelFormat, pixel_count usize) !PixelStorage {
	return match format {
		.invalid {
			PixelStorage(InvalidPixels{})
		}
		.indexed1 {
			PixelStorage(IndexedStorage1.init(pixel_count))
		}
		.indexed2 {
			PixelStorage(IndexedStorage2.init(pixel_count))
		}
		.indexed4 {
			PixelStorage(IndexedStorage4.init(pixel_count))
		}
		.indexed8 {
			PixelStorage(IndexedStorage8.init(pixel_count))
		}
		.indexed16 {
			PixelStorage(IndexedStorage16.init(pixel_count))
		}
		.grayscale1 {
			PixelStorage(Grayscale1Pixels{
				data: []Grayscale1{len: int(pixel_count)}
			})
		}
		.grayscale2 {
			PixelStorage(Grayscale2Pixels{
				data: []Grayscale2{len: int(pixel_count)}
			})
		}
		.grayscale4 {
			PixelStorage(Grayscale4Pixels{
				data: []Grayscale4{len: int(pixel_count)}
			})
		}
		.grayscale8 {
			PixelStorage(Grayscale8Pixels{
				data: []Grayscale8{len: int(pixel_count)}
			})
		}
		.grayscale16 {
			PixelStorage(Grayscale16Pixels{
				data: []Grayscale16{len: int(pixel_count)}
			})
		}
		.grayscale8_alpha {
			PixelStorage(Grayscale8AlphaPixels{
				data: []Grayscale8Alpha{len: int(pixel_count)}
			})
		}
		.grayscale16_alpha {
			PixelStorage(Grayscale16AlphaPixels{
				data: []Grayscale16Alpha{len: int(pixel_count)}
			})
		}
		.rgb332 {
			PixelStorage(Rgb332Pixels{
				data: []Rgb332{len: int(pixel_count)}
			})
		}
		.rgb555 {
			PixelStorage(Rgb555Pixels{
				data: []Rgb555{len: int(pixel_count)}
			})
		}
		.rgb565 {
			PixelStorage(Rgb565Pixels{
				data: []Rgb565{len: int(pixel_count)}
			})
		}
		.rgb24 {
			PixelStorage(Rgb24Pixels{
				data: []Rgb24{len: int(pixel_count)}
			})
		}
		.rgba32 {
			PixelStorage(Rgba32Pixels{
				data: []Rgba32{len: int(pixel_count)}
			})
		}
		.bgr555 {
			PixelStorage(Bgr555Pixels{
				data: []Bgr555{len: int(pixel_count)}
			})
		}
		.bgr24 {
			PixelStorage(Bgr24Pixels{
				data: []Bgr24{len: int(pixel_count)}
			})
		}
		.bgra32 {
			PixelStorage(Bgra32Pixels{
				data: []Bgra32{len: int(pixel_count)}
			})
		}
		.rgb48 {
			PixelStorage(Rgb48Pixels{
				data: []Rgb48{len: int(pixel_count)}
			})
		}
		.rgba64 {
			PixelStorage(Rgba64Pixels{
				data: []Rgba64{len: int(pixel_count)}
			})
		}
		.float32 {
			mut data := []Colorf32{len: int(pixel_count)}
			if pixel_count == 0 {
				// Allocator.alloc with align(1) and zero bytes returns maxInt(usize).
				// The converter's unconditional f32 alignCast observes this pointer.
				unsafe {
					data.data = voidptr(~usize(0))
					data.flags = .nofree
				}
			}
			PixelStorage(Colorf32Pixels{
				data: data
			})
		}
	}
}

pub fn (storage PixelStorage) deinit() {
	// Source frees each active slice/palette allocation. GC owns these in V.
	_ = storage
}

pub fn PixelStorage.init_raw_pixels(bytes []u8, format PixelFormat) !PixelStorage {
	return match format {
		.grayscale1 {
			PixelStorage(Grayscale1Pixels{
				data: pixel_array_view[Grayscale1](bytes, false)
			})
		}
		.grayscale2 {
			PixelStorage(Grayscale2Pixels{
				data: pixel_array_view[Grayscale2](bytes, false)
			})
		}
		.grayscale4 {
			PixelStorage(Grayscale4Pixels{
				data: pixel_array_view[Grayscale4](bytes, false)
			})
		}
		.grayscale8 {
			PixelStorage(Grayscale8Pixels{
				data: pixel_array_view[Grayscale8](bytes, false)
			})
		}
		.grayscale8_alpha {
			PixelStorage(Grayscale8AlphaPixels{
				data: pixel_array_view[Grayscale8Alpha](bytes, false)
			})
		}
		.grayscale16_alpha {
			PixelStorage(Grayscale16AlphaPixels{
				data: pixel_array_view[Grayscale16Alpha](bytes, true)
			})
		}
		.rgb332 {
			PixelStorage(Rgb332Pixels{
				data: pixel_array_view[Rgb332](bytes, false)
			})
		}
		.rgb555 {
			PixelStorage(Rgb555Pixels{
				data: pixel_array_view[Rgb555](bytes, true)
			})
		}
		.rgb565 {
			PixelStorage(Rgb565Pixels{
				data: pixel_array_view[Rgb565](bytes, true)
			})
		}
		.rgb24 {
			PixelStorage(Rgb24Pixels{
				data: pixel_array_view[Rgb24](bytes, false)
			})
		}
		.rgba32 {
			PixelStorage(Rgba32Pixels{
				data: pixel_array_view[Rgba32](bytes, false)
			})
		}
		.bgr555 {
			PixelStorage(Bgr555Pixels{
				data: pixel_array_view[Bgr555](bytes, true)
			})
		}
		.bgr24 {
			PixelStorage(Bgr24Pixels{
				data: pixel_array_view[Bgr24](bytes, false)
			})
		}
		.bgra32 {
			PixelStorage(Bgra32Pixels{
				data: pixel_array_view[Bgra32](bytes, false)
			})
		}
		.rgb48 {
			PixelStorage(Rgb48Pixels{
				data: pixel_array_view[Rgb48](bytes, false)
			})
		}
		.rgba64 {
			PixelStorage(Rgba64Pixels{
				data: pixel_array_view[Rgba64](bytes, false)
			})
		}
		.float32 {
			PixelStorage(Colorf32Pixels{
				data: pixel_array_view[Colorf32](bytes, false)
			})
		}
		else {
			return error('Unsupported')
		}
	}
}

fn pixel_array_view[T](bytes []u8, check_alignment bool) []T {
	if usize(bytes.len) % sizeof(T) != 0 { panic('exact division produced remainder') }
	if bytes.len != 0 && check_alignment && usize(bytes.data) % 2 != 0 {
		panic('incorrect alignment')
	}
	mut result := []T{}
	unsafe {
		result.data = bytes.data
		$if T is Colorf32 {
			// Empty Source slices carry an undefined pointer; retain the existing
			// deterministic sentinel adaptation for the float converter.
			if bytes.len == 0 { result.data = voidptr(~usize(0)) }
		}
		result.len = int(usize(bytes.len) / sizeof(T))
		result.cap = result.len
		result.flags = .nofree
	}
	return result
}

pub fn (storage PixelStorage) pixel_format() PixelFormat {
	return match storage {
		InvalidPixels { .invalid }
		IndexedStorage1 { .indexed1 }
		IndexedStorage2 { .indexed2 }
		IndexedStorage4 { .indexed4 }
		IndexedStorage8 { .indexed8 }
		IndexedStorage16 { .indexed16 }
		Grayscale1Pixels { .grayscale1 }
		Grayscale2Pixels { .grayscale2 }
		Grayscale4Pixels { .grayscale4 }
		Grayscale8Pixels { .grayscale8 }
		Grayscale16Pixels { .grayscale16 }
		Grayscale8AlphaPixels { .grayscale8_alpha }
		Grayscale16AlphaPixels { .grayscale16_alpha }
		Rgb332Pixels { .rgb332 }
		Rgb555Pixels { .rgb555 }
		Rgb565Pixels { .rgb565 }
		Rgb24Pixels { .rgb24 }
		Rgba32Pixels { .rgba32 }
		Bgr555Pixels { .bgr555 }
		Bgr24Pixels { .bgr24 }
		Bgra32Pixels { .bgra32 }
		Rgb48Pixels { .rgb48 }
		Rgba64Pixels { .rgba64 }
		Colorf32Pixels { .float32 }
	}
}

pub fn (storage PixelStorage) len() usize {
	return match storage {
		InvalidPixels { usize(0) }
		IndexedStorage1 { usize(storage.indices.len) }
		IndexedStorage2 { usize(storage.indices.len) }
		IndexedStorage4 { usize(storage.indices.len) }
		IndexedStorage8 { usize(storage.indices.len) }
		IndexedStorage16 { usize(storage.indices.len) }
		Grayscale1Pixels { usize(storage.data.len) }
		Grayscale2Pixels { usize(storage.data.len) }
		Grayscale4Pixels { usize(storage.data.len) }
		Grayscale8Pixels { usize(storage.data.len) }
		Grayscale16Pixels { usize(storage.data.len) }
		Grayscale8AlphaPixels { usize(storage.data.len) }
		Grayscale16AlphaPixels { usize(storage.data.len) }
		Rgb332Pixels { usize(storage.data.len) }
		Rgb555Pixels { usize(storage.data.len) }
		Rgb565Pixels { usize(storage.data.len) }
		Rgb24Pixels { usize(storage.data.len) }
		Rgba32Pixels { usize(storage.data.len) }
		Bgr555Pixels { usize(storage.data.len) }
		Bgr24Pixels { usize(storage.data.len) }
		Bgra32Pixels { usize(storage.data.len) }
		Rgb48Pixels { usize(storage.data.len) }
		Rgba64Pixels { usize(storage.data.len) }
		Colorf32Pixels { usize(storage.data.len) }
	}
}

pub fn (storage PixelStorage) is_indexed() bool {
	return match storage {
		InvalidPixels { false }
		IndexedStorage1 { true }
		IndexedStorage2 { true }
		IndexedStorage4 { true }
		IndexedStorage8 { true }
		IndexedStorage16 { true }
		Grayscale1Pixels { false }
		Grayscale2Pixels { false }
		Grayscale4Pixels { false }
		Grayscale8Pixels { false }
		Grayscale16Pixels { false }
		Grayscale8AlphaPixels { false }
		Grayscale16AlphaPixels { false }
		Rgb332Pixels { false }
		Rgb555Pixels { false }
		Rgb565Pixels { false }
		Rgb24Pixels { false }
		Rgba32Pixels { false }
		Bgr555Pixels { false }
		Bgr24Pixels { false }
		Bgra32Pixels { false }
		Rgb48Pixels { false }
		Rgba64Pixels { false }
		Colorf32Pixels { false }
	}
}

pub fn (storage PixelStorage) get_palette() ?[]Rgba32 {
	return match storage {
		InvalidPixels { none }
		IndexedStorage1 { storage.palette }
		IndexedStorage2 { storage.palette }
		IndexedStorage4 { storage.palette }
		IndexedStorage8 { storage.palette }
		IndexedStorage16 { storage.palette }
		Grayscale1Pixels { none }
		Grayscale2Pixels { none }
		Grayscale4Pixels { none }
		Grayscale8Pixels { none }
		Grayscale16Pixels { none }
		Grayscale8AlphaPixels { none }
		Grayscale16AlphaPixels { none }
		Rgb332Pixels { none }
		Rgb555Pixels { none }
		Rgb565Pixels { none }
		Rgb24Pixels { none }
		Rgba32Pixels { none }
		Bgr555Pixels { none }
		Bgr24Pixels { none }
		Bgra32Pixels { none }
		Rgb48Pixels { none }
		Rgba64Pixels { none }
		Colorf32Pixels { none }
	}
}

pub fn (storage PixelStorage) as_bytes() []u8 {
	return match storage {
		InvalidPixels { []u8{} }
		IndexedStorage1 { unsafe { (&u8(storage.indices.data)).vbytes(storage.indices.len * int(sizeof(u8))) } }
		IndexedStorage2 { unsafe { (&u8(storage.indices.data)).vbytes(storage.indices.len * int(sizeof(u8))) } }
		IndexedStorage4 { unsafe { (&u8(storage.indices.data)).vbytes(storage.indices.len * int(sizeof(u8))) } }
		IndexedStorage8 { unsafe { (&u8(storage.indices.data)).vbytes(storage.indices.len * int(sizeof(u8))) } }
		IndexedStorage16 { unsafe { (&u8(storage.indices.data)).vbytes(storage.indices.len * int(sizeof(u16))) } }
		Grayscale1Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale1))) } }
		Grayscale2Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale2))) } }
		Grayscale4Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale4))) } }
		Grayscale8Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale8))) } }
		Grayscale16Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale16))) } }
		Grayscale8AlphaPixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale8Alpha))) } }
		Grayscale16AlphaPixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Grayscale16Alpha))) } }
		Rgb332Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgb332))) } }
		Rgb555Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgb555))) } }
		Rgb565Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgb565))) } }
		Rgb24Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgb24))) } }
		Rgba32Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgba32))) } }
		Bgr555Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Bgr555))) } }
		Bgr24Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Bgr24))) } }
		Bgra32Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Bgra32))) } }
		Rgb48Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgb48))) } }
		Rgba64Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Rgba64))) } }
		Colorf32Pixels { unsafe { (&u8(storage.data.data)).vbytes(storage.data.len * int(sizeof(Colorf32))) } }
	}
}

pub fn (storage PixelStorage) as_const_bytes() []u8 {
	return storage.as_bytes()
}

pub fn (mut storage PixelStorage) resize_palette(size usize) {
	match mut storage {
		IndexedStorage1 { storage.resize_palette(size) }
		IndexedStorage2 { storage.resize_palette(size) }
		IndexedStorage4 { storage.resize_palette(size) }
		IndexedStorage8 { storage.resize_palette(size) }
		IndexedStorage16 { storage.resize_palette(size) }
		else {}
	}
}

pub fn (storage PixelStorage) slice(begin usize, end usize) PixelStorage {
	if storage !is InvalidPixels {
		// Source checks the range order before checking its end, using usize.
		if begin > end { panic('start index ${begin} is larger than end index ${end}') }
		if end > storage.len() { panic('index out of bounds: index ${end}, len ${storage.len()}') }
	}
	return match storage {
		InvalidPixels {
			storage
		}
		IndexedStorage1 {
			PixelStorage(IndexedStorage1{
				palette: storage.palette
				indices: unsafe { storage.indices[int(begin)..int(end)] }
			})
		}
		IndexedStorage2 {
			PixelStorage(IndexedStorage2{
				palette: storage.palette
				indices: unsafe { storage.indices[int(begin)..int(end)] }
			})
		}
		IndexedStorage4 {
			PixelStorage(IndexedStorage4{
				palette: storage.palette
				indices: unsafe { storage.indices[int(begin)..int(end)] }
			})
		}
		IndexedStorage8 {
			PixelStorage(IndexedStorage8{
				palette: storage.palette
				indices: unsafe { storage.indices[int(begin)..int(end)] }
			})
		}
		IndexedStorage16 {
			PixelStorage(IndexedStorage16{
				palette: storage.palette
				indices: unsafe { storage.indices[int(begin)..int(end)] }
			})
		}
		Grayscale1Pixels {
			PixelStorage(Grayscale1Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale2Pixels {
			PixelStorage(Grayscale2Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale4Pixels {
			PixelStorage(Grayscale4Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale8Pixels {
			PixelStorage(Grayscale8Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale16Pixels {
			PixelStorage(Grayscale16Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale8AlphaPixels {
			PixelStorage(Grayscale8AlphaPixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Grayscale16AlphaPixels {
			PixelStorage(Grayscale16AlphaPixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgb332Pixels {
			PixelStorage(Rgb332Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgb555Pixels {
			PixelStorage(Rgb555Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgb565Pixels {
			PixelStorage(Rgb565Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgb24Pixels {
			PixelStorage(Rgb24Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgba32Pixels {
			PixelStorage(Rgba32Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Bgr555Pixels {
			PixelStorage(Bgr555Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Bgr24Pixels {
			PixelStorage(Bgr24Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Bgra32Pixels {
			PixelStorage(Bgra32Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgb48Pixels {
			PixelStorage(Rgb48Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Rgba64Pixels {
			PixelStorage(Rgba64Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
		Colorf32Pixels {
			PixelStorage(Colorf32Pixels{
				data: unsafe { storage.data[int(begin)..int(end)] }
			})
		}
	}
}
