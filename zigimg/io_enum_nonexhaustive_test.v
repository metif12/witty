module zigimg

@[nonexhaustive]
enum ReaderAnyByte as u8 {
	zero = 0
}

@[nonexhaustive]
enum ReaderAnySigned as i16 {
	low  = -32768
	zero = 0
}

type ReaderAnyByteAlias = ReaderAnyByte
type ReaderAnySignedAlias = ReaderAnySigned
type ReaderAnyEndianAlias = LittleEndian

fn test_nonexhaustive_reads_accept_every_byte_through_direct_and_aliased_types() {
	data := []u8{len: 256, init: u8(index)}
	mut reader := ReadStream.init_memory(data)
	mut adapter := reader.reader()
	for byte in data {
		assert u8(adapter.take_enum_nonexhaustive[ReaderAnyByteAlias, BigEndian](BigEndian{})!) == byte
	}
	assert reader.get_pos() == 256
	mut status := 'ok'
	reader.take_enum_nonexhaustive[ReaderAnyByte, BigEndian](BigEndian{}) or { status = err.msg() }
	assert status == 'EndOfStream' && reader.get_pos() == 256
}

fn test_nonexhaustive_signed_tags_and_incomplete_input_preserve_progress() {
	mut reader := ReadStream.init_memory([u8(0x80), 1, 0xff, 0xff, 0x80])
	assert i16(reader.take_enum_nonexhaustive[ReaderAnySigned, BigEndian](BigEndian{})!) == -32767
	assert i16(reader.take_enum_nonexhaustive[ReaderAnySignedAlias, ReaderAnyEndianAlias](ReaderAnyEndianAlias{})!) == -1
	mut status := 'ok'
	reader.take_enum_nonexhaustive[ReaderAnySigned, BigEndian](BigEndian{}) or {
		status = err.msg()
	}
	assert status == 'EndOfStream' && reader.get_pos() == 4
	assert reader.buffered() == [u8(0x80)]
}

fn test_nonexhaustive_png_method_reads_accept_unnamed_tags() {
	mut reader := ReadStream.init_memory([u8(255), 127])
	assert u8(reader.take_enum_nonexhaustive[PngCompressionMethod, BigEndian](BigEndian{})!) == 255
	assert u8(reader.take_enum_nonexhaustive[PngFilterMethod, LittleEndian](LittleEndian{})!) == 127
	assert reader.get_pos() == 2
}
