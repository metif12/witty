module font

fn named_coretext_test_face(name string, points f32) !CoreTextFace {
	base := C.witty_coretext_create_font_named(&char(name.str), f64(points))
	if base == unsafe { nil } {
		return error('CoreText font unavailable: ${name}')
	}
	defer { C.witty_coretext_release(base) }
	return CoreTextFace.init_font_copy(base, FaceOptions{
		size: DesiredSize{
			points: points
		}
	})
}

fn test_coretext_basic_ascii_rendering() {
	$if macos {
		mut face := named_coretext_test_face('Menlo', 12) or { panic(err) }
		defer { face.deinit() }
		metrics := Metrics.calc(face.get_metrics())
		mut atlas := Atlas.init(512, .grayscale)
		defer { atlas.deinit() }
		for cp in u32(32) .. u32(127) {
			glyph := face.glyph_index(cp) or { panic('Menlo is missing ASCII ${cp}') }
			face.render_glyph(mut atlas, glyph, RenderOptions{
				grid_metrics: metrics
			}) or { panic(err) }
		}
	}
}

fn test_coretext_name() {
	$if macos {
		mut face := named_coretext_test_face('Menlo', 12) or { panic(err) }
		defer { face.deinit() }
		mut buf := []u8{len: 1024}
		assert face.name(mut buf)! == 'Menlo'
	}
}

fn test_coretext_emoji_color_detection() {
	$if macos {
		mut face := named_coretext_test_face('Apple Color Emoji', 18) or { panic(err) }
		defer { face.deinit() }
		glyph := face.glyph_index(0x1f978) or { panic('emoji glyph unavailable') }
		assert face.is_color_glyph(glyph)
	}
}

fn test_coretext_in_memory_font() {
	$if macos {
		mut face := CoreTextFace.init(Library{}, embedded_regular, FaceOptions{
			size: DesiredSize{
				points: 12
			}
		}) or { panic(err) }
		defer { face.deinit() }
		assert face.glyph_index(u32(`A`)) != none
		mut atlas := Atlas.init(128, .grayscale)
		defer { atlas.deinit() }
		glyph := face.glyph_index(u32(`A`)) or { panic('missing A') }
		info := face.render_glyph(mut atlas, glyph, RenderOptions{
			grid_metrics: Metrics.calc(face.get_metrics())
		}) or { panic(err) }
		assert info.width > 0
		assert info.height > 0
	}
}

fn test_coretext_variable_font_variation() {
	$if macos {
		opts := FaceOptions{
			size: DesiredSize{
				points: 12
			}
		}
		mut face := CoreTextFace.init(Library{}, embedded_variable, opts) or { panic(err) }
		defer { face.deinit() }
		face.set_variations([Variation{
			id: VariationId.init('wght')
			value: 400
		}], opts) or { panic(err) }
		assert face.glyph_index(u32(`A`)) != none
	}
}

fn test_coretext_svg_font_table_and_color_range() {
	$if macos {
		mut face := CoreTextFace.init(Library{}, embedded_julia_mono, FaceOptions{
			size: DesiredSize{
				points: 12
			}
		}) or { panic(err) }
		defer { face.deinit() }
		table := face.copy_table('SVG ') or { panic(err) }
		assert table.len > 0
		text_glyph := face.glyph_index(u32(`A`)) or { panic('missing A') }
		assert !face.is_color_glyph(text_glyph)
		color_glyph := face.glyph_index(0xe800) or { panic('missing SVG glyph') }
		assert face.is_color_glyph(color_glyph)
	}
}

fn test_coretext_deferred_face_queries_and_load() {
	$if macos {
		font_ptr := C.witty_coretext_create_font_named(c'Menlo', 12)
		if font_ptr == unsafe { nil } {
			panic('Menlo unavailable')
		}
		mut deferred := CoreTextDeferredFace{
			ct_font: font_ptr
		}
		defer { deferred.deinit() }
		assert deferred.has_codepoint(u32(`A`), .text)
		assert !deferred.has_codepoint(u32(`A`), .emoji)
		mut buf := []u8{len: 1024}
		assert deferred.family_name(mut buf)! == 'Menlo'
		mut display_buf := []u8{len: 1024}
		assert deferred.name(mut display_buf)!.len > 0
		mut loaded := deferred.load(Library{}, FaceOptions{
			size: DesiredSize{
				points: 13
			}
		}) or { panic(err) }
		defer { loaded.deinit() }
		assert loaded.glyph_index(u32(`A`)) != none
	}
}
