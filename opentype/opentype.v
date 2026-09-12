module opentype

// OpenType font table parsing module.
//
// This module provides types for reading OpenType font tables
// such as 'head', 'hhea', 'OS/2', 'post', and 'SVG'. Used by the
// font discovery system to derive font properties.
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/otff
// - https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6.html

// ============================================================
// Binary reading helpers (big-endian)
// ============================================================

// read_u8 reads a single byte from data at offset.
fn read_u8(data []u8, offset int) u8 {
	return data[offset]
}

// read_u16_be reads a big-endian u16 from data at offset.
fn read_u16_be(data []u8, offset int) u16 {
	return u16(data[offset]) << 8 | u16(data[offset + 1])
}

// read_i16_be reads a big-endian i16 from data at offset.
fn read_i16_be(data []u8, offset int) i16 {
	return i16(read_u16_be(data, offset))
}

// read_u32_be reads a big-endian u32 from data at offset.
fn read_u32_be(data []u8, offset int) u32 {
	return u32(data[offset]) << 24 | u32(data[offset + 1]) << 16 | u32(data[offset + 2]) << 8 | u32(data[offset + 3])
}

// read_i32_be reads a big-endian i32 from data at offset.
fn read_i32_be(data []u8, offset int) i32 {
	return i32(read_u32_be(data, offset))
}

// read_i64_be reads a big-endian i64 from data at offset.
fn read_i64_be(data []u8, offset int) i64 {
	return i64(u64(read_u32_be(data, offset)) << 32 | u64(read_u32_be(data, offset + 4)))
}

// ============================================================
// Core OpenType types (from sfnt.zig)
// ============================================================

// Tag is an array of four u8s (length = 32 bits) used to identify a table,
// design-variation axis, script, language system, feature, or baseline.
pub type Tag = [4]u8

// Version16Dot16 is a packed 32-bit value with major and minor version numbers.
pub struct Version16Dot16 {
	value u32
}

pub fn Version16Dot16.init(major u16, minor u16) Version16Dot16 {
	return Version16Dot16{
		value: u32(minor) | (u32(major) << 16)
	}
}

pub fn (version Version16Dot16) minor() u16 {
	return u16(version.value & 0xffff)
}

pub fn (version Version16Dot16) major() u16 {
	return u16(version.value >> 16)
}

// Fixed is a 32-bit signed fixed-point number (16.16).
// The integer part is the high 16 bits and the fractional part is the low 16 bits.
pub struct Fixed {
	raw i32
}

pub fn (f Fixed) frac() u16 {
	return u16(u32(f.raw) & 0xffff)
}

pub fn (f Fixed) int_part() i16 {
	return i16(f.raw >> 16)
}

// to_f64 converts a Fixed value to f64.
pub fn (f Fixed) to_f64() f64 {
	return f64(f.raw) / 65536.0
}

// fixed_from creates a Fixed value from a float.
pub fn fixed_from(float f64) Fixed {
	raw := i32(float * 65536.0 + if float >= 0 { 0.5 } else { -0.5 })
	return Fixed{
		raw: raw
	}
}

// round returns the fixed-point value rounded using the high fractional bit,
// matching SFNT.FixedPoint.round.
pub fn (f Fixed) round() i32 {
	if f.frac() & 0x8000 != 0 {
		return i32(f.int_part()) + 1
	}
	return i32(f.int_part())
}

// read_fixed_be reads a big-endian Fixed from data at offset.
fn read_fixed_be(data []u8, offset int) Fixed {
	raw := read_u32_be(data, offset)
	return Fixed{
		raw: i32(raw)
	}
}

// F26Dot6 is a 32-bit signed 26.6 fixed-point number.
// The integer part is the high 26 bits and the fractional part is the low 6 bits.
// Internally stored as the raw i32 value for correct signed arithmetic.
pub struct F26Dot6 {
pub:
	// The raw 26.6 fixed-point value.
	raw i32
}

// frac returns the fractional part (low 6 bits).
pub fn (f F26Dot6) frac() u8 {
	return u8(u32(f.raw) & 0x3F)
}

// int_part returns the integer part (arithmetic right shift by 6).
pub fn (f F26Dot6) int_part() i32 {
	return f.raw >> 6
}

// to_f64 converts an F26Dot6 value to f64.
pub fn (f F26Dot6) to_f64() f64 {
	return f64(f.raw) / 64.0
}

// f26dot6_from creates an F26Dot6 value from a float.
pub fn f26dot6_from(float f64) F26Dot6 {
	raw := i32(float * 64.0 + if float >= 0 { 0.5 } else { -0.5 })
	return F26Dot6{
		raw: raw
	}
}

// round rounds to the nearest integer, .5 rounds away from 0.
pub fn (f F26Dot6) round() i32 {
	if f.frac() & 0x20 != 0 {
		return f.int_part() + 1
	} else {
		return f.int_part()
	}
}

