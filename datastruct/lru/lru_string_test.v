module lru

fn set_string_value(mut result GetOrPutResult[string, int], value int) {
	unsafe {
		*result.value_ptr = value
	}
}

fn test_resize_grow_with_string_keys() {
	mut cache := new_auto_hash_map[string, int](1)
	mut result := cache.get_or_put('one')
	set_string_value(mut result, 1)
	assert cache.resize(3) == none
	assert cache.capacity == 3
	assert cache.get('one')? == 1
}

struct FoldedStringContext {}

fn (_ &FoldedStringContext) hash(key string) u64 {
	mut hash := u64(14695981039346656037)
	for b in key.to_lower().bytes() {
		hash = (hash ^ u64(b)) * 1099511628211
	}
	return hash
}

fn (_ &FoldedStringContext) eql(a string, b string) bool {
	return a.to_lower() == b.to_lower()
}

fn test_context_lookup_and_recency() {
	ctx := FoldedStringContext{}
	mut cache := new_auto_hash_map[string, int](2)

	mut first := cache.get_or_put_context('Alpha', ctx)
	assert !first.found_existing
	set_string_value(mut first, 10)
	mut second := cache.get_or_put_context('Beta', ctx)
	set_string_value(mut second, 20)

	assert cache.get_context('alpha', ctx)? == 10
	assert cache.get_context('missing', ctx) == none
	assert cache.get_or_put_context('ALPHA', ctx).found_existing

	third := cache.get_or_put_context('Gamma', ctx)
	evicted := third.evicted or { panic('expected an eviction') }
	assert evicted.key == 'Gamma'
	assert evicted.value == 20
	assert cache.get_context('beta', ctx) == none
}
