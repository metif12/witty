module tripwire

fn test_basic() {
	mut io := new()

	// Reset should work (no tripwires set, so end succeeds)
	io.end(.reset) or { assert false, 'end should succeed with no tripwires' }

	// By default, its pass-through
	io.check('read') or { assert false, 'check should pass by default' }

	// Always trip
	io.error_always('read', error('OutOfMemory'))
	if _ := io.check('read') {
		assert false, 'expected error from tripped read'
	} else {
		assert err.msg() == 'OutOfMemory'
	}

	// Happens again
	if _ := io.check('read') {
		assert false, 'expected error from tripped read again'
	} else {
		assert err.msg() == 'OutOfMemory'
	}

	io.end(.reset) or { assert false, 'end should succeed after tripping' }
}

fn test_error_after() {
	mut io := new()

	// Trip after 2 calls (on the 3rd call)
	io.error_after('read', error('OutOfMemory'), 2)

	// First two calls succeed
	io.check('read') or { assert false, 'first call should succeed' }
	io.check('read') or { assert false, 'second call should succeed' }

	// Third call and on trips
	if _ := io.check('read') {
		assert false, 'third call should error'
	} else {
		assert err.msg() == 'OutOfMemory'
	}
	if _ := io.check('read') {
		assert false, 'fourth call should error'
	} else {
		assert err.msg() == 'OutOfMemory'
	}

	io.end(.reset) or { assert false, 'end should succeed after tripping' }
}

fn test_error_after_untripped() {
	mut io := new()

	io.error_after('read', error('OutOfMemory'), 2)

	// Only call once, not enough to trip
	io.check('read') or { assert false, 'first call should succeed' }

	// end should fail because tripwire was set but never tripped
	if _ := io.end(.reset) {
		assert false, 'end should fail for untripped tripwire'
	} else {
		assert err.msg() == 'UntrippedError'
	}
}
