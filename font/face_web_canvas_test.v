module font

fn test_web_canvas_grapheme_ids_are_stable_and_reversible() {
	mut face := WebCanvasFace{}
	defer { face.deinit() }
	first := face.grapheme_glyph_index('👩🏽‍💻'.bytes()) or { panic(err) }
	second := face.grapheme_glyph_index('👩🏽‍💻'.bytes()) or { panic(err) }
	third := face.grapheme_glyph_index('ñ'.bytes()) or { panic(err) }
	assert first == web_canvas_grapheme_start
	assert second == first
	assert third == first + 1
	assert face.glyph_to_grapheme[first].bytestr() == '👩🏽‍💻'
	assert face.glyph_to_grapheme[third].bytestr() == 'ñ'
}

fn test_web_canvas_grapheme_id_exhaustion() {
	mut face := WebCanvasFace{
		grapheme_next: 0
	}
	defer { face.deinit() }
	if _ := face.grapheme_glyph_index('ab'.bytes()) {
		assert false, 'wrapped grapheme IDs must be rejected'
	} else {
		assert err.msg().contains('out of grapheme')
	}
}

fn test_web_canvas_native_platform_fails_explicitly() {
	$if !js {
		if _ := WebCanvasFace.init_named('monospace', DesiredSize{
			points: 12
		}, .text) {
			assert false, 'native builds do not provide the browser Canvas API'
		} else {
			assert err.msg().contains('JavaScript backend')
		}
	}
}

fn test_web_canvas_deferred_presentation_fast_rejection() {
	deferred := WebCanvasDeferredFace{
		font_str: 'monospace'
		presentation: .text
	}
	assert !deferred.has_codepoint(u32(`A`), Presentation.emoji)
}
