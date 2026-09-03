module font

// Tests for SharedGrid.
// Translated from ghostty/src/font/SharedGrid.zig tests.

fn make_grid(mode string) !SharedGrid {
	_ = mode
	mut c := Collection.init()
	c.load_options = LoadOptions{
		library: Library.init()!
		size: DesiredSize{
			points: 12
			xdpi: 96
			ydpi: 96
		}
	}

	load_opts := c.load_options or { return error('missing load options') }
	c.add(Face.init_mem(load_opts.library, embedded_regular,
		load_opts.face_options())!, AddOptions{
		style: .regular
		fallback: false
		size_adjustment: .none_
	})!

	r := CodepointResolver{
		collection: c
	}

	return SharedGrid.init(r)!
}

fn test_shared_grid_get_index() {
	mut grid := make_grid('normal') or { panic(err) }
	defer { grid.deinit() }
	for cp := u32(32); cp < 127; cp++ {
		value := grid.get_index(cp, .regular, none) or { panic(err) }
		assert value.has_value
		assert value.index.style == .regular
		assert value.index.idx == 0
		assert grid.has_codepoint(value.index, cp, none)
	}
	// The second pass exercises the cached lookup path.
	for cp := u32(32); cp < 127; cp++ {
		value := grid.get_index(cp, .regular, none) or { panic(err) }
		assert value.has_value && value.index.idx == 0
	}
}

fn test_shared_grid_render_glyph_cache() {
	mut grid := make_grid('normal') or { panic(err) }
	defer { grid.deinit() }
	value := grid.get_index(u32(`A`), .regular, none) or { panic(err) }
	face := grid.resolver.collection.get_face(value.index) or { panic(err) }
	glyph_index := face.glyph_index(u32(`A`)) or { panic('missing A') }
	opts := RenderOptions{grid_metrics: grid.metrics}
	first := grid.render_glyph(value.index, glyph_index, opts) or { panic(err) }
	count := grid.glyphs.len
	second := grid.render_glyph(value.index, glyph_index, opts) or { panic(err) }
	assert first == second
	assert grid.glyphs.len == count
}

fn test_shared_grid_cell_size() {
	mut grid := make_grid('normal') or { panic(err) }
	defer { grid.deinit() }
	cs := grid.cell_size()
	assert cs.width > 0
	assert cs.height > 0
}

fn test_shared_grid_init_deinit() {
	mut grid := make_grid('normal') or { panic(err) }
	grid.deinit()
}
