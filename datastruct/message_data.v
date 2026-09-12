module datastruct

// MessageDataKind identifies the storage selected for a message payload.
pub enum MessageDataKind as u8 {
	small
	stable
	alloc
}

// MessageData accommodates payloads that fit in a small request, have stable
// backing storage, or require owned storage. This is the V representation of
// Ghostty's tagged MessageData union.
//
// V arrays are GC-managed rather than allocator-owned. We retain the same
// ownership choices and observable tags: init copies into small/alloc storage,
// while from_stable passes its backing array through unchanged.
pub struct MessageData[T] {
pub:
	kind MessageDataKind
mut:
	small  []T
	stable []T
	alloc  []T
}

// init copies data, selecting small when it fits and alloc otherwise.
pub fn MessageData.init[T](small_size usize, data []T) MessageData[T] {
	if data.len <= int(small_size) {
		return MessageData[T]{
			kind: .small
			small: data.clone()
		}
	}
	return MessageData[T]{
		kind: .alloc
		alloc: data.clone()
	}
}

// from_stable creates a payload backed directly by caller-stable memory.
pub fn MessageData.from_stable[T](data []T) MessageData[T] {
	return MessageData[T]{
		kind: .stable
		stable: data
	}
}

// deinit releases owned allocated storage. Small and stable payloads require
// no ownership action, matching Ghostty's union.
pub fn (mut self MessageData[T]) deinit() {
	if self.kind == .alloc {
		self.alloc = []T{}
	}
}

// slice returns the payload regardless of its storage representation.
pub fn (self &MessageData[T]) slice() []T {
	return match self.kind {
		.small { self.small }
		.stable { self.stable }
		.alloc { self.alloc }
	}
}
