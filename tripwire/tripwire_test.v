module tripwire

fn test_reset_mode_source_layout_and_ordinals() {
	assert sizeof(ResetMode) == 1
	assert [ResetMode.reset, .retain].map(u8(it)) == [u8(0), 1]
}

enum Point {
	read
	write
}

fn test_basic() {
	mut io := new[Point]()
	io.end(.reset)!
	io.check(.read)!
	io.error_always(.read, error('OutOfMemory'))
	if _ := io.check(.read) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	if _ := io.check(.read) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	io.end(.reset)!
}

fn test_error_after() {
	mut io := new[Point]()
	io.error_after(.read, error('OutOfMemory'), 2)
	io.check(.read)!
	io.check(.read)!
	if _ := io.check(.read) {
		assert false
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	io.end(.reset)!
}

fn test_untripped_expectation() {
	mut io := new[Point]()
	io.error_after(.read, error('OutOfMemory'), 2)
	io.check(.read)!
	if _ := io.end(.reset) {
		assert false
	} else {
		assert err.msg() == 'UntrippedError'
	}
}
