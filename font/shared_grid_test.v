module font

// Tests for SharedGrid.
// Translated from ghostty/src/font/SharedGrid.zig tests.

fn make_grid(mode string) !SharedGrid {
	// XTODO: needs real embedded font data loaded into the collection.
	// For now, set up a minimal collection with load_options.
	mut c := Collection.init()
	c.load_options = LoadOptions{
		library: Library.init()!
		size: DesiredSize{
			points: 12
			xdpi: 96
			ydpi: 96
		}
	}

	// XTODO: add a real font face when embedded fonts are available.
	// _ = c.add(Face.init_mem(c.load_options.?.library, embedded_regular,
	//     c.load_options.?.face_options())!, AddOptions{
	//     style: .regular
	//     fallback: false
	//     size_adjustment: .none_
	// })!

	r := CodepointResolver{
		collection: c
	}

	return SharedGrid.init(r)!
}

fn test_shared_grid_get_index() {
	// XTODO: needs real embedded font data.
	// When embedded fonts are available:
	//
	// mut grid := make_grid('normal') or { return }
	// defer { grid.deinit() }
	//
	// // Visible ASCII.
	// for i in u32(32) .. u32(127) {
	//     idx := grid.get_index(i, .regular, none) or { continue } or { continue }
	//     assert idx.style == .regular
	//     assert idx.idx == 0
	//     assert grid.has_codepoint(idx, i, none)
	// }
	//
	// // Do it again without a resolver set to ensure we only hit the cache
	// old_resolver := grid.resolver
	// grid.resolver = CodepointResolver{}
	// defer { grid.resolver = old_resolver }
	// for i in u32(32) .. u32(127) {
	//     idx := grid.get_index(i, .regular, none) or { continue } or { continue }
	//     assert idx.style == .regular
	//     assert idx.idx == 0
	// }
}

fn test_shared_grid_render_glyph_cache() {
	// XTODO: needs real embedded font data.
	// This test verifies that when renderGlyph fails after inserting a cache
	// entry (via getOrPut), the errdefer properly removes the entry, preventing
	// corrupted/uninitialized data from remaining in the cache.
	//
	// When embedded fonts are available:
	// mut grid := make_grid('normal') or { return }
	// defer { grid.deinit() }
	//
	// // Get the font index for 'A'
	// idx := grid.get_index(u32(`A`), .regular, none) or { return } or { return }
	//
	// // Get the glyph index for 'A'
	// face := grid.resolver.collection.get_face(idx) or { return }
	// glyph_index := face.glyph_index(u32(`A`)) or { return }
	//
	// render_opts := RenderOptions{ grid_metrics: grid.metrics }
	// key := GlyphKey{ index: idx, glyph: glyph_index, opts: render_opts }
	//
	// // Verify the cache is empty for this glyph
	// assert key !in grid.glyphs
}

fn test_shared_grid_cell_size() {
	// XTODO: needs real embedded font data.
	// When available:
	// mut grid := make_grid('normal') or { return }
	// defer { grid.deinit() }
	// cs := grid.cell_size()
	// assert cs.width > 0
	// assert cs.height > 0
}

fn test_shared_grid_init_deinit() {
	// Test that init and deinit don't leak memory.
	// XTODO: needs real embedded font data for full test.
	// For now just test the struct can be created and destroyed.
	mut grid := SharedGrid{
		atlas_grayscale: Atlas.init(64, .grayscale)
		atlas_color: Atlas.init(64, .bgra)
	}
	grid.deinit()
}
