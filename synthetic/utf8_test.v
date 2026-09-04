module synthetic

import encoding.utf8.validate
import rand

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
