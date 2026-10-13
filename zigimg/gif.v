module zigimg

// Source packed flags retain their byte layout through explicit backing words.
@[packed]
pub struct GifHeaderFlags {
pub mut:
	raw u8
}

pub fn (flags GifHeaderFlags) global_color_table_size() u8 {
	return flags.raw & 7
}

pub fn (flags GifHeaderFlags) sorted() bool {
	return flags.raw & 8 != 0
}

pub fn (flags GifHeaderFlags) color_resolution() u8 {
	return (flags.raw >> 4) & 7
}

pub fn (flags GifHeaderFlags) use_global_color_table() bool {
	return flags.raw & 0x80 != 0
}

pub fn (mut flags GifHeaderFlags) set_global_color_table_size(size u8) {
	if size > 7 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 0xf8) | size
}

pub fn (mut flags GifHeaderFlags) set_sorted(sorted bool) {
	flags.raw = (flags.raw & 0xf7) | (u8(sorted) << 3)
}

pub fn (mut flags GifHeaderFlags) set_color_resolution(resolution u8) {
	if resolution > 7 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 0x8f) | (resolution << 4)
}

pub fn (mut flags GifHeaderFlags) set_use_global_color_table(use_table bool) {
	flags.raw = (flags.raw & 0x7f) | (u8(use_table) << 7)
}

@[packed]
pub struct GifHeader {
pub mut:
	magic                  [3]u8
	version                [3]u8
	width                  u16
	height                 u16
	flags                  GifHeaderFlags
	background_color_index u8
	pixel_aspect_ratio     u8
}

@[packed]
pub struct GifImageDescriptorFlags {
pub mut:
	raw u8
}

pub fn (flags GifImageDescriptorFlags) local_color_table_size() u8 {
	return flags.raw & 7
}

pub fn (flags GifImageDescriptorFlags) reserved() u8 {
	return (flags.raw >> 3) & 3
}

pub fn (flags GifImageDescriptorFlags) sort() bool {
	return flags.raw & 0x20 != 0
}

pub fn (flags GifImageDescriptorFlags) is_interlaced() bool {
	return flags.raw & 0x40 != 0
}

pub fn (flags GifImageDescriptorFlags) has_local_color_table() bool {
	return flags.raw & 0x80 != 0
}

pub fn (mut flags GifImageDescriptorFlags) set_local_color_table_size(size u8) {
	if size > 7 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 0xf8) | size
}

pub fn (mut flags GifImageDescriptorFlags) set_reserved(reserved u8) {
	if reserved > 3 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 0xe7) | (reserved << 3)
}

pub fn (mut flags GifImageDescriptorFlags) set_sort(sort bool) {
	flags.raw = (flags.raw & 0xdf) | (u8(sort) << 5)
}

pub fn (mut flags GifImageDescriptorFlags) set_is_interlaced(interlaced bool) {
	flags.raw = (flags.raw & 0xbf) | (u8(interlaced) << 6)
}

pub fn (mut flags GifImageDescriptorFlags) set_has_local_color_table(has_table bool) {
	flags.raw = (flags.raw & 0x7f) | (u8(has_table) << 7)
}

@[packed]
pub struct GifImageDescriptor {
pub mut:
	left_position u16
	top_position  u16
	width         u16
	height        u16
	flags         GifImageDescriptorFlags
}

pub enum GifDisposeMethod as u8 {
	none                     = 0
	do_not_dispose           = 1
	restore_background_color = 2
	restore_to_previous      = 3
}

@[packed]
pub struct GifGraphicControlExtensionFlags {
pub mut:
	raw u8
}

pub fn (flags GifGraphicControlExtensionFlags) has_transparent_color() bool {
	return flags.raw & 1 != 0
}

pub fn (flags GifGraphicControlExtensionFlags) user_input() bool {
	return flags.raw & 2 != 0
}

pub fn (flags GifGraphicControlExtensionFlags) disposal_method() GifDisposeMethod {
	// DisposeMethod is nonexhaustive in the source; values 4..7 follow its else arm.
	return unsafe { GifDisposeMethod((flags.raw >> 2) & 7) }
}

pub fn (flags GifGraphicControlExtensionFlags) reserved() u8 {
	return flags.raw >> 5
}

pub fn (mut flags GifGraphicControlExtensionFlags) set_has_transparent_color(transparent bool) {
	flags.raw = (flags.raw & 0xfe) | u8(transparent)
}

