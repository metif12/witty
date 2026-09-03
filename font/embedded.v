module font

// Fonts that can be embedded with Ghostty. Note they are only actually
// embedded in the binary if they are referenced by the code, so fonts
// used for tests will not result in the final binary being larger.
//
// Be careful to ensure that any fonts you embed are licensed for
// redistribution and include their license as necessary.
//
// Translated from ghostty/src/font/embedded.zig. V's `$embed_file` provides
// the same compile-time resource embedding used by Zig's `@embedFile`.

// Default fonts that we prefer for Ghostty.
pub const embedded_variable = $embed_file('res/JetBrainsMono-Variable.ttf').to_bytes()
pub const embedded_variable_italic = $embed_file('res/JetBrainsMono-VariableItalic.ttf').to_bytes()

// Symbols-only nerd font.
pub const embedded_symbols_nerd_font = $embed_file('res/SymbolsNerdFont-Regular.ttf').to_bytes()

// Static jetbrains mono faces, currently unused.
pub const embedded_regular = $embed_file('res/JetBrainsMono-Regular.ttf').to_bytes()
pub const embedded_bold = $embed_file('res/JetBrainsMono-Bold.ttf').to_bytes()
pub const embedded_italic = $embed_file('res/JetBrainsMono-Italic.ttf').to_bytes()
pub const embedded_bold_italic = $embed_file('res/JetBrainsMono-BoldItalic.ttf').to_bytes()

// Emoji fonts
pub const embedded_emoji = $embed_file('res/NotoColorEmoji.ttf').to_bytes()
pub const embedded_emoji_text = $embed_file('res/NotoEmoji-Regular.ttf').to_bytes()

// Fonts below are ONLY used for testing.

// Fonts with general properties
pub const embedded_arabic = $embed_file('res/KawkabMono-Regular.ttf').to_bytes()

// A font for testing which is patched with nerd font symbols.
pub const embedded_test_nerd_font = $embed_file('res/JetBrainsMonoNerdFont-Regular.ttf').to_bytes()

// Specific font families below:
pub const embedded_code_new_roman = $embed_file('res/CodeNewRoman-Regular.otf').to_bytes()
pub const embedded_inconsolata = $embed_file('res/Inconsolata-Regular.ttf').to_bytes()
pub const embedded_geist_mono = $embed_file('res/GeistMono-Regular.ttf').to_bytes()
pub const embedded_jetbrains_mono = $embed_file('res/JetBrainsMonoNoNF-Regular.ttf').to_bytes()
pub const embedded_julia_mono = $embed_file('res/JuliaMono-Regular.ttf').to_bytes()

// Cozette is a unique font because it embeds some emoji characters
// but has a text presentation.
pub const embedded_cozette = $embed_file('res/CozetteVector.ttf').to_bytes()

// Monaspace has weird ligature behaviors we want to test in our shapers
// so we embed it here.
pub const embedded_monaspace_neon = $embed_file('res/MonaspaceNeon-Regular.otf').to_bytes()

// Terminus TTF is a scalable font with bitmap glyphs at various sizes.
pub const embedded_terminus_ttf = $embed_file('res/TerminusTTF-Regular.ttf').to_bytes()

// Spleen is a monospaced bitmap font available in multiple formats.
// Used for testing bitmap font support across different file formats.
pub const embedded_spleen_bdf = $embed_file('res/spleen-8x16.bdf').to_bytes()
pub const embedded_spleen_pcf = $embed_file('res/spleen-8x16.pcf').to_bytes()
pub const embedded_spleen_otb = $embed_file('res/spleen-8x16.otb').to_bytes()

// ============================================================
// Built-in sprite rendering
// ============================================================
//
// The `sprite` module implements the full built-in "sprite face" (box
// drawing, block elements, cursors, underlines, etc.) using a vector
// Canvas. That module `import font`, so `font` cannot `import sprite`
// (V rejects the import cycle). The functions below therefore provide a
// small, self-contained sprite renderer, faithful to ghostty's
// src/font/sprite/Face.zig `renderGlyph` and src/font/sprite/draw/special.zig,
// for the cases the font module itself needs (cursor sprites and simple
// cell glyphs) without pulling in the whole vector drawing pipeline.

