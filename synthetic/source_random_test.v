module synthetic

fn test_xoshiro_original_sequence() {
	mut rng := new_source_random(0)
	for expected in [u64(0x53175d61490b23df), 0x61da6f3dc380d507, 0x5c0fdf91ec9a7bfc,
		0x02eebf8c3bbe5e1a, 0x7eca04ebaf4a5eea, 0x0543c37757f08d9a] {
		assert rng.u64() == expected
	}
}

fn test_source_equal_range_consumes_a_random_value() {
	mut rng := new_source_random(0)
	assert source_range_biased(mut rng, 9, 9, 64) == 9
	assert rng.u64() == u64(0x61da6f3dc380d507)
}

fn test_bytes_writer_failure_retains_prefix_and_rng_position() {
	mut rng := new_source_random(0)
	mut bytes := Bytes.init(rng)
	bytes.min_len = 32
	bytes.max_len = 32
	mut writer := FixedWriter{
		buffer: []u8{len: 9, init: 0xa5}
	}
	bytes.write_writer(mut writer) or {
		assert err.msg() == 'WriteFailed'
		assert writer.end == 9
		// length consumes word1, full chunk word2, failing chunk word3.
		assert writer.buffer == [u8(7), 0xd5, 0x80, 0xc3, 0x3d, 0x6f, 0xda, 0x61, 0xfc]
		assert rng.u64() == u64(0x02eebf8c3bbe5e1a)
		return
	}
	assert false
}

fn test_conemu_source_seed_and_nominal_limit() {
	mut rng := new_source_random(0)
	mut generator := Osc.init(rng)
	mut weights := [13]f64{}
	weights[int(OscValidKind.conemu_progress)] = 1
	generator.p_valid_kind = weights
	mut writer := FixedWriter{
		buffer: []u8{len: 64}
	}
	generator.next_writer(mut writer, 3)!
	assert writer.buffer[..writer.end] == [u8(0x1b), `]`, `9`, `;`, `;`, `2`, `;`, `9`, `2`, 7]
}