// F2Dot14 is a 16-bit signed fixed number with the low 14 bits of fraction (2.14).
pub struct F2Dot14 {
	raw i16
}

pub fn (f F2Dot14) frac() u16 {
	return u16(f.raw) & 0x3fff
}

pub fn (f F2Dot14) int_part() i8 {
	return i8(f.raw >> 14)
}

// to_f64 converts an F2Dot14 value to f64.
pub fn (f F2Dot14) to_f64() f64 {
	return f64(f.raw) / 16384.0
}

// f2dot14_from creates an F2Dot14 value from a float.
pub fn f2dot14_from(float f64) F2Dot14 {
	raw := i16(float * 16384.0 + if float >= 0 { 0.5 } else { -0.5 })
	return F2Dot14{
		raw: raw
	}
}

// round returns the fixed-point value rounded using the high fractional bit,
// matching SFNT.FixedPoint.round.
pub fn (f F2Dot14) round() i16 {
	if f.frac() & 0x2000 != 0 {
		return i16(f.int_part()) + 1
	}
	return i16(f.int_part())
}

// read_version16dot16_be reads a big-endian Version16Dot16 from data at offset.
fn read_version16dot16_be(data []u8, offset int) Version16Dot16 {
	raw := read_u32_be(data, offset)
	return Version16Dot16{
		value: raw
	}
}

// ============================================================
// SFNT font parser (from sfnt.zig)
// ============================================================

// The static (fixed-sized) portion of the table directory.
//
// This struct matches the memory layout of the TrueType/OpenType
// TableDirectory, but does not include the TableRecord array, since
// that is dynamically sized, so we parse it separately.
//
// In the TrueType reference manual this
// is referred to as the "offset subtable".
//
// https://learn.microsoft.com/en-us/typography/opentype/spec/otff#table-directory
pub struct OffsetSubtable {
pub:
	// Indicates the type of font file we're reading.
	//   - 0x00_01_00_00   ----   TrueType
	//   - 0x74_72_75_65  'true'  TrueType
	//   - 0x4F_54_54_4F  'OTTO'  OpenType
	//   - 0x74_79_70_31  'typ1'  PostScript
	sfnt_version u32
	// Number of tables.
	num_tables u16
	// Maximum power of 2 less than or equal to numTables, times 16
	// ((2**floor(log2(numTables))) * 16, where "**" is an exponentiation operator).
	search_range u16
	// Log2 of the maximum power of 2 less than or equal to numTables
	// (log2(searchRange/16), which is equal to floor(log2(numTables))).
	entry_selector u16
	// numTables times 16, minus searchRange ((numTables * 16) - searchRange).
	range_shift u16
}

// TableRecord describes a single table in the font file.
pub struct TableRecord {
pub:
	// Table identifier.
	tag Tag
	// Checksum for this table.
	checksum u32
	// Offset from beginning of font file.
	offset u32
	// Length of this table.
	length u32
}

// SFNT is a wrapper for parsing an SFNT font and accessing its tables.
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/otff
// - https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6.html
pub struct SFNT {
pub:
	offset_subtable OffsetSubtable
	records         []TableRecord
	data            []u8
}

// init parses a font from raw data. The struct will keep a
// reference to `data` and use it for future operations.
pub fn SFNT.init(data []u8) !SFNT {
	if data.len < 12 {
		return error('SFNT data too short for offset subtable')
	}

	// SFNT files use big endian.
	sfnt_version := read_u32_be(data, 0)
	num_tables := read_u16_be(data, 4)
	search_range := read_u16_be(data, 6)
	entry_selector := read_u16_be(data, 8)
	range_shift := read_u16_be(data, 10)

	offset_sub := OffsetSubtable{
		sfnt_version: sfnt_version
		num_tables: num_tables
		search_range: search_range
		entry_selector: entry_selector
		range_shift: range_shift
	}

	// Each table record is 16 bytes (4 tag + 4 checksum + 4 offset + 4 length).
	records_start := 12
	required_len := records_start + int(num_tables) * 16
	if data.len < required_len {
		return error('SFNT data too short for table records')
	}

	mut records := []TableRecord{cap: int(num_tables)}
	for i in 0 .. int(num_tables) {
		rec_offset := records_start + i * 16
		mut tag := Tag{}
		tag[0] = data[rec_offset]
		tag[1] = data[rec_offset + 1]
		tag[2] = data[rec_offset + 2]
		tag[3] = data[rec_offset + 3]
		records << TableRecord{
			tag: tag
			checksum: read_u32_be(data, rec_offset + 4)
			offset: read_u32_be(data, rec_offset + 8)
			length: read_u32_be(data, rec_offset + 12)
		}
	}

	return SFNT{
		offset_subtable: offset_sub
		records: records
		data: data
	}
}