pub fn (mut flags GifGraphicControlExtensionFlags) set_user_input(user_input bool) {
	flags.raw = (flags.raw & 0xfd) | (u8(user_input) << 1)
}

pub fn (mut flags GifGraphicControlExtensionFlags) set_disposal_method(method GifDisposeMethod) {
	if u8(method) > 7 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 0xe3) | (u8(method) << 2)
}

pub fn (mut flags GifGraphicControlExtensionFlags) set_reserved(reserved u8) {
	if reserved > 7 { panic('integer does not fit in destination type') }
	flags.raw = (flags.raw & 31) | (reserved << 5)
}

@[packed]
pub struct GifGraphicControlExtension {
pub mut:
	flags                   GifGraphicControlExtensionFlags
	delay_time              u16
	transparent_color_index u8
}

pub struct GifCommentExtension {
pub mut:
	comment []u8 @[required]
}

pub fn (comment &GifCommentExtension) deinit() {
	_ = comment
}

pub struct GifApplicationExtension {
pub mut:
	application_identifier [8]u8 @[required]
	authentification_code  [3]u8 @[required]
	data                   []u8  @[required]
}

pub fn (application &GifApplicationExtension) deinit() {
	_ = application
}

pub struct GifSubImage {
pub mut:
	local_color_table FixedStorage256[Rgb24]
	image_descriptor  GifImageDescriptor
	pixels            []u8
}

pub fn (image &GifSubImage) deinit() {
	_ = image
}

pub struct GifFrameData {
pub mut:
	graphics_control ?GifGraphicControlExtension
	sub_images       []&GifSubImage
}

pub fn (mut frame GifFrameData) deinit() {
	for sub_image in frame.sub_images {
		sub_image.deinit()
	}
	frame.sub_images.clear()
}

pub fn (mut frame GifFrameData) alloc_new_sub_image() !&GifSubImage {
	image := &GifSubImage{}
	frame.sub_images << image
	return image
}

struct GifReaderContext {
mut:
	current_frame_data                  ?&GifFrameData
	has_animation_application_extension bool
}

pub struct GIF {
pub mut:
	header             GifHeader
	global_color_table FixedStorage256[Rgb24]
	frames             []GifFrameData
	comments           []GifCommentExtension
	application_infos  []GifApplicationExtension
}

// GC owns the storage that the source groups in its arena allocator.
pub fn GIF.init() GIF {
	return GIF{}
}

pub fn (codec &GIF) deinit() {
	_ = codec
}

pub fn GIF.format_detect(mut stream ReadStream) !bool {
	bytes := stream.peek(6)!
	return bytes[..3] == 'GIF'.bytes() && bytes[3..].bytestr() in ['87a', '89a']
}

pub fn GIF.read_image(mut stream ReadStream) !ImageUnmanaged {
	mut codec := GIF.init()
	defer { codec.deinit() }
	frames := codec.read(mut stream)!
	if frames.len == 0 { return error('InvalidData') }
	return ImageUnmanaged{
		width:     usize(codec.header.width)
		height:    usize(codec.header.height)
		pixels:    frames[0].pixels
		animation: Animation{
			frames:     frames
			loop_count: codec.loop_count()
		}
	}
}

pub fn GIF.write_image(mut stream WriteStream, image ImageUnmanaged) ! {
	_ = stream
	_ = image
}

fn gif_animation_extension(info GifApplicationExtension) bool {
	return (info.application_identifier[..].bytestr() == 'NETSCAPE'
		&& info.authentification_code[..].bytestr() == '2.0')
		|| (info.application_identifier[..].bytestr() == 'ANIMEXTS'
		&& info.authentification_code[..].bytestr() == '1.0')
}

pub fn (codec &GIF) loop_count() i32 {
	for info in codec.application_infos {
		if gif_animation_extension(info) {
			count := u16(info.data[1]) | u16(info.data[2]) << 8
			return if count == 0 { animation_loop_infinite } else { i32(count) }
		}
	}
	return 0
}

fn gif_u16(bytes []u8, offset int) u16 {
	return u16(bytes[offset]) | u16(bytes[offset + 1]) << 8
}

fn gif_read_header(mut stream ReadStream) !GifHeader {
	bytes := stream.take(13)!
	return GifHeader{
		magic:                  [bytes[0], bytes[1], bytes[2]]!
		version:                [bytes[3], bytes[4], bytes[5]]!
		width:                  gif_u16(bytes, 6)
		height:                 gif_u16(bytes, 8)
		flags:                  GifHeaderFlags{
			raw: bytes[10]
		}
		background_color_index: bytes[11]
		pixel_aspect_ratio:     bytes[12]
	}
}

