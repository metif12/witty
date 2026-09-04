module renderer

import font
import terminal
import configpkg

// ============================================================
// Renderer tests
// ============================================================

// Test creating a DerivedConfig with defaults.
fn test_derived_config_defaults() {
	config := DerivedConfig{}
	assert config.background_opacity == 1.0
	assert config.cursor_opacity == 1.0
	assert config.min_contrast == 0.0
	assert config.vsync == true
	assert config.faint_opacity == 128
}

// Test DerivedConfig init and deinit.
fn test_derived_config_deinit() {
	mut config := DerivedConfig{
		font_features: ['liga', 'calt']
	}
	config.deinit()
	assert config.font_features.len == 0
}

fn test_derived_config_compiles_default_links() {
	cfg := configpkg.Config.default_config()
	mut derived := DerivedConfig.init(&cfg)!
	assert derived.links.links.len == 1
	derived.deinit()
	assert derived.links.links.len == 0
}

fn test_derived_config_preserves_explicit_bold_color() {
	mut cfg := configpkg.Config.default_config()
	cfg.load_string('bold-color = #123456\n')
	mut derived := DerivedConfig.init(&cfg)!
	bold := derived.bold_color or { panic('missing bold color') }
	assert !bold.bright
	assert bold.color == terminal.RGB{ r: 0x12, g: 0x34, b: 0x56 }
	derived.deinit()
}

fn test_terminal_color_resolves_explicit_and_cell_colors() {
	fg := terminal.RGB{ r: 10, g: 20, b: 30 }
	bg := terminal.RGB{ r: 40, g: 50, b: 60 }
	explicit := configpkg.TerminalColor{
		color: configpkg.ColorRGB{ r: 1, g: 2, b: 3 }
	}
	assert resolve_terminal_color(explicit, false, fg, bg) == terminal.RGB{ r: 1, g: 2, b: 3 }
	assert resolve_terminal_color(configpkg.TerminalColor{ kind: .cell_foreground }, false, fg, bg) == fg
	assert resolve_terminal_color(configpkg.TerminalColor{ kind: .cell_foreground }, true, fg, bg) == bg
	assert resolve_terminal_color(configpkg.TerminalColor{ kind: .cell_background }, false, fg, bg) == bg
	assert resolve_terminal_color(configpkg.TerminalColor{ kind: .cell_background }, true, fg, bg) == fg
}

// Test CellContents resize and reset.
fn test_cell_contents_resize() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 80, rows: 24 })!
	assert cells.size.columns == 80
	assert cells.size.rows == 24
	assert cells.bg_cells.len == 80 * 24
	assert cells.fg_rows.len == 24
}

// Test CellContents reset clears everything.
fn test_cell_contents_reset() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 10, rows: 5 })!

	// Set some bg cell data
	cells.set_bg(0, 0, CellBg{ r: 255, g: 0, b: 0, a: 255 })

	// Add a fg cell
	cells.add(.text, CellText{
		grid_pos: [u16(0), u16(0)]!
		color: [u8(255), 255, 255, 255]!
		glyph_size: [u32(10), u32(20)]!
	})!

	cells.reset()

	// Check bg is cleared
	assert cells.bg_cells[0] == CellBg{}
	// Check fg is cleared
	assert cells.fg_rows[0].len == 0
}

// Test CellContents clear for a specific row.
fn test_cell_contents_clear_row() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 10, rows: 5 })!

	// Add fg cells to rows 0 and 1
	cells.add(.text, CellText{
		grid_pos: [u16(0), u16(0)]!
		color: [u8(255), 255, 255, 255]!
	})!
	cells.add(.text, CellText{
		grid_pos: [u16(0), u16(1)]!
		color: [u8(255), 255, 255, 255]!
	})!

	// Clear row 0 only
	cells.clear(0)
	assert cells.fg_rows[0].len == 0
	assert cells.fg_rows[1].len == 1
}

// Test cursor set/get.
fn test_cell_contents_cursor() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 80, rows: 24 })!

	// No cursor by default
	assert cells.get_cursor_glyph() == none

	// Set a cursor
	cursor_cell := CellText{
		bools: CellTextBools{ is_cursor_glyph: true }
		grid_pos: [u16(5), u16(10)]!
		color: [u8(255), 255, 255, 255]!
	}
	cells.set_cursor(cursor_cell, .block)

	got := cells.get_cursor_glyph() or {
		assert false, 'expected cursor'
		return
	}
	assert got.grid_pos[0] == 5
	assert got.grid_pos[1] == 10
	assert got.bools.is_cursor_glyph == true
}

// Test Uniforms default values.
fn test_uniforms_defaults() {
	u := Uniforms{}
	assert u.min_contrast == 0.0
	assert u.bools.cursor_wide == false
}