// get_table returns the bytes of the table with the provided tag if present.
pub fn (self SFNT) get_table(tag string) ?[]u8 {
	for record in self.records {
		if record.tag[0] == tag[0] && record.tag[1] == tag[1] && record.tag[2] == tag[2]
			&& record.tag[3] == tag[3] {
			start := int(record.offset)
			end := start + int(record.length)
			if end <= self.data.len {
				return self.data[start..end]
			}
			return none
		}
	}
	return none
}

// ============================================================
// Head table ('head') - Font Header Table
// ============================================================

// Font Header Table
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/head
//
// Field names are in snake_case (translated from camelCase in spec).
pub struct Head {
pub:
	// Major version number of the font header table -- set to 1.
	major_version u16
	// Minor version number of the font header table -- set to 0.
	minor_version u16
	// Set by font manufacturer.
	font_revision Fixed
	// To compute: set it to 0, sum the entire font as u32, then store
	// 0xB1B0AFBA - sum. If the font is used as a component in a font
	// collection file, the value of this field will be invalidated by
	// changes to the file structure and font table directory, and must
	// be ignored.
	checksum_adjustment u32
	// Set to 0x5F0F3CF5.
	magic_number u32
	// Bit 0: Baseline for font at y=0.
	//
	// Bit 1: Left sidebearing point at x=0
	//        (relevant only for TrueType rasterizers)
	//
	// Bit 2: Instructions may depend on point size.
	//
	// Bit 3: Force ppem to integer values for all internal scaler math; may
	//        use fractional ppem sizes if this bit is clear. It is strongly
	//        recommended that this be set in hinted fonts.
	//
	// Bit 4: Instructions may alter advance width
	//        (the advance widths might not scale linearly).
	//
	// Bit 5: This bit is not used in OpenType, and should not be set in order
	//        to ensure compatible behavior on all platforms. If set, it may
	//        result in different behavior for vertical layout in some
	//        platforms.
	//
	//        (See Apple's specification for details
	//        regarding behavior in Apple platforms.)
	//
	// Bits 6 - 10: These bits are not used in OpenType and should always be
	//              cleared.
	//
	//              (See Apple's specification for details
	//              regarding legacy use in Apple platforms.)
	//
	// Bit 11: Font data is "lossless" as a result of having been
	//         subjected to optimizing transformation and/or compression
	//         (such as compression mechanisms defined by ISO/IEC 14496-18,
	//         MicroType Express, WOFF 2.0, or similar) where the original
	//         font functionality and features are retained but the binary
	//         compatibility between input and output font files is not
	//         guaranteed. As a result of the applied transform, the DSIG
	//         table may also be invalidated.
	//
	// Bit 12: Font converted (produce compatible metrics).
	//
	// Bit 13: Font optimized for ClearType. Note, fonts that rely on embedded
	//         bitmaps (EBDT) for rendering should not be considered optimized
	//         for ClearType, and therefore should keep this bit cleared.
	//
	// Bit 14: Last Resort font. If set, indicates that the glyphs encoded in
	//         the 'cmap' subtables are simply generic symbolic representations
	//         of code point ranges and do not truly represent support for
	//         those code points. If unset, indicates that the glyphs encoded
	//         in the 'cmap' subtables represent proper support for those code
	//         points.
	//
	// Bit 15: Reserved, set to 0.
	flags u16
	// Set to a value from 16 to 16384. Any value in this range is valid.
	//
	// In fonts that have TrueType outlines, a power of 2 is recommended
	// as this allows performance optimization in some rasterizers.
	units_per_em u16
	// Number of seconds since 12:00 midnight that started
	// January 1st, 1904, in GMT/UTC time zone.
	created i64
	// Number of seconds since 12:00 midnight that started
	// January 1st, 1904, in GMT/UTC time zone.
	modified i64
	// Minimum x coordinate across all glyph bounding boxes.
	x_min i16
	// Minimum y coordinate across all glyph bounding boxes.
	y_min i16
	// Maximum x coordinate across all glyph bounding boxes.
	x_max i16
	// Maximum y coordinate across all glyph bounding boxes.
	y_max i16
	// Bit 0: Bold (if set to 1);
	// Bit 1: Italic (if set to 1)
	// Bit 2: Underline (if set to 1)
	// Bit 3: Outline (if set to 1)
	// Bit 4: Shadow (if set to 1)
	// Bit 5: Condensed (if set to 1)
	// Bit 6: Extended (if set to 1)
	// Bits 7 - 15: Reserved (set to 0).
	mac_style u16
	// Smallest readable size in pixels.
	lowest_rec_ppem u16
	// Deprecated (Set to 2).
	// 0: Fully mixed directional glyphs;
	// 1: Only strongly left to right;
	// 2: Like 1 but also contains neutrals;
	// -1: Only strongly right to left;
	// -2: Like -1 but also contains neutrals.
	font_direction_hint i16
	// 0 for short offsets (Offset16), 1 for long (Offset32).
	index_to_loc_format i16
	// 0 for current format.
	glyph_data_format i16
}

