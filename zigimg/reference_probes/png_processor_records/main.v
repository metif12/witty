module main

import zigimg as z

struct Context {
mut:
	calls u32
	fail  bool
	bias  u8
}

fn chunk(ctx voidptr, mut data z.PngChunkProcessData) !z.PixelFormat {
	mut self := unsafe { &Context(ctx) }
	self.calls++
	data.read_stream.take(1)!
	data.chunk_id += self.bias
	data.chunk_length = 17
	data.current_format = .rgba32
	if self.fail { return error('Unsupported') }
	return .rgba64
}

fn palette(ctx voidptr, mut data z.PngPaletteProcessData) ! {
	mut self := unsafe { &Context(ctx) }
	self.calls++
	data.palette[0].a = self.bias
	if self.fail { return error('Unsupported') }
	data.palette = unsafe { data.palette[..1] }
}

fn row(ctx voidptr, mut data z.PngRowProcessData) !z.PixelFormat {
	mut self := unsafe { &Context(ctx) }
	self.calls++
	data.dest_row[0] = self.bias
	data.src_format = .rgb24
	if self.fail { return error('Unsupported') }
	data.dest_row = unsafe { data.dest_row[..1] }
	data.dest_format = .rgba64
	return .rgba32
}

fn main() {
	options := z.PngReaderOptions{}
	initialized := z.PngReaderOptions.init()
	trns := z.PngTrnsProcessor{}
	plte := z.PngPlteProcessor{}
	println('D|${options.processors.len}|${initialized.processors.len}|${trns.trns_data is z.PngTrnsUnset}|${trns.processed}|${plte.processed}')
	mut gray := z.PngTrnsProcessor{
		trns_data: z.PngTrnsGray{
			value: 7
		}
	}
	gray_copy := gray
	gray.trns_data = z.PngTrnsGray{
		value: 65535
	}
	mut rgb := z.PngTrnsProcessor{
		trns_data: z.PngTrnsRGB{
			color: z.Rgb48{
				r: 1
				g: 2
				b: 3
			}
		}
	}
	rgb_copy := rgb
	rgb.trns_data = z.PngTrnsRGB{
		color: z.Rgb48{
			r: 42
			g: 2
			b: 3
		}
	}
	mut alpha := [u8(11), 22]
	mut indexed := z.PngTrnsProcessor{
		trns_data: z.PngTrnsIndexAlpha{
			data: unsafe { alpha[..] }
		}
	}
	indexed_copy := indexed
	match mut indexed.trns_data {
		z.PngTrnsIndexAlpha {
			indexed.trns_data.data[0] = 33
		}
		else {
			panic('wrong arm')
		}
	}

	indexed.trns_data = z.PngTrnsIndexAlpha{
		data: unsafe { alpha[..1] }
	}
	gray_old := (gray_copy.trns_data as z.PngTrnsGray).value
	gray_now := (gray.trns_data as z.PngTrnsGray).value
	rgb_old := (rgb_copy.trns_data as z.PngTrnsRGB).color.r
	rgb_now := (rgb.trns_data as z.PngTrnsRGB).color.r
	indexed_old := indexed_copy.trns_data as z.PngTrnsIndexAlpha
	indexed_now := indexed.trns_data as z.PngTrnsIndexAlpha
	println('U|${gray_old}|${gray_now}|${rgb_old}|${rgb_now}|${indexed_old.data[0]}|${alpha[0]}|${indexed_old.data.len}|${indexed_now.data.len}')
	for mask in 0 .. 8 {
		for fail in [false, true] {
			for bias in [u8(0), 1, 127, 255] {
				mut bytes := [u8(1), 2, 3, 4]
				mut stream := z.ReadStream.init_memory(bytes)
				mut header := z.PngHeaderData{
					width:              3
					height:             4
					bit_depth:          8
					color_type:         .grayscale
					compression_method: .deflate
					filter_method:      .adaptive
					interlace_method:   .none
				}
				mut ctx := Context{
					fail: fail
					bias: bias
				}
				mut table := z.PngReaderProcessorVTable{
					chunk_processor:    none
					palette_processor:  none
					data_row_processor: none
				}
				if mask & 1 != 0 { table.chunk_processor = chunk }
				if mask & 2 != 0 { table.palette_processor = palette }
				if mask & 4 != 0 { table.data_row_processor = row }
				mut processor := z.PngReaderProcessor{
					id:      1
					context: unsafe { voidptr(&ctx) }
					vtable:  &table
				}
				copied := processor
				processor.id = 99
				mut cdata := z.PngChunkProcessData{
					read_stream:    &stream
					chunk_id:       100
					chunk_length:   3
					current_format: .grayscale8
					header:         &header
				}
				mut ccopy := cdata
				cdata.chunk_id = 200
				header.width = 42
				mut cstatus := 'ok'
				cresult := copied.process_chunk(mut ccopy) or {
					cstatus = err.msg()
					z.PixelFormat.invalid
				}
				mut colors := [z.Rgba32{ r: 1, g: 2, b: 3, a: 4 },
					z.Rgba32{ r: 5, g: 6, b: 7, a: 8 }]
				mut pdata := z.PngPaletteProcessData{
					palette: unsafe { colors[..] }
				}
				pcopy := pdata
				mut pstatus := 'ok'
				copied.process_palette(mut pdata) or { pstatus = err.msg() }
				mut values := [u8(10), 20, 30, 40]
				mut rdata := z.PngRowProcessData{
					dest_row:    unsafe { values[..] }
					src_format:  .grayscale8
					dest_format: .rgba32
					header:      &header
				}
				rcopy := rdata
				mut rstatus := 'ok'
				rresult := copied.process_data_row(mut rdata) or {
					rstatus = err.msg()
					z.PixelFormat.invalid
				}
				println('C|${mask}|${fail}|${bias}|${cstatus}|${u32(cresult)}|${pstatus}|${rstatus}|${u32(rresult)}|${ctx.calls}|${stream.get_pos()}|${processor.id}|${copied.id}|${cdata.chunk_id}|${ccopy.chunk_id}|${ccopy.chunk_length}|${u32(ccopy.current_format)}|${ccopy.header.width}|${pdata.palette.len}|${pcopy.palette.len}|${pcopy.palette[0].a}|${rdata.dest_row.len}|${rcopy.dest_row[0]}|${u32(rdata.src_format)}|${u32(rcopy.src_format)}|${copied.context == unsafe { voidptr(&ctx) }}|${copied.vtable == &table}')
				table.chunk_processor = none
				table.palette_processor = none
				table.data_row_processor = none
				cafter := copied.process_chunk(mut ccopy) or { panic(err) }
				copied.process_palette(mut pdata) or { panic(err) }
				rafter := copied.process_data_row(mut rdata) or { panic(err) }
				println('V|${mask}|${u32(cafter)}|${u32(rafter)}|${ctx.calls}')
				mut processors := [copied]
				with_processors :=
					z.PngReaderOptions.init_with_processors(unsafe { processors[..] })
				mut options_copy := with_processors
				options_copy.processors = unsafe { options_copy.processors[..0] }
				processors[0].id = 123
				println('O|${with_processors.processors.len}|${options_copy.processors.len}|${with_processors.processors[0].id}|${with_processors.processors.data == unsafe { voidptr(&processors[0]) }}')
			}
		}
	}
	mut one := z.PngCustomReaderOptions1.init(z.PngTrnsProcessor{})
	mut one_view := one.get()
	mut one_copy := one
	one.processors[0].id = 123
	mut colors := [z.Rgba32{ r: 1, g: 2, b: 3, a: 4 }]
	mut data := z.PngPaletteProcessData{
		palette: unsafe { colors[..] }
	}
	one_copy.processors[0].process_palette(mut data) or { panic(err) }
	println('G1|${one_view.processors.len}|${one_view.processors[0].id}|${one_view.processors.data == unsafe { voidptr(&one.processors[0]) }}|${one_view.processors[0].context == unsafe { voidptr(&one.processor) }}|${one.processor.processed}|${one_copy.processor.processed}')
	one_view = one.get()
	println('G1R|${one_view.processors[0].id}|${one_view.processors[0].context == unsafe { voidptr(&one.processor) }}')
	mut two := z.PngCustomReaderOptions2.init(z.PngTrnsProcessor{}, z.PngPlteProcessor{})
	two_view := two.get()
	two.processors[1].process_palette(mut data) or { panic(err) }
	println('G2|${two_view.processors.len}|${two_view.processors[0].id}|${two_view.processors[1].id}|${two_view.processors.data == unsafe { voidptr(&two.processors[0]) }}|${two_view.processors[0].context == unsafe { voidptr(&two.processor1) }}|${two_view.processors[1].context == unsafe { voidptr(&two.processor2) }}|${two.processor2.palette[0].a}')
	colors[0].a = 77
	println('GB|${two.processor2.palette[0].a}|${two.processor2.processed}')
	mut defaults := z.PngDefaultOptions.init(z.PngTrnsProcessor{})
	default_view := defaults.get()
	println('GD|${default_view.processors.len}|${default_view.processors[0].id}|${default_view.processors[0].context == unsafe { voidptr(&defaults.processor) }}')
}
