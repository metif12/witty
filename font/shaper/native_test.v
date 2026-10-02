module shaper

import font

fn test_native_shaper_selected_backend_reaches_native_face() ! {
	$if !macos { return }
	for backend in [font.Backend.coretext, .coretext_harfbuzz, .coretext_noshape, .coretext_freetype,
		.freetype] {
		mut library := font.Library.init_backend(backend)!
		mut collection := font.Collection.init()
		collection.load_options = font.LoadOptions{
			library: library
			size:    font.DesiredSize{
				points: 12
			}
		}
		options := collection.load_options or { return error('missing load options') }
		mut face := font.Face.init_mem(library, font.embedded_regular, options.face_options())!
		assert face.backend == backend
		if backend.has_freetype() {
			assert !isnil(face.face.handle)
			assert isnil(face.ct_font)
		} else {
			assert isnil(library.lib.handle)
			assert isnil(face.face.handle)
			assert !isnil(face.ct_font)
		}
		assert (!isnil(face.hb_font.ptr)) == backend.has_harfbuzz()
		collection.add(face, font.AddOptions{ style: .regular })!
		mut grid := font.SharedGrid.init(font.CodepointResolver{ collection: collection })!
		mut selected := NativeShaper.init_backend(backend, font.ShaperOptions{ features: [
			'-liga,+dlig',
			'kern==1',
		] })!
		assert selected.backend == backend
		if backend == .coretext { assert !isnil(selected.coretext)
		 }
		if backend.has_harfbuzz() { assert selected.harfbuzz.hb_feats.len == 4
		 }
		mut iterator := selected.run_iterator(font.RunOptions{ grid: &grid, cells: [
			u8(`A`),
			`B`,
		] })
		run := (iterator.next()!).get() or { return error('missing run') }
		cells := selected.shape(run)!
		assert cells.len == 2
		assert cells[0].x == 0
		assert cells[1].x == 1
		assert cells[0].glyph_index > 0
		assert cells[1].glyph_index > 0
		if backend == .coretext_noshape {
			loaded := grid.resolver.collection.get_face(run.font_index)!
			assert cells[0].glyph_index == loaded.glyph_index(u32(`A`)) or { 0 }
		}
		selected.end_frame()
		selected.deinit()
		grid.deinit()
		library.deinit()
	}
}

fn test_native_discovery_deferred_load_preserves_render_backend() ! {
	$if !macos { return }
	for backend in [font.Backend.coretext, .coretext_freetype] {
		mut discover := font.Discover.init_backend(backend)
		defer { discover.deinit() }
		mut iterator := discover.discover(font.Descriptor{ family: 'Menlo', size: 12 })!
		defer { iterator.deinit() }
		value := iterator.next()!
		assert value.has_value
		mut deferred := value.face
		defer { deferred.deinit() }
		mut library := font.Library.init_backend(backend)!
		defer { library.deinit() }
		mut face := deferred.load(library, font.FaceOptions{ size: font.DesiredSize{ points: 12 } })!
		defer { face.deinit() }
		assert face.backend == backend
		assert (!isnil(face.face.handle)) == backend.has_freetype()
		assert (!isnil(face.ct_font)) == !backend.has_freetype()
		assert face.glyph_index(u32(`A`)) != none
	}
	for backend in [font.Backend.freetype, .web_canvas] {
		mut discover := font.Discover.init_backend(backend)
		defer { discover.deinit() }
		mut iterator := discover.discover(font.Descriptor{ family: 'Menlo', size: 12 })!
		defer { iterator.deinit() }
		assert !(iterator.next()!).has_value
	}
}