// Head table total size: 54 bytes
// 2+2+4+4+4+2+2+8+8+2+2+2+2+2+2+2+2+2 = 54
const head_table_size = 54

// init parses a Head table from raw bytes.
pub fn Head.init(data []u8) !Head {
	// Parse the head table from raw font data.
	if data.len < head_table_size {
		return error('head table too short')
	}
	return Head{
		major_version: read_u16_be(data, 0)
		minor_version: read_u16_be(data, 2)
		font_revision: read_fixed_be(data, 4)
		checksum_adjustment: read_u32_be(data, 8)
		magic_number: read_u32_be(data, 12)
		flags: read_u16_be(data, 16)
		units_per_em: read_u16_be(data, 18)
		created: read_i64_be(data, 20)
		modified: read_i64_be(data, 28)
		x_min: read_i16_be(data, 36)
		y_min: read_i16_be(data, 38)
		x_max: read_i16_be(data, 40)
		y_max: read_i16_be(data, 42)
		mac_style: read_u16_be(data, 44)
		lowest_rec_ppem: read_u16_be(data, 46)
		font_direction_hint: read_i16_be(data, 48)
		index_to_loc_format: read_i16_be(data, 50)
		glyph_data_format: read_i16_be(data, 52)
	}
}

// ============================================================
// Hhea table ('hhea') - Horizontal Header Table
// ============================================================

// Horizontal Header Table
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/hhea
//
// Field names are in snake_case (translated from camelCase in spec).
pub struct Hhea {
pub:
	// Major version number of the horizontal header table -- set to 1.
	major_version u16
	// Minor version number of the horizontal header table -- set to 0.
	minor_version u16
	// Typographic ascent -- see remarks below.
	ascender i16
	// Typographic descent -- see remarks below.
	descender i16
	// Typographic line gap.
	//
	// Negative lineGap values are treated as zero
	// in some legacy platform implementations.
	line_gap i16
	// Maximum advance width value in 'hmtx' table.
	advance_width_max u16
	// Minimum left sidebearing value in 'hmtx' table for
	// glyphs with contours (empty glyphs should be ignored).
	min_left_side_bearing i16
	// Minimum right sidebearing value; calculated as
	// min(aw - (lsb + xMax - xMin)) for glyphs with
	// contours (empty glyphs should be ignored).
	min_right_side_bearing i16
	// Max(lsb + (xMax - xMin)).
	x_max_extent i16
	// Used to calculate the slope of the cursor (rise/run); 1 for vertical.
	caret_slope_rise i16
	// 0 for vertical.
	caret_slope_run i16
	// The amount by which a slanted highlight on a glyph needs to be shifted
	// to produce the best appearance. Set to 0 for non-slanted fonts.
	caret_offset i16
	// Reserved, set to 0.
	reserved0 i16
	// Reserved, set to 0.
	reserved1 i16
	// Reserved, set to 0.
	reserved2 i16
	// Reserved, set to 0.
	reserved3 i16
	// 0 for current format.
	metric_data_format i16
	// Number of hMetric entries in 'hmtx' table.
	number_of_h_metrics u16
}

// Hhea table total size: 36 bytes
// 2+2+2+2+2+2+2+2+2+2+2+2+2+2+2+2+2+2 = 36
const hhea_table_size = 36

// init parses an Hhea table from raw bytes.
pub fn Hhea.init(data []u8) !Hhea {
	// Parse the hhea table from raw font data.
	if data.len < hhea_table_size {
		return error('hhea table too short')
	}
	return Hhea{
		major_version: read_u16_be(data, 0)
		minor_version: read_u16_be(data, 2)
		ascender: read_i16_be(data, 4)
		descender: read_i16_be(data, 6)
		line_gap: read_i16_be(data, 8)
		advance_width_max: read_u16_be(data, 10)
		min_left_side_bearing: read_i16_be(data, 12)
		min_right_side_bearing: read_i16_be(data, 14)
		x_max_extent: read_i16_be(data, 16)
		caret_slope_rise: read_i16_be(data, 18)
		caret_slope_run: read_i16_be(data, 20)
		caret_offset: read_i16_be(data, 22)
		reserved0: read_i16_be(data, 24)
		reserved1: read_i16_be(data, 26)
		reserved2: read_i16_be(data, 28)
		reserved3: read_i16_be(data, 30)
		metric_data_format: read_i16_be(data, 32)
		number_of_h_metrics: read_u16_be(data, 34)
	}
}

// ============================================================
// OS/2 table ('OS/2') - OS/2 and Windows Metrics Table
// ============================================================

// FSSelection contains information concerning the nature of the font patterns.
//
// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#fsselection
pub struct FSSelection {
	value u16
}

