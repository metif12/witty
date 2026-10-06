module zigimg

import internal_hash

pub enum TiffEndian as u8 {
	big
	little
}

pub enum TiffCompressionType as u16 {
	uncompressed     = 1
	ccitt_rle        = 2
	gp_3_fax         = 3
	gp_4_fax         = 4
	lzw              = 5
	jpeg             = 6
	deflate          = 8
	uncompressed_old = 32771
	packbits         = 32773
	pixar_deflate    = 32946
}

pub enum TiffResolutionUnit as u16 {
	no_unit = 1
	inch    = 2
	cm      = 3
}

pub enum TiffTagId as u16 {
	new_subfile_type           = 254
	image_width                = 256
	image_height               = 257
	bits_per_sample            = 258
	compression                = 259
	photometric_interpretation = 262
	fill_order                 = 266
	document_name              = 269
	image_description          = 270
	strip_offsets              = 273
	orientation                = 274
	samples_per_pixel          = 277
	rows_per_strip             = 278
	strip_byte_counts          = 279
	x_resolution               = 282
	y_resolution               = 283
	planar_configuration       = 284
	x_position                 = 286
	y_position                 = 287
	t4_options                 = 292
	resolution_unit            = 296
	page_number                = 297
	software                   = 305
	predictor                  = 317
	white_point                = 318
	primary_chromaticities     = 319
	color_map                  = 320
	extra_samples              = 338
	sample_format              = 339
	unknown_1                  = 700
	unknown_2                  = 34665
	unknown_3                  = 34675
}

const tiff_tag_ids = [TiffTagId.new_subfile_type, .image_width, .image_height, .bits_per_sample,
	.compression, .photometric_interpretation, .fill_order, .document_name, .image_description,
	.strip_offsets, .orientation, .samples_per_pixel, .rows_per_strip, .strip_byte_counts,
	.x_resolution, .y_resolution, .planar_configuration, .x_position, .y_position, .t4_options,
	.resolution_unit, .page_number, .software, .predictor, .white_point, .primary_chromaticities,
	.color_map, .extra_samples, .sample_format, .unknown_1, .unknown_2, .unknown_3]!

fn tiff_tag_id(value u16) TiffTagId {
	for tag in tiff_tag_ids {
		if u16(tag) == value { return tag }
	}
	panic('invalid TIFF tag enum')
}

pub enum TiffTagType as u16 {
	short = 3
	long  = 4
}

@[packed]
pub struct TiffHeader {
pub mut:
	version    u16
	idf_offset u32
}

pub const tiff_little_endian_magic = 'II'
pub const tiff_big_endian_magic = 'MM'

@[packed]
pub struct TiffPackedTag {
pub mut:
	tag_id      u16
	data_type   u16
	data_count  u32
	data_offset u32
}

@[packed]
pub struct TiffTagField {
pub mut:
	data_type   u16
	data_count  u32
	data_offset u32
}

pub fn (tag TiffTagField) to_long() u32 {
	return tag.data_offset
}

pub fn (tag TiffTagField) to_long_or_short(endianess TiffEndian) u32 {
	return if tag.data_type == u16(TiffTagType.short) {
		u32(tag.to_short(endianess))
	} else {
		tag.data_offset
	}
}

pub fn (tag TiffTagField) to_short(endianess TiffEndian) u16 {
	return if endianess == .big { u16(tag.data_offset >> 16) } else { u16(tag.data_offset) }
}

fn tiff_u16(bytes []u8, endianess TiffEndian) u16 {
	big := (u16(bytes[0]) << 8) | u16(bytes[1])
	little := (u16(bytes[1]) << 8) | u16(bytes[0])
	return if endianess == .big { big } else { little }
}

fn tiff_u32(bytes []u8, endianess TiffEndian) u32 {
	little := u32(bytes[0]) | (u32(bytes[1]) << 8) | (u32(bytes[2]) << 16) | (u32(bytes[3]) << 24)
	return if endianess == .big { read_be_u32(bytes) } else { little }
}

pub fn (tag TiffTagField) read_rational(mut stream ReadStream, endianess TiffEndian) ![2]u32 {
	stream.seek_to(tag.data_offset)!
	first := tiff_u32(stream.take(4)!, endianess)
	second := tiff_u32(stream.take(4)!, endianess)
	return [first, second]!
}