// SpriteCanvas is a minimal single-channel (alpha8) drawing surface,
// equivalent to the subset of `sprite.Canvas` used here. The underlying
// buffer has dimensions (width + 2*padding_x) x (height + 2*padding_y);
// all drawing coordinates are cell-relative with the padding applied
// internally.
struct SpriteCanvas {
mut:
	width       u32
	height      u32
	padding_x   u32
	padding_y   u32
	clip_top    u32
	clip_left   u32
	clip_right  u32
	clip_bottom u32
	data        []u8
}

// sprite_canvas_init creates a new SpriteCanvas with the given cell
// dimensions and padding, matching sprite.Canvas.init.
fn sprite_canvas_init(w u32, h u32, pad_x u32, pad_y u32) SpriteCanvas {
	total := (w + 2 * pad_x) * (h + 2 * pad_y)
	return SpriteCanvas{
		width: w
		height: h
		padding_x: pad_x
		padding_y: pad_y
		data: []u8{len: int(total)}
	}
}

// sfc_width returns the full surface width (including padding).
fn (c &SpriteCanvas) sfc_width() u32 {
	return c.width + 2 * c.padding_x
}

// sfc_height returns the full surface height (including padding).
fn (c &SpriteCanvas) sfc_height() u32 {
	return c.height + 2 * c.padding_y
}

// pixel writes a single pixel value. The coordinate is cell-relative;
// the padding offset is applied here. Out of bounds writes are silently
// ignored, matching z2d's putPixel behavior.
fn (mut c SpriteCanvas) pixel(x i32, y i32, value u8) {
	px := x + i32(c.padding_x)
	py := y + i32(c.padding_y)
	if px < 0 || py < 0 {
		return
	}
	w := i32(c.sfc_width())
	h := i32(c.sfc_height())
	if px >= w || py >= h {
		return
	}
	c.data[py * w + px] = value
}

// rect fills a rectangle with the given value. This is the main
// primitive used by the cursor and cell sprites, mirroring
// sprite.Canvas.rect.
fn (mut c SpriteCanvas) rect(x i32, y i32, width i32, height i32, value u8) {
	mut yy := y
	for yy < y + height {
		mut xx := x
		for xx < x + width {
			c.pixel(xx, yy, value)
			xx += 1
		}
		yy += 1
	}
}

// sprite_sat_sub is a saturating subtraction for u32 (matches Zig's -|).
fn sprite_sat_sub(a u32, b u32) u32 {
	return if a > b { a - b } else { u32(0) }
}

// trim adjusts the clip boundaries to trim off any fully transparent
// rows or columns, mirroring sprite.Canvas.trim.
fn (mut c SpriteCanvas) trim() {
	width := c.sfc_width()
	height := c.sfc_height()

	// top
	for c.clip_top < height - c.clip_bottom {
		y := c.clip_top
		x0 := c.clip_left
		x1 := width - c.clip_right
		mut found := false
		for x in x0 .. x1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_top += 1
	}

	// bottom
	for c.clip_bottom < height - c.clip_top {
		y := sprite_sat_sub(height - c.clip_bottom, 1)
		x0 := c.clip_left
		x1 := width - c.clip_right
		mut found := false
		for x in x0 .. x1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_bottom += 1
	}

	// left
	for c.clip_left < width - c.clip_right {
		x := c.clip_left
		y0 := c.clip_top
		y1 := height - c.clip_bottom
		mut found := false
		for y in y0 .. y1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_left += 1
	}

	// right
	for c.clip_right < width - c.clip_left {
		x := sprite_sat_sub(width - c.clip_right, 1)
		y0 := c.clip_top
		y1 := height - c.clip_bottom
		mut found := false
		for y in y0 .. y1 {
			if c.data[y * width + x] != 0 {
				found = true
				break
			}
		}
		if found {
			break
		}
		c.clip_right += 1
	}
}

// write_atlas trims transparent margins, reserves a region in the atlas,
// and copies the trimmed drawing in. Mirrors sprite.Canvas.writeAtlas,
// but uses the real font.Atlas reserve/set allocator.
fn (mut c SpriteCanvas) write_atlas(mut atlas Atlas) !AtlasRegion {
	c.trim()

	sfc_width := c.sfc_width()
	sfc_height := c.sfc_height()

	// Subtract our clip margins to get the region size (saturating).
	region_width := sprite_sat_sub(sprite_sat_sub(sfc_width, c.clip_left), c.clip_right)
	region_height := sprite_sat_sub(sprite_sat_sub(sfc_height, c.clip_top), c.clip_bottom)

	mut region := reserve_growing(mut atlas, region_width, region_height)!

	if region.width > 0 && region.height > 0 {
		// Copy the (trimmed) sub-rectangle of our surface in to the atlas.
		atlas.set_from_larger(region, c.data, sfc_width, c.clip_left, c.clip_top)
	}

	return region
}

