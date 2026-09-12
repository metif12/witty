module synthetic

import rand

fn synthetic_test_even_byte(value u8) bool {
	return value & 1 == 0
}

fn test_bytes_generate_alphabet() {
	alphabet := generate_alphabet(synthetic_test_even_byte)
	assert alphabet.len == 128
	assert alphabet[0] == 0
	assert alphabet[1] == 2
	assert alphabet[127] == 254
}

fn test_bytes_generator_respects_exact_length() {
	mut rng := rand.new_default(seed_: [u32(0), 0])
	defer { rng.free() }
	mut bytes := Bytes.init(rng)
	bytes.min_len = 256
	bytes.max_len = 256
	result := bytes.next(256)!
	assert result.len == 256
}

fn test_bytes_generator_bounds_and_alphabet() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffee), 0])
	defer { rng.free() }
	base := Bytes.init(rng)
	mut bytes := base.new_alphabet([u8(`a`), `a`, `a`, `b`]).at_least(10).at_most(20)
	for _ in 0 .. 50 {
		result := bytes.next(15)!
		assert result.len >= 10 && result.len <= 15
		assert result.all(it == `a` || it == `b`)
	}
}

fn test_bytes_generator_maps_byte_values_not_iterator_addresses() {
	mut rng := rand.new_default(seed_: [u32(0xc0ffeeee), 0xeeeeeeee])
	defer { rng.free() }
	base := Bytes.init(rng)
	mut alphabet := []u8{}
	for value in `A` .. `Z` + 1 {
		alphabet << u8(value)
	}
	for value in `a` .. `z` + 1 {
		alphabet << u8(value)
	}
	mut bytes := base.new_alphabet(alphabet).at_least(256).at_most(256)
	result := bytes.next(256)!
	assert result.len == 256
	assert result.all(it in alphabet)
}

fn test_bytes_generator_interface() {
	mut rng := rand.new_default(seed_: [u32(1), 0])
	defer { rng.free() }
	mut bytes := Bytes.init(rng)
	bytes.min_len = 8
	bytes.max_len = 8
	mut generator := bytes.generator()
	assert generator.next(8)!.len == 8
}

fn test_bytes_generator_preserves_pointer_width_limits() {
	mut rng := rand.new_default(seed_: [u32(2), 0])
	defer { rng.free() }
	mut bytes := Bytes.init(rng)
	assert bytes.max_len == ~usize(0)
	bytes.min_len = usize(2147483647) + 1
	mut generator := bytes.generator()
	assert generator.next(8)!.len == 8
}

fn test_bytes_generator_preserves_optional_alphabet() {
	mut rng := rand.new_default(seed_: [u32(3), 0])
	defer { rng.free() }
	bytes := Bytes.init(rng)
	assert bytes.alphabet == none
	with_empty := bytes.new_alphabet([]u8{})
	assert with_empty.alphabet != none
}
