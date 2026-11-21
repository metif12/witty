module datastruct

// MessageData accommodates payloads that fit in a small request, have stable
// backing storage, or require owned storage. Ghostty represents this as a
// tagged union, so only the active storage arm is retained.
//
// The source's small_size is a comptime integer and makes Small.data a fixed
// array. V has no integer generic parameters, so init receives that limit at
// runtime and the small arm owns a cloned V array. The active-arm semantics
// and stable-versus-owned behavior remain the same.
pub type MessageData[T] = MessageDataSmall[T] | MessageDataStable[T] | MessageDataAlloc[T]

pub struct MessageDataSmall[T] {
pub:
	data []T
}

pub struct MessageDataStable[T] {
pub:
	data []T
}

pub struct MessageDataAlloc[T] {
pub mut:
	data []T
}

// MessageDataKind is the declaration-order tag of Ghostty's union.
pub enum MessageDataKind as u8 {
	small
	stable
	alloc
}

// init copies data, selecting small when it fits and alloc otherwise. It can
// never infer caller-stable storage, matching the source constructor.
pub fn MessageData.init[T](small_size uint, data []T) MessageData[T] {
	if data.len <= int(small_size) {
		return MessageData[T](MessageDataSmall[T]{
			data: data.clone()
		})
	}
	return MessageData[T](MessageDataAlloc[T]{
		data: data.clone()
	})
}

// from_stable creates a payload backed directly by caller-stable memory.
pub fn MessageData.from_stable[T](data []T) MessageData[T] {
	return MessageData[T](MessageDataStable[T]{
		data: data
	})
}

// kind returns the compact source union tag.
pub fn (self MessageData[T]) kind[T]() MessageDataKind {
	return match self {
		MessageDataSmall[T] { .small }
		MessageDataStable[T] { .stable }
		MessageDataAlloc[T] { .alloc }
	}
}

// deinit releases owned allocated storage. Small and stable payloads require
// no ownership action, matching Ghostty's union.
pub fn (mut self MessageData[T]) deinit[T]() {
	match mut self {
		MessageDataSmall[T], MessageDataStable[T] {}
		MessageDataAlloc[T] {
			self.data = []T{}
		}
	}
}

// slice returns the payload regardless of its storage representation.
pub fn (self MessageData[T]) slice[T]() []T {
	return match self {
		MessageDataSmall[T] { self.data }
		MessageDataStable[T] { self.data }
		MessageDataAlloc[T] { self.data }
	}
}