// Test ortho2d projection.
fn test_ortho2d() {
	m := ortho2d(0, 800, 600, 0)
	// Check that the matrix is a valid orthographic projection
	// m[0] = 2 / (right - left) = 2 / 800 = 0.0025
	assert m[0] > 0.0024 && m[0] < 0.0026
	// m[5] = 2 / (top - bottom) = 2 / -600 = -0.00333...
	assert m[5] < -0.003 && m[5] > -0.004
	assert m[15] == 1.0
}

// Test Size.terminal_size.
fn test_size_terminal_size() {
	s := Size{
		screen: ScreenSize{ width: 800, height: 600 }
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{ top: 5, bottom: 5, left: 5, right: 5 }
	}
	ts := s.terminal_size()
	// Usable area: 790x590, grid: 79x29, terminal: 790x580
	assert ts.width == 790
	assert ts.height == 580
}

// Test Size.blank_padding.
fn test_size_blank_padding() {
	s := Size{
		screen: ScreenSize{ width: 800, height: 600 }
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{ top: 0, bottom: 0, left: 0, right: 0 }
	}
	grid := GridSize{ columns: 80, rows: 30 }
	bp := s.blank_padding(grid)
	// Screen 800x600, grid 80*10=800, 30*20=600 => no extra padding
	assert bp.left == 0
	assert bp.right == 0
	assert bp.top == 0
	assert bp.bottom == 0
}

// Test Padding.add.
fn test_padding_add() {
	a := Padding{ top: 5, bottom: 5, left: 10, right: 10 }
	b := Padding{ top: 3, bottom: 3, left: 7, right: 7 }
	c := a.add(b)
	assert c.top == 8
	assert c.bottom == 8
	assert c.left == 17
	assert c.right == 17
}

// Test GridSize.
fn test_grid_size() {
	mut s := Size{
		screen: ScreenSize{ width: 800, height: 600 }
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{ top: 0, bottom: 0, left: 0, right: 0 }
	}
	g := s.grid()
	assert g.columns == 80
	assert g.rows == 30
}

// Test ScreenSize.equals.
fn test_screen_size_equals() {
	a := ScreenSize{ width: 800, height: 600 }
	b := ScreenSize{ width: 800, height: 600 }
	c := ScreenSize{ width: 1024, height: 768 }
	assert a.equals(b)
	assert !a.equals(c)
}

// Test Health enum.
fn test_health_enum() {
	h := Health.healthy
	assert h == .healthy
	assert h != .unhealthy
}

// Test CursorStyle enum values.
fn test_cursor_style_enum() {
	assert CursorStyle.block != CursorStyle.bar
	assert CursorStyle.block_hollow != CursorStyle.underline
}

// Test BgImageBuffer defaults.
fn test_bg_image_buffer_defaults() {
	buf := BgImageBuffer{}
	assert buf.opacity == 1.0
	assert buf.info.position == .mc
	assert buf.info.fit == .contain
	assert buf.info.repeat == false
}

// Test CustomShaderUniforms defaults.
fn test_custom_shader_uniforms_defaults() {
	u := CustomShaderUniforms{}
	assert u.focus == 1
	assert u.frame_rate == 60.0
	assert u.time == 0.0
	assert $sizeof(CustomShaderUniforms) == 4480
	assert __offsetof(CustomShaderUniforms, channel_time) == 32
	assert __offsetof(CustomShaderUniforms, palette) == 288
}

// Test HighlightTag enum.
fn test_highlight_tag() {
	t1 := HighlightTag.search_match
	t2 := HighlightTag.search_match_selected
	assert t1 != t2
	assert u8(t1) == 0
	assert u8(t2) == 1
}

// Test Preedit width calculation.
fn test_preedit_width() {
	p := Preedit{
		codepoints: [
			PreeditCodepoint{ codepoint: 0x3042, wide: true }, // あ (wide)
			PreeditCodepoint{ codepoint: 0x3044, wide: true }, // い (wide)
			PreeditCodepoint{ codepoint: 0x61, wide: false }, // a (narrow)
		]
	}
	assert p.width() == 5 // 2 + 2 + 1
}

// Test CellText initialization.
fn test_cell_text_init() {
	ct := CellText{
		atlas: .grayscale
		bools: CellTextBools{ no_min_contrast: true }
		grid_pos: [u16(42), u16(7)]!
		color: [u8(200), 100, 50, 255]!
		glyph_pos: [u32(100), u32(200)]!
		glyph_size: [u32(8), u32(16)]!
		bearings: [i32(1), i32(-2)]!
	}
	assert ct.atlas == .grayscale
	assert ct.bools.no_min_contrast == true
	assert ct.grid_pos[0] == 42
	assert ct.grid_pos[1] == 7
	assert ct.color[0] == 200
	assert ct.glyph_size[0] == 8
	assert ct.bearings[1] == -2
}

// Test UniformBools initialization.
fn test_uniform_bools() {
	b := UniformBools{
		cursor_wide: true
		use_display_p3: true
	}
	assert b.cursor_wide == true
	assert b.use_display_p3 == true
	assert b.use_linear_blending == false
}