pub fn (tag TiffTagField) read_tag_data(mut stream ReadStream, endianess TiffEndian) ![]u32 {
	stride := if tag.data_type == u16(TiffTagType.short) { u32(2) } else { u32(4) }
	if tag.data_count > u32(0xffffffff) / stride { panic('integer overflow') }
	byte_size := tag.data_count * stride
	if tag.data_count > 0x7fffffff || byte_size > 0x7fffffff {
		panic('TIFF tag array length exceeds V array limit')
	}
	mut result := []u32{len: int(tag.data_count)}
	if tag.data_count == 1 {
		// Source returns the raw inline word even for a big-endian SHORT.
		result[0] = tag.data_offset
		return result
	}
	mut bytes := []u8{len: int(byte_size)}
	stream.seek_to(tag.data_offset)!
	// readSliceShort permits partial input and leaves unread allocator bytes undefined.
	remaining := stream.get_end_pos()! - stream.get_pos()
	count := if remaining < byte_size { int(remaining) } else { int(byte_size) }
	copy(mut bytes, stream.take(count)!)
	actual_stride := if tag.data_type == u16(TiffTagType.long) { 4 } else { 2 }
	if bytes.len / actual_stride != int(tag.data_count) {
		panic('for loop over objects with non-equal lengths')
	}
	for i in 0 .. result.len {
		result[i] = if actual_stride == 4 {
			tiff_u32(bytes[i * 4..], endianess)
		} else {
			u32(tiff_u16(bytes[i * 2..], endianess))
		}
	}
	return result
}

struct TiffTagSlot {
mut:
	used  bool
	key   TiffTagId
	value TiffTagField
}

// Insertion/growth/iteration match Zig 0.15.2 AutoHashMap(TagId, TagField).
// TIFF palette processing observes this bucket order. There are no deletions
// in the source IFD path; the rest of the general HashMap API is not exposed.
pub struct TiffTagMap {
mut:
	slots []TiffTagSlot
	size  int
}

fn tiff_tag_hash(key TiffTagId) u64 {
	value := u16(key)
	$if big_endian { return internal_hash.wyhash([u8(value >> 8), u8(value)], 0) }
	return internal_hash.wyhash([u8(value), u8(value >> 8)], 0)
}

pub fn (table TiffTagMap) capacity() u32 {
	return u32(table.slots.len)
}

pub fn (table TiffTagMap) count() u32 {
	return u32(table.size)
}

fn (mut table TiffTagMap) put_without_growth(key TiffTagId, value TiffTagField) {
	mask := table.slots.len - 1
	mut index := int(tiff_tag_hash(key) & u64(mask))
	for table.slots[index].used {
		if table.slots[index].key == key {
			table.slots[index].value = value
			return
		}
		index = (index + 1) & mask
	}
	table.slots[index] = TiffTagSlot{
		used:  true
		key:   key
		value: value
	}
	table.size++
}

pub fn (mut table TiffTagMap) put(key TiffTagId, value TiffTagField) ! {
	if table.size >= table.slots.len * 80 / 100 {
		table.grow(if table.slots.len == 0 { 8 } else { table.slots.len * 2 })
	}
	table.put_without_growth(key, value)
}

fn (mut table TiffTagMap) grow(capacity int) {
	old := table.slots
	table.slots = []TiffTagSlot{len: capacity}
	table.size = 0
	for slot in old {
		if slot.used { table.put_without_growth(slot.key, slot.value) }
	}
}

pub fn (mut table TiffTagMap) ensure_total_capacity(size u32) ! {
	if u64(size) <= u64(table.slots.len) * 80 / 100 { return }
	required := u64(size) * 100 / 80 + 1
	if required > 0xffffffff { panic('integer does not fit in destination type') }
	if required > 0x80000000 { panic('attempt to unwrap error: Overflow') }
	mut capacity := u64(8)
	for capacity < required {
		capacity *= 2
	}
	if capacity > 0x7fffffff { panic('TIFF tag map capacity exceeds V array limit') }
	table.grow(int(capacity))
}

pub fn (table TiffTagMap) get(key TiffTagId) ?TiffTagField {
	if table.slots.len == 0 { return none }
	mask := table.slots.len - 1
	mut index := int(tiff_tag_hash(key) & u64(mask))
	for table.slots[index].used {
		if table.slots[index].key == key { return table.slots[index].value }
		index = (index + 1) & mask
	}
	return none
}

