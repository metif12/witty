module zigimg

struct PngRecordContext {
mut:
	calls int
}

fn png_record_error_callback(context voidptr, mut data PngPaletteProcessData) ! {
	mut state := unsafe { &PngRecordContext(context) }
	state.calls++
	data.palette[0].a = 91
	return error('Unsupported')
}

fn test_png_processor_table_and_palette_borrow_on_error() {
	mut state := PngRecordContext{}
	mut table := PngReaderProcessorVTable{
		chunk_processor:    none
		palette_processor:  png_record_error_callback
		data_row_processor: none
	}
	processor := PngReaderProcessor{
		id:      1
		context: unsafe { voidptr(&state) }
		vtable:  &table
	}
	mut colors := [Rgba32{ r: 1, g: 2, b: 3, a: 4 }, Rgba32{ r: 5, g: 6, b: 7, a: 8 }]
	mut data := PngPaletteProcessData{
		palette: unsafe { colors[..] }
	}
	copy := data
	mut failed := false
	processor.process_palette(mut data) or { failed = err.msg() == 'Unsupported' }
	assert failed
	assert state.calls == 1
	assert colors[0].a == 91
	assert copy.palette[0].a == 91
	assert copy.palette.len == 2
	table.palette_processor = none
	processor.process_palette(mut data) or { panic(err) }
	assert state.calls == 1
}

fn test_png_processor_whole_payload_replacement_and_slice_borrow() {
	mut processor := PngTrnsProcessor{
		trns_data: PngTrnsGray{
			value: 7
		}
	}
	copy := processor
	processor.trns_data = PngTrnsGray{
		value: 65535
	}
	assert (copy.trns_data as PngTrnsGray).value == 7
	assert (processor.trns_data as PngTrnsGray).value == 65535
	mut bytes := [u8(3), 4]
	mut indexed := PngTrnsProcessor{
		trns_data: PngTrnsIndexAlpha{
			data: unsafe { bytes[..] }
		}
	}
	index_copy := indexed
	bytes[0] = 17
	indexed.trns_data = PngTrnsIndexAlpha{
		data: unsafe { bytes[..1] }
	}
	assert (index_copy.trns_data as PngTrnsIndexAlpha).data[0] == 17
	assert (index_copy.trns_data as PngTrnsIndexAlpha).data.len == 2
	assert (indexed.trns_data as PngTrnsIndexAlpha).data.len == 1
}

fn test_png_processor_options_borrow_processor_array() {
	mut trns := PngTrnsProcessor{}
	mut processors := [trns.processor()]
	options := PngReaderOptions.init_with_processors(unsafe { processors[..] })
	mut copy := options
	copy.processors = unsafe { copy.processors[..0] }
	processors[0].id = 123
	assert options.processors[0].id == 123
	assert options.processors.len == 1
	assert copy.processors.len == 0
	assert options.processors.data == unsafe { voidptr(&processors[0]) }
}

fn test_png_custom_processor_options_get_borrows_owner_and_refreshes() {
	mut options := PngCustomReaderOptions1.init(PngTrnsProcessor{})
	view := options.get()
	mut copied := options
	options.processors[0].id = 123
	assert view.processors[0].id == 123
	assert view.processors.data == unsafe { voidptr(&options.processors[0]) }
	mut colors := [Rgba32{ r: 1, g: 2, b: 3, a: 4 }]
	mut data := PngPaletteProcessData{
		palette: unsafe { colors[..] }
	}
	copied.processors[0].process_palette(mut data) or { panic(err) }
	assert options.processor.processed
	assert !copied.processor.processed
	refreshed := options.get()
	assert refreshed.processors[0].id == png_chunk_trns.id
	assert refreshed.processors[0].context == unsafe { voidptr(&options.processor) }
}

fn test_png_processor_defined_defaults() {
	assert PngReaderOptions{}.processors.len == 0
	assert PngReaderOptions.init().processors.len == 0
	trns := PngTrnsProcessor{}
	assert trns.trns_data is PngTrnsUnset
	assert !trns.processed
	assert !PngPlteProcessor{}.processed
}
