module opentype

// ============================================================
// Tests for core types (FixedPoint, F26Dot6, etc.)
// ============================================================

fn test_fixed_from_and_to_f64() {
	// Test positive value
	f := fixed_from(1.5)
	assert sizeof(Fixed) == 4
	assert f.int_part() == 1
	assert f.frac() == 32768 // 0.5 * 65536

	result := f.to_f64()
	assert result == 1.5

	// Test zero
	z := fixed_from(0.0)
	assert z.int_part() == 0
	assert z.frac() == 0
	assert z.to_f64() == 0.0
}

fn test_fixed_negative() {
	// Test negative value
	f := fixed_from(-1.5)
	result := f.to_f64()
	assert result == -1.5
}

fn test_fixed_round() {
	assert fixed_from(1.5).round() == 2
	assert fixed_from(1.25).round() == 1
	assert fixed_from(-1.5).round() == -1
	assert fixed_from(-1.25).round() == -1
}

fn test_f26dot6_from_and_to_f64() {
	// Test positive value: 26.6
	p := f26dot6_from(26.6)
	assert p.int_part() == 26
	assert p.frac() == 38 // 0.6 * 64 ~ 38.4 -> rounded to 38

	result := p.to_f64()
	// 26 + 38/64 = 26.59375
	assert result == 26.59375

	// Round: .59375 > .5, so rounds up
	assert p.round() == 27
}

fn test_f26dot6_negative() {
	// Test negative value: -26.6
	n := f26dot6_from(-26.6)
	result := n.to_f64()
	assert result == -26.59375
	assert n.round() == -27
}

fn test_f26dot6_round_half() {
	// 0.5 should round to 1 (bit 5 set = 32 & 0x20 != 0)
	half := f26dot6_from(0.5)
	assert half.round() == 1

	// 0.25 should round to 0 (bit 5 not set = 16 & 0x20 == 0)
	quarter := f26dot6_from(0.25)
	assert quarter.round() == 0
}

fn test_f2dot14_from_to_and_round() {
	positive := f2dot14_from(1.5)
	assert sizeof(F2Dot14) == 2
	assert positive.int_part() == 1
	assert positive.frac() == 8192
	assert positive.to_f64() == 1.5
	assert positive.round() == 2

	negative := f2dot14_from(-1.5)
	assert negative.int_part() == -2
	assert negative.frac() == 8192
	assert negative.to_f64() == -1.5
	assert negative.round() == -1

	quarter := f2dot14_from(0.25)
	assert quarter.int_part() == 0
	assert quarter.frac() == 4096
	assert quarter.to_f64() == 0.25
	assert quarter.round() == 0
}

fn test_version16dot16() {
	v := Version16Dot16.init(2, 0)
	assert sizeof(Version16Dot16) == 4
	assert v.value == 0x0002_0000
	assert v.major() == 2
	assert v.minor() == 0
}

// ============================================================
// Tests for binary reading helpers
// ============================================================

fn test_read_u16_be() {
	data := [u8(0x01), 0x02]
	assert read_u16_be(data, 0) == 0x0102
}

fn test_read_i16_be() {
	// Positive value
	data := [u8(0x00), 0x64]
	assert read_i16_be(data, 0) == 100

	// Negative value (0xFFCE = -50)
	data2 := [u8(0xFF), 0xCE]
	assert read_i16_be(data2, 0) == -50
}

fn test_read_u32_be() {
	data := [u8(0x00), 0x01, 0x00, 0x00]
	assert read_u32_be(data, 0) == 0x00010000
}

fn test_read_i32_be() {
	// Positive
	data := [u8(0x00), 0x00, 0x00, 0x0A]
	assert read_i32_be(data, 0) == 10

	// Negative (0xFFFFFFFF = -1)
	data2 := [u8(0xFF), 0xFF, 0xFF, 0xFF]
	assert read_i32_be(data2, 0) == -1
}

