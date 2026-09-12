module fastmem

struct Item {
	value u64
}

fn test_copy_is_generic() {
	source := [Item{ value: 1 }, Item{ value: 2 }]
	mut dest := []Item{len: 2}
	copy(mut dest, source)
	assert dest == source
}

fn test_move_overlapping() {
	mut items := [0, 1, 2, 3]
	mut dest := unsafe { items[..3] }
	source := unsafe { items[1..] }
	move(mut dest, source)
	assert items == [1, 2, 3, 3]
}

fn test_rotate_once() {
	mut items := [0, 1, 2, 3]
	rotate_once(mut items)
	assert items == [1, 2, 3, 0]
	rotate_once_r(mut items)
	assert items == [0, 1, 2, 3]
}

fn test_rotate_in() {
	mut items := [0, 1, 2, 3]
	assert rotate_in(mut items, 4) == 0
	assert items == [1, 2, 3, 4]
	assert rotate_in_r(mut items, 0) == 4
	assert items == [0, 1, 2, 3]
}
