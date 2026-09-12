module synthetic

// Generator is the common interface for synthetic byte producers. Zig writes
// into a caller-provided writer; the V translation returns the owned byte
// slice while preserving the same maximum-length contract.
pub interface Generator {
mut:
	next(max_len usize) ![]u8
}
