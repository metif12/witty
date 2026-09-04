module terminal

struct SizeTestWidget {
	x u32
	y u32
}

// Tests for size.v types.
// Translated from Ghostty's terminal/size.zig tests.
// Note: Zig pointer arithmetic tests are skipped as they are
// Zig-specific and not applicable to V's memory model.

// ============================================================
// Offset tests
// ============================================================

// Test that OffsetInt is u32 - this test is here so that if
// Offset changes, we can be very aware of this effect and
// think about the implications of it.
fn test_offset_int_is_u32() {
	// The offset field is u32, matching Zig's OffsetInt = u32.
	o := Offset{ offset: 42 }
	assert o.offset == u32(42)
}

// Test that Offset default is zero.
fn test_offset_default_zero() {
	o := Offset{}
	assert o.offset == u32(0)
}

// Test that OffsetSlice default is zero offset and zero length.
fn test_offset_slice_default() {
	s := OffsetSlice{}
	assert s.offset.offset == u32(0)
	assert s.len == 0
}

// ============================================================
// OffsetBuf tests
// ============================================================

// Test OffsetBuf.init creates a zero-offset buffer.
fn test_offset_buf_init() {
	buf := [4]u8{}
	ob := OffsetBuf.init(&buf[0])
	assert ob.offset == 0
}

// Test OffsetBuf.init_offset creates a buffer with the given offset.
fn test_offset_buf_init_offset() {
	buf := [4]u8{}
	ob := OffsetBuf.init_offset(&buf[0], 10)
	assert ob.offset == 10
}

// Test OffsetBuf.member computes offset against the true base.
fn test_offset_buf_member() {
	buf := [64]u8{}
	ob := OffsetBuf.init_offset(&buf[0], 8)
	m := ob.member(4)
	// member offset is ob.offset + len = 8 + 4 = 12
	assert m.offset == u32(12)
}

// Test OffsetBuf.add adds to the current offset.
fn test_offset_buf_add() {
	buf := [64]u8{}
	ob := OffsetBuf.init_offset(&buf[0], 8)
	ob2 := ob.add(4)
	assert ob2.offset == 12
}

// ============================================================
// Constants tests
// ============================================================

// Test that our size constants have the expected values.
fn test_size_constants() {
	assert cell_count_int_max == u16(65535)
	assert style_count_int_max == u16(65535)
	assert hyperlink_count_int_max == u16(65535)
	assert grapheme_bytes_int_max == u32(0xFFFFFFFF)
	assert string_bytes_int_max == u32(0xFFFFFFFF)
}

fn test_offset_ptr_u8() {
	buf := [64]u8{}
	offset := Offset{ offset: 42 }
	base := unsafe { &buf[0] }
	assert u64(offset.ptr(base)) == u64(base) + 42
}

fn test_offset_ptr_structural_alignment() {
	widgets := [5]SizeTestWidget{}
	base := unsafe { &u8(&widgets[0]) }
	expected := unsafe { &widgets[2] }
	offset := Offset{ offset: u32(sizeof(SizeTestWidget) * 2) }
	assert u64(offset.ptr(base)) == u64(expected)
}

fn test_get_offset_bytes() {
	bytes := 'ABCD'.bytes()
	actual := get_offset(&bytes[0], &bytes[2])
	assert actual.offset == 2
}

fn test_get_offset_structs() {
	widgets := [SizeTestWidget{ x: 1, y: 2 }, SizeTestWidget{ x: 3, y: 4 },
		SizeTestWidget{ x: 5, y: 6 }, SizeTestWidget{ x: 7, y: 8 }, SizeTestWidget{ x: 9, y: 10 }]
	base := unsafe { &u8(&widgets[0]) }
	ptr := unsafe { &u8(&widgets[2]) }
	actual := get_offset(base, ptr)
	assert actual.offset == u32(sizeof(SizeTestWidget) * 2)
}