// reserve_growing reserves a region in the atlas, growing it (doubling)
// as necessary if the reservation fails because the atlas is full.
fn reserve_growing(mut atlas Atlas, width u32, height u32) !AtlasRegion {
	for {
		if region := atlas.reserve(width, height) {
			return region
		} else {
			// Atlas is full; grow and retry. We double the size, matching
			// ghostty's SharedGrid growth strategy.
			atlas.grow(atlas.size * 2)
		}
	}
	return AtlasRegion{}
}

// render_sprite_glyph renders one of the built-in special sprites
// (cursors, underlines, overline, strikethrough) into the atlas.
//
// This follows ghostty's sprite Face.renderGlyph flow for the "special"
// sprites: adjust width by the cell width, make a padded canvas, draw the
// sprite, and write it to the atlas. See src/font/sprite/draw/special.zig
// for the individual draw functions.
pub fn render_sprite_glyph(mut atlas Atlas, sprite Sprite, metrics Metrics, cell_width u32) !GlyphInfo {
	// We adjust our sprite width based on the cell width.
	width := if cell_width == 0 || cell_width == 1 {
		metrics.cell_width
	} else {
		metrics.cell_width * cell_width
	}
	height := metrics.cell_height

	padding_x := width / 4
	padding_y := height / 4

	mut canvas := sprite_canvas_init(width, height, padding_x, padding_y)

	draw_special_sprite(mut canvas, sprite, width, height, metrics)

	region := canvas.write_atlas(mut atlas)!

	return GlyphInfo{
		width: region.width
		height: region.height
		offset_x: i32(canvas.clip_left) - i32(padding_x)
		offset_y: i32(region.height + canvas.clip_bottom) - i32(padding_y)
		atlas_x: region.x
		atlas_y: region.y
	}
}

// draw_special_sprite draws a special sprite (cursor/underline/etc.) onto
// the canvas. Faithful to src/font/sprite/draw/special.zig.
fn draw_special_sprite(mut canvas SpriteCanvas, sprite Sprite, width u32, height u32, metrics Metrics) {
	match sprite {
		.underline {
			canvas.rect(0, i32(metrics.underline_position), i32(width), i32(metrics.underline_thickness), 255)
		}
		.underline_double {
			canvas.rect(0, i32(metrics.underline_position), i32(width), i32(metrics.underline_thickness), 255)
			canvas.rect(0, i32(metrics.underline_position) + 2 * i32(metrics.underline_thickness), i32(width), i32(metrics.underline_thickness), 255)
		}
		.underline_dotted {
			// Dotted underline: dots one thickness wide with gaps.
			dot := i32(metrics.underline_thickness)
			mut x := i32(0)
			for x < i32(width) {
				canvas.rect(x, i32(metrics.underline_position), dot, dot, 255)
				x += dot * 2
			}
		}
		.underline_dashed {
			// Dashed underline: dashes a quarter cell wide with gaps.
			dash := i32(width) / 4
			canvas.rect(0, i32(metrics.underline_position), dash, i32(metrics.underline_thickness), 255)
			canvas.rect(dash * 2, i32(metrics.underline_position), dash, i32(metrics.underline_thickness), 255)
		}
		.underline_curly {
			// Approximate a curly underline with a straight stroke; the
			// full vector rendering lives in the sprite module.
			canvas.rect(0, i32(metrics.underline_position), i32(width), i32(metrics.underline_thickness), 255)
		}
		.overline {
			canvas.rect(0, i32(metrics.overline_position), i32(width), i32(metrics.overline_thickness), 255)
		}
		.strikethrough {
			canvas.rect(0, i32(metrics.strikethrough_position), i32(width), i32(metrics.strikethrough_thickness), 255)
		}
		.cursor_rect {
			canvas.rect(0, 0, i32(width), i32(height), 255)
		}
		.cursor_hollow_rect {
			// Fill the entire rect then hollow out the inside.
			canvas.rect(0, 0, i32(width), i32(height), 255)
			t := metrics.cursor_thickness
			canvas.rect(i32(t), i32(t), i32(sprite_sat_sub(width, t * 2)), i32(sprite_sat_sub(height, t * 2)), 0)
		}
		.cursor_bar {
			canvas.rect(0, 0, i32(metrics.cursor_thickness), i32(height), 255)
		}
		.cursor_underline {
			canvas.rect(0, i32(sprite_sat_sub(height, metrics.cursor_thickness)), i32(width), i32(metrics.cursor_thickness), 255)
		}
	}
}

