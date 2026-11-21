module zigimg

// Buffer is an inline fixed-array type, replacing Zig's integer type-factory
// parameter. For example: FixedStorage[u16, MySevenWords] with
// `type MySevenWords = [7]u16`. V rejects zero-length fixed arrays; an empty
// []T represents that specialization. data always borrows storage.
pub struct FixedStorage[T, B] {
pub mut:
	data    []T
	storage B
}

pub fn (mut buffer FixedStorage[T, B]) resize[T, B](size uint) {
	$if B.unaliased_typ is []T {
		if buffer.storage.len != 0 {
			panic('FixedStorage zero-capacity adapter requires empty storage')
		}
		if size != 0 { panic('index out of bounds: index ${size}, len 0') }
		buffer.data = unsafe { buffer.storage[..] }
	} $else $if B.unaliased_typ is $array {
		element := buffer.storage[0]
		$if element is T {
			_ = element
		} $else {
			$compile_error('FixedStorage requires an inline array of its element type')
		}
		capacity := uint(sizeof(B) / sizeof(T))
		if size > capacity {
			panic('index out of bounds: index ${size}, len ${capacity}')
		}
		mut data := []T{}
		unsafe {
			data.data = &buffer.storage
			data.len = int(size)
			data.cap = int(size)
			data.flags = .nofree
		}
		buffer.data = data
	} $else {
		$compile_error('FixedStorage requires an inline array of its element type')
	}
}

// TIFF uses the source's separate eight-element specialization.
pub struct FixedStorage8[T] {
pub mut:
	data    []T
	storage [8]T
}

pub fn (mut buffer FixedStorage8[T]) resize[T](size uint) {
	if size > 8 { panic('index out of bounds: index ${size}, len 8') }
	mut data := []T{}
	unsafe {
		data.data = &buffer.storage[0]
		data.len = int(size)
		data.cap = int(size)
		data.flags = .nofree
	}
	buffer.data = data
}

// The 256-element specialization of pinned utils.FixedStorage(T, size).
// V does not provide Zig's type factory parameterized on an integer value.
pub struct FixedStorage256[T] {
pub mut:
	data    []T
	storage [256]T
}

pub fn (mut buffer FixedStorage256[T]) resize[T](size uint) {
	if size > 256 { panic('index out of bounds: index ${size}, len 256') }
	mut data := []T{}
	unsafe {
		data.data = &buffer.storage[0]
		data.len = int(size)
		data.cap = int(size)
		data.flags = .nofree
	}
	buffer.data = data
}
