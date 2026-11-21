module zigimg

fn test_limit_values_minimum_and_optional_subtraction() {
	assert Limit.nothing().value == 0 && !Limit.nothing().nonzero()
	assert Limit.limited64(~u64(0)) == Limit.unlimited()
	assert Limit.limited(7).min(Limit.limited(3)).value == 3
	assert Limit.limited(7).min_int64(~u64(0)) == 7
	assert Limit.limited(7).to_int()? == 7
	assert Limit.unlimited().to_int() == none
	assert (Limit.limited(7).subtract(7) or { panic('missing zero') }).value == 0
	assert Limit.limited(7).subtract(8) == none
	assert (Limit.unlimited().subtract(~uint(0)) or { panic('missing unlimited') }) == Limit.unlimited()
}

fn test_limit_slices_borrow_and_slice1_saturates() {
	mut bytes := 'abcdef'.bytes()
	mut prefix := Limit.limited(2).slice(mut bytes)
	prefix[1] = `x`
	assert bytes == 'axcdef'.bytes() && prefix == 'ax'.bytes()
	assert Limit.limited(3).slice_const(bytes) == 'axc'.bytes()
	mut first := Limit.nothing().slice1(mut bytes)
	first[0] = `y`
	assert bytes == 'yxcdef'.bytes() && first.len == 1
	assert Limit.unlimited().slice1(mut bytes) == bytes
	assert Limit.limited(~uint(0) - 1).slice1(mut bytes) == bytes
}

fn test_limit_counts_shared_and_empty_vectors() {
	mut bytes := 'abcdef'.bytes()
	data := [unsafe { bytes[..3] }, []u8{}, unsafe { bytes[1..5] }]
	assert Limit.count_vec(data).value == 7
	assert Limit.count_vec([][]u8{}) == Limit.nothing()
	assert bytes == 'abcdef'.bytes()
}