// Font contains italic or oblique glyphs, otherwise they are upright.
pub fn (fs FSSelection) italic() bool {
	return fs.value & 0x0001 != 0
}

// Glyphs are underscored.
pub fn (fs FSSelection) underscore() bool {
	return fs.value & 0x0002 != 0
}

// Glyphs have their foreground and background reversed.
pub fn (fs FSSelection) negative() bool {
	return fs.value & 0x0004 != 0
}

// Outline (hollow) glyphs, otherwise they are solid.
pub fn (fs FSSelection) outlined() bool {
	return fs.value & 0x0008 != 0
}

// Glyphs are overstruck.
pub fn (fs FSSelection) strikeout() bool {
	return fs.value & 0x0010 != 0
}

// Glyphs are emboldened.
pub fn (fs FSSelection) bold() bool {
	return fs.value & 0x0020 != 0
}

// Glyphs are in the standard weight/style for the font.
pub fn (fs FSSelection) regular() bool {
	return fs.value & 0x0040 != 0
}

// Use the OS/2 typographic metrics as the default line spacing.
pub fn (fs FSSelection) use_typo_metrics() bool {
	return fs.value & 0x0080 != 0
}

// The name table follows the WWS family-model recommendations.
pub fn (fs FSSelection) wws() bool {
	return fs.value & 0x0100 != 0
}

// Font contains oblique glyphs.
pub fn (fs FSSelection) oblique() bool {
	return fs.value & 0x0200 != 0
}

// fs_selection_from_u16 parses FSSelection flags from a u16 value.
pub fn fs_selection_from_u16(val u16) FSSelection {
	return FSSelection{
		value: val
	}
}

// to_u16 converts FSSelection flags to a u16 value.
pub fn (fs FSSelection) to_u16() u16 {
	return fs.value
}

