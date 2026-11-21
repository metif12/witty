module synthetic

import encoding.utf8.validate
import rand

fn test_utf8_length_storage() {
	assert sizeof(Utf8Len) == 1
	assert u8(Utf8Len.one) == 1
	assert u8(Utf8Len.four) == 4
}

fn test_utf8_generator_fills_valid_buffer() {
	mut rng := rand.new_default(seed_: [u32(0), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	value.min_len = 256
	value.max_len = 256
	result := value.next(256)!
	assert result.len == 256
	assert validate.utf8_data(result.data, result.len)
}

fn test_utf8_generator_respects_encoding_length_weights() {
	mut rng := rand.new_default(seed_: [u32(42), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	value.min_len = 64
	value.max_len = 64
	value.p_length = [f64(0), 0, 0, 1]!
	result := value.next(64)!
	assert validate.utf8_data(result.data, result.len)
	assert result.len == 64
	assert result.bytestr().runes().len == 16
}

fn test_utf8_generator_uses_smaller_sequence_for_remaining_bytes() {
	mut rng := rand.new_default(seed_: [u32(7), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	value.min_len = 7
	value.max_len = 7
	value.p_length = [f64(0), 0, 0, 1]!
	result := value.next(7)!
	assert validate.utf8_data(result.data, result.len)
	assert result.len == 7
	assert result.bytestr().runes().len == 2
}

fn test_utf8_generator_allows_zero_length_output() {
	mut rng := rand.new_default(seed_: [u32(9), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	assert value.next(0)! == []u8{}
	value.min_len = 0
	value.max_len = 0
	assert value.next(32)! == []u8{}
}

fn test_utf8_generator_retains_source_pointer_semantics() {
	mut rng := rand.new_default(seed_: [u32(10), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	value.min_len = 1
	value.max_len = 1
	mut generator := value.generator()
	value.min_len = 8
	value.max_len = 8
	assert generator.next(8)!.len == 8
}

fn test_utf8_generator_preserves_pointer_width_limits() {
	mut rng := rand.new_default(seed_: [u32(8), 0])
	defer { rng.free() }
	mut value := Utf8.init(rng)
	assert value.max_len == ~uint(0)
	value.min_len = uint(2147483647) + 1
	result := value.next(8)!
	assert result.len == 8
	assert validate.utf8_data(result.data, result.len)
}
