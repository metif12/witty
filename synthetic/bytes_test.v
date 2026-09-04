module synthetic

import rand

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

fn test_bytes_generator_interface() {
	mut rng := rand.new_default(seed_: [u32(1), 0])
	defer { rng.free() }
	mut bytes := Bytes.init(rng)
	bytes.min_len = 8
	bytes.max_len = 8
	mut generator := bytes.generator()
	assert generator.next(8)!.len == 8
}
