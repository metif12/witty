module zigimg

enum ReaderByteTag as u8 {
	zero = 0
	two  = 2
	high = 255
}

enum ReaderSignedTag as i16 {
	low  = -32768
	zero = 0
	high = 32766
}

@[nonexhaustive]
enum ReaderOpenTag as u64 {
	zero = 0
	high = 0xffffffffffffffff
}

type ReaderTagAlias = ReaderByteTag
type ReaderEndianAlias = LittleEndian

fn test_enum_invalid_tag_consumes_its_integer_and_allows_the_next_read() {
	mut reader := ReadStream.init_memory([u8(2), 7, 255])
	assert reader.take_enum[ReaderTagAlias, BigEndian](BigEndian{})! == .two
	mut status := 'ok'
	reader.take_enum[ReaderByteTag, BigEndian](BigEndian{}) or { status = err.msg() }
	assert status == 'InvalidEnumTag' && reader.get_pos() == 2
	assert reader.take_enum[ReaderByteTag, BigEndian](BigEndian{})! == .high
	status = 'ok'
	reader.take_enum[ReaderByteTag, BigEndian](BigEndian{}) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 3
}

fn test_enum_signed_endian_reads_leave_incomplete_tags_pending() {
	mut reader := ReadStream.init_memory([u8(0x80), 0, 0xfe, 0x7f, 0x80])
	assert reader.take_enum[ReaderSignedTag, BigEndian](BigEndian{})! == .low
	assert reader.take_enum[ReaderSignedTag, ReaderEndianAlias](ReaderEndianAlias{})! == .high
	mut status := 'ok'
	reader.take_enum[ReaderSignedTag, BigEndian](BigEndian{}) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 4
	assert reader.buffered() == [u8(0x80)]
}

fn test_enum_nonexhaustive_marker_and_png_types_accept_unnamed_tags() {
	mut reader := ReadStream.init_memory([u8(0x80), 0, 0, 0, 0, 0, 0, 1, 255, 127])
	assert u64(reader.take_enum[ReaderOpenTag, BigEndian](BigEndian{})!) == 0x8000000000000001
	assert u8(reader.take_enum[PngCompressionMethod, BigEndian](BigEndian{})!) == 255
	assert u8(reader.take_enum[PngFilterMethod, LittleEndian](LittleEndian{})!) == 127
	assert reader.get_pos() == 10
}
