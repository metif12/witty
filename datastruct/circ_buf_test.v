module datastruct

fn test_circ_buf_empty() {
	buf := new_circ_buf[u8](12, 0)
	assert buf.empty()
	assert buf.len() == 0
}

fn test_circ_buf_append_and_wrap() ! {
	mut buf := new_circ_buf[u8](3, 0)
	buf.append(1)!
	buf.append(2)!
	buf.append(3)!
	buf.append(4) or {
		assert err.msg() == 'OutOfMemory'
		buf.delete_oldest(1)
		buf.append(4)!
		mut iterator := buf.iterator(.forward)
		assert iterator.next()? == 2
		assert iterator.next()? == 3
		assert iterator.next()? == 4
		assert iterator.next() == none
		return
	}
	assert false, 'expected append to reject a full buffer'
}

fn test_circ_buf_reverse_iterator_seek_and_reset() {
	mut buf := new_circ_buf[u8](3, 0)
	buf.append_assume_capacity(1)
	buf.append_assume_capacity(2)
	buf.append_assume_capacity(3)
	mut iterator := buf.iterator(.reverse)
	assert iterator.next()? == 3
	iterator.seek_by(1)
	assert iterator.next()? == 1
	iterator.seek_by(-100)
	assert iterator.next()? == 3
	iterator.reset()
	assert iterator.next()? == 3
}

fn test_circ_buf_first_last_and_clear() {
	mut buf := new_circ_buf[int](3, -1)
	assert buf.first() == none
	assert buf.last() == none
	buf.append_assume_capacity(4)
	buf.append_assume_capacity(5)
	assert buf.first()? == 4
	assert buf.last()? == 5
	buf.clear()
	assert buf.empty()
	assert buf.len() == 0
}

fn test_circ_buf_append_slice_and_get_ptr_slice_wrap() {
	mut buf := new_circ_buf[u8](4, 0)
	buf.append_slice_assume_capacity([u8(1), 2, 3, 4])
	buf.delete_oldest(2)
	buf.append_slice_assume_capacity([u8(5), 6])
	mut slices := buf.get_ptr_slice(0, 4)
	assert slices.first == [u8(3), 4]
	assert slices.second == [u8(5), 6]
}

fn test_circ_buf_rotate_to_zero() {
	mut buf := new_circ_buf[u8](4, 0)
	buf.append_slice_assume_capacity([u8(1), 2, 3])
	buf.delete_oldest(2)
	buf.append_slice_assume_capacity([u8(4), 5])
	buf.rotate_to_zero()
	assert buf.tail == 0
	assert buf.head == 3
	mut slices := buf.get_ptr_slice(0, 3)
	assert slices.first == [u8(3), 4, 5]
	assert slices.second.len == 0
}

fn test_circ_buf_resize_grow_and_shrink() {
	mut buf := new_circ_buf[u8](4, 0)
	buf.append_slice_assume_capacity([u8(1), 2, 3, 4])
	buf.resize(6)
	assert !buf.full
	assert buf.len() == 4
	assert buf.capacity() == 6
	assert buf.storage[4] == 0
	assert buf.storage[5] == 0

	mut shrinking := new_circ_buf[u8](4, 0)
	shrinking.append_slice_assume_capacity([u8(1), 2, 3, 4])
	shrinking.resize(3)
	assert shrinking.full
	assert shrinking.len() == 3
	mut slices := shrinking.get_ptr_slice(0, 3)
	assert slices.first == [u8(1), 2, 3]
}

fn test_circ_buf_zero_length_operations() {
	mut buf := new_circ_buf[u8](5, 0)
	buf.append_slice_assume_capacity([]u8{})
	buf.delete_oldest(0)
	mut slices := buf.get_ptr_slice(0, 0)
	assert slices.first.len == 0
	assert slices.second.len == 0
	assert buf.empty()
}

fn test_circ_buf_ensure_unused_capacity() {
	mut buf := new_circ_buf[int](0, -1)
	assert buf.full
	buf.ensure_unused_capacity(2)
	assert !buf.full
	assert buf.capacity() == 2
	assert buf.storage == [-1, -1]
}