fn test_read_i64_be() {
	data := [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]
	assert read_i64_be(data, 0) == 1

	data2 := [u8(0xFF), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
	assert read_i64_be(data2, 0) == -1
}

// ============================================================
// Tests for FSSelection
// ============================================================

fn test_fs_selection_from_u16() {
	// Regular + use_typo_metrics
	fs := fs_selection_from_u16(0x00C0)
	assert sizeof(FSSelection) == 2
	assert fs.regular()
	assert fs.use_typo_metrics()
	assert !fs.italic()
	assert !fs.bold()
	assert !fs.underscore()
	assert !fs.negative()
	assert !fs.outlined()
	assert !fs.strikeout()
	assert !fs.wws()
	assert !fs.oblique()
}

fn test_fs_selection_to_u16() {
	fs := fs_selection_from_u16(0x0021)
	val := fs.to_u16()
	assert (val & 0x0001) != 0 // italic
	assert (val & 0x0020) != 0 // bold
	assert (val & 0x0040) == 0 // not regular
}

fn test_fs_selection_roundtrip() {
	original := u16(0x01E1) // italic + strikeout + bold + regular + use_typo_metrics
	fs := fs_selection_from_u16(original)
	result := fs.to_u16()
	assert result == original
	assert fs_selection_from_u16(0xfc00).to_u16() == 0xfc00
}

fn test_fs_selection_all_bits() {
	// All bits set
	fs := fs_selection_from_u16(0x03FF)
	assert fs.italic()
	assert fs.underscore()
	assert fs.negative()
	assert fs.outlined()
	assert fs.strikeout()
	assert fs.bold()
	assert fs.regular()
	assert fs.use_typo_metrics()
	assert fs.wws()
	assert fs.oblique()
}

// ============================================================
// Tests for SFNT parser
// ============================================================

fn test_sfnt_too_short() {
	data := [u8(0x00), 0x01]
	sfnt := SFNT.init(data) or {
		assert err.msg() == 'SFNT data too short for offset subtable'
		return
	}
	_ = sfnt
	assert false // Should have errored
}

fn test_sfnt_parse_minimal() {
	// Construct a minimal SFNT with 0 tables.
	mut data := []u8{len: 12}
	// sfnt_version = 0x00010000 (TrueType)
	data[0] = 0x00
	data[1] = 0x01
	data[2] = 0x00
	data[3] = 0x00
	// num_tables = 0
	data[4] = 0x00
	data[5] = 0x00
	// search_range = 0
	data[6] = 0x00
	data[7] = 0x00
	// entry_selector = 0
	data[8] = 0x00
	data[9] = 0x00
	// range_shift = 0
	data[10] = 0x00
	data[11] = 0x00

	sfnt := SFNT.init(data) or {
		assert false
		return
	}
	assert sfnt.offset_subtable.sfnt_version == 0x00010000
	assert sfnt.offset_subtable.num_tables == 0
	assert sfnt.records.len == 0
}

fn test_sfnt_parse_with_table() {
	// Construct an SFNT with 1 table record.
	// Header (12 bytes) + 1 TableRecord (16 bytes) = 28 bytes minimum
	// Plus some dummy table data.
	mut data := []u8{len: 32}
	// sfnt_version = 0x00010000
	data[0] = 0x00
	data[1] = 0x01
	data[2] = 0x00
	data[3] = 0x00
	// num_tables = 1
	data[4] = 0x00
	data[5] = 0x01
	// search_range = 16
	data[6] = 0x00
	data[7] = 0x10
	// entry_selector = 0
	data[8] = 0x00
	data[9] = 0x00
	// range_shift = 0
	data[10] = 0x00
	data[11] = 0x00

	// Table record: tag = "head", checksum = 0, offset = 28, length = 4
	data[12] = 0x68 // 'h'
	data[13] = 0x65 // 'e'
	data[14] = 0x61 // 'a'
	data[15] = 0x64 // 'd'
	data[16] = 0x00 // checksum
	data[17] = 0x00
	data[18] = 0x00
	data[19] = 0x00
	data[20] = 0x00 // offset = 28
	data[21] = 0x00
	data[22] = 0x00
	data[23] = 0x1C
	data[24] = 0x00 // length = 4
	data[25] = 0x00
	data[26] = 0x00
	data[27] = 0x04

	// Dummy table data at offset 28 (4 bytes)
	data[28] = 0xDE
	data[29] = 0xAD
	data[30] = 0xBE
	data[31] = 0xEF

	sfnt := SFNT.init(data) or {
		assert false
		return
	}
	assert sfnt.offset_subtable.num_tables == 1
	assert sfnt.records.len == 1
	assert sfnt.records[0].tag[0] == 0x68
	assert sfnt.records[0].tag[1] == 0x65
	assert sfnt.records[0].tag[2] == 0x61
	assert sfnt.records[0].tag[3] == 0x64
	assert sfnt.records[0].offset == 28
	assert sfnt.records[0].length == 4
}

fn test_sfnt_get_table() {
	// Construct an SFNT with 1 table record.
	mut data := []u8{len: 32}
	// sfnt_version = 0x00010000
	data[0] = 0x00
	data[1] = 0x01
	data[2] = 0x00
	data[3] = 0x00
	// num_tables = 1
	data[4] = 0x00
	data[5] = 0x01
	// search_range, entry_selector, range_shift = 0
	for i in 6 .. 12 {
		data[i] = 0x00
	}

	// Table record: tag = "test", checksum = 0, offset = 28, length = 4
	data[12] = 0x74 // 't'
	data[13] = 0x65 // 'e'
	data[14] = 0x73 // 's'
	data[15] = 0x74 // 't'
	data[16] = 0x00
	data[17] = 0x00
	data[18] = 0x00
	data[19] = 0x00
	data[20] = 0x00 // offset = 28
	data[21] = 0x00
	data[22] = 0x00
	data[23] = 0x1C
	data[24] = 0x00 // length = 4
	data[25] = 0x00
	data[26] = 0x00
	data[27] = 0x04

	data[28] = 0x01
	data[29] = 0x02
	data[30] = 0x03
	data[31] = 0x04

	sfnt := SFNT.init(data) or {
		assert false
		return
	}

	// Existing table
	table := sfnt.get_table('test') or {
		assert false
		return
	}
	assert table.len == 4
	assert table[0] == 0x01
	assert table[1] == 0x02
	assert table[2] == 0x03
	assert table[3] == 0x04

	// Non-existing table
	missing := sfnt.get_table('miss')
	assert missing == none
}

// ============================================================
// Tests for Head table
// ============================================================

fn test_head_too_short() {
	data := []u8{len: 10}
	_ := Head.init(data) or {
		assert err.msg() == 'head table too short'
		return
	}
	assert false // Should have errored
}

fn test_head_parse() {
	// Construct a minimal head table (54 bytes).
	mut data := []u8{len: 54}

	// majorVersion = 1 (offset 0)
	data[0] = 0x00
	data[1] = 0x01
	// minorVersion = 0 (offset 2)
	data[2] = 0x00
	data[3] = 0x00
	// fontRevision = 1.0 (Fixed 16.16: 0x00010000) (offset 4)
	data[4] = 0x00
	data[5] = 0x01
	data[6] = 0x00
	data[7] = 0x00
	// checksumAdjustment = 0x12345678 (offset 8)
	data[8] = 0x12
	data[9] = 0x34
	data[10] = 0x56
	data[11] = 0x78
	// magicNumber = 0x5F0F3CF5 (offset 12)
	data[12] = 0x5F
	data[13] = 0x0F
	data[14] = 0x3C
	data[15] = 0xF5
	// flags = 7 (offset 16)
	data[16] = 0x00
	data[17] = 0x07
	// unitsPerEm = 2000 (offset 18)
	data[18] = 0x07
	data[19] = 0xD0
	// created = 0 (offset 20, 8 bytes)
	// modified = 0 (offset 28, 8 bytes)
	// xMin = -10 (offset 36)
	data[36] = 0xFF
	data[37] = 0xF6
	// yMin = -20 (offset 38)
	data[38] = 0xFF
	data[39] = 0xEC
	// xMax = 100 (offset 40)
	data[40] = 0x00
	data[41] = 0x64
	// yMax = 200 (offset 42)
	data[42] = 0x00
	data[43] = 0xC8
	// macStyle = 0 (offset 44)
	data[44] = 0x00
	data[45] = 0x00
	// lowestRecPPEM = 8 (offset 46)
	data[46] = 0x00
	data[47] = 0x08
	// fontDirectionHint = 2 (offset 48)
	data[48] = 0x00
	data[49] = 0x02
	// indexToLocFormat = 1 (offset 50)
	data[50] = 0x00
	data[51] = 0x01
	// glyphDataFormat = 0 (offset 52)
	data[52] = 0x00
	data[53] = 0x00

	head := Head.init(data) or {
		assert false
		return
	}

	assert head.major_version == 1
	assert head.minor_version == 0
	assert head.font_revision.int_part() == 1
	assert head.font_revision.frac() == 0
	assert head.checksum_adjustment == 0x12345678
	assert head.magic_number == 0x5F0F3CF5
	assert head.flags == 7
	assert head.units_per_em == 2000
	assert head.x_min == -10
	assert head.y_min == -20
	assert head.x_max == 100
	assert head.y_max == 200
	assert head.mac_style == 0
	assert head.lowest_rec_ppem == 8
	assert head.font_direction_hint == 2
	assert head.index_to_loc_format == 1
	assert head.glyph_data_format == 0
}

fn test_head_mac_style_bold_italic() {
	// Build head table with macStyle = 3 (bold + italic)
	mut data := []u8{len: 54}
	data[0] = 0x00
	data[1] = 0x01 // majorVersion = 1
	// macStyle = 3 at offset 44
	data[44] = 0x00
	data[45] = 0x03

	head := Head.init(data) or {
		assert false
		return
	}
	// Bit 0 = bold, bit 1 = italic
	assert (head.mac_style & 0x01) != 0 // bold
	assert (head.mac_style & 0x02) != 0 // italic
}

// ============================================================
// Tests for Hhea table
// ============================================================

fn test_hhea_too_short() {
	data := []u8{len: 10}
	_ := Hhea.init(data) or {
		assert err.msg() == 'hhea table too short'
		return
	}
	assert false // Should have errored
}

fn test_hhea_parse() {
	// Construct an hhea table (36 bytes).
	mut data := []u8{len: 36}

	// majorVersion = 1 (offset 0)
	data[0] = 0x00
	data[1] = 0x01
	// minorVersion = 0 (offset 2)
	data[2] = 0x00
	data[3] = 0x00
	// ascender = 1900 = 0x076C (offset 4)
	data[4] = 0x07
	data[5] = 0x6C
	// descender = -450 = 0xFE3E (offset 6)
	data[6] = 0xFE
	data[7] = 0x3E
	// lineGap = 0 (offset 8)
	data[8] = 0x00
	data[9] = 0x00
	// advanceWidthMax = 1200 = 0x04B0 (offset 10)
	data[10] = 0x04
	data[11] = 0xB0
	// minLeftSideBearing = -100 = 0xFF9C (offset 12)
	data[12] = 0xFF
	data[13] = 0x9C
	// minRightSideBearing = -200 = 0xFF38 (offset 14)
	data[14] = 0xFF
	data[15] = 0x38
	// xMaxExtent = 500 = 0x01F4 (offset 16)
	data[16] = 0x01
	data[17] = 0xF4
	// caretSlopeRise = 1 (offset 18)
	data[18] = 0x00
	data[19] = 0x01
	// caretSlopeRun = 0 (offset 20)
	data[20] = 0x00
	data[21] = 0x00
	// caretOffset = 0 (offset 22)
	data[22] = 0x00
	data[23] = 0x00
	// reserved0-3 = 0 (offsets 24-31)
	// metricDataFormat = 0 (offset 32)
	data[32] = 0x00
	data[33] = 0x00
	// numberOfHMetrics = 10 (offset 34)
	data[34] = 0x00
	data[35] = 0x0A

	hhea := Hhea.init(data) or {
		assert false
		return
	}

	assert hhea.major_version == 1
	assert hhea.minor_version == 0
	assert hhea.ascender == 1900
	assert hhea.descender == -450
	assert hhea.line_gap == 0
	assert hhea.advance_width_max == 1200
	assert hhea.min_left_side_bearing == -100
	assert hhea.min_right_side_bearing == -200
	assert hhea.x_max_extent == 500
	assert hhea.caret_slope_rise == 1
	assert hhea.caret_slope_run == 0
	assert hhea.caret_offset == 0
	assert hhea.reserved0 == 0
	assert hhea.reserved1 == 0
	assert hhea.reserved2 == 0
	assert hhea.reserved3 == 0
	assert hhea.metric_data_format == 0
	assert hhea.number_of_h_metrics == 10
}

// ============================================================
// Tests for OS/2 table
// ============================================================

fn test_os2_too_short() {
	data := []u8{len: 1}
	_ := OS2.init(data) or {
		assert err.msg() == 'OS/2 table too short'
		return
	}
	assert false // Should have errored
}

fn test_os2_unsupported_version() {
	mut data := []u8{len: 100}
	// version = 99
	data[0] = 0x00
	data[1] = 0x63
	_ := OS2.init(data) or {
		assert err.msg() == 'OS/2 version not supported'
		return
	}
	assert false // Should have errored
}

// build_os2_v0_data builds a minimal OS/2 v0 table (78 bytes) with test values.
fn build_os2_v0_data() []u8 {
	mut data := []u8{len: 100}

	// version = 0 (offset 0)
	data[0] = 0x00
	data[1] = 0x00
	// xAvgCharWidth = 500 (offset 2)
	data[2] = 0x01
	data[3] = 0xF4
	// usWeightClass = 400 (offset 4)
	data[4] = 0x01
	data[5] = 0x90
	// usWidthClass = 5 (offset 6)
	data[6] = 0x00
	data[7] = 0x05
	// fsType = 0 (offset 8)
	data[8] = 0x00
	data[9] = 0x00
	// ySubscriptXSize = 100 (offset 10)
	data[10] = 0x00
	data[11] = 0x64
	// ySubscriptYSize = 100 (offset 12)
	data[12] = 0x00
	data[13] = 0x64
	// ySubscriptXOffset = 0 (offset 14)
	data[14] = 0x00
	data[15] = 0x00
	// ySubscriptYOffset = 50 (offset 16)
	data[16] = 0x00
	data[17] = 0x32
	// ySuperscriptXSize = 100 (offset 18)
	data[18] = 0x00
	data[19] = 0x64
	// ySuperscriptYSize = 100 (offset 20)
	data[20] = 0x00
	data[21] = 0x64
	// ySuperscriptXOffset = 0 (offset 22)
	data[22] = 0x00
	data[23] = 0x00
	// ySuperscriptYOffset = 50 (offset 24)
	data[24] = 0x00
	data[25] = 0x32
	// yStrikeoutSize = 50 (offset 26)
	data[26] = 0x00
	data[27] = 0x32
	// yStrikeoutPosition = 250 (offset 28)
	data[28] = 0x00
	data[29] = 0xFA
	// sFamilyClass = 0 (offset 30)
	data[30] = 0x00
	data[31] = 0x00
	// panose (offset 32, 10 bytes) = all zeros
	// ulUnicodeRange1 = 0xFFFFFFFF (offset 42)
	data[42] = 0xFF
	data[43] = 0xFF
	data[44] = 0xFF
	data[45] = 0xFF
	// ulUnicodeRange2 = 0 (offset 46)
	// ulUnicodeRange3 = 0 (offset 50)
	// ulUnicodeRange4 = 0 (offset 54)
	// achVendID = "TEST" (offset 58)
	data[58] = 0x54 // 'T'
	data[59] = 0x45 // 'E'
	data[60] = 0x53 // 'S'
	data[61] = 0x54 // 'T'
	// fsSelection = 0x0040 (regular) (offset 62)
	data[62] = 0x00
	data[63] = 0x40
	// usFirstCharIndex = 32 (offset 64)
	data[64] = 0x00
	data[65] = 0x20
	// usLastCharIndex = 127 (offset 66)
	data[66] = 0x00
	data[67] = 0x7F
	// sTypoAscender = 800 (offset 68)
	data[68] = 0x03
	data[69] = 0x20
	// sTypoDescender = -200 = 0xFF38 (offset 70)
	data[70] = 0xFF
	data[71] = 0x38
	// sTypoLineGap = 0 (offset 72)
	data[72] = 0x00
	data[73] = 0x00
	// usWinAscent = 1000 (offset 74)
	data[74] = 0x03
	data[75] = 0xE8
	// usWinDescent = 200 (offset 76)
	data[76] = 0x00
	data[77] = 0xC8

	return data
}

fn test_os2_v0_parse() {
	data := build_os2_v0_data()
	os2 := OS2.init(data) or {
		assert false
		return
	}

	assert os2.version == 0
	assert os2.x_avg_char_width == 500
	assert os2.us_weight_class == 400
	assert os2.us_width_class == 5
	assert os2.fs_type == 0
	assert os2.y_subscript_x_size == 100
	assert os2.y_subscript_y_size == 100
	assert os2.y_subscript_x_offset == 0
	assert os2.y_subscript_y_offset == 50
	assert os2.y_superscript_x_size == 100
	assert os2.y_superscript_y_size == 100
	assert os2.y_superscript_x_offset == 0
	assert os2.y_superscript_y_offset == 50
	assert os2.y_strikeout_size == 50
	assert os2.y_strikeout_position == 250
	assert os2.s_family_class == 0
	assert os2.ul_unicode_range1 == 0xFFFFFFFF
	assert os2.ach_vend_id[0] == 0x54
	assert os2.ach_vend_id[1] == 0x45
	assert os2.ach_vend_id[2] == 0x53
	assert os2.ach_vend_id[3] == 0x54
	assert os2.fs_selection.regular()
	assert !os2.fs_selection.italic()
	assert !os2.fs_selection.bold()
	assert os2.us_first_char_index == 32
	assert os2.us_last_char_index == 127
	assert os2.s_typo_ascender == 800
	assert os2.s_typo_descender == -200
	assert os2.s_typo_line_gap == 0
	assert os2.us_win_ascent == 1000
	assert os2.us_win_descent == 200

	// v0 should not have optional fields
	assert os2.ul_code_page_range1 == -1
	assert os2.ul_code_page_range2 == -1
	assert os2.has_sx_height == false
	assert os2.has_s_cap_height == false
	assert os2.has_us_default_char == false
	assert os2.has_us_break_char == false
	assert os2.has_us_max_context == false
	assert os2.has_us_lower_optical_point_size == false
	assert os2.has_us_upper_optical_point_size == false
}

fn test_os2_v1_parse() {
	mut data := build_os2_v0_data()
	// Change version to 1
	data[0] = 0x00
	data[1] = 0x01
	// ulCodePageRange1 = 0x12345678 (offset 78)
	data[78] = 0x12
	data[79] = 0x34
	data[80] = 0x56
	data[81] = 0x78
	// ulCodePageRange2 = 0x00000001 (offset 82)
	data[82] = 0x00
	data[83] = 0x00
	data[84] = 0x00
	data[85] = 0x01

	os2 := OS2.init(data) or {
		assert false
		return
	}

	assert os2.version == 1
	assert os2.ul_code_page_range1 == i64(0x12345678)
	assert os2.ul_code_page_range2 == 1
	assert os2.has_sx_height == false
}

fn test_os2_v4_parse() {
	mut data := build_os2_v0_data()
	// Change version to 4
	data[0] = 0x00
	data[1] = 0x04
	// ulCodePageRange1 = 0x00000001 (offset 78)
	data[78] = 0x00
	data[79] = 0x00
	data[80] = 0x00
	data[81] = 0x01
	// ulCodePageRange2 = 0x00000000 (offset 82)
	data[82] = 0x00
	data[83] = 0x00
	data[84] = 0x00
	data[85] = 0x00
	// sxHeight = 500 (offset 86)
	data[86] = 0x01
	data[87] = 0xF4
	// sCapHeight = 700 (offset 88)
	data[88] = 0x02
	data[89] = 0xBC
	// usDefaultChar = 0 (offset 90)
	data[90] = 0x00
	data[91] = 0x00
	// usBreakChar = 32 (offset 92)
	data[92] = 0x00
	data[93] = 0x20
	// usMaxContext = 10 (offset 94)
	data[94] = 0x00
	data[95] = 0x0A

	os2 := OS2.init(data) or {
		assert false
		return
	}

	assert os2.version == 4
	assert os2.ul_code_page_range1 == 1
	assert os2.ul_code_page_range2 == 0
	assert os2.has_sx_height == true
	assert os2.sx_height == 500
	assert os2.has_s_cap_height == true
	assert os2.s_cap_height == 700
	assert os2.has_us_default_char == true
	assert os2.us_default_char == 0
	assert os2.has_us_break_char == true
	assert os2.us_break_char == 32
	assert os2.has_us_max_context == true
	assert os2.us_max_context == 10
	assert os2.has_us_lower_optical_point_size == false
	assert os2.has_us_upper_optical_point_size == false
}

fn test_os2_v5_parse() {
	mut data := build_os2_v0_data()
	// Change version to 5
	data[0] = 0x00
	data[1] = 0x05
	// ulCodePageRange1 = 0 (offset 78)
	// ulCodePageRange2 = 0 (offset 82)
	// sxHeight = 500 (offset 86)
	data[86] = 0x01
	data[87] = 0xF4
	// sCapHeight = 700 (offset 88)
	data[88] = 0x02
	data[89] = 0xBC
	// usDefaultChar = 0 (offset 90)
	// usBreakChar = 32 (offset 92)
	data[92] = 0x00
	data[93] = 0x20
	// usMaxContext = 10 (offset 94)
	data[94] = 0x00
	data[95] = 0x0A
	// usLowerOpticalPointSize = 8 (offset 96)
	data[96] = 0x00
	data[97] = 0x08
	// usUpperOpticalPointSize = 72 (offset 98)
	data[98] = 0x00
	data[99] = 0x48

	os2 := OS2.init(data) or {
		assert false
		return
	}

	assert os2.version == 5
	assert os2.has_sx_height == true
	assert os2.sx_height == 500
	assert os2.has_s_cap_height == true
	assert os2.s_cap_height == 700
	assert os2.has_us_lower_optical_point_size == true
	assert os2.us_lower_optical_point_size == 8
	assert os2.has_us_upper_optical_point_size == true
	assert os2.us_upper_optical_point_size == 72
}

fn test_os2_fs_selection_bold_italic() {
	mut data := build_os2_v0_data()
	// fsSelection = 0x0021 (italic + bold) at offset 62
	data[62] = 0x00
	data[63] = 0x21

	os2 := OS2.init(data) or {
		assert false
		return
	}
	assert os2.fs_selection.italic()
	assert os2.fs_selection.bold()
	assert !os2.fs_selection.regular()
}

// ============================================================
// Tests for Post table
// ============================================================

fn test_post_too_short() {
	data := []u8{len: 10}
	_ := Post.init(data) or {
		assert err.msg() == 'post table too short'
		return
	}
	assert false // Should have errored
}

fn test_post_parse() {
	// Construct a post table (32 bytes).
	mut data := []u8{len: 32}

	// version = 2.0 (Version16Dot16: major=2, minor=0 -> big-endian 0x00020000)
	data[0] = 0x00
	data[1] = 0x02
	data[2] = 0x00
	data[3] = 0x00
	// italicAngle = 0.0 (Fixed: 0x00000000)
	data[4] = 0x00
	data[5] = 0x00
	data[6] = 0x00
	data[7] = 0x00
	// underlinePosition = -200 = 0xFF38 (offset 8)
	data[8] = 0xFF
	data[9] = 0x38
	// underlineThickness = 100 (offset 10)
	data[10] = 0x00
	data[11] = 0x64
	// isFixedPitch = 1 (offset 12)
	data[12] = 0x00
	data[13] = 0x00
	data[14] = 0x00
	data[15] = 0x01

	// minMemType42 = 0 (offset 16)
	// maxMemType42 = 0 (offset 20)
	// minMemType1 = 0 (offset 24)
	// maxMemType1 = 0 (offset 28)

	post := Post.init(data) or {
		assert false
		return
	}

	assert post.version.major() == 2
	assert post.version.minor() == 0
	assert post.italic_angle.to_f64() == 0.0
	assert post.underline_position == -200
	assert post.underline_thickness == 100
	assert post.is_fixed_pitch == 1
	assert post.min_mem_type42 == 0
	assert post.max_mem_type42 == 0
	assert post.min_mem_type1 == 0
	assert post.max_mem_type1 == 0
}

fn test_post_italic_angle() {
	mut data := []u8{len: 32}
	// version = 2.0
	data[0] = 0x00
	data[1] = 0x02
	data[2] = 0x00
	data[3] = 0x00
	// italicAngle = -12.0 (Fixed: 0xFFF40000)
	// -12 in i16 = 0xFFF4, frac = 0x0000
	// Big endian: 0xFF, 0xF4, 0x00, 0x00
	data[4] = 0xFF
	data[5] = 0xF4
	data[6] = 0x00
	data[7] = 0x00

	post := Post.init(data) or {
		assert false
		return
	}
	assert post.italic_angle.to_f64() == -12.0
}

// ============================================================
// Tests for SVG table
// ============================================================

fn test_svg_too_short() {
	data := []u8{len: 2}
	_ := SVG.init(data) or {
		assert err.msg() == 'SVG table too short'
		return
	}
	assert false // Should have errored
}

fn test_svg_bad_version() {
	mut data := []u8{len: 20}
	// version = 1
	data[0] = 0x00
	data[1] = 0x01
	_ := SVG.init(data) or {
		assert err.msg() == 'SVG version not supported'
		return
	}
	assert false // Should have errored
}

fn test_svg_parse_single_record() {
	// Build a minimal SVG table with 1 record.
	// Header: version(2) + offset(4) = 6 bytes
	// Document list: numRecords(2) + 1 record(12) = 14 bytes
	// Total = 20 bytes
	mut data := []u8{len: 20}

	// version = 0 (offset 0)
	data[0] = 0x00
	data[1] = 0x00
	// svgDocumentListOffset = 6 (offset 2)
	data[2] = 0x00
	data[3] = 0x00
	data[4] = 0x00
	data[5] = 0x06
	// numEntries = 1 (offset 6)
	data[6] = 0x00
	data[7] = 0x01
	// SVG Document Record (offset 8, 12 bytes):
	// startGlyphID = 100 (offset 8)
	data[8] = 0x00
	data[9] = 0x64
	// endGlyphID = 105 (offset 10)
	data[10] = 0x00
	data[11] = 0x69

	// svgDocOffset = 0 (offset 12, 4 bytes)
	// svgDocLength = 0 (offset 16, 4 bytes)

	svg := SVG.init(data) or {
		assert false
		return
	}

	assert svg.start_glyph_id == 100
	assert svg.end_glyph_id == 105
	assert svg.num_records == 1
}

fn test_svg_has_glyph_single_range() {
	// Build SVG with one record covering glyphs 100-105.
	mut data := []u8{len: 20}
	data[0] = 0x00
	data[1] = 0x00 // version 0
	data[2] = 0x00
	data[3] = 0x00
	data[4] = 0x00
	data[5] = 0x06 // offset to doc list = 6
	data[6] = 0x00
	data[7] = 0x01 // numEntries = 1
	// Record: startGlyphID=100, endGlyphID=105
	data[8] = 0x00
	data[9] = 0x64
	data[10] = 0x00
	data[11] = 0x69

	// svgDocOffset and svgDocLength = 0

	svg := SVG.init(data) or {
		assert false
		return
	}

	// Inside range
	assert svg.has_glyph(100) == true
	assert svg.has_glyph(102) == true
	assert svg.has_glyph(105) == true

	// Outside range
	assert svg.has_glyph(99) == false
	assert svg.has_glyph(106) == false
	assert svg.has_glyph(0) == false
	assert svg.has_glyph(65535) == false
}

fn test_svg_has_glyph_multiple_ranges() {
	// Build SVG with 3 records:
	// Record 0: glyphs 10-20
	// Record 1: glyphs 50-60
	// Record 2: glyphs 100-110
	mut data := []u8{len: 44}
	data[0] = 0x00
	data[1] = 0x00 // version 0
	data[2] = 0x00
	data[3] = 0x00
	data[4] = 0x00
	data[5] = 0x06 // offset to doc list = 6
	data[6] = 0x00
	data[7] = 0x03 // numEntries = 3

	// Record 0 (offset 8): startGlyphID=10, endGlyphID=20
	data[8] = 0x00
	data[9] = 0x0A
	data[10] = 0x00
	data[11] = 0x14

	// svgDocOffset = 0, svgDocLength = 0 (8 bytes padding)

	// Record 1 (offset 20): startGlyphID=50, endGlyphID=60
	data[20] = 0x00
	data[21] = 0x32
	data[22] = 0x00
	data[23] = 0x3C

	// Record 2 (offset 32): startGlyphID=100, endGlyphID=110
	data[32] = 0x00
	data[33] = 0x64
	data[34] = 0x00
	data[35] = 0x6E

	svg := SVG.init(data) or {
		assert false
		return
	}

	assert svg.start_glyph_id == 10
	assert svg.end_glyph_id == 110

	// In first range
	assert svg.has_glyph(10) == true
	assert svg.has_glyph(15) == true
	assert svg.has_glyph(20) == true

	// Between first and second ranges
	assert svg.has_glyph(30) == false

	// In second range
	assert svg.has_glyph(50) == true
	assert svg.has_glyph(55) == true
	assert svg.has_glyph(60) == true

	// Between second and third ranges
	assert svg.has_glyph(75) == false

	// In third range
	assert svg.has_glyph(100) == true
	assert svg.has_glyph(105) == true
	assert svg.has_glyph(110) == true

	// Outside all ranges
	assert svg.has_glyph(5) == false
	assert svg.has_glyph(111) == false
}

fn test_svg_has_glyph_binary_search_edge() {
	// Build SVG with 2 records to test binary search edges.
	// Record 0: glyphs 1000-1000 (single glyph)
	// Record 1: glyphs 2000-2000 (single glyph)
	mut data := []u8{len: 32}
	data[0] = 0x00
	data[1] = 0x00 // version 0
	data[2] = 0x00
	data[3] = 0x00
	data[4] = 0x00
	data[5] = 0x06 // offset to doc list = 6
	data[6] = 0x00
	data[7] = 0x02 // numEntries = 2

	// Record 0 (offset 8): startGlyphID=1000, endGlyphID=1000
	data[8] = 0x03
	data[9] = 0xE8
	data[10] = 0x03
	data[11] = 0xE8

	// Record 1 (offset 20): startGlyphID=2000, endGlyphID=2000
	data[20] = 0x07
	data[21] = 0xD0
	data[22] = 0x07
	data[23] = 0xD0

	svg := SVG.init(data) or {
		assert false
		return
	}

	assert svg.has_glyph(1000) == true
	assert svg.has_glyph(2000) == true
	assert svg.has_glyph(999) == false
	assert svg.has_glyph(1001) == false
	assert svg.has_glyph(1500) == false
	assert svg.has_glyph(1999) == false
	assert svg.has_glyph(2001) == false
}

// ============================================================
// Tests that require embedded font data
// ============================================================

fn test_sfnt_parse_real_font() {
	// TODO: needs embedded font data
}

fn test_sfnt_get_table_real_font() {
	// TODO: needs embedded font data
}

fn test_head_real_font() {
	// TODO: needs embedded font data
}

fn test_hhea_real_font() {
	// TODO: needs embedded font data
}

fn test_os2_real_font() {
	// TODO: needs embedded font data
}

fn test_post_real_font() {
	// TODO: needs embedded font data
}

fn test_svg_real_font() {
	// TODO: needs embedded font data
}