// Test PaddingExtend.
fn test_padding_extend() {
	pe := PaddingExtend{
		up: true
		down: true
		left: true
		right: true
	}
	assert pe.up == true
	assert pe.right == true
}

// Test multiple fg cells per row.
fn test_multiple_fg_cells_per_row() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 80, rows: 24 })!

	// Add multiple cells to the same row
	for col in 0 .. 10 {
		cells.add(.text, CellText{
			grid_pos: [u16(col), u16(0)]!
			color: [u8(255), 255, 255, 255]!
			glyph_size: [u32(8), u32(16)]!
		})!
	}

	assert cells.fg_rows[0].len == 10
	assert cells.fg_rows[1].len == 0
}

// Test set_bg / get_bg.
fn test_bg_cell_set_get() ! {
	mut cells := CellContents{}
	cells.resize(GridSize{ columns: 10, rows: 5 })!

	// Set bg for cell at (3, 2)
	cells.set_bg(2, 3, CellBg{ r: 100, g: 150, b: 200, a: 255 })

	// Read it back
	idx := 2 * 10 + 3
	assert cells.bg_cells[idx] == CellBg{ r: 100, g: 150, b: 200, a: 255 }

	// Also test get_bg
	got := cells.get_bg(2, 3)
	assert got.r == 100
	assert got.g == 150
	assert got.b == 200
	assert got.a == 255
}

// Test AtlasKind enum.
fn test_atlas_kind() {
	assert AtlasKind.grayscale != AtlasKind.color
}

// Test CellLayer enum.
fn test_cell_layer() {
	assert CellLayer.text != CellLayer.underline
	assert CellLayer.overline != CellLayer.strikethrough
}

// Test FontStyleStatus defaults.
fn test_font_style_status() {
	s := FontStyleStatus{}
	assert s.bold == true
	assert s.italic == true
	assert s.bold_italic == true
}

// Test Size.balance_padding.
fn test_balance_padding() {
	mut s := Size{
		screen: ScreenSize{ width: 810, height: 610 }
		cell: CellSize{ width: 10, height: 20 }
		padding: Padding{}
	}
	s.balance_padding(Padding{ top: 0, bottom: 0, left: 0, right: 0 })
	// 810/10 = 81 cols, extra 0. 610/20 = 30 rows, extra 10.
	assert s.padding.top == 5
	assert s.padding.bottom == 5
}

// Verify the production row path shapes codepoints, rasterizes their glyphs,
// and emits foreground cells backed by the shared font atlases.
fn test_rebuild_row_shapes_and_renders_text() ! {
	mut library := font.Library.init()!
	defer { library.deinit() }

	mut collection := font.Collection.init()
	collection.load_options = font.LoadOptions{
		library: library
		size: font.DesiredSize{
			points: 12
			xdpi: 96
			ydpi: 96
		}
	}
	load_opts := collection.load_options or { return error('missing font load options') }
	collection.add(font.Face.init_mem(library, font.embedded_regular, load_opts.face_options())!, font.AddOptions{
		style: .regular
		fallback: false
		size_adjustment: .none_
	})!

	mut grid := font.SharedGrid.init(font.CodepointResolver{
		collection: collection
	})!
	defer { grid.deinit() }

	mut render := Renderer.init(RendererOpts{
		font_grid: &grid
		config: DerivedConfig{}
		size: Size{
			screen: ScreenSize{ width: 300, height: 100 }
			cell: CellSize{
				width: grid.metrics.cell_width
				height: grid.metrics.cell_height
			}
		}
	})!
	defer { render.deinit() }
	render.cells.resize(GridSize{ columns: 3, rows: 1 })!

	row := terminal.RenderRow{
		cells: [
			terminal.RenderCell{ raw: terminal.CellData.init(u32(`A`)) },
			terminal.RenderCell{ raw: terminal.CellData.init(u32(`B`)) },
			terminal.RenderCell{ raw: terminal.CellData.init(u32(`C`)) },
		]
	}
	links := terminal.CellSet{}
	render.rebuild_row(0, &row, none, &links)!

	assert render.cells.fg_rows[0].len == 3
	for cell in render.cells.fg_rows[0] {
		assert cell.glyph_size[0] > 0
		assert cell.glyph_size[1] > 0
	}
	assert grid.glyphs.len == 3

	// Exercise the complete off-screen Metal frame path with the exact cells
	// produced above. This compiles/binds all resources, draws the background
	// and glyph instances, commits the command buffer, and waits for the GPU.
	render.uniforms.grid_size = [u16(3), 1]!
	render.update_screen_size_uniforms()
	render.cells_rebuilt = true
	render.draw_frame(true)!
	assert render.health == .healthy
	assert render.frame_index == 0
	assert render.frames[0].target.width == 300
	assert render.frames[0].target.height == 100
}
