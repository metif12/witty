module terminal

struct SizeTestWidget {
	x u32
	y u32
}

// Tests for size.v types, translated from Ghostty's terminal/size.zig tests.

// ============================================================
// Offset tests
// ============================================================

// Test that OffsetInt is u32 - this test is here so that if
// Offset changes, we can be very aware of this effect and
// think about the implications of it.
fn test_offset_int_is_u32() {
	assert sizeof(OffsetInt) == sizeof(u32)
	o := Offset{ offset: 42 }
	assert o.offset == OffsetInt(42)
}

// Test that Offset default is zero.
fn test_offset_default_zero() {
	o := Offset{}
	assert o.offset == OffsetInt(0)
}

// Test that OffsetSlice default is zero offset and zero length.
fn test_offset_slice_default() {
	s := OffsetSlice{}
	assert s.offset.offset == OffsetInt(0)
	assert s.len == 0
}

fn test_offset_slice_view() {
	mut bytes := 'ABCD'.bytes()
	s := OffsetSlice{
		offset: Offset{ offset: 1 }
		len: 2
	}
	base := unsafe { &bytes[0] }
	mut view := s.slice(base)
	assert view.bytestr() == 'BC'
	view[0] = `X`
	assert bytes.bytestr() == 'AXCD'
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
	assert m.offset == OffsetInt(12)
}

// Test OffsetBuf.add adds to the current offset.
fn test_offset_buf_add() {
	buf := [64]u8{}
	ob := OffsetBuf.init_offset(&buf[0], 8)
	ob2 := ob.add(4)
	assert ob2.offset == 12
}

fn test_offset_buf_rebase() {
	buf := [64]u8{}
	ob := OffsetBuf.init_offset(&buf[0], 8)
	rebased := ob.rebase(4)
	assert rebased.offset == 0
	base := unsafe { &buf[0] }
	assert u64(rebased.base) == u64(base) + 12
}

// ============================================================
// Constants tests
// ============================================================

// Test that our size constants have the expected values.
fn test_size_constants() {
	assert sizeof(CellCountInt) == sizeof(u16)
	assert sizeof(StyleCountInt) == sizeof(u16)
	assert sizeof(HyperlinkCountInt) == sizeof(u16)
	assert sizeof(GraphemeBytesInt) == sizeof(u32)
	assert sizeof(StringBytesInt) == sizeof(u32)
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
	offset := Offset{ offset: OffsetInt(sizeof(SizeTestWidget) * 2) }
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
	assert actual.offset == OffsetInt(sizeof(SizeTestWidget) * 2)
}