fn gif_read_descriptor(mut stream ReadStream) !GifImageDescriptor {
	bytes := stream.take(9)!
	return GifImageDescriptor{
		left_position: gif_u16(bytes, 0)
		top_position:  gif_u16(bytes, 2)
		width:         gif_u16(bytes, 4)
		height:        gif_u16(bytes, 6)
		flags:         GifImageDescriptorFlags{
			raw: bytes[8]
		}
	}
}

fn gif_read_color(mut stream ReadStream) !Rgb24 {
	bytes := stream.take(3)!
	return Rgb24{
		r: bytes[0]
		g: bytes[1]
		b: bytes[2]
	}
}

pub fn (mut codec GIF) read(mut stream ReadStream) ![]AnimationFrame {
	mut context := GifReaderContext{}
	codec.header = gif_read_header(mut stream)!
	if codec.header.magic[..].bytestr() != 'GIF'
		|| codec.header.version[..].bytestr() !in ['87a', '89a'] {
		return error('InvalidData')
	}
	count := usize(1) << (codec.header.flags.global_color_table_size() + 1)
	codec.global_color_table.resize(count)
	if codec.header.flags.use_global_color_table() {
		for i in 0 .. int(count) {
			codec.global_color_table.data[i] = gif_read_color(mut stream)!
		}
	}
	codec.read_data(mut stream, mut context)!
	return codec.render()!
}

fn gif_read_block_kind(mut stream ReadStream) !u8 {
	kind := stream.take_byte() or { return error('InvalidData') }
	if kind !in [u8(0x2c), 0x21, 0x3b] { return error('InvalidData') }
	return kind
}

fn gif_read_extension_kind(mut stream ReadStream) !u8 {
	kind := stream.take_byte()!
	if kind !in [u8(0xf9), 0xfe, 1, 0xff] { return error('InvalidEnumTag') }
	return kind
}

fn (mut codec GIF) read_data(mut stream ReadStream, mut context GifReaderContext) ! {
	mut block := gif_read_block_kind(mut stream)!
	for block != 0x3b {
		mut extension := ?u8(none)
		mut graphic := block == 0x2c
		if block == 0x21 {
			if value := gif_read_extension_kind(mut stream) {
				extension = value
			} else {
				mut byte := stream.take_byte()!
				for byte != 0 {
					byte = stream.take_byte()!
				}
				extension = none
			}
			if kind := extension {
				graphic = kind in [u8(0xf9), 1]
			} else {
				block = gif_read_block_kind(mut stream)!
				continue
			}
		}
		if graphic {
			codec.read_graphic_block(mut stream, mut context, block, extension)!
		} else {
			codec.read_special_purpose_block(mut stream, mut context, extension or {
				panic('missing extension')
			})!
		}
		block = gif_read_block_kind(mut stream)!
	}
}

fn (mut codec GIF) alloc_new_frame() !&GifFrameData {
	codec.frames << GifFrameData{}
	return unsafe { &codec.frames[codec.frames.len - 1] }
}

fn (mut codec GIF) read_graphic_block(mut stream ReadStream, mut context GifReaderContext, block u8, extension ?u8) ! {
	if kind := extension {
		if kind == 0xf9 {
			context.current_frame_data = codec.alloc_new_frame()!
			mut frame := context.current_frame_data or { panic('missing frame') }
			stream.toss(1)
			flags := GifGraphicControlExtensionFlags{
				raw: stream.take_byte()!
			}
			delay := gif_u16(stream.take(2)!, 0)
			mut transparent := u8(0)
			if flags.has_transparent_color() {
				transparent = stream.take_byte()!
			} else {
				stream.toss(1)
			}
			stream.toss(1)
			frame.graphics_control = GifGraphicControlExtension{
				flags:                   flags
				delay_time:              delay
				transparent_color_index: transparent
			}
			new_block := gif_read_block_kind(mut stream)!
			codec.read_graphic_rendering_block(mut stream, mut context, new_block, none)!
		} else if kind == 1 {
			codec.read_graphic_rendering_block(mut stream, mut context, block, extension)!
		}
	} else {
		if context.current_frame_data == none || context.has_animation_application_extension {
			context.current_frame_data = codec.alloc_new_frame()!
		}
		codec.read_graphic_rendering_block(mut stream, mut context, block, extension)!
	}
}

