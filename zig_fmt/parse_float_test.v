module zig_fmt

import math

fn test_parse_float_decimal_grammar() {
	assert parse_f64('+0')! == 0
	assert parse_f64('-0')! == 0
	assert parse_f64('1.')! == 1
	assert parse_f64('.5')! == 0.5
	assert parse_f64('0_1_2.5_0e0_1')! == 125
	assert math.is_inf(parse_f64('1e5000')!, 1)
	assert parse_f64('1e-5000')! == 0
	for invalid in ['', '   1', '1 ', '+', '-', '.', '.e1', '0.e', '0__1', '1_.0', '1e_2', '1e'] {
		if _ := parse_f64(invalid) {
			assert false, 'expected ${invalid} to fail'
		}
	}
}

fn test_parse_float_special_and_hex_values() {
	assert math.is_nan(parse_f64('nAn')!)
	assert math.is_nan(parse_f64('-NaN')!)
	assert math.is_inf(parse_f64('+Infinity')!, 1)
	assert math.is_inf(parse_f64('-INF')!, -1)
	assert parse_f64('0x1p0')! == 1
	assert parse_f64('0x0')! == 0
	assert parse_f64('-0x1p-1')! == -0.5
	assert parse_f64('0x10p+10')! == 16384
	assert parse_f64('0x1_f.p1')! == 62
	for invalid in ['nanx', 'infinite', '0x', '0x.p1', '0x1p', '0x1p_1'] {
		if _ := parse_f64(invalid) {
			assert false, 'expected ${invalid} to fail'
		}
	}
}

fn test_parse_float_f32_uses_direct_rounding() {
	assert parse_f32('3.4028234664E38')! == f32(3.4028234663852886e38)
	assert parse_f32('0x1p-1')! == f32(0.5)
}