// Generic OS/2 table with optional fields
// for those that don't exist in all versions.
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/os2
//
// Field names are in snake_case (translated from camelCase in spec).
pub struct OS2 {
pub:
	// The version number for the OS/2 table: 0x0000 to 0x0005.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2#version
	version u16
	// The Average Character Width field specifies the arithmetic average of
	// the escapement (width) of all non-zero width glyphs in the font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#xavgcharwidth
	x_avg_char_width i16
	// Indicates the visual weight (degree of blackness or thickness of strokes)
	// of the characters in the font. Values from 1 to 1000 are valid.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usweightclass
	us_weight_class u16
	// Indicates a relative change from the normal aspect ratio (width to height ratio)
	// as specified by a font designer for the glyphs in a font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#uswidthclass
	us_width_class u16
	// Indicates font embedding licensing rights for the font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#fstype
	fs_type u16
	// The recommended horizontal size in font design units for subscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysubscriptxsize
	y_subscript_x_size i16
	// The recommended vertical size in font design units for subscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysubscriptysize
	y_subscript_y_size i16
	// The recommended horizontal offset in font design units for subscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysubscriptxoffset
	y_subscript_x_offset i16
	// The recommended vertical offset in font design units from the baseline
	// for subscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysubscriptyoffset
	y_subscript_y_offset i16
	// The recommended horizontal size in font design units for superscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysuperscriptxsize
	y_superscript_x_size i16
	// The recommended vertical size in font design units for superscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysuperscriptysize
	y_superscript_y_size i16
	// The recommended horizontal offset in font design units for superscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysuperscriptxoffset
	y_superscript_x_offset i16
	// The recommended vertical offset in font design units from the baseline
	// for superscripts for this font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ysuperscriptyoffset
	y_superscript_y_offset i16
	// Thickness of the strikeout stroke in font design units. Should be > 0.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ystrikeoutsize
	y_strikeout_size i16
	// The position of the top of the strikeout stroke relative to the baseline
	// in font design units.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ystrikeoutposition
	y_strikeout_position i16
	// This field provides a classification of font-family design.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#sfamilyclass
	s_family_class i16
	// This 10-byte array of numbers is used to describe the visual
	// characteristics of a given typeface.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#panose
	panose [10]u8
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulunicoderange
	ul_unicode_range1 u32
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulunicoderange
	ul_unicode_range2 u32
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulunicoderange
	ul_unicode_range3 u32
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulunicoderange
	ul_unicode_range4 u32
	// The four character identifier for the vendor of the given type face.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#achvendid
	ach_vend_id [4]u8
	// Contains information concerning the nature of the font patterns.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#fsselection
	fs_selection FSSelection
	// The minimum Unicode index (character code) in this font, according to the
	// 'cmap' subtable for platform ID 3 and platform-specific encoding ID 0 or 1.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usfirstcharindex
	us_first_char_index u16
	// The maximum Unicode index (character code) in this font, according to the
	// 'cmap' subtable for platform ID 3 and encoding ID 0 or 1.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#uslastcharindex
	us_last_char_index u16
	// The typographic ascender for this font. This field should be combined with
	// the sTypoDescender and sTypoLineGap values to determine default line spacing.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#stypoascender
	s_typo_ascender i16
	// The typographic descender for this font. This field should be combined with
	// the sTypoAscender and sTypoLineGap values to determine default line spacing.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#stypodescender
	s_typo_descender i16
	// The typographic line gap for this font. This field should be combined with
	// the sTypoAscender and sTypoDescender values to determine default line spacing.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#stypolinegap
	s_typo_line_gap i16
	// The "Windows ascender" metric. This should be used to specify the height
	// above the baseline for a clipping region.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#uswinascent
	us_win_ascent u16
	// The "Windows descender" metric. This should be used to specify the vertical
	// extent below the baseline for a clipping region.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#uswindescent
	us_win_descent u16
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulcodepagerange
	// Version >= 1 only. -1 means not present.
	ul_code_page_range1 i64 = -1
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#ulcodepagerange
	// Version >= 1 only. -1 means not present.
	ul_code_page_range2 i64 = -1
	// This metric specifies the distance between the baseline and the approximate
	// height of non-ascending lowercase letters measured in font design units.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#sxheight
	// Version >= 2 only. -1 means not present (use has_sx_height).
	sx_height i16 = -1
	// Whether sx_height is present (version >= 2).
	has_sx_height bool
	// This metric specifies the distance between the baseline and the approximate
	// height of uppercase letters measured in font design units.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#scapheight
	// Version >= 2 only. -1 means not present (use has_s_cap_height).
	s_cap_height i16 = -1
	// Whether s_cap_height is present (version >= 2).
	has_s_cap_height bool
	// This is the Unicode code point, in UTF-16 encoding, of a character that
	// can be used for a default glyph if a requested character is not supported
	// in the font.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usdefaultchar
	// Version >= 2 only. -1 means not present (use has_us_default_char).
	us_default_char i32 = -1
	// Whether us_default_char is present (version >= 2).
	has_us_default_char bool
	// This is the Unicode code point, in UTF-16 encoding, of a character that
	// can be used as a default break character.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usbreakchar
	// Version >= 2 only. -1 means not present (use has_us_break_char).
	us_break_char i32 = -1
	// Whether us_break_char is present (version >= 2).
	has_us_break_char bool
	// The maximum length of a target glyph context for any feature in this font.
	// For example, a font which has only a pair kerning feature should set this
	// field to 2.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usmaxcontext
	// Version >= 2 only. -1 means not present (use has_us_max_context).
	us_max_context i32 = -1
	// Whether us_max_context is present (version >= 2).
	has_us_max_context bool
	// This field is used for fonts with multiple optical styles.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usloweropticalpointsize
	// Version 5 only. -1 means not present (use has_us_lower_optical_point_size).
	us_lower_optical_point_size i32 = -1
	// Whether us_lower_optical_point_size is present (version 5).
	has_us_lower_optical_point_size bool
	// This field is used for fonts with multiple optical styles.
	//
	// https://learn.microsoft.com/en-us/typography/opentype/spec/os2/#usupperopticalpointsize
	// Version 5 only. -1 means not present (use has_us_upper_optical_point_size).
	us_upper_optical_point_size i32 = -1
	// Whether us_upper_optical_point_size is present (version 5).
	has_us_upper_optical_point_size bool
}

// OS/2 v0 table size: 78 bytes
// 2+2+2+2+2+2+2+2+2+2+2+2+2+2+2+2+10+4+4+4+4+4+2+2+2+2+2+2+2+2 = 78
const os2_v0_size = 78

// OS/2 v1 table size: 86 bytes (v0 + 2*u32 = 78 + 8)
const os2_v1_size = 86

// OS/2 v2/v3/v4 table size: 96 bytes (v1 + 2+2+2+2+2 = 86 + 10)
const os2_v2_size = 96

// OS/2 v5 table size: 100 bytes (v2 + 2+2 = 96 + 4)
const os2_v5_size = 100

