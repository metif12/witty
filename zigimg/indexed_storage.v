module zigimg

// The named built-ins keep their required-field checks and sub-byte carriers.
pub struct IndexedStorage[T] {
pub mut:
	palette []Rgba32 @[required]
	indices []T      @[required]
}

// V uses a static function for Source's compile-time PaletteSize member.
pub fn IndexedStorage.palette_size[T]() u64 {
	$if T.unaliased_typ is bool {
		return 2
	} $else $if T.unaliased_typ is u8 || T.unaliased_typ is i8 || T.unaliased_typ is u16
		|| T.unaliased_typ is i16 || T.unaliased_typ is u32 || T.unaliased_typ is int
		|| T.unaliased_typ is f32 {
		return u64(1) << (sizeof(T) * 8)
	} $else {
		$compile_error('IndexedStorage palette size is outside the represented scalar types')
	}
}

pub fn IndexedStorage.init[T](pixel_count uint) IndexedStorage[T] {
	return IndexedStorage.init_palette_size[T](pixel_count, uint(IndexedStorage.palette_size[T]()))
}

pub fn IndexedStorage.init_palette_size[T](pixel_count uint, palette_size uint) IndexedStorage[T] {
	capacity := IndexedStorage.palette_size[T]()
	if u64(palette_size) > capacity { panic('reached unreachable code') }
	// Source can describe allocations beyond V's signed array-length carrier.
	if capacity > 0x7fffffff || pixel_count > 0x7fffffff {
		panic('indexed storage exceeds V array length')
	}
	mut palette := []Rgba32{len: int(capacity)}
	for i in 0 .. int(palette_size) {
		palette[i] = Rgba32{
			a: 255
		}
	}
	return IndexedStorage[T]{
		palette: unsafe { palette[..int(palette_size)] }
		indices: []T{len: int(pixel_count)}
	}
}

// Static calls let records with other index types exist without instantiating
// palette arithmetic in V's eagerly checked generic receiver methods.
pub fn IndexedStorage.resize_palette[T](mut storage IndexedStorage[T], size uint) {
	if u64(size) > IndexedStorage.palette_size[T]() { panic('reached unreachable code') }
	if size > 0x7fffffff { panic('indexed storage exceeds V array length') }
	unsafe {
		storage.palette.len = int(size)
	}
}

pub fn (storage IndexedStorage[T]) deinit() {
	// Source releases both allocations without changing the slice descriptors.
	// V's GC owns those allocations.
}

pub fn IndexedStorage1.palette_size() uint {
	return 2
}

pub fn IndexedStorage2.palette_size() uint {
	return 4
}

pub fn IndexedStorage4.palette_size() uint {
	return 16
}

pub fn IndexedStorage8.palette_size() uint {
	return 256
}

pub fn IndexedStorage16.palette_size() uint {
	return 65536
}

pub fn (storage IndexedStorage1) deinit() {}

pub fn (storage IndexedStorage2) deinit() {}

pub fn (storage IndexedStorage4) deinit() {}

pub fn (storage IndexedStorage8) deinit() {}

pub fn (storage IndexedStorage16) deinit() {}
