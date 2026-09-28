module lru

// KV is the key/value pair returned when an insertion evicts the least
// recently used entry.
pub struct KV[K, V] {
pub:
	key   K
	value V
}

// GetOrPutResult matches Ghostty's getOrPut result. value_ptr always points
// at the cache-owned value storage and may be overwritten by the caller.
pub struct GetOrPutResult[K, V] {
pub mut:
	value_ptr &V
	// These are immutable by convention; V groups them with value_ptr so the
	// pointed-to value can be updated through the result.
	found_existing bool
	evicted        ?KV[K, V]
}

@[heap]
struct Entry[K, V] {
mut:
	key   K
	value V
	next  ?&Entry[K, V]
	prev  ?&Entry[K, V]
}

// HashMap is Ghostty's elementary hashmap-backed least-recently-used cache.
// get_or_put marks an entry as most recently used; get intentionally does not
// change recency.
pub struct HashMap[K, V] {
mut:
	items map[K]&Entry[K, V]
	first ?&Entry[K, V]
	last  ?&Entry[K, V]
pub mut:
	capacity int
}

// new_auto_hash_map constructs the V equivalent of Ghostty's AutoHashMap.
pub fn new_auto_hash_map[K, V](capacity int) HashMap[K, V] {
	assert capacity >= 0
	return HashMap[K, V]{
		items:    map[K]&Entry[K, V]{}
		capacity: capacity
	}
}

pub fn (mut self HashMap[K, V]) deinit() {
	self.items.clear()
	self.first = none
	self.last = none
}

// get_or_put returns existing storage or inserts a new key. Insertion beyond
// capacity reuses and reports the least-recently-used entry.
pub fn (mut self HashMap[K, V]) get_or_put(key K) GetOrPutResult[K, V] {
	if key in self.items {
		entry := self.items[key] or { panic('LRU map entry disappeared') }
		return self.found_entry(entry)
	}
	return self.insert_entry(key)
}

// get_or_put_context performs the source HashMap's context-aware lookup. A
// valid context must return the same hash for keys it considers equal; the V
// map remains only the ownership index while equality is decided by ctx.
pub fn (mut self HashMap[K, V]) get_or_put_context[X](key K, ctx X) GetOrPutResult[K, V] {
	_ = ctx.hash(key)
	mut current := self.first
	for current != none {
		entry := current or { break }
		if ctx.eql(entry.key, key) {
			return self.found_entry(entry)
		}
		current = entry.next
	}
	return self.insert_entry(key)
}

fn (mut self HashMap[K, V]) found_entry(entry &Entry[K, V]) GetOrPutResult[K, V] {
	self.remove_entry(entry)
	self.append_entry(entry)
	return GetOrPutResult[K, V]{
		value_ptr:      &entry.value
		found_existing: true
	}
}

fn (mut self HashMap[K, V]) insert_entry(key K) GetOrPutResult[K, V] {
	if self.items.len < self.capacity {
		mut entry := &Entry[K, V]{}
		entry.key = key
		self.append_entry(entry)
		self.items[key] = entry
		return GetOrPutResult[K, V]{
			value_ptr: &entry.value
		}
	}

	least_used := self.pop_first_entry() or { panic('cannot insert into a zero-capacity LRU') }
	evicted_value := least_used.value
	self.items.delete(least_used.key)
	mut entry := unsafe { least_used }
	entry.key = key
	self.append_entry(entry)
	self.items[key] = entry
	return GetOrPutResult[K, V]{
		value_ptr: &entry.value
		// Ghostty copies entry.data after reassigning its key. Preserve that
		// source order: the returned key is the inserted key while the value is
		// still the evicted value until the caller initializes value_ptr.
		evicted:   KV[K, V]{
			key:   entry.key
			value: evicted_value
		}
	}
}

pub fn (self &HashMap[K, V]) get(key K) ?V {
	entry := self.items[key] or { return none }
	return entry.value
}

// get_context returns the value whose key is equal according to ctx without
// changing recency, matching getContext in the pinned implementation.
pub fn (self &HashMap[K, V]) get_context[X](key K, ctx X) ?V {
	_ = ctx.hash(key)
	mut current := self.first
	for current != none {
		entry := current or { break }
		if ctx.eql(entry.key, key) {
			return entry.value
		}
		current = entry.next
	}
	return none
}

pub fn (self &HashMap[K, V]) len() int {
	return self.items.len
}

// resize changes the eviction capacity. Shrinking below the current size
// removes least-recently-used entries and returns their values in LRU order.
pub fn (mut self HashMap[K, V]) resize(capacity int) ?[]V {
	assert capacity >= 0
	if capacity >= self.capacity {
		self.capacity = capacity
		return none
	}
	if self.items.len <= capacity {
		self.capacity = capacity
		return none
	}

	delta := self.items.len - capacity
	mut evicted := []V{cap: delta}
	for _ in 0 .. delta {
		entry := self.pop_first_entry() or { panic('LRU queue and map are out of sync') }
		evicted << entry.value
		self.items.delete(entry.key)
	}
	self.capacity = capacity
	assert self.items.len == capacity
	return evicted
}

fn (mut self HashMap[K, V]) append_entry(entry &Entry[K, V]) {
	unsafe {
		mut inserted := entry
		inserted.next = none
		inserted.prev = self.last
		if last := self.last {
			mut last_entry := last
			last_entry.next = entry
		} else {
			self.first = entry
		}
		self.last = entry
	}
}

fn (mut self HashMap[K, V]) remove_entry(entry &Entry[K, V]) {
	if previous := entry.prev {
		unsafe {
			mut previous_entry := previous
			previous_entry.next = entry.next
		}
	} else {
		self.first = entry.next
	}
	if next := entry.next {
		unsafe {
			mut next_entry := next
			next_entry.prev = entry.prev
		}
	} else {
		self.last = entry.prev
	}
}

fn (mut self HashMap[K, V]) pop_first_entry() ?&Entry[K, V] {
	entry := self.first or { return none }
	self.remove_entry(entry)
	return entry
}