fn (mut codec GIF) read_graphic_rendering_block(mut stream ReadStream, mut context GifReaderContext, block u8, extension ?u8) ! {
	match block {
		0x2c {
			codec.read_image_descriptor_and_data(mut stream, mut context)!
		}
		0x21 {
			kind := extension or {
				gif_read_extension_kind(mut stream) or { return error('InvalidData') }
			}

			if kind != 1 { return error('InvalidData') }
			size := stream.take_byte()!
			stream.discard_all(usize(size))!
			sub_size := stream.take_byte()!
			if sub_size == 255 { panic('integer overflow') }
			stream.discard_all(usize(sub_size + 1))!
		}
		0x3b {}
		else {
			return error('InvalidData')
		}
	}
}

fn gif_read_sub_blocks(mut stream ReadStream) ![]u8 {
	mut bytes := []u8{cap: 256}
	mut size := stream.take_byte()!
	for size > 0 {
		mut data := []u8{len: int(size)}
		stream.read_slice_all(mut data)!
		bytes << data
		size = stream.take_byte()!
	}
	return bytes
}

fn (mut codec GIF) read_special_purpose_block(mut stream ReadStream, mut context GifReaderContext, kind u8) ! {
	match kind {
		0xfe {
			codec.comments << GifCommentExtension{
				comment: []u8{}
			}
			comment := gif_read_sub_blocks(mut stream)!
			codec.comments[codec.comments.len - 1].comment = comment
		}
		0xff {
			stream.toss(1)
			mut identifier := []u8{len: 8}
			stream.read_slice_all(mut identifier)!
			mut authentication := []u8{len: 3}
			stream.read_slice_all(mut authentication)!
			data := gif_read_sub_blocks(mut stream)!
			info := GifApplicationExtension{
				application_identifier: [identifier[0], identifier[1], identifier[2], identifier[3],
					identifier[4], identifier[5], identifier[6], identifier[7]]!
				authentification_code:  [authentication[0], authentication[1], authentication[2]]!
				data:                   data
			}
			if gif_animation_extension(info) { context.has_animation_application_extension = true }
			codec.application_infos << info
		}
		else {
			return error('InvalidData')
		}
	}
}

fn (mut codec GIF) read_image_descriptor_and_data(mut stream ReadStream, mut context GifReaderContext) ! {
	if mut frame := context.current_frame_data {
		mut image := frame.alloc_new_sub_image()!
		image.image_descriptor = gif_read_descriptor(mut stream)!
		descriptor := image.image_descriptor
		if descriptor.width == 0 || descriptor.height == 0 { return }
		count := usize(1) << (descriptor.flags.local_color_table_size() + 1)
		image.local_color_table.resize(count)
		if descriptor.flags.has_local_color_table() {
			for i in 0 .. int(count) {
				image.local_color_table.data[i] = gif_read_color(mut stream)!
			}
		}
		image.pixels = []u8{len: int(usize(descriptor.height) * descriptor.width)}
		mut writer := WriteStream.init_memory(mut image.pixels)
		code_size := stream.take_byte()!
		if code_size == 0x3b { return error('InvalidData') }
		mut decoder := lzw_decoder_init[LittleEndian](code_size, 0)!
		defer { decoder.deinit() }
		mut size := stream.take_byte()!
		for size > 0 {
			mut data := []u8{len: int(size)}
			stream.read_slice_all(mut data)!
			mut reader := ReadStream.init_memory(data)
			decoder.decode(mut reader, mut writer) or {
				if err.msg() != 'WriteFailed' { return error('InvalidData') }
			}
			size = stream.take_byte()!
		}
	}
}

fn (codec &GIF) create_new_animation_frame(format PixelFormat) !AnimationFrame {
	mut pixels := PixelStorage.init(format, usize(codec.header.width) * codec.header.height)!
	if format !in [.indexed1, .indexed2, .indexed4, .indexed8, .rgb24, .rgba32] {
		panic('Pixel format ${format} not supported')
	}
	if mut pixels is Rgba32Pixels {
		for i in 0 .. pixels.data.len {
			pixels.data[i] = Rgba32{
				a: 0
			}
		}
	}
	return AnimationFrame{
		pixels:   pixels
		duration: 0
	}
}

