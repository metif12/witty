module unicode

// This is the exact property model used by the pinned Ghostty revision.
// The lookup data was emitted by Ghostty's props-unigen and symbols-unigen
// programs at commit 6c0e02d1138d5376e4ac2f5e311b225494514a97 with its
// pinned uucode dependency 31655fba3c638229989cc524363ef5e3c7b580c1.
//
// Generator output SHA-256:
//   props:   b32ded890688c75f0dad566e4b07060ecdbaa367c8e18f0e717fe576713dfea9
//   symbols: 43bbdff55dc0787b17fa2f73cd6b183ebbaa640e999b4ca27276970e1d71d869
// Embedded table SHA-256:
//   c66888cff0007450992232712af32fa216455db60987abaa9dec00f681fb3eed

pub enum GraphemeBreak as u8 {
	other
	prepend
	regional_indicator
	spacing_mark
	l
	v
	t
	lv
	lvt
	zwj
	zwnj
	extended_pictographic
	emoji_modifier_base
	emoji_modifier
	indic_conjunct_break_extend
	indic_conjunct_break_linker
	indic_conjunct_break_consonant
}

pub struct Properties {
	value u8
}

pub fn Properties.from_int(value u8) Properties {
	return Properties{
		value: value
	}
}

pub fn (props Properties) width() u8 {
	return props.value & 0x03
}

pub fn (props Properties) grapheme_break() GraphemeBreak {
	return unsafe { GraphemeBreak((props.value >> 2) & 0x1f) }
}

pub fn (props Properties) emoji_vs_base() bool {
	return props.value & 0x80 != 0
}

pub fn (a Properties) eql(b Properties) bool {
	return a.value == b.value
}

const table_data = $embed_file('@VMODROOT/unicode/tables.bin').to_bytes()

const props_stage1_offset = 0
const props_stage1_len = 8192
const props_stage2_offset = 16384
const props_stage2_len = 31232
const props_stage3_offset = 78848
const props_stage3_len = 28
const symbols_stage1_offset = 78876
const symbols_stage1_len = 8192
const symbols_stage2_offset = 95260
const symbols_stage2_len = 1792
const symbols_stage3_offset = 98844
const symbols_stage3_len = 2
const grapheme_break_offset = 98846
const grapheme_break_len = 8192

@[direct_array_access; inline]
fn table_u16(offset int, index u32) u16 {
	byte_offset := offset + int(index) * 2
	return u16(table_data[byte_offset]) | (u16(table_data[byte_offset + 1]) << 8)
}

// get returns the width, tailored grapheme-break property, and emoji
// variation-sequence compatibility for a Unicode code point. The generated
// table covers the full u21 domain, matching Ghostty's table exactly.
@[direct_array_access]
pub fn get(cp u32) Properties {
	assert cp <= 0x1fffff
	high := cp >> 8
	low := cp & 0xff
	stage2 := table_u16(props_stage1_offset, high)
	stage3 := table_u16(props_stage2_offset, u32(stage2) + low)
	return Properties.from_int(table_data[props_stage3_offset + int(stage3)])
}

// is_symbol uses Ghostty's separately generated symbol table. It includes
// private-use code points and only the Unicode blocks selected by Ghostty's
// uucode build configuration.
@[direct_array_access]
pub fn is_symbol(cp u32) bool {
	assert cp <= 0x1fffff
	high := cp >> 8
	low := cp & 0xff
	stage2 := table_u16(symbols_stage1_offset, high)
	stage3 := table_u16(symbols_stage2_offset, u32(stage2) + low)
	return table_data[symbols_stage3_offset + int(stage3)] != 0
}