// init parses an OS2 table from raw bytes.
pub fn OS2.init(data []u8) !OS2 {
	// We need at least 2 bytes for the version.
	if data.len < 2 {
		return error('OS/2 table too short')
	}

	version := read_u16_be(data, 0)

	// All versions have at least v0 fields.
	if data.len < os2_v0_size {
		return error('OS/2 table too short for v0')
	}

	// Parse the common v0 fields.
	mut panose := [10]u8{}
	for i in 0 .. 10 {
		panose[i] = data[32 + i]
	}
	mut ach_vend_id := [4]u8{}
	for i in 0 .. 4 {
		ach_vend_id[i] = data[58 + i]
	}

	mut result := OS2{
		version: version
		x_avg_char_width: read_i16_be(data, 2)
		us_weight_class: read_u16_be(data, 4)
		us_width_class: read_u16_be(data, 6)
		fs_type: read_u16_be(data, 8)
		y_subscript_x_size: read_i16_be(data, 10)
		y_subscript_y_size: read_i16_be(data, 12)
		y_subscript_x_offset: read_i16_be(data, 14)
		y_subscript_y_offset: read_i16_be(data, 16)
		y_superscript_x_size: read_i16_be(data, 18)
		y_superscript_y_size: read_i16_be(data, 20)
		y_superscript_x_offset: read_i16_be(data, 22)
		y_superscript_y_offset: read_i16_be(data, 24)
		y_strikeout_size: read_i16_be(data, 26)
		y_strikeout_position: read_i16_be(data, 28)
		s_family_class: read_i16_be(data, 30)
		panose: panose
		ul_unicode_range1: read_u32_be(data, 42)
		ul_unicode_range2: read_u32_be(data, 46)
		ul_unicode_range3: read_u32_be(data, 50)
		ul_unicode_range4: read_u32_be(data, 54)
		ach_vend_id: ach_vend_id
		fs_selection: fs_selection_from_u16(read_u16_be(data, 62))
		us_first_char_index: read_u16_be(data, 64)
		us_last_char_index: read_u16_be(data, 66)
		s_typo_ascender: read_i16_be(data, 68)
		s_typo_descender: read_i16_be(data, 70)
		s_typo_line_gap: read_i16_be(data, 72)
		us_win_ascent: read_u16_be(data, 74)
		us_win_descent: read_u16_be(data, 76)
	}

	match version {
		0 {
			// v0: no additional fields
			return result
		}
		1 {
			// v1: adds ulCodePageRange1, ulCodePageRange2
			if data.len < os2_v1_size {
				return error('OS/2 table too short for v1')
			}
			result = OS2{
				...result
				ul_code_page_range1: i64(read_u32_be(data, 78))
				ul_code_page_range2: i64(read_u32_be(data, 82))
			}
			return result
		}
		2, 3, 4 {
			// v2/v3/v4: adds code page ranges + sxHeight, sCapHeight,
			// usDefaultChar, usBreakChar, usMaxContext
			if data.len < os2_v2_size {
				return error('OS/2 table too short for v2/v3/v4')
			}
			result = OS2{
				...result
				ul_code_page_range1: i64(read_u32_be(data, 78))
				ul_code_page_range2: i64(read_u32_be(data, 82))
				sx_height: read_i16_be(data, 86)
				has_sx_height: true
				s_cap_height: read_i16_be(data, 88)
				has_s_cap_height: true
				us_default_char: i32(read_u16_be(data, 90))
				has_us_default_char: true
				us_break_char: i32(read_u16_be(data, 92))
				has_us_break_char: true
				us_max_context: i32(read_u16_be(data, 94))
				has_us_max_context: true
			}
			return result
		}
		5 {
			// v5: adds usLowerOpticalPointSize, usUpperOpticalPointSize
			if data.len < os2_v5_size {
				return error('OS/2 table too short for v5')
			}
			result = OS2{
				...result
				ul_code_page_range1: i64(read_u32_be(data, 78))
				ul_code_page_range2: i64(read_u32_be(data, 82))
				sx_height: read_i16_be(data, 86)
				has_sx_height: true
				s_cap_height: read_i16_be(data, 88)
				has_s_cap_height: true
				us_default_char: i32(read_u16_be(data, 90))
				has_us_default_char: true
				us_break_char: i32(read_u16_be(data, 92))
				has_us_break_char: true
				us_max_context: i32(read_u16_be(data, 94))
				has_us_max_context: true
				us_lower_optical_point_size: i32(read_u16_be(data, 96))
				has_us_lower_optical_point_size: true
				us_upper_optical_point_size: i32(read_u16_be(data, 98))
				has_us_upper_optical_point_size: true
			}
			return result
		}
		else {
			return error('OS/2 version not supported')
		}
	}
}

// ============================================================
// Post table ('post') - PostScript Table
// ============================================================

// PostScript Table
//
// This implementation doesn't parse the
// extra fields in versions 2.0 and 2.5.
//
// References:
// - https://learn.microsoft.com/en-us/typography/opentype/spec/post
//
// Field names are in snake_case (translated from camelCase in spec).
pub struct Post {
pub:
	// Version of the post table.
	version Version16Dot16
	// Italic angle in counter-clockwise degrees from the vertical.
	// Zero for upright text, negative for text that leans to the
	// right (forward).
	italic_angle Fixed
	// Suggested y-coordinate of the top of the underline.
	underline_position i16
	// Suggested values for the underline thickness.
	// In general, the underline thickness should match the thickness of
	// the underscore character (U+005F LOW LINE), and should also match
	// the strikeout thickness, which is specified in the OS/2 table.
	underline_thickness i16
	// Set to 0 if the font is proportionally spaced, non-zero if
	// the font is not proportionally spaced (i.e. monospaced).
	is_fixed_pitch u32
	// Minimum memory usage when an OpenType font is downloaded.
	min_mem_type42 u32
	// Maximum memory usage when an OpenType font is downloaded.
	max_mem_type42 u32
	// Minimum memory usage when an OpenType
	// font is downloaded as a Type 1 font.
	min_mem_type1 u32
	// Maximum memory usage when an OpenType
	// font is downloaded as a Type 1 font.
	max_mem_type1 u32
}