pub struct TiffTagIterator {
mut:
	slots []TiffTagSlot
	index int
}

pub fn (table TiffTagMap) key_iterator() TiffTagIterator {
	return TiffTagIterator{
		slots: unsafe { table.slots }
	}
}

pub fn (mut iter TiffTagIterator) next() ?&TiffTagId {
	for iter.index < iter.slots.len {
		index := iter.index
		iter.index++
		if iter.slots[index].used { return unsafe { &iter.slots[index].key } }
	}
	return none
}

pub fn (mut table TiffTagMap) deinit() {
	// GC owns the table; the source's post-deinit state is undefined.
}

pub struct TiffIFD {
pub mut:
	ifd_offset      u32
	num_tag_entries u16
	tags_map        TiffTagMap
	next_ifd_offset u32
	read_stream     &ReadStream = unsafe { nil }
}

pub fn TiffIFD.init(stream &ReadStream, ifd_offset u32) !TiffIFD {
	return TiffIFD{
		read_stream: unsafe { stream }
		ifd_offset:  ifd_offset
	}
}

pub fn (mut directory TiffIFD) read_tags(endianess TiffEndian) ! {
	mut stream := unsafe { directory.read_stream }
	stream.seek_to(directory.ifd_offset)!
	num_tags := tiff_u16(stream.take(2)!, endianess)
	mut bytes := []u8{len: int(num_tags) * 12}
	stream.read_slice_all(mut bytes)!
	next := tiff_u32(stream.take(4)!, endianess)
	for index in 0 .. int(num_tags) {
		tag := unsafe { bytes[index * 12..] }
		key := tiff_tag_id(tiff_u16(tag, endianess))
		directory.tags_map.put(key, TiffTagField{
			data_type:   tiff_u16(tag[2..], endianess)
			data_count:  tiff_u32(tag[4..], endianess)
			data_offset: tiff_u32(tag[8..], endianess)
		})!
	}
	directory.num_tag_entries = num_tags
	directory.next_ifd_offset = next
}

pub fn (mut directory TiffIFD) deinit() {
	directory.tags_map.deinit()
}

pub struct TiffBitmapDescriptor {
pub mut:
	compression                TiffCompressionType = .uncompressed
	image_width                u32
	image_height               u32
	photometric_interpretation u16
	rows_per_strip             u32
	strip_offsets              ?[]u32
	strip_byte_counts          ?[]u32
	x_resolution               [2]u32
	y_resolution               [2]u32
	resolution_unit            TiffResolutionUnit = .no_unit
	bits_per_sample            FixedStorage8[u16]
	new_subfile_type           u32
	color_map                  FixedStorage256[Rgba32]
	samples_per_pixel          u16 = 1
	fill_order                 u16 = 1
	extra_samples              FixedStorage8[u16]
	planar_configuration       u16 = 1
	predictor                  u16 = 1
}

pub fn (bitmap &TiffBitmapDescriptor) guess_pixel_format() !PixelFormat {
	if bitmap.compression !in [.uncompressed, .packbits, .ccitt_rle, .lzw, .deflate, .pixar_deflate] {
		return error('Unsupported')
	}
	match bitmap.photometric_interpretation {
		0, 1 {
			bits := bitmap.bits_per_sample.data[0]
			if bits == 1 && bitmap.fill_order == 1 && bitmap.predictor == 1 { return .grayscale1 }
			if bits == 8 { return .grayscale8 }
		}
		3 {
			if bitmap.bits_per_sample.data[0] == 8 { return .indexed8 }
		}
		2 {
			bits := bitmap.bits_per_sample.data
			if bits.len == 3 && bits[0] == 8 && bits[1] == 8 && bits[2] == 8 { return .rgb24 }
			if bits.len == 4 {
				extra := bitmap.extra_samples.data[0]
				if bits[0] == 8 && bits[1] == 8 && bits[2] == 8 && bits[3] == 8
					&& extra in [u16(1), 2] {
					return .rgba32
				}
			}
		}
		else {}
	}

	return error('Unsupported')
}

pub fn (mut bitmap TiffBitmapDescriptor) deinit() {
	// Source frees the two optional strip arrays; GC replaces reclamation.
}
