module terminal

fn test_find_free_chunks_single_found() {
	mut bitmaps := [
		u64(0b10000000_00000000_00000000_00000000_00000000_00000000_00001110_00000000),
	]
	idx := find_free_chunks(mut bitmaps, 2) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert idx == 9
	assert bitmaps[0] == u64(0b10000000_00000000_00000000_00000000_00000000_00000000_00001000_00000000)
}

fn test_find_free_chunks_single_not_found() {
	mut bitmaps := [
		u64(0b10000111_00000000_00000000_00000000_00000000_00000000_00000000_00000000),
	]
	r := find_free_chunks(mut bitmaps, 4)
	assert r == none
}

fn test_find_free_chunks_multiple_found() {
	mut bitmaps := [
		u64(0b10000111_00000000_00000000_00000000_00000000_00000000_00000000_01110000),
		u64(0b10000000_00111110_00000000_00000000_00000000_00000000_00111110_00000000),
	]
	idx := find_free_chunks(mut bitmaps, 4) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert idx == 73
	assert bitmaps[1] == u64(0b10000000_00111110_00000000_00000000_00000000_00000000_00100000_00000000)
}

fn test_find_free_chunks_exactly_64() {
	mut bitmaps := [
		~u64(0),
	]
	idx := find_free_chunks(mut bitmaps, 64) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert bitmaps[0] == u64(0)
	assert idx == 0
}

fn test_find_free_chunks_larger_than_64() {
	mut bitmaps := [
		~u64(0),
		~u64(0),
	]
	idx := find_free_chunks(mut bitmaps, 65) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert bitmaps[0] == u64(0)
	assert bitmaps[1] == u64(0b11111111_11111111_11111111_11111111_11111111_11111111_11111111_11111110)
	assert idx == 0
}

fn test_find_free_chunks_larger_than_64_not_at_beginning() {
	mut bitmaps := [
		u64(0b11111111_00000000_00000000_00000000_00000000_00000000_00000000_00000000),
		~u64(0),
		~u64(0),
	]
	idx := find_free_chunks(mut bitmaps, 65) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert bitmaps[0] == u64(0)
	assert bitmaps[1] == u64(0b11111110_00000000_00000000_00000000_00000000_00000000_00000000_00000000)
	assert bitmaps[2] == ~u64(0)
	assert idx == 56
}

fn test_find_free_chunks_larger_than_64_exact() {
	mut bitmaps := [
		~u64(0),
		~u64(0),
	]
	idx := find_free_chunks(mut bitmaps, 128) or {
		assert false, 'expected to find free chunks'
		return
	}
	assert bitmaps[0] == u64(0)
	assert bitmaps[1] == u64(0)
	assert idx == 0
}

fn test_bitmap_allocator_layout() {
	chunk_size := 4
	cap := usize(64 * 4)
	l := bitmap_allocator_layout(cap, chunk_size)

	// We expect to use one bitmap since the cap is bytes.
	assert l.bitmap_count == 1
}

fn test_bitmap_allocator_alloc_sequentially() {
	chunk_size := 4
	cap := usize(64)
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	off1 := bm.alloc(1) or {
		assert false, 'alloc failed'
		return
	}
	bm.chunks[off1] = u8(`A`)

	off2 := bm.alloc(1) or {
		assert false, 'alloc2 failed'
		return
	}
	assert off1 != off2

	// Should grab the next chunk
	assert off2 == off1 + 4

	// Free off1 and next allocation should be back
	bm.release(off1, 1)
	off3 := bm.alloc(1) or {
		assert false, 'alloc3 failed'
		return
	}
	assert off3 == off1
}

fn test_bitmap_allocator_alloc_large() {
	chunk_size := 2
	cap := usize(256)
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	off := bm.alloc(129) or {
		assert false, 'alloc failed'
		return
	}
	bm.chunks[off] = u8(`A`)
	bm.release(off, 129)
}