fn (codec &GIF) find_best_pixel_format() PixelFormat {
	mut total := usize(0)
	if codec.header.flags.use_global_color_table() {
		total = usize(1) << (codec.header.flags.global_color_table_size() + 1)
	}
	mut transparent := false
	mut max_colors := usize(0)
	for frame in codec.frames {
		if control := frame.graphics_control {
			if control.flags.has_transparent_color() { transparent = true }
		}
		mut colors := usize(0)
		for image in frame.sub_images {
			if image.image_descriptor.flags.has_local_color_table() {
				colors += usize(1) << (image.image_descriptor.flags.local_color_table_size() + 1)
			}
		}
		if colors > max_colors { max_colors = colors }
	}
	total += max_colors
	if total <= 2 { return .indexed1 }
	if total <= 4 { return .indexed2 }
	if total <= 16 { return .indexed4 }
	if total <= 256 { return .indexed8 }
	return if transparent { PixelFormat.rgba32 } else { PixelFormat.rgb24 }
}

fn gif_fill_palette(mut frame AnimationFrame, colors []Rgb24, transparent ?u8) {
	_ = transparent
	if mut palette := frame.pixels.get_palette() {
		count := if colors.len < palette.len { colors.len } else { palette.len }
		for i in 0 .. count {
			palette[i] = Rgba32{
				r: colors[i].r
				g: colors[i].g
				b: colors[i].b
			}
		}
	}
}

fn gif_fill_background(mut frame AnimationFrame, colors []Rgb24, index u8) {
	if index >= colors.len { return }
	format := frame.pixels.pixel_format()
	mut bytes := frame.pixels.as_bytes()
	match mut frame.pixels {
		IndexedStorage1, IndexedStorage2, IndexedStorage4, IndexedStorage8 {
			if usize(index) >= usize(1) << format.bits_per_channel() {
				panic('integer does not fit in destination type')
			}
			for i in 0 .. bytes.len {
				bytes[i] = index
			}
		}
		Rgb24Pixels {
			for i in 0 .. frame.pixels.data.len {
				frame.pixels.data[i] = colors[index]
			}
		}
		Rgba32Pixels {
			color := colors[index]
			// The source feeds u32Rgb into from.u32Rgba here, shifting the channels.
			for i in 0 .. frame.pixels.data.len {
				frame.pixels.data[i] = Rgba32{
					r: 0
					g: color.r
					b: color.g
					a: color.b
				}
			}
		}
		else {
			panic('Pixel format ${frame.pixels.pixel_format()} not supported')
		}
	}
}

fn gif_copy_frame(source &AnimationFrame, mut target AnimationFrame) {
	assert target.pixels.pixel_format() in [.indexed1, .indexed2, .indexed4, .indexed8, .rgb24,
		.rgba32]
	assert source.pixels.pixel_format() == target.pixels.pixel_format()
	bytes := source.pixels.as_bytes()
	mut destination := target.pixels.as_bytes()
	assert bytes.len == destination.len
	copy(mut destination, bytes)
}

fn gif_store_index(mut frame AnimationFrame, target usize, index u8, checked bool) {
	bits := frame.pixels.pixel_format().bits_per_channel()
	mask := u8((u16(1) << bits) - 1)
	if checked && index > mask { panic('integer does not fit in destination type') }
	mut bytes := frame.pixels.as_bytes()
	bytes[int(target)] = index & mask
}

fn gif_plot_pixel(image &GifSubImage, mut frame AnimationFrame, colors []Rgb24, transparent ?u8, source usize, target usize) {
	if source >= usize(image.pixels.len) || target >= frame.pixels.len() { return }
	index := image.pixels[int(source)]
	if transparency := transparent {
		if index == transparency { return }
	}
	match mut frame.pixels {
		IndexedStorage1, IndexedStorage2, IndexedStorage4, IndexedStorage8 {
			gif_store_index(mut frame, target, index, false)
		}
		Rgb24Pixels {
			if index < colors.len { frame.pixels.data[int(target)] = colors[index] }
		}
		Rgba32Pixels {
			if index < colors.len {
				color := colors[index]
				frame.pixels.data[int(target)] = Rgba32{
					r: color.r
					g: color.g
					b: color.b
				}
			}
		}
		else {
			panic('Pixel format ${frame.pixels.pixel_format()} not supported')
		}
	}
}

