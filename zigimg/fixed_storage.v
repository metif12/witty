module zigimg

// The 256-element specialization of pinned utils.FixedStorage(T, size).
// V does not provide Zig's type factory parameterized on an integer value.
pub struct FixedStorage256[T] {
pub mut:
	data    []T
	storage [256]T
}

pub fn (mut buffer FixedStorage256[T]) resize[T](size usize) {
	assert size <= 256
	mut data := []T{}
	unsafe {
		data.data = &buffer.storage[0]
		data.len = int(size)
		data.cap = int(size)
		data.flags = .nofree
	}
	buffer.data = data
}
