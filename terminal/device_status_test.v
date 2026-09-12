module terminal

// Tests for device_status.v (translated from device_status.zig)

fn test_device_status_tag_order() {
	// Zig test "order": tag with value=1 should pack to integer 1
	t := DeviceStatusTag.init(1, false)
	int_val := t.to_u16()
	assert int_val == u16(1)
	assert sizeof(DeviceStatusTag) == 2
}

fn test_device_status_tag_roundtrip() {
	t := DeviceStatusTag.init(996, true)
	packed := t.to_u16()
	unpacked := DeviceStatusTag.from_u16(packed)
	assert unpacked.value() == 996
	assert unpacked.question() == true
}

fn test_device_status_tag_no_question() {
	t := DeviceStatusTag.init(5, false)
	packed := t.to_u16()
	unpacked := DeviceStatusTag.from_u16(packed)
	assert unpacked.value() == 5
	assert unpacked.question() == false
}

fn test_device_status_req_from_int() {
	r1 := DeviceStatusRequest.from_int(5, false) or { panic('expected value') }
	assert r1 == .operating_status

	r2 := DeviceStatusRequest.from_int(6, false) or { panic('expected value') }
	assert r2 == .cursor_position

	r3 := DeviceStatusRequest.from_int(996, true) or { panic('expected value') }
	assert r3 == .color_scheme
}

fn test_device_status_req_from_int_invalid() {
	// Wrong question flag
	assert DeviceStatusRequest.from_int(5, true) == none
	assert DeviceStatusRequest.from_int(996, false) == none

	// Unknown value
	assert DeviceStatusRequest.from_int(999, false) == none
	assert DeviceStatusRequest.from_int(0, false) == none
}

fn test_device_status_req_tag() {
	r := DeviceStatusRequest.operating_status
	t := r.tag()
	assert t.value() == 5
	assert t.question() == false

	r2 := DeviceStatusRequest.color_scheme
	t2 := r2.tag()
	assert t2.value() == 996
	assert t2.question() == true
}

fn test_device_status_request_uses_packed_tag_values() {
	assert u16(DeviceStatusRequest.operating_status) == 5
	assert u16(DeviceStatusRequest.cursor_position) == 6
	assert u16(DeviceStatusRequest.color_scheme) == (u16(1) << 15) | 996
}
