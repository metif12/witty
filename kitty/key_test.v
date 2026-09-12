module kitty

// Tests for Kitty keyboard protocol types.
//
// Source: kitty/key.zig (tests)

fn test_flags_int_disambiguate() {
	f := KeyFlags.init(true, false, false, false, false)
	assert f.int() == 0b00001
}

fn test_flags_int_report_events() {
	f := KeyFlags.init(false, true, false, false, false)
	assert f.int() == 0b00010
}

fn test_flags_int_disabled() {
	f := key_flags_disabled
	assert f.int() == 0
}

fn test_flags_int_all() {
	f := key_flags_all
	assert f.int() == 0b11111
	assert sizeof(KeyFlags) == 1
}

fn test_flags_from_int_roundtrip() {
	original := KeyFlags.init(true, false, true, false, true)
	v := original.int()
	restored := KeyFlags.from_int(v)
	assert restored.disambiguate() == true
	assert restored.report_events() == false
	assert restored.report_alternates() == true
	assert restored.report_all() == false
	assert restored.report_associated() == true
}

fn test_flag_stack_overflow() {
	// Make sure the overflow works as expected.
	mut stack := KeyFlagStack{}
	stack.idx = 7 // last position
	stack.idx = (stack.idx + 1) % 8
	assert stack.idx == 0

	stack.idx = 0
	// Wrapping decrement
	if stack.idx == 0 {
		stack.idx = 7
	} else {
		stack.idx -= 1
	}
	assert stack.idx == 7
}

fn test_flag_stack_push_pop() {
	mut stack := KeyFlagStack{}
	stack.push(KeyFlags.init(true, false, false, false, false))
	assert stack.current().disambiguate() == true

	stack.pop(1)
	assert stack.current() == key_flags_disabled
}

fn test_flag_stack_pop_big_number() {
	mut stack := KeyFlagStack{}
	stack.pop(100)
	assert stack.current() == key_flags_disabled
}

fn test_flag_stack_set() {
	mut stack := KeyFlagStack{}
	stack.set(.set_, KeyFlags.init(true, false, false, false, false))
	assert stack.current().disambiguate() == true
	assert stack.current().report_events() == false

	stack.set(.or_, KeyFlags.init(false, true, false, false, false))
	assert stack.current().disambiguate() == true
	assert stack.current().report_events() == true

	stack.set(.not_, KeyFlags.init(false, true, false, false, false))
	assert stack.current().disambiguate() == true
	assert stack.current().report_events() == false
}