fn test_bitmap_allocator_alloc_and_free_one_bitmap() {
	chunk_size := 1
	// Capacity such that we'll have 3 bitmaps.
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	// Allocate exactly one bitmap worth of bytes.
	alloc_size := bitmap_bit_size
	off := bm.alloc(alloc_size) or {
		assert false, 'alloc failed'
		return
	}

	// Fill the allocated region
	for i in 0 .. alloc_size {
		bm.chunks[off + i] = 0x11
	}

	// Verify fill
	for i in 0 .. alloc_size {
		assert bm.chunks[off + i] == 0x11
	}

	// Free it
	assert bm.is_allocated(off, alloc_size)
	bm.release(off, alloc_size)
	assert !bm.is_allocated(off, alloc_size)

	// All of our bitmaps should be free.
	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

fn test_bitmap_allocator_alloc_and_free_half_bitmap() {
	chunk_size := 1
	// Capacity such that we'll have 3 bitmaps.
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	// Allocate exactly half a bitmap worth of bytes.
	alloc_size := bitmap_bit_size / 2
	off := bm.alloc(alloc_size) or {
		assert false, 'alloc failed'
		return
	}
	assert off == 0

	// Fill the allocated region
	for i in 0 .. alloc_size {
		bm.chunks[off + i] = 0x11
	}

	// Free it
	assert bm.is_allocated(off, alloc_size)
	bm.release(off, alloc_size)
	assert !bm.is_allocated(off, alloc_size)

	// All of our bitmaps should be free.
	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

fn test_bitmap_allocator_alloc_and_free_two_half_bitmaps() {
	chunk_size := 1
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	alloc_size := bitmap_bit_size / 2

	// Allocate exactly one bitmap worth of bytes across two allocations.
	off1 := bm.alloc(alloc_size) or {
		assert false, 'alloc1 failed'
		return
	}
	for i in 0 .. alloc_size {
		bm.chunks[off1 + i] = 0x11
	}

	off2 := bm.alloc(alloc_size) or {
		assert false, 'alloc2 failed'
		return
	}
	for i in 0 .. alloc_size {
		bm.chunks[off2 + i] = 0x22
	}

	// Verify fills are intact
	for i in 0 .. alloc_size {
		assert bm.chunks[off1 + i] == 0x11
	}
	for i in 0 .. alloc_size {
		assert bm.chunks[off2 + i] == 0x22
	}

	// Free them
	assert bm.is_allocated(off2, alloc_size)
	bm.release(off2, alloc_size)
	assert !bm.is_allocated(off2, alloc_size)
	assert bm.is_allocated(off1, alloc_size)
	bm.release(off1, alloc_size)
	assert !bm.is_allocated(off1, alloc_size)

	// All of our bitmaps should be free.
	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

fn test_bitmap_allocator_alloc_and_free_1_5_bitmaps() {
	chunk_size := 1
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	// Allocate exactly 1.5 bitmaps worth of bytes.
	alloc_size := 3 * bitmap_bit_size / 2
	off := bm.alloc(alloc_size) or {
		assert false, 'alloc failed'
		return
	}

	for i in 0 .. alloc_size {
		bm.chunks[off + i] = 0x11
	}

	// Free it
	assert bm.is_allocated(off, alloc_size)
	bm.release(off, alloc_size)
	assert !bm.is_allocated(off, alloc_size)

	// All bitmaps should be free.
	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

fn test_bitmap_allocator_bytes_required() {
	// Chunk size of 16 bytes
	{
		l := bitmap_allocator_layout(1024, 16)
		bm := BitmapAllocator.init(16, l)

		// Single byte rounds up to chunk size
		assert bm.bytes_required(1, 1) == 16
		assert bm.bytes_required(1, 16) == 16
		assert bm.bytes_required(1, 17) == 32
		assert bm.bytes_required(4, 1) == 16
		assert bm.bytes_required(4, 4) == 16
		assert bm.bytes_required(4, 5) == 32
		assert bm.bytes_required(4, 6) == 32
	}

	// Chunk size of 4 bytes
	{
		l := bitmap_allocator_layout(1024, 4)
		bm := BitmapAllocator.init(4, l)

		assert bm.bytes_required(1, 1) == 4
		assert bm.bytes_required(1, 4) == 4
		assert bm.bytes_required(1, 5) == 8

		// u32 (4 bytes each) - exactly one chunk per element
		assert bm.bytes_required(4, 1) == 4
		assert bm.bytes_required(4, 2) == 8
	}

	// Chunk size of 32 bytes
	{
		l := bitmap_allocator_layout(2048, 32)
		bm := BitmapAllocator.init(32, l)

		assert bm.bytes_required(1, 1) == 32
		assert bm.bytes_required(1, 32) == 32
		assert bm.bytes_required(1, 33) == 64
	}
}

// Test alloc non-byte (element size 4, one chunk each).
fn test_bitmap_allocator_alloc_non_byte() {
	chunk_size := 4
	cap := usize(128)
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	sz := bm.bytes_required(4, 1)
	off1 := bm.alloc(sz) or {
		assert false, 'alloc failed'
		return
	}
	bm.chunks[off1] = u8(`A`)

	off2 := bm.alloc(sz) or {
		assert false, 'alloc2 failed'
		return
	}
	assert off1 != off2
	assert off2 == off1 + 4

	// Free off1 and next allocation should be back.
	bm.release(off1, sz)
	off3 := bm.alloc(sz) or {
		assert false, 'alloc3 failed'
		return
	}
	assert off3 == off1
}

// Test alloc non-byte spanning multiple chunks.
fn test_bitmap_allocator_alloc_non_byte_multi_chunk() {
	chunk_size := 4 * 4
	cap := usize(128)
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	// 6 elements of size 4 = 24 bytes, aligned up to 2 chunks (32 bytes).
	sz := bm.bytes_required(4, 6)
	off1 := bm.alloc(sz) or {
		assert false, 'alloc failed'
		return
	}
	for i in 0 .. sz {
		bm.chunks[off1 + i] = u8(`A`)
	}

	sz2 := bm.bytes_required(4, 1)
	off2 := bm.alloc(sz2) or {
		assert false, 'alloc2 failed'
		return
	}
	assert off1 != off2
	assert off2 == off1 + (4 * 4 * 2)

	bm.release(off1, sz)
	off3 := bm.alloc(sz2) or {
		assert false, 'alloc3 failed'
		return
	}
	assert off3 == off1
}

// Test alloc and free two 1.5 bitmaps.
fn test_bitmap_allocator_alloc_and_free_two_1_5_bitmaps() {
	chunk_size := 1
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	size := 3 * bitmap_bit_size / 2
	off := bm.alloc(size) or {
		assert false, 'alloc failed'
		return
	}
	for i in 0 .. size {
		bm.chunks[off + i] = 0x11
	}

	off2 := bm.alloc(size) or {
		assert false, 'alloc2 failed'
		return
	}
	for i in 0 .. size {
		bm.chunks[off2 + i] = 0x22
	}
	// The first region must be undisturbed.
	for i in 0 .. size {
		assert bm.chunks[off + i] == 0x11
	}
	for i in 0 .. size {
		assert bm.chunks[off2 + i] == 0x22
	}

	assert bm.is_allocated(off2, size)
	bm.release(off2, size)
	assert !bm.is_allocated(off2, size)
	assert bm.is_allocated(off, size)
	bm.release(off, size)
	assert !bm.is_allocated(off, size)

	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

// Test alloc and free 1.5 bitmaps offset by 0.75 (spans 3 bitmaps).
fn test_bitmap_allocator_alloc_and_free_1_5_bitmaps_offset_0_75() {
	chunk_size := 1
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	size1 := 3 * bitmap_bit_size / 4
	off := bm.alloc(size1) or {
		assert false, 'alloc failed'
		return
	}
	for i in 0 .. size1 {
		bm.chunks[off + i] = 0x11
	}

	// A 1.5 bitmap allocation spans 0.75 -> 2.25, occupying 3 bitmaps.
	size2 := 3 * bitmap_bit_size / 2
	off2 := bm.alloc(size2) or {
		assert false, 'alloc2 failed'
		return
	}
	for i in 0 .. size2 {
		bm.chunks[off2 + i] = 0x22
	}
	for i in 0 .. size1 {
		assert bm.chunks[off + i] == 0x11
	}
	for i in 0 .. size2 {
		assert bm.chunks[off2 + i] == 0x22
	}

	assert bm.is_allocated(off2, size2)
	bm.release(off2, size2)
	assert !bm.is_allocated(off2, size2)
	assert bm.is_allocated(off, size1)
	bm.release(off, size1)
	assert !bm.is_allocated(off, size1)

	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

// Test alloc and free three 0.75 bitmaps.
fn test_bitmap_allocator_alloc_and_free_three_0_75_bitmaps() {
	chunk_size := 1
	cap := bitmap_bit_size * 3
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	size := 3 * bitmap_bit_size / 4
	off := bm.alloc(size) or {
		assert false, 'alloc failed'
		return
	}
	for i in 0 .. size {
		bm.chunks[off + i] = 0x11
	}

	off2 := bm.alloc(size) or {
		assert false, 'alloc2 failed'
		return
	}
	for i in 0 .. size {
		bm.chunks[off2 + i] = 0x22
	}

	off3 := bm.alloc(size) or {
		assert false, 'alloc3 failed'
		return
	}
	for i in 0 .. size {
		bm.chunks[off3 + i] = 0x33
	}

	for i in 0 .. size {
		assert bm.chunks[off + i] == 0x11
	}
	for i in 0 .. size {
		assert bm.chunks[off2 + i] == 0x22
	}
	for i in 0 .. size {
		assert bm.chunks[off3 + i] == 0x33
	}

	assert bm.is_allocated(off2, size)
	bm.release(off2, size)
	assert !bm.is_allocated(off2, size)
	assert bm.is_allocated(off, size)
	bm.release(off, size)
	assert !bm.is_allocated(off, size)
	assert bm.is_allocated(off3, size)
	bm.release(off3, size)
	assert !bm.is_allocated(off3, size)

	for bi in 0 .. 3 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}

// Test alloc and free two 1.5 bitmaps offset 0.75 (4 bitmaps).
fn test_bitmap_allocator_alloc_and_free_two_1_5_bitmaps_offset_0_75() {
	chunk_size := 1
	cap := bitmap_bit_size * 4
	l := bitmap_allocator_layout(cap, chunk_size)
	mut bm := BitmapAllocator.init(chunk_size, l)

	size1 := 3 * bitmap_bit_size / 4
	off := bm.alloc(size1) or {
		assert false, 'alloc failed'
		return
	}
	for i in 0 .. size1 {
		bm.chunks[off + i] = 0x11
	}

	size2 := 3 * bitmap_bit_size / 2
	off2 := bm.alloc(size2) or {
		assert false, 'alloc2 failed'
		return
	}
	for i in 0 .. size2 {
		bm.chunks[off2 + i] = 0x22
	}

	off3 := bm.alloc(size2) or {
		assert false, 'alloc3 failed'
		return
	}
	for i in 0 .. size2 {
		bm.chunks[off3 + i] = 0x33
	}

	for i in 0 .. size2 {
		assert bm.chunks[off3 + i] == 0x33
	}
	for i in 0 .. size2 {
		assert bm.chunks[off2 + i] == 0x22
	}
	for i in 0 .. size1 {
		assert bm.chunks[off + i] == 0x11
	}

	assert bm.is_allocated(off2, size2)
	bm.release(off2, size2)
	assert !bm.is_allocated(off2, size2)
	assert bm.is_allocated(off, size1)
	bm.release(off, size1)
	assert !bm.is_allocated(off, size1)
	assert bm.is_allocated(off3, size2)
	bm.release(off3, size2)
	assert !bm.is_allocated(off3, size2)

	for bi in 0 .. 4 {
		assert bm.bitmaps[bi] == ~u64(0)
	}
}
