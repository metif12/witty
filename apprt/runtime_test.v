module apprt

// Test Runtime enum values.
fn test_runtime_enum() {
	assert Runtime.none_ == .none_
	assert Runtime.gtk == .gtk
}
