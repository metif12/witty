module datastruct

// Faithful specialization of Ghostty's datastruct.CacheTable for the
// shaper cache. Ghostty configures that cache with an identity u64 hash,
// 256 buckets, and 8 entries per bucket.
const cache_table_bucket_count = 256
const cache_table_bucket_size = 8

pub struct U64CacheEntry[T] {
pub:
	key   u64
	value T
}

// U64CacheTable is a fixed-capacity, bucketed LRU cache. Entries within a
// bucket are ordered from least to most recently used.
pub struct U64CacheTable[T] {
mut:
	buckets [][]U64CacheEntry[T]
	count_  int
}

pub fn U64CacheTable.init[T]() U64CacheTable[T] {
	return U64CacheTable[T]{
		buckets: [][]U64CacheEntry[T]{len: cache_table_bucket_count}
	}
}

// put appends a value to its bucket, evicting the least-recently-used entry
// when the bucket is full. Like Ghostty's CacheTable, this deliberately does
// not deduplicate equal keys; get searches newest-first.
pub fn (mut self U64CacheTable[T]) put(key u64, value T) ?U64CacheEntry[T] {
	idx := int(key & (cache_table_bucket_count - 1))
	entry := U64CacheEntry[T]{
		key: key
		value: value
	}
	mut bucket := self.buckets[idx]
	if bucket.len < cache_table_bucket_size {
		bucket << entry
		self.buckets[idx] = bucket
		self.count_++
		return none
	}

	evicted := bucket[0]
	for i in 1 .. bucket.len {
		bucket[i - 1] = bucket[i]
	}
	bucket[bucket.len - 1] = entry
	self.buckets[idx] = bucket
	return evicted
}

// get returns the newest matching value and promotes it to most-recently
// used within its bucket.
pub fn (mut self U64CacheTable[T]) get(key u64) ?T {
	idx := int(key & (cache_table_bucket_count - 1))
	mut bucket := self.buckets[idx]
	mut i := bucket.len
	for i > 0 {
		i--
		if bucket[i].key == key {
			entry := bucket[i]
			for j in i .. bucket.len - 1 {
				bucket[j] = bucket[j + 1]
			}
			bucket[bucket.len - 1] = entry
			self.buckets[idx] = bucket
			return entry.value
		}
	}
	return none
}

pub fn (mut self U64CacheTable[T]) clear() {
	for i in 0 .. self.buckets.len {
		self.buckets[i].clear()
	}
	self.count_ = 0
}

pub fn (self &U64CacheTable[T]) count() int {
	return self.count_
}