// Post table total size: 32 bytes
// 4+4+2+2+4+4+4+4+4 = 32
const post_table_size = 32

// init parses a Post table from raw bytes.
pub fn Post.init(data []u8) !Post {
	// Parse the post table from raw font data.
	if data.len < post_table_size {
		return error('post table too short')
	}
	return Post{
		version: read_version16dot16_be(data, 0)
		italic_angle: read_fixed_be(data, 4)
		underline_position: read_i16_be(data, 8)
		underline_thickness: read_i16_be(data, 10)
		is_fixed_pitch: read_u32_be(data, 12)
		min_mem_type42: read_u32_be(data, 16)
		max_mem_type42: read_u32_be(data, 20)
		min_mem_type1: read_u32_be(data, 24)
		max_mem_type1: read_u32_be(data, 28)
	}
}

// ============================================================
// SVG table ('SVG ') - SVG glyphs description table
// ============================================================

// SVG glyphs description table.
//
// This struct is focused purely on the operations we need for Ghostty,
// namely to be able to look up whether a glyph ID is present in the SVG
// table or not. This struct isn't meant to be a general purpose SVG table
// reader.
//
// References:
// - https://www.w3.org/2013/10/SVG_in_OpenType/#thesvg
// - https://learn.microsoft.com/en-us/typography/opentype/spec/svg
pub struct SVG {
pub:
	// The start glyph ID (inclusive) that is present in the table.
	// This is used to very quickly include/exclude a glyph from the table.
	start_glyph_id u16
	// The end glyph ID (inclusive) that is present in the table.
	end_glyph_id u16
	// The raw data for the SVG document records.
	// Each record is 12 bytes: startGlyphID(u16) + endGlyphID(u16) +
	// svgDocOffset(u32) + svgDocLength(u32).
	data []u8
	// The number of SVG document records.
	num_records u16
	// The offset within data where the records start.
	records_offset int
}

// init parses an SVG table from raw bytes.
pub fn SVG.init(data []u8) !SVG {
	// Need at least 2 (version) + 4 (offset) = 6 bytes for the header.
	if data.len < 6 {
		return error('SVG table too short')
	}

	// Version
	version := read_u16_be(data, 0)
	if version != 0 {
		return error('SVG version not supported')
	}

	// Offset to the SVG document list
	doc_list_offset := int(read_u32_be(data, 2))

	// Seek to the document list to get the number of entries.
	if data.len < doc_list_offset + 2 {
		return error('SVG table too short for document list')
	}
	num_records := read_u16_be(data, doc_list_offset)

	records_offset := doc_list_offset + 2

	// Check we have enough data for all records.
	required := records_offset + int(num_records) * 12
	if data.len < required {
		return error('SVG table too short for records')
	}

	// Get the start/end glyph range from first and last records.
	first_start := read_u16_be(data, records_offset)
	mut end_glyph := first_start
	if num_records == 1 {
		end_glyph = read_u16_be(data, records_offset + 2)
	} else {
		last_record_offset := records_offset + int(num_records - 1) * 12
		end_glyph = read_u16_be(data, last_record_offset + 2)
	}

	return SVG{
		start_glyph_id: first_start
		end_glyph_id: end_glyph
		data: data
		num_records: num_records
		records_offset: records_offset
	}
}

// has_glyph returns true if the given glyph ID is present in the SVG table.
pub fn (self SVG) has_glyph(glyph_id u16) bool {
	// Fast path: outside the table range
	if glyph_id < self.start_glyph_id || glyph_id > self.end_glyph_id {
		return false
	}

	// Fast path, matches the start/end glyph IDs
	if glyph_id == self.start_glyph_id || glyph_id == self.end_glyph_id {
		return true
	}

	// Slow path: binary search our records
	mut low := 0
	mut high := int(self.num_records) - 1
	for low <= high {
		mid := (low + high) / 2
		rec_offset := self.records_offset + mid * 12
		start := read_u16_be(self.data, rec_offset)
		end := read_u16_be(self.data, rec_offset + 2)
		if glyph_id < start {
			high = mid - 1
		} else if glyph_id > end {
			low = mid + 1
		} else {
			return true
		}
	}
	return false
}
