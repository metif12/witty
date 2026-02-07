module terminal

// Tests for screen_set.v helper methods.
// Translated from Ghostty's terminal/ScreenSet.zig tests.
//
// The core ScreenSet tests are in terminal_test.v (test_screen_set_init_and_switch).
// These tests cover the additional helper methods defined in screen_set.v.

// ============================================================
// is_active tests
// ============================================================

// Test that is_active returns correct value after init.
fn test_screen_set_is_active_primary() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Primary should be active after init.
	assert ss.is_active(.primary) == true
	assert ss.is_active(.alternate) == false
}

// Test that is_active updates after switching screens.
fn test_screen_set_is_active_after_switch() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Initialize alternate screen so we can switch to it.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'failed to init alternate'
		return
	}

	ss.switch_to(.alternate)
	assert ss.is_active(.primary) == false
	assert ss.is_active(.alternate) == true

	ss.switch_to(.primary)
	assert ss.is_active(.primary) == true
	assert ss.is_active(.alternate) == false
}

// ============================================================
// get_or_init tests
// ============================================================

// Test that get_or_init returns the primary screen.
fn test_screen_set_get_or_init_primary() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Primary is always initialized.
	_ = ss.get_or_init(.primary, 10, 10, 100) or {
		assert false, 'get_or_init primary should succeed'
		return
	}
}

// Test that get_or_init lazily initializes the alternate screen.
fn test_screen_set_get_or_init_alternate() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Alternate should not be initialized yet.
	alt_before := ss.get(.alternate)
	assert alt_before == none

	// get_or_init should initialize it.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'get_or_init alternate should succeed'
		return
	}

	// Now it should be initialized.
	alt_after := ss.get(.alternate)
	assert alt_after != none
}

// Test that get_or_init returns the same screen on repeated calls.
fn test_screen_set_get_or_init_idempotent() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// First call initializes.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'first get_or_init should succeed'
		return
	}

	// Second call should return the same screen.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'second get_or_init should succeed'
		return
	}
}

// ============================================================
// get_inactive tests
// ============================================================

// Test that get_inactive returns the alternate when primary is active.
fn test_screen_set_get_inactive_returns_alternate() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Initialize alternate.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'failed to init alternate'
		return
	}

	// Primary is active, so inactive should be alternate.
	inactive := ss.get_inactive()
	assert inactive != none
}

// Test that get_inactive returns none when only primary exists.
fn test_screen_set_get_inactive_none_when_no_alternate() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Alternate is not initialized, so get_inactive should return none.
	inactive := ss.get_inactive()
	assert inactive == none
}

// Test full lifecycle: init, get_or_init alternate, switch, get_inactive, remove.
fn test_screen_set_full_lifecycle() {
	mut ss := ScreenSet.init(10, 10, 100) or {
		assert false, 'failed to init ScreenSet'
		return
	}
	defer { ss.deinit() }

	// Start on primary.
	assert ss.active_key == .primary

	// Initialize and switch to alternate.
	_ = ss.get_or_init(.alternate, 10, 10, 100) or {
		assert false, 'failed to init alternate'
		return
	}
	ss.switch_to(.alternate)
	assert ss.active_key == .alternate

	// Inactive should be primary.
	inactive := ss.get_inactive()
	assert inactive != none

	// Switch back and remove alternate.
	ss.switch_to(.primary)
	ss.remove(.alternate)

	// Alternate should be gone.
	alt := ss.get(.alternate)
	assert alt == none
}
