module terminal

import math.bits

// A relatively naive bitmap allocator that uses bitmaps to track
// which chunks of memory are free or in use.
//
// The chunk size determines the size of each chunk in bytes. This is the
// minimum distributed unit of memory. For example, if you request a
// 1-byte allocation, you'll use a chunk of chunk_size bytes. Likewise,
// if your chunk size is 4, and you request a 5-byte allocation, you'll
// use 2 chunks.
//
// The allocator is susceptible to fragmentation. If you allocate and free
// memory in a way that leaves small holes in the memory, you may not be
// able to allocate large chunks of memory even if there is enough free
// memory in aggregate. To avoid fragmentation, use a chunk size that is
// large enough to cover most of your allocations.

const bitmap_bit_size = 64

// BitmapAllocatorLayout describes the memory layout for a BitmapAllocator.
pub struct BitmapAllocatorLayout {
pub:
	total_size   int
	bitmap_count int
	bitmap_start int
	chunks_start int
}

// BitmapAllocator manages a pool of fixed-size chunks using bitmaps.
// Each bit in the bitmap represents a chunk: 1 = free, 0 = used.
// We use 1 for free since it makes it very slightly faster to find
// free chunks.
pub struct BitmapAllocator {
pub mut:
	chunk_size int
	// The bitmap of available chunks. Each bit represents a chunk. A
	// 1 means the chunk is free and a 0 means it's used.
	bitmaps []u64
	// The contiguous buffer of chunks.
	chunks []u8
}

// bitmap_allocator_layout computes the layout for a given capacity and
// chunk_size. The capacity is in number of bytes, not chunks. The capacity
// will likely be rounded up to the nearest chunk size and bitmap size so
// everything is perfectly divisible.
pub fn bitmap_allocator_layout(cap int, chunk_size int) BitmapAllocatorLayout {
	// Align the cap forward to our chunk size so we always have
	// a full chunk at the end.
	aligned_cap := align_forward(cap, chunk_size)

	// Calculate the number of bitmaps. We need 1 bitmap per 64 chunks.
	// We align the chunk count forward so our bitmaps are full so we
	// don't have to handle the case where we have a partial bitmap.
	chunk_count := aligned_cap / chunk_size
	aligned_chunk_count := align_forward(chunk_count, 64)
	bm_count := aligned_chunk_count / 64

	bitmap_start := 0
	bitmap_end := 8 * bm_count // 8 bytes per u64
	chunks_start := align_forward(bitmap_end, 1)
	chunks_end := chunks_start + (aligned_cap * chunk_size)
	total := chunks_end

	return BitmapAllocatorLayout{
		total_size:   total
		bitmap_count: bm_count
		bitmap_start: bitmap_start
		chunks_start: chunks_start
	}
}

// init initializes the allocator with the given layout.
// All chunks are marked as free.
pub fn BitmapAllocator.init(chunk_size int, l BitmapAllocatorLayout) BitmapAllocator {
	// Initialize our bitmaps to all 1s to note that all chunks are free.
	mut bms := []u64{len: l.bitmap_count, init: ~u64(0)}
	total_chunks := l.bitmap_count * bitmap_bit_size
	chk := []u8{len: total_chunks * chunk_size}

	return BitmapAllocator{
		chunk_size: chunk_size
		bitmaps:    bms
		chunks:     chk
	}
}

// bytes_required returns the number of bytes required to allocate n elements
// of size element_size. This accounts for the chunk size alignment used by
// the bitmap allocator.
pub fn (self &BitmapAllocator) bytes_required(element_size int, n int) int {
	byte_count := element_size * n
	return align_forward(byte_count, self.chunk_size)
}

// alloc allocates n contiguous chunks worth of bytes.
// Returns the byte offset into the chunks buffer, or none if out of memory.
pub fn (mut self BitmapAllocator) alloc(n_bytes int) ?int {
	if n_bytes <= 0 {
		return none
	}
	chunk_count := div_ceil(n_bytes, self.chunk_size)

	// Find free chunks. This also marks them as used.
	idx := find_free_chunks(mut self.bitmaps, chunk_count) or { return none }

	return idx * self.chunk_size
}

// release marks the chunks starting at byte offset `start` spanning `n_bytes` as free.
pub fn (mut self BitmapAllocator) release(start int, n_bytes int) {
	aligned_len := align_forward(n_bytes, self.chunk_size)
	chunk_count := aligned_len / self.chunk_size
	chunk_idx := start / self.chunk_size

	// Current bitmap index.
	mut i := chunk_idx / 64
	// Number of chunks we still have to mark as free.
	mut rem := chunk_count

	// Mark any bits in the starting bitmap that need to be marked.
	{
		// Bit index.
		bit := chunk_idx % 64
		// Number of bits we need to mark in this bitmap.
		nbits := min_int(rem, 64 - bit)

		self.bitmaps[i] |= (~u64(0) >> u64(64 - nbits)) << u64(bit)
		rem -= nbits
	}

	// Mark any full bitmaps worth of bits that need to be marked.
	i += 1
	for rem > 64 {
		self.bitmaps[i] = ~u64(0)
		rem -= 64
		i += 1
	}

	// Mark any bits at the start of this last bitmap if it needs it.
	if rem > 0 {
		self.bitmaps[i] |= ~u64(0) >> u64(64 - rem)
	}
}

