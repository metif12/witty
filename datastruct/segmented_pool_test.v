module datastruct

fn test_segmented_pool() {
	mut pool := SegmentedPool.init[u8](2)
	defer { pool.deinit() }
	assert pool.available == 2

	// Get to capacity.
	mut v1 := pool.get()!
	v2 := pool.get()!
	assert v1 != v2
	if _ := pool.get() {
		assert false, 'expected OutOfValues'
	}

	// Test writing for later.
	unsafe {
		*v1 = 42
	}

	// Put a value back.
	pool.put()
	temp := pool.get()!
	assert v1 == temp
	assert *temp == 42
	if _ := pool.get() {
		assert false, 'expected OutOfValues'
	}

	// Grow.
	v3 := pool.get_grow()!
	assert v1 != v3 && v2 != v3
	_ = pool.get()!
	if _ := pool.get() {
		assert false, 'expected OutOfValues'
	}

	// Put a value back.
	pool.put()
	assert v1 == pool.get()!
	if _ := pool.get() {
		assert false, 'expected OutOfValues'
	}
}
