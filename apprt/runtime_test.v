module apprt

// Test Runtime enum values.
fn test_runtime_enum() {
	assert Runtime.none_ == .none_
	assert Runtime.gtk == .gtk
	assert sizeof(Runtime) == 1
	$if linux {
		assert Runtime.default() == .gtk
	} $else $if freebsd {
		assert Runtime.default() == .gtk
	} $else {
		assert Runtime.default() == .none_
	}
}
