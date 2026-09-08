module zig_fmt

fn test_parse_unsigned_matches_zig_separators_and_bases() {
	assert parse_unsigned('65_535', 65535, 10)! == 65535
	assert parse_unsigned('1__2', 255, 10)! == 12
	assert parse_unsigned('DeadBeef', 0xffffffff, 16)! == 0xdeadbeef
	assert parse_unsigned('0b1__01', 255, 0)! == 5
	assert parse_unsigned('NUMBER', 0xffffffff, 36)! == 1442151747
}

fn test_parse_unsigned_rejects_signs_edges_and_overflow() {
	for invalid in ['', '+0', '-0', '_12', '12_', '256', '0x_10', '0x10_'] {
		if _ := parse_unsigned(invalid, 255, if invalid.starts_with('0x') { u8(0) } else { u8(10) }) {
			assert false, 'expected ${invalid} to fail'
		}
	}
}

fn test_parse_int_unsigned_matches_zig_sign_rules() {
	assert parse_int_unsigned('+0xff', 8, 0)! == 255
	assert parse_int_unsigned('-0', 8, 10)! == 0
	assert parse_int_unsigned('1__2', 8, 10)! == 12
	for invalid in ['', '+', '-', '-1', '256'] {
		if _ := parse_int_unsigned(invalid, 8, 10) {
			assert false, 'expected ${invalid} to fail'
		}
	}
}

fn test_parse_int_signed_matches_zig_ranges() {
	assert parse_int_signed('-0x1__0', 16, 0)! == -16
	assert parse_int_signed('-128', 8, 10)! == -128
	assert parse_int_signed('+127', 8, 10)! == 127
	assert parse_int_signed('-9223372036854775808', 64, 10)! == min_i64
	for invalid in ['-129', '128', '+', '1_'] {
		if _ := parse_int_signed(invalid, 8, 10) {
			assert false, 'expected ${invalid} to fail'
		}
	}
}