fn (codec &GIF) render_sub_image(image &GifSubImage, mut frame AnimationFrame, colors []Rgb24, transparent ?u8) {
	descriptor := image.image_descriptor
	if descriptor.flags.is_interlaced() {
		mut source_y := usize(0)
		for pass in [[usize(0), 8], [usize(4), 8], [usize(2), 4],
			[usize(1), 2]] {
			for target_y := pass[0] + descriptor.top_position; target_y < codec.header.height; target_y += pass[1] {
				for x := usize(0); x < descriptor.width; x++ {
					gif_plot_pixel(image, mut frame, colors, transparent,

						source_y * descriptor.width + x, target_y * codec.header.width + x +
						descriptor.left_position)
				}
				source_y++
			}
		}
	} else {
		for y := usize(0); y < descriptor.height; y++ {
			for x := usize(0); x < descriptor.width; x++ {
				gif_plot_pixel(image, mut frame, colors, transparent, y * descriptor.width + x,
					(y + descriptor.top_position) * codec.header.width + x +
					descriptor.left_position)
			}
		}
	}
}

fn (codec &GIF) replace_with_background(image &GifSubImage, mut frame AnimationFrame, colors []Rgb24, transparent ?u8) {
	index := transparent or { codec.header.background_color_index }
	descriptor := image.image_descriptor
	for y := usize(0); y < descriptor.height; y++ {
		for x := usize(0); x < descriptor.width; x++ {
			if y * descriptor.width + x >= usize(image.pixels.len) { continue
			 }
			target := (y + descriptor.top_position) * codec.header.width + x +
				descriptor.left_position
			if target >= frame.pixels.len() { return }
			match mut frame.pixels {
				IndexedStorage1, IndexedStorage2, IndexedStorage4, IndexedStorage8 {
					gif_store_index(mut frame, target, index, true)
				}
				Rgb24Pixels {
					if index < colors.len { frame.pixels.data[int(target)] = colors[index] }
				}
				Rgba32Pixels {
					if index < colors.len {
						color := colors[index]
						frame.pixels.data[int(target)] = Rgba32{
							r: color.r
							g: color.g
							b: color.b
						}
					}
				}
				else {
					panic('Pixel format ${frame.pixels.pixel_format()} not supported')
				}
			}
		}
	}
}

fn (codec &GIF) render() ![]AnimationFrame {
	format := codec.find_best_pixel_format()
	mut frames := []AnimationFrame{}
	if codec.frames.len == 0 {
		mut frame := codec.create_new_animation_frame(format)!
		gif_fill_palette(mut frame, codec.global_color_table.data, none)
		gif_fill_background(mut frame, codec.global_color_table.data,
			codec.header.background_color_index)
		frames << frame
		return frames
	}
	mut canvas := codec.create_new_animation_frame(format)!
	mut previous := codec.create_new_animation_frame(format)!
	if codec.header.flags.use_global_color_table() {
		gif_fill_palette(mut canvas, codec.global_color_table.data, none)
		gif_fill_background(mut canvas, codec.global_color_table.data,
			codec.header.background_color_index)
		gif_copy_frame(&canvas, mut previous)
	}
	mut has_control := false
	for frame in codec.frames {
		if frame.graphics_control != none {
			has_control = true
			break
		}
	}
	for frame in codec.frames {
		mut current := codec.create_new_animation_frame(format)!
		mut transparent := ?u8(none)
		mut dispose := GifDisposeMethod.none
		if control := frame.graphics_control {
			current.duration = f32(control.delay_time) * f32(1.0 / 100.0)
			if control.flags.has_transparent_color() {
				transparent = control.transparent_color_index
			}
			dispose = control.flags.disposal_method()
		}
		if codec.header.flags.use_global_color_table() {
			gif_fill_palette(mut current, codec.global_color_table.data, transparent)
		}
		for image in frame.sub_images {
			colors := if image.image_descriptor.flags.has_local_color_table() {
				image.local_color_table.data
			} else {
				codec.global_color_table.data
			}
			if image.image_descriptor.flags.has_local_color_table() {
				gif_fill_palette(mut current, colors, transparent)
			}
			codec.render_sub_image(image, mut canvas, colors, transparent)
		}
		gif_copy_frame(&canvas, mut current)
		if !has_control || frame.graphics_control != none { frames << current }
		match dispose {
			.restore_to_previous {
				gif_copy_frame(&previous, mut canvas)
			}
			.restore_background_color {
				for image in frame.sub_images {
					colors := if image.image_descriptor.flags.has_local_color_table() {
						image.local_color_table.data
					} else {
						codec.global_color_table.data
					}
					codec.replace_with_background(image, mut canvas, colors, transparent)
				}
				gif_copy_frame(&canvas, mut previous)
			}
			else {
				gif_copy_frame(&canvas, mut previous)
			}
		}
	}
	return frames
}
