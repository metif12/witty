module datastruct

struct CacheTestContext {
mut:
	evicted_keys   []u32
	evicted_values []string
}

fn (_ &CacheTestContext) hash(key u32) u64 {
	return u64(key)
}

fn (_ &CacheTestContext) eql(a u32, b u32) bool {
	return a == b
}

fn (mut context CacheTestContext) evicted(key u32, value string) {
	context.evicted_keys << key
	context.evicted_values << value
}

fn test_cache_table_context_lru_and_eviction_callback() {
	mut table := cache_table[u32, string, CacheTestContext](CacheTestContext{}, 2, 2)
	assert table.put(0, 'zero') == none
	assert table.put(2, 'two') == none
	assert table.put(1, 'one') == none
	assert table.get(0)? == 'zero'
	assert table.buckets[0].map(it.key) == [u32(2), 0]

	evicted := table.put(4, 'four')?
	assert evicted == CacheEntry[u32, string]{
		key:   2
		value: 'two'
	}
	assert table.context.evicted_keys == [u32(2)]
	assert table.context.evicted_values == ['two']
	assert table.get(2) == none
	assert table.get(0)? == 'zero'
	assert table.buckets[0].map(it.key) == [u32(4), 0]

	table.clear()
	assert table.buckets.all(it.len == 0)
	assert table.context.evicted_keys == [u32(2), 4, 0, 1]
	assert table.context.evicted_values == ['two', 'four', 'zero', 'one']
}

struct CacheNoEvictionContext {}

fn (_ &CacheNoEvictionContext) hash(key u32) u64 {
	return u64(key)
}

fn (_ &CacheNoEvictionContext) eql(a u32, b u32) bool {
	return a == b
}

fn test_cache_table_context_without_eviction_callback() {
	mut table := cache_table[u32, u32, CacheNoEvictionContext](CacheNoEvictionContext{}, 2, 2)
	for key in 0 .. 4 {
		assert table.put(u32(key), u32(key * 10)) == none
	}
	assert table.put(4, 40)? == CacheEntry[u32, u32]{
		key:   0
		value: 0
	}
	assert table.get(0) == none
}

fn test_u64_cache_table_evicts_least_recently_used_entry() {
	mut table := U64CacheTable.init[int]()

	// Multiples of 256 deliberately collide under the identity hash.
	for i in 0 .. 8 {
		assert table.put(u64(i * 256), i) == none
	}
	assert table.count() == 8

	// Promote key 0, then force an eviction. Key 256 is now the LRU entry.
	assert table.get(0)? == 0
	evicted := table.put(8 * 256, 8)?
	assert evicted.key == 256
	assert evicted.value == 1
	assert table.get(256) == none
	assert table.get(0)? == 0
	assert table.get(8 * 256)? == 8
	assert table.count() == 8
}

fn test_u64_cache_table_keeps_duplicate_keys_newest_first() {
	mut table := U64CacheTable.init[string]()
	assert table.put(42, 'old') == none
	assert table.put(42, 'new') == none
	assert table.count() == 2
	assert table.get(42)? == 'new'
}

fn test_u64_cache_table_clear() {
	mut table := U64CacheTable.init[int]()
	table.put(1, 1)
	table.put(2, 2)
	table.clear()
	assert table.count() == 0
	assert table.get(1) == none
}