// capacity_bytes returns the total capacity in bytes.
pub fn (self &BitmapAllocator) capacity_bytes() int {
	return self.bitmaps.len * bitmap_bit_size * self.chunk_size
}

// used_bytes returns the number of bytes currently in use.
pub fn (self &BitmapAllocator) used_bytes() int {
	mut free_chunks := 0
	for bm in self.bitmaps {
		free_chunks += bits.ones_count_64(bm)
	}
	total_chunks := self.bitmaps.len * bitmap_bit_size
	return (total_chunks - free_chunks) * self.chunk_size
}

// is_allocated returns true if all chunks covered by the given range are allocated.
// For testing only.
fn (self &BitmapAllocator) is_allocated(start int, n_bytes int) bool {
	aligned_len := align_forward(n_bytes, self.chunk_size)
	chunk_count := aligned_len / self.chunk_size
	chunk_idx := start / self.chunk_size

	for ci in chunk_idx .. chunk_idx + chunk_count {
		bm_idx := ci / bitmap_bit_size
		bit := ci % bitmap_bit_size
		if (self.bitmaps[bm_idx] & (u64(1) << u64(bit))) != 0 {
			return false
		}
	}

	return true
}

// find_free_chunks finds `n` sequential free chunks in the given bitmaps and
// returns the index of the first chunk. If no chunks are found, returns none.
// This also updates the bitmap to mark the chunks as used.
fn find_free_chunks(mut bitmaps []u64, n int) ?int {
	// NOTE: This is a naive implementation that just iterates through the
	// bitmaps. There is very likely a more efficient way to do this but
	// I'm not a bit twiddling expert. Perhaps even SIMD could be used here
	// but unsure. Contributor friendly: let's benchmark and improve this!

	// Large chunks require special handling.
	if n > 64 {
		mut i := 0
		for i < bitmaps.len {
			// Number of chunks available at the end of this bitmap.
			prefix := bits.leading_zeros_64(~bitmaps[i])

			// If there are no chunks available at the end of this bitmap
			// then we can't start in it, so we'll try the next one.
			if prefix == 0 {
				i += 1
				continue
			}

			// Starting position if we manage to find the span we need here.
			start_bitmap := i
			start_bit := 64 - prefix

			// The remaining number of sequential free chunks we need to find.
			mut rem := n - prefix

			i += 1
			mut found := true
			for rem > 64 {
				// We ran out of bitmaps, there's no sufficiently large gap.
				if i >= bitmaps.len {
					return none
				}

				// There's more than 64 remaining chunks and this bitmap has
				// content in it, so we try starting again with this bitmap.
				if bitmaps[i] != ~u64(0) {
					found = false
					break
				}

				// This bitmap is completely free, we can subtract 64 from
				// our remaining number.
				rem -= 64
				i += 1
			}

			if !found {
				continue
			}

			// If the number of available chunks at the start of this bitmap
			// is less than the remaining required, we have to try again.
			if i >= bitmaps.len {
				return none
			}
			if bits.trailing_zeros_64(~bitmaps[i]) < rem {
				continue
			}

			suffix := (n - prefix) % 64

			// Found! Mark everything between our start and end as full.
			bitmaps[start_bitmap] ^= ~u64(0) >> u64(start_bit) << u64(start_bit)
			full_bitmaps := (n - prefix - suffix) / 64
			for fi in 0 .. full_bitmaps {
				bitmaps[start_bitmap + 1 + fi] = 0
			}
			if suffix > 0 {
				bitmaps[i] ^= ~u64(0) >> u64(64 - suffix)
			}

			return start_bitmap * 64 + start_bit
		}

		return none
	}

	// Small chunks (n <= 64): use bit shifting to find sequential 1s.
	for idx in 0 .. bitmaps.len {
		bm := bitmaps[idx]
		// Shift the bitmap to find `n` sequential free chunks.
		// EXAMPLE:
		// n = 4
		// shifted = 001111001011110010
		//         & 000111100101111001
		//         & 000011110010111100
		//         & 000001111001011110
		//         = 000001000000010000
		//                ^       ^
		// In this example there are 2 places with at least 4 sequential 1s.
		mut shifted := bm
		for si in 1 .. n {
			shifted &= bm >> u64(si)
		}

		// If we have zero then we have no matches
		if shifted == 0 {
			continue
		}

		// Trailing zeroes gets us the index of the first bit index with at
		// least `n` sequential 1s. In the example above, that would be `4`.
		bit := bits.trailing_zeros_64(shifted)

		// Calculate the mask so we can mark it as used
		mask := (~u64(0) >> u64(64 - n)) << u64(bit)
		bitmaps[idx] ^= mask

		return idx * 64 + bit
	}

	return none
}

// align_forward aligns val up to the given alignment.
fn align_forward(val int, alignment int) int {
	if alignment <= 0 {
		return val
	}
	return ((val + alignment - 1) / alignment) * alignment
}

// div_ceil divides a by b, rounding up.
fn div_ceil(a int, b int) int {
	return (a + b - 1) / b
}

// min_int returns the smaller of two ints.
fn min_int(a int, b int) int {
	if a < b {
		return a
	}
	return b
}