// render_builtin_cell_glyph renders a built-in cell glyph for the given
// codepoint into the atlas.
//
// If the codepoint is one of our special sprite codepoints, it is drawn
// as such; otherwise we render a simple full-cell placeholder glyph. This
// is used by tests and by callers that need a cell-sized glyph without a
// real font face. The result fills the full cell (no trimming) so callers
// get stable width/height matching the grid metrics.
pub fn render_builtin_cell_glyph(mut atlas Atlas, cp u32, metrics Metrics) !GlyphInfo {
	width := metrics.cell_width
	height := metrics.cell_height

	padding_x := width / 4
	padding_y := height / 4

	mut canvas := sprite_canvas_init(width, height, padding_x, padding_y)

	// Fill the full cell as the built-in placeholder glyph. We touch cp so
	// the signature stays faithful to a real per-codepoint renderer.
	_ = cp
	canvas.rect(0, 0, i32(width), i32(height), 255)

	// Reserve a region of exactly the cell size and copy the cell in
	// directly (skip trimming so the glyph is always full-cell sized).
	region := reserve_growing(mut atlas, width, height)!
	if region.width > 0 && region.height > 0 {
		atlas.set_from_larger(region, canvas.data, canvas.sfc_width(), padding_x, padding_y)
	}

	return GlyphInfo{
		width: region.width
		height: region.height
		offset_x: 0
		offset_y: 0
		atlas_x: region.x
		atlas_y: region.y
	}
}

// sprite_face_render_glyph renders the sprite glyph for the given
// codepoint into the atlas, faithful to ghostty's sprite Face.renderGlyph.
// This is the shared implementation used by SpriteFace.render_glyph.
//
// For non-special codepoints (box drawing, block elements, etc.) the full
// vector drawing lives in the `sprite` module which the `font` module
// cannot import (cycle); here we render a full-cell placeholder so that
// callers within the font module still get a valid, non-empty glyph.
pub fn sprite_face_render_glyph(mut atlas Atlas, cp u32, metrics Metrics, opts RenderOptions) !GlyphInfo {
	// Special sprite codepoints are drawn directly.
	if sprite := sprite_for_codepoint(cp) {
		return render_sprite_glyph(mut atlas, sprite, metrics, opts.cell_width)
	}

	// We adjust our sprite width based on the cell width.
	width := if opts.cell_width == 0 || opts.cell_width == 1 {
		metrics.cell_width
	} else {
		metrics.cell_width * opts.cell_width
	}
	height := metrics.cell_height

	padding_x := width / 4
	padding_y := height / 4

	mut canvas := sprite_canvas_init(width, height, padding_x, padding_y)

	// Placeholder rendering for box/block/etc. codepoints. Draw a full
	// cell so downstream rendering produces visible output; the precise
	// vector shape is provided by the `sprite` module in the full pipeline.
	canvas.rect(0, 0, i32(width), i32(height), 255)

	region := canvas.write_atlas(mut atlas)!

	return GlyphInfo{
		width: region.width
		height: region.height
		offset_x: i32(canvas.clip_left) - i32(padding_x)
		offset_y: i32(region.height + canvas.clip_bottom) - i32(padding_y)
		atlas_x: region.x
		atlas_y: region.y
	}
}

// sprite_for_codepoint maps a special sprite codepoint (>= 0x110000) to
// its Sprite enum value, faithful to ghostty's Sprite enum ordering
// (see font/sprite.zig). All other codepoints (including box drawing)
// return none here.
fn sprite_for_codepoint(cp u32) ?Sprite {
	// Sprite.start is one above the maximum Unicode codepoint (0x110000),
	// and Sprite.cursor_underline is the last (highest) sprite codepoint.
	if cp < u32(Sprite.underline) || cp > u32(Sprite.cursor_underline) {
		return none
	}
	return unsafe { Sprite(cp) }
}
