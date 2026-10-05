module zigimg

enum UtilityEnum16 as u16 {
	zero
	one
	large = 0x1234
}

struct UtilityInner {
	color PngColorType
	flag  bool
	bytes [3]u8
}

struct UtilityHeader {
	value        u32
	signed_value i16
	code         UtilityEnum16
	inner        UtilityInner
	bytes        [2]u8
}

type UtilityBigAlias = BigEndian
type UtilityLittleAlias = LittleEndian
type UtilityCodeAlias = UtilityEnum16
type UtilityByteAlias = u8
type UtilityBytesAlias = [2]UtilityByteAlias
type UtilityWordAlias = u16
type UtilityBoolAlias = bool
type UtilityCompressionAlias = PngCompressionMethod
type UtilityFilterAlias = PngFilterMethod

struct UtilityAliasedInner {
	code  UtilityCodeAlias
	flag  UtilityBoolAlias
	bytes UtilityBytesAlias
}

type UtilityInnerAlias = UtilityAliasedInner

struct UtilityAliasedHeader {
	number      UtilityWordAlias
	inner       UtilityInnerAlias
	compression UtilityCompressionAlias
	filter      UtilityFilterAlias
}

type UtilityHeaderAlias = UtilityAliasedHeader

fn test_magic_number_endian_and_short_signatures() {
	assert to_magic_number_native([]u8{}) == 0
	assert to_magic_number_foreign([]u8{}) == 0
	assert to_magic_number_native('IHDR'.bytes()) == 0x52444849
	assert to_magic_number_foreign('IHDR'.bytes()) == 0x49484452
	assert to_magic_number('abc'.bytes(), BigEndian{}) == 0x616263
	assert to_magic_number('abc'.bytes(), LittleEndian{}) == 0x636261
}

fn test_struct_read_swaps_nested_enum_fields_and_keeps_padding() {
	assert sizeof(UtilityHeader) == 16
	mut stream := ReadStream.init_memory([u8(0x01), 2, 3, 4, 0xff, 0xfe, 0x12, 0x34, 2, 1, 9, 8,
		7, 6, 5, 0x80])
	result := take_struct[UtilityHeader, BigEndian](mut stream, BigEndian{}) or { panic(err) }
	assert result.value == 0x01020304
	assert result.signed_value == -2
	assert result.code == .large
	assert result.inner.color == .rgb_color
	assert result.inner.flag
	assert result.inner.bytes == [u8(9), 8, 7]!
	assert result.bytes == [u8(6), 5]!
	assert stream.get_pos() == 16
	assert unsafe { (&u8(&result)).vbytes(16)[15] } == 0x80
}

fn test_struct_read_consumes_invalid_enum_but_not_short_input() {
	mut bytes := [u8(0), 0, 0, 1, 0, 0, 0x12, 0x34, 5, 0, 0, 0, 0, 0, 0, 0]
	mut reader := ReadStream.init_memory(bytes)
	mut failed := false
	take_struct_foreign[UtilityHeader](mut reader) or {
		failed = true
		assert err.msg() == 'InvalidData'
		assert reader.get_pos() == 16
	}
	assert failed
	mut short := ReadStream.init_memory(bytes[..15])
	failed = false
	take_struct_native[UtilityHeader](mut short) or {
		failed = true
		assert err.msg() == 'EndOfStream'
		assert short.get_pos() == 0
	}
	assert failed
}

fn test_struct_read_preserves_non_exhaustive_png_enums() {
	mut reader := ReadStream.init_memory([u8(0), 0, 0, 1, 0, 0, 0, 1, 8, 2, 173, 199, 0])
	result := take_struct[PngHeaderData, BigEndian](mut reader, BigEndian{}) or { panic(err) }
	assert u8(result.compression_method) == 173
	assert u8(result.filter_method) == 199
}

fn test_struct_read_accepts_aliases_and_validates_nested_aliased_enums() {
	assert to_magic_number('abc'.bytes(), UtilityBigAlias{}) == 0x616263
	assert to_magic_number('abc'.bytes(), UtilityLittleAlias{}) == 0x636261
	assert sizeof(UtilityHeaderAlias) == 10
	mut bytes := [u8(0x12), 0x34, 0x12, 0x34, 1, 9, 8, 0x80, 173, 199]
	mut reader := ReadStream.init_memory(bytes)
	value := take_struct[UtilityHeaderAlias, UtilityBigAlias](mut reader, UtilityBigAlias{}) or {
		panic(err)
	}
	assert u16(value.number) == 0x1234 && u16(value.inner.code) == 0x1234
	assert bool(value.inner.flag) && u8(value.inner.bytes[0]) == 9 && u8(value.inner.bytes[1]) == 8
	assert u8(value.compression) == 173 && u8(value.filter) == 199
	assert reader.get_pos() == 10
	assert unsafe { (&u8(&value)).vbytes(10)[7] } == 0x80
	bytes[2] = 0xab
	bytes[3] = 0xcd
	mut invalid := ReadStream.init_memory(bytes)
	mut failed := false
	take_struct_foreign[UtilityHeaderAlias](mut invalid) or {
		failed = true
		assert err.msg() == 'InvalidData'
		assert invalid.get_pos() == 10
	}
	assert failed
	mut short := ReadStream.init_memory(bytes[..9])
	failed = false
	take_struct_native[UtilityHeaderAlias](mut short) or {
		failed = true
		assert err.msg() == 'EndOfStream' && short.get_pos() == 0
	}
	assert failed
}
