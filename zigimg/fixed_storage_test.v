module zigimg

type FixedStorageTestWords = [7]u16

fn test_fixed_storage_borrows_inline_storage_and_retains_old_views() {
	mut buffer := FixedStorage[u16, FixedStorageTestWords]{}
	assert buffer.data.len == 0 && sizeof(buffer.storage) == 14
	buffer.resize(7)
	assert buffer.data.len == 7 && buffer.data.data == voidptr(&buffer.storage)
	for i in 0 .. 7 {
		buffer.data[i] = u16(100 + i)
	}
	old_view := buffer.data
	buffer.resize(3)
	assert buffer.data.len == 3 && buffer.data.data == old_view.data
	buffer.data[1] = 200
	assert old_view.len == 7 && old_view[1] == 200 && old_view[6] == 106
	buffer.resize(0)
	assert buffer.data.len == 0 && buffer.data.data == old_view.data
	buffer.resize(7)
	assert buffer.data[1] == 200 && buffer.data[6] == 106
}

fn fixed_storage_test_size[T, B](storage B, value T) {
	mut buffer := FixedStorage[T, B]{
		storage: storage
	}
	capacity := uint(sizeof(B) / sizeof(T))
	buffer.resize(capacity)
	assert buffer.data.len == int(capacity)
	buffer.data[int(capacity) - 1] = value
	buffer.resize(capacity - 1)
	buffer.resize(capacity)
	assert buffer.data[int(capacity) - 1] == value
}

fn test_fixed_storage_supports_independent_capacities_and_struct_elements() {
	fixed_storage_test_size([1]u8{}, u8(42))
	fixed_storage_test_size([17]u8{}, u8(43))
	fixed_storage_test_size([513]u8{}, u8(44))
	fixed_storage_test_size([11]u32{}, u32(0xabcdef01))
	fixed_storage_test_size([3]Rgba32{}, Rgba32{ r: 1, g: 2, b: 3, a: 4 })
	mut empty := FixedStorage[u16, []u16]{}
	empty.resize(0)
	assert empty.data.len == 0 && empty.storage.len == 0
}
