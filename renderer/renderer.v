module renderer

import gg
import sync
import terminal
import font
import time

// Create a renderer type with the provided graphics API wrapper.
//
// The graphics API wrapper must provide the interface outlined below.
// Specific details for the interfaces are documented on the existing
// implementations (Metal and OpenGL).
//
// In this V translation, we use gg.Context as our graphics backend,
// which handles Metal/OpenGL/Vulkan selection internally.
//
// Hierarchy of graphics abstractions:
//
// [ GraphicsAPI ] - Responsible for configuring the runtime surface
//    |     |        and providing render Targets that draw to it,
//    |     |        as well as Frames and Pipelines.
//    |     V
//    | [ Target ] - Represents an abstract target for rendering, which
//    |              could be a surface directly but is also used as an
//    |              abstraction for off-screen frame buffers.
//    V
// [ Frame ] - Represents the context for drawing a given frame,
//    |        provides RenderPasses for issuing draw commands
//    |        to, and reports the frame health when complete.
//    V
// [ RenderPass ] - Represents a render pass in a frame, consisting of
//   :              one or more Steps applied to the same target(s),
// [ Step ] - - - - each describing the input buffers and textures and
//   :              the vertex/fragment functions and geometry to use.
//   :_ _ _ _ _ _ _ _ _ _/
//   v
// [ Pipeline ] - Describes a vertex and fragment function to be used
//                for a Step; the GraphicsAPI is responsible for
//                these and they should be constructed and cached
//                ahead of time.
//
// [ Buffer ] - An abstraction over a GPU buffer.
//
// [ Texture ] - An abstraction over a GPU texture.

// Renderer handles drawing the terminal surface using gg.
pub struct Renderer {
pub mut:
	// The gg context for rendering.
	ctx &gg.Context = unsafe { nil }

	// The configuration we need derived from the main config.
	config DerivedConfig

	// Current font metrics defining our grid.
	grid_metrics font.Metrics

	// The size of everything.
	size Size

	// True if the window is focused.
	focused bool = true

	// Flag to indicate that our focus state changed for custom
	// shaders to update their state.
	custom_shader_focused_changed bool

	// The most recent scrollbar state. We use this as a cache to
	// determine if we need to notify the apprt that there was a
	// scrollbar change.
	scrollbar terminal.Scrollbar
	// Whether the scrollbar state has changed since last frame.
	scrollbar_dirty bool

	// The most recent viewport matches so that we can render search
	// matches in the visible frame. This is provided asynchronously
	// from the search thread so we have the dirty flag to also note
	// if we need to rebuild our cells to include search highlights.
	//
	// Note that the selections MAY BE INVALID (point to PageList nodes
	// that do not exist anymore). These must be validated prior to use.
	search_matches_dirty bool

	// The current set of cells to render. This is rebuilt on every frame
	// but we keep this around so that we don't reallocate. Each set of
	// cells goes into a separate shader.
	cells CellContents

	// Set to true after rebuild_cells is called. This can be used
	// to determine if any possible changes have been made to the
	// cells for the draw call.
	cells_rebuilt bool

	// The current GPU uniform values.
	uniforms Uniforms

	// Custom shader uniform values.
	custom_shader_uniforms CustomShaderUniforms

	// Timestamp we rendered our first frame (nanoseconds since monotonic epoch).
	//
	// This is used when updating custom shader uniforms.
	first_frame_time i64 = -1

	// Timestamp when we rendered our most recent frame (nanoseconds since monotonic epoch).
	//
	// This is used when updating custom shader uniforms.
	last_frame_time i64 = -1

	// The font structures.
	font_grid &font.SharedGrid = unsafe { nil }
	font_shaper font.Shaper
	font_shaper_cache font.ShaperCache

	// Whether or not we have custom shaders.
	has_custom_shaders bool

	// If something happened that requires us to reinitialize our shaders,
	// this is set to true so that we can do that whenever possible.
	reinitialize_shaders bool

	// The render state we update per loop.
	terminal_state terminal.RenderState

	// The number of frames since the last terminal state reset.
	// We reset the terminal state after ~100,000 frames (about 10 to
	// 15 minutes at 120Hz) to prevent wasted memory buildup from
	// a large screen.
	terminal_state_frame_count u64

	// Background image data, if we have one.
	bg_image ?gg.Image

	// Set whenever the background image changes, signalling
	// that the new background image needs to be uploaded to
	// the GPU.
	//
	// This is initialized as true so that we load the image
	// on renderer initialization, not just on config change.
	bg_image_changed bool = true

	// Background image vertex buffer.
	bg_image_buffer BgImageBuffer

	// Health of the most recently completed frame.
	health Health = .healthy
}

// Initialize the renderer.
pub fn Renderer.init(opts RendererOpts) !Renderer {
	// Create the font shaper
	mut font_shaper := font.Shaper.init(font.ShaperOptions{})!

	// Get font metrics from the grid
	grid := opts.font_grid
	metrics := grid.metrics

	has_custom_shaders := false

	mut result := Renderer{
		config: opts.config
		grid_metrics: metrics
		size: opts.size
		focused: true
		scrollbar: terminal.Scrollbar{}
		scrollbar_dirty: false
		search_matches_dirty: false
		// Render state
		cells: CellContents{}
		uniforms: Uniforms{
			min_contrast: opts.config.min_contrast
			cursor_pos: [u16(0xFFFF), u16(0xFFFF)]!
			bg_color: [
				opts.config.background.r,
				opts.config.background.g,
				opts.config.background.b,
				u8(opts.config.background_opacity * 255.0),
			]!
			bools: UniformBools{
				cursor_wide: false
				use_display_p3: opts.config.colorspace == .display_p3
				use_linear_blending: opts.config.blending.is_linear()
				use_linear_correction: opts.config.blending == .linear_corrected
			}
		}
		custom_shader_uniforms: CustomShaderUniforms{
			focus: 1
		}
		// Fonts
		font_grid: opts.font_grid
		font_shaper: font_shaper
		font_shaper_cache: font.ShaperCache.init()
		has_custom_shaders: has_custom_shaders
	}

	// Ensure our undefined values above are correctly initialized
	result.update_font_grid_uniforms()
	result.update_screen_size_uniforms()
	result.update_bg_image_buffer()

	return result
}

// Deinitialize the renderer and free all resources.
pub fn (mut self Renderer) deinit() {
	self.terminal_state.deinit()
	self.font_shaper.deinit()
	self.font_shaper_cache.deinit()
	self.config.deinit()
}

// Mark the full screen as dirty so that we redraw everything.
pub fn (mut self Renderer) mark_dirty() {
	self.terminal_state.dirty = .full
}

// True if our renderer has animations so that a higher frequency
// timer is used.
pub fn (self &Renderer) has_animations() bool {
	return self.has_custom_shaders
}

// True if our renderer is using vsync. If true, the renderer or apprt
// is responsible for triggering draw_now calls to the render thread.
// That is the only way to trigger a draw_frame.
pub fn (self &Renderer) has_vsync() bool {
	return false
}

// Callback when the focus changes for the terminal this is rendering.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_focus(focus bool) ! {
	self.focused = focus

	// Flag that we need to update our custom shaders
	self.custom_shader_focused_changed = true
}

// Callback when the window is visible or occluded.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_visible(visible bool) {
	// On platforms with display links, we would start/stop
	// the display link here based on visibility. With gg,
	// visibility is managed by the framework.
	_ = visible
}

// Set the new font grid.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_font_grid(grid &font.SharedGrid) {
	// Update our grid
	self.font_grid = unsafe { grid }

	// Get our metrics from the grid. This doesn't require a lock because
	// the metrics are never recalculated.
	metrics := grid.metrics
	self.grid_metrics = metrics

	// Reset our shaper cache. If our font changed (not just the size) then
	// the data in the shaper cache may be invalid and cannot be used, so we
	// always clear the cache just in case.
	font_shaper_cache := font.ShaperCache.init()
	self.font_shaper_cache.deinit()
	self.font_shaper_cache = font_shaper_cache

	// Update cell size
	self.size.cell = CellSize{
		width: metrics.cell_width
		height: metrics.cell_height
	}

	// Update relevant uniforms
	self.update_font_grid_uniforms()

	// Force a full rebuild, because cached rows may still reference
	// an outdated atlas from the old grid and this can cause garbage
	// to be rendered.
	self.mark_dirty()
}

// Update uniforms that are based on the font grid.
fn (mut self Renderer) update_font_grid_uniforms() {
	self.uniforms.cell_size = [
		f32(self.grid_metrics.cell_width),
		f32(self.grid_metrics.cell_height),
	]!
}

// Update the frame data.
pub fn (mut self Renderer) update_frame(state &terminal.Terminal, cursor_blink_visible bool) ! {
	// XTODO: Full frame update requires complete terminal state integration.
	// This method should:
	// 1. Check synchronized output mode
	// 2. Update terminal_state from terminal
	// 3. Extract critical data (links, mouse, preedit, scrollbar)
	// 4. Update search highlights
	// 5. Rebuild cells
	// 6. Update uniforms

	// We fully deinit and reset the terminal state every so often
	// so that a particularly large terminal state doesn't cause
	// the renderer to hold on to retained memory.
	//
	// Frame count is ~12 minutes at 120Hz.
	max_terminal_state_frame_count := u64(100_000)
	if self.terminal_state_frame_count >= max_terminal_state_frame_count {
		self.terminal_state.deinit()
		self.terminal_state = terminal.RenderState{}
	}
	self.terminal_state_frame_count += 1

	// Update our background color
	self.uniforms.bg_color = [
		self.terminal_state.colors.background.r,
		self.terminal_state.colors.background.g,
		self.terminal_state.colors.background.b,
		u8(self.config.background_opacity * 255.0),
	]!

	// Update custom shader uniforms that depend on terminal state
	self.update_custom_shader_uniforms_from_state()

	// Signal shaper we're done for the frame
	self.font_shaper.end_frame()
}

// Draw the frame to the screen.
//
// If `sync` is true, this will synchronously block until
// the frame is finished drawing and has been presented.
pub fn (mut self Renderer) draw_frame(sync_ bool) ! {
	// XTODO: Full frame drawing requires gg integration.
	// This method should:
	// 1. Check if redraw is needed
	// 2. Begin gg frame
	// 3. Draw background color/image
	// 4. Draw cell backgrounds
	// 5. Draw text glyphs
	// 6. Draw images (kitty)
	// 7. Draw custom shaders
	// 8. End gg frame

	ctx := self.ctx
	if ctx == unsafe { nil } {
		return
	}

	// If either of our surface dimensions is zero
	// then drawing is absurd, so we just return.
	if self.size.screen.width == 0 || self.size.screen.height == 0 {
		return
	}

	// Conditions under which we need to draw the frame, otherwise we
	// don't need to since the previous frame should be identical.
	needs_redraw := self.cells_rebuilt || self.has_animations() || sync_

	if !needs_redraw {
		return
	}
	self.cells_rebuilt = false

	// Begin the gg frame
	ctx.begin()

	// Draw the background color
	bg_r := self.uniforms.bg_color[0]
	bg_g := self.uniforms.bg_color[1]
	bg_b := self.uniforms.bg_color[2]
	bg_a := self.uniforms.bg_color[3]
	ctx.draw_rect_filled(0, 0, f32(self.size.screen.width), f32(self.size.screen.height),
		gg.Color{
		r: bg_r
		g: bg_g
		b: bg_b
		a: bg_a
	})

	// Draw background image if we have one
	if bg := self.bg_image {
		self.draw_background_image(ctx, bg)
	}

	// Draw cell backgrounds
	self.draw_cell_backgrounds(ctx)

	// Draw foreground glyphs (text, underlines, etc)
	self.draw_cell_foregrounds(ctx)

	// Draw cursor
	self.draw_cursor(ctx)

	// End the gg frame
	ctx.end(gg.EndOptions{})

	_ = sync_
}

// Draw the background image.
fn (self &Renderer) draw_background_image(ctx &gg.Context, img gg.Image) {
	// XTODO: Background image rendering with position/fit/repeat
	// requires computing the correct source/dest rectangles based
	// on bg_image_buffer settings.
	opacity := self.bg_image_buffer.opacity
	ctx.draw_image_with_config(gg.DrawImageConfig{
		img: unsafe { &img }
		img_rect: gg.Rect{
			x: 0
			y: 0
			width: f32(self.size.screen.width)
			height: f32(self.size.screen.height)
		}
		color: gg.Color{
			r: 255
			g: 255
			b: 255
			a: u8(opacity * 255)
		}
	})
}

// Draw all cell background colors.
fn (self &Renderer) draw_cell_backgrounds(ctx &gg.Context) {
	cell_w := f32(self.grid_metrics.cell_width)
	cell_h := f32(self.grid_metrics.cell_height)
	pad_left := f32(self.size.padding.left)
	pad_top := f32(self.size.padding.top)

	for row in 0 .. int(self.cells.size.rows) {
		for col in 0 .. int(self.cells.size.columns) {
			idx := row * int(self.cells.size.columns) + col
			if idx >= self.cells.bg_cells.len {
				continue
			}
			bg := self.cells.bg_cells[idx]
			// Skip fully transparent backgrounds
			if bg.a == 0 {
				continue
			}
			x := pad_left + f32(col) * cell_w
			y := pad_top + f32(row) * cell_h
			ctx.draw_rect_filled(x, y, cell_w, cell_h, gg.Color{
				r: bg.r
				g: bg.g
				b: bg.b
				a: bg.a
			})
		}
	}
}

// Draw all foreground cells (text glyphs, underlines, etc).
fn (self &Renderer) draw_cell_foregrounds(ctx &gg.Context) {
	// XTODO: Proper glyph rendering requires font atlas texture
	// integration with gg. For now we use gg's text rendering
	// as a placeholder for text cells.
	cell_w := f32(self.grid_metrics.cell_width)
	cell_h := f32(self.grid_metrics.cell_height)
	pad_left := f32(self.size.padding.left)
	pad_top := f32(self.size.padding.top)

	for row_cells in self.cells.fg_rows {
		for cell in row_cells {
			x := pad_left + f32(cell.grid_pos[0]) * cell_w
			y := pad_top + f32(cell.grid_pos[1]) * cell_h

			// Draw a colored rectangle as placeholder for the glyph
			if cell.glyph_size[0] > 0 && cell.glyph_size[1] > 0 {
				gx := x + f32(cell.bearings[0])
				gy := y + f32(cell.bearings[1])
				gw := f32(cell.glyph_size[0])
				gh := f32(cell.glyph_size[1])
				ctx.draw_rect_filled(gx, gy, gw, gh, gg.Color{
					r: cell.color[0]
					g: cell.color[1]
					b: cell.color[2]
					a: cell.color[3]
				})
			}
		}
	}
}

// Draw the cursor.
fn (self &Renderer) draw_cursor(ctx &gg.Context) {
	cursor_cell := self.cells.cursor or { return }
	style := self.cells.cursor_style or { return }

	cell_w := f32(self.grid_metrics.cell_width)
	cell_h := f32(self.grid_metrics.cell_height)
	pad_left := f32(self.size.padding.left)
	pad_top := f32(self.size.padding.top)

	x := pad_left + f32(cursor_cell.grid_pos[0]) * cell_w
	y := pad_top + f32(cursor_cell.grid_pos[1]) * cell_h
	w := if self.uniforms.bools.cursor_wide { cell_w * 2 } else { cell_w }

	color := gg.Color{
		r: cursor_cell.color[0]
		g: cursor_cell.color[1]
		b: cursor_cell.color[2]
		a: cursor_cell.color[3]
	}

	match style {
		.block {
			ctx.draw_rect_filled(x, y, w, cell_h, color)
		}
		.block_hollow {
			ctx.draw_rect_empty(x, y, w, cell_h, color)
		}
		.bar {
			bar_w := f32(2)
			ctx.draw_rect_filled(x, y, bar_w, cell_h, color)
		}
		.underline {
			ul_h := f32(2)
			ctx.draw_rect_filled(x, y + cell_h - ul_h, w, ul_h, color)
		}
		.lock {
			// Draw a filled block as fallback for the lock cursor
			ctx.draw_rect_filled(x, y, w, cell_h, color)
		}
	}
}

// Callback from the graphics API when a frame is completed.
pub fn (mut self Renderer) frame_completed(health Health) {
	// If our health value hasn't changed, then we do nothing.
	if self.health != health {
		self.health = health
	}
}

// Call this any time the background image path changes.
fn (mut self Renderer) prep_background_image() ! {
	// XTODO: Background image loading requires file I/O and image
	// decoding (PNG/JPEG). With gg, we would use ctx.create_image().
	if self.config.bg_image != none {
		// Would load and decode the image here
		self.bg_image_changed = true
	} else {
		self.bg_image = none
	}
}

// Update the configuration.
pub fn (mut self Renderer) change_config(config &DerivedConfig) ! {
	// We always redo the font shaper in case font features changed. We
	// could check to see if there was an actual config change but this is
	// easier and rare enough to not cause performance issues.
	mut font_shaper := font.Shaper.init(font.ShaperOptions{
		features: config.font_features
	})!
	self.font_shaper.deinit()
	self.font_shaper = font_shaper

	// We also need to reset the shaper cache so shaper info
	// from the previous font isn't reused for the new font.
	font_shaper_cache := font.ShaperCache.init()
	self.font_shaper_cache.deinit()
	self.font_shaper_cache = font_shaper_cache

	// Set our new minimum contrast
	self.uniforms.min_contrast = config.min_contrast

	// Set our new color space and blending
	self.uniforms.bools.use_display_p3 = config.colorspace == .display_p3
	self.uniforms.bools.use_linear_blending = config.blending.is_linear()
	self.uniforms.bools.use_linear_correction = config.blending == .linear_corrected

	bg_image_config_changed := self.config.bg_image_fit != config.bg_image_fit
		|| self.config.bg_image_position != config.bg_image_position
		|| self.config.bg_image_repeat != config.bg_image_repeat
		|| self.config.bg_image_opacity != config.bg_image_opacity

	self.config.deinit()
	self.config = *config

	// If our background image config changed, update the vertex buffer
	if bg_image_config_changed {
		self.update_bg_image_buffer()
	}

	// Reset our viewport to force a rebuild, in case of a font change
	self.mark_dirty()
}

// Resize the screen.
pub fn (mut self Renderer) set_screen_size(size Size) {
	// We only actually need the padding from this,
	// everything else is derived elsewhere.
	self.size.padding = size.padding

	self.update_screen_size_uniforms()
}

// Update uniforms that are based on the screen size.
fn (mut self Renderer) update_screen_size_uniforms() {
	terminal_size := self.size.terminal_size()

	// Blank space around the grid
	blank := self.size.blank_padding(self.cells.size)

	// Setup our uniforms
	self.uniforms.projection_matrix = ortho2d(
		-1 * f32(self.size.padding.left),
		f32(terminal_size.width + self.size.padding.right),
		f32(terminal_size.height + self.size.padding.bottom),
		-1 * f32(self.size.padding.top),
	)
	self.uniforms.grid_padding = [
		f32(blank.top),
		f32(blank.right),
		f32(blank.bottom),
		f32(blank.left),
	]!
	self.uniforms.screen_size = [
		f32(self.size.screen.width),
		f32(self.size.screen.height),
	]!
}

// Update the background image vertex buffer (CPU-side).
//
// This should be called if and when configs change that
// could affect the background image.
fn (mut self Renderer) update_bg_image_buffer() {
	self.bg_image_buffer = BgImageBuffer{
		opacity: self.config.bg_image_opacity
		info: BgImageInfo{
			position: match self.config.bg_image_position {
				.top_left { .tl }
				.top_center { .tc }
				.top_right { .tr }
				.center_left { .ml }
				.center { .mc }
				.center_right { .mr }
				.bottom_left { .bl }
				.bottom_center { .bc }
				.bottom_right { .br }
			}
			fit: match self.config.bg_image_fit {
				.contain { .contain }
				.cover { .cover }
				.stretch { .stretch }
				.none_ { .none_ }
			}
			repeat: self.config.bg_image_repeat
		}
	}
}

// Update custom shader uniforms that depend on terminal state.
//
// This should be called in update_frame when terminal state changes.
fn (mut self Renderer) update_custom_shader_uniforms_from_state() {
	// We only need to do this if we have custom shaders
	if !self.has_custom_shaders {
		return
	}

	// Only update when terminal state is dirty
	if self.terminal_state.dirty == .false_ {
		return
	}

	colors := &self.terminal_state.colors

	// 256-color palette
	for i in 0 .. 256 {
		c := colors.palette[i]
		self.custom_shader_uniforms.palette[i] = [
			f32(c.r) / 255.0,
			f32(c.g) / 255.0,
			f32(c.b) / 255.0,
			f32(1.0),
		]!
	}

	// Background color
	self.custom_shader_uniforms.background_color = [
		f32(colors.background.r) / 255.0,
		f32(colors.background.g) / 255.0,
		f32(colors.background.b) / 255.0,
		f32(1.0),
	]!

	// Foreground color
	self.custom_shader_uniforms.foreground_color = [
		f32(colors.foreground.r) / 255.0,
		f32(colors.foreground.g) / 255.0,
		f32(colors.foreground.b) / 255.0,
		f32(1.0),
	]!

	// Cursor color
	if cursor_color := colors.cursor {
		self.custom_shader_uniforms.cursor_color = [
			f32(cursor_color.r) / 255.0,
			f32(cursor_color.g) / 255.0,
			f32(cursor_color.b) / 255.0,
			f32(1.0),
		]!
	}
}

// Update per-frame custom shader uniforms.
//
// This should be called exactly once per frame, inside draw_frame.
fn (mut self Renderer) update_custom_shader_uniforms_for_frame() ! {
	// We only need to do this if we have custom shaders
	if !self.has_custom_shaders {
		return
	}

	mut uniforms := &self.custom_shader_uniforms

	now := time.sys_mono_now()

	if self.first_frame_time >= 0 {
		since_ns := now - self.first_frame_time
		uniforms.time = f32(since_ns) / 1_000_000_000.0
	} else {
		self.first_frame_time = now
		uniforms.time = 0
	}

	if self.last_frame_time >= 0 {
		delta_ns := now - self.last_frame_time
		uniforms.time_delta = f32(delta_ns) / 1_000_000_000.0
	} else {
		uniforms.time_delta = 0
	}

	self.last_frame_time = now

	uniforms.frame += 1

	screen := self.size.screen

	uniforms.resolution = [
		f32(screen.width),
		f32(screen.height),
		f32(1),
	]!
	uniforms.channel_resolution[0] = [
		f32(screen.width),
		f32(screen.height),
		f32(1),
		f32(0),
	]!

	// Update custom cursor uniforms, if we have a cursor
	if cursor := self.cells.get_cursor_glyph() {
		cursor_width := f32(cursor.glyph_size[0])
		cursor_height := f32(cursor.glyph_size[1])

		cell := self.size.cell
		padding := self.size.padding

		// Left edge of the cell the cursor is in
		mut pixel_x := f32(u32(cursor.grid_pos[0]) * cell.width + padding.left)
		// Top edge of the cell the cursor is in
		pixel_y := f32(u32(cursor.grid_pos[1]) * cell.height + padding.top)

		// Add the X bearing to get the left edge of the cursor
		pixel_x += f32(cursor.bearings[0])

		new_cursor := [pixel_x, pixel_y, cursor_width, cursor_height]!
		new_cursor_color := [
			f32(cursor.color[0]) / 255.0,
			f32(cursor.color[1]) / 255.0,
			f32(cursor.color[2]) / 255.0,
			f32(cursor.color[3]) / 255.0,
		]!

		cursor_changed := new_cursor[0] != uniforms.current_cursor[0]
			|| new_cursor[1] != uniforms.current_cursor[1]
			|| new_cursor[2] != uniforms.current_cursor[2]
			|| new_cursor[3] != uniforms.current_cursor[3]
			|| new_cursor_color[0] != uniforms.current_cursor_color[0]
			|| new_cursor_color[1] != uniforms.current_cursor_color[1]
			|| new_cursor_color[2] != uniforms.current_cursor_color[2]
			|| new_cursor_color[3] != uniforms.current_cursor_color[3]

		if cursor_changed {
			uniforms.previous_cursor = uniforms.current_cursor
			uniforms.previous_cursor_color = uniforms.current_cursor_color
			uniforms.current_cursor = new_cursor
			uniforms.current_cursor_color = new_cursor_color
			uniforms.cursor_change_time = uniforms.time
		}
	}

	// Update focus uniforms
	uniforms.focus = if self.focused { u32(1) } else { u32(0) }

	// If we need to update the time our focus state changed
	// then update it to our current frame time.
	if self.custom_shader_focused_changed && self.focused {
		uniforms.time_focus = uniforms.time
		self.custom_shader_focused_changed = false
	}
}

// Convert the terminal state to GPU cells stored in CPU memory. These
// are then synced to the GPU in the next frame. This only updates CPU
// memory and doesn't touch the GPU.
//
// Dirty state on terminal state won't be reset by this.
fn (mut self Renderer) rebuild_cells() ! {
	// XTODO: Full cell rebuild requires complete terminal render state,
	// font shaping, selection handling, preedit, etc.
	// For now, this is a simplified version.

	state := &self.terminal_state

	grid_size_diff := self.cells.size.rows != u32(state.rows)
		|| self.cells.size.columns != u32(state.cols)

	if grid_size_diff {
		mut new_size := self.cells.size
		new_size.rows = u32(state.rows)
		new_size.columns = u32(state.cols)
		self.cells.resize(new_size)!

		// Update our uniforms accordingly, otherwise
		// our background cells will be out of place
		self.uniforms.grid_size = [u16(new_size.columns), u16(new_size.rows)]!
	}

	rebuild := state.dirty == .full || grid_size_diff
	if rebuild {
		// If we are doing a full rebuild, then we clear the entire cell buffer
		self.cells.reset()
	}

	// Update that our cells rebuilt
	self.cells_rebuilt = true
}

// Add an underline decoration to the specified cell.
fn (mut self Renderer) add_underline(x u16, y u16, style terminal.UnderlineStyle, color terminal.RGB, alpha u8) ! {
	// Map the underline style to a sprite
	if style == .none {
		return
	}
	sprite := match style {
		.none { font.Sprite.underline } // unreachable
		.single { font.Sprite.underline }
		.double { font.Sprite.underline_double }
		.dotted { font.Sprite.underline_dotted }
		.dashed { font.Sprite.underline_dashed }
		.curly { font.Sprite.underline_curly }
	}

	render := self.font_grid.render_glyph(font.sprite_index, u32(sprite), font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.underline, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add an overline decoration to the specified cell.
fn (mut self Renderer) add_overline(x u16, y u16, color terminal.RGB, alpha u8) ! {
	render := self.font_grid.render_glyph(font.sprite_index, u32(font.Sprite.overline),
		font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.overline, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add a strikethrough decoration to the specified cell.
fn (mut self Renderer) add_strikethrough(x u16, y u16, color terminal.RGB, alpha u8) ! {
	render := self.font_grid.render_glyph(font.sprite_index, u32(font.Sprite.strikethrough),
		font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.strikethrough, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add a glyph to the specified cell.
fn (mut self Renderer) add_glyph(x u16, y u16, color terminal.RGB, alpha u8, glyph_index u32, font_index u32, x_offset i32, y_offset i32, cell_width u32) ! {
	// XTODO: Full glyph rendering requires font grid render_glyph
	// with constraint handling and Nerd Font attributes.
	render := self.font_grid.render_glyph(font_index, glyph_index, font.RenderOptions{
		grid_metrics: self.grid_metrics
		thicken: self.config.font_thicken
		thicken_strength: self.config.font_thicken_strength
		cell_width: cell_width
	})!

	// If the glyph is 0 width or height, it will be invisible
	// when drawn, so don't bother adding it to the buffer.
	if render.glyph.width == 0 || render.glyph.height == 0 {
		return
	}

	self.cells.add(.text, CellText{
		atlas: match render.presentation {
			.emoji { .color }
			.text { .grayscale }
		}
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [
			i32(render.glyph.offset_x + x_offset),
			i32(render.glyph.offset_y + y_offset),
		]!
	})!
}

// Add a cursor to the cell rendering.
fn (mut self Renderer) add_cursor(cursor_state &terminal.RenderCursor, cursor_style CursorStyle, cursor_color terminal.RGB) {
	cursor_vp := cursor_state.viewport or { return }

	// Add the cursor. We render the cursor over the wide character if
	// we're on the wide character tail.
	wide, x := if !cursor_vp.wide_tail {
		cursor_state.cell.wide == .wide, cursor_vp.x
	} else {
		// If we're part of a wide character, we move the cursor back
		// to the actual character.
		true, cursor_vp.x - 1
	}

	alpha := if !self.focused {
		u8(255)
	} else {
		u8(255 * self.config.cursor_opacity)
	}

	// Map cursor style to sprite
	sprite := match cursor_style {
		.block { font.Sprite.cursor_rect }
		.block_hollow { font.Sprite.cursor_hollow_rect }
		.bar { font.Sprite.cursor_bar }
		.underline { font.Sprite.cursor_underline }
		.lock { font.Sprite.cursor_rect } // fallback for lock
	}

	render := self.font_grid.render_glyph(
		font.sprite_index,
		u32(sprite),
		font.RenderOptions{
			cell_width: if wide { u32(2) } else { u32(1) }
			grid_metrics: self.grid_metrics
		},
	) or {
		return
	}

	self.cells.set_cursor(CellText{
		atlas: .grayscale
		bools: CellTextBools{
			is_cursor_glyph: true
		}
		grid_pos: [x, cursor_vp.y]!
		color: [cursor_color.r, cursor_color.g, cursor_color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	}, cursor_style)
}

// Add a preedit (IME composition) cell.
fn (mut self Renderer) add_preedit_cell(cp PreeditCodepoint, coord terminal.ViewportPoint, screen_bg terminal.RGB, screen_fg terminal.RGB) ! {
	// XTODO: Preedit cell rendering requires font_grid.render_codepoint
	// for the actual codepoint glyph rendering.

	// Add our opaque background cell
	self.cells.set_bg(coord.y, coord.x, CellBg{
		r: screen_bg.r
		g: screen_bg.g
		b: screen_bg.b
		a: 255
	})
	if cp.wide && coord.x < u16(self.cells.size.columns) - 1 {
		self.cells.set_bg(coord.y, coord.x + 1, CellBg{
			r: screen_bg.r
			g: screen_bg.g
			b: screen_bg.b
			a: 255
		})
	}

	// Add underline for preedit text
	self.add_underline(coord.x, coord.y, .single, screen_fg, 255)!
	if cp.wide && coord.x < u16(self.cells.size.columns) - 1 {
		self.add_underline(coord.x + 1, coord.y, .single, screen_fg, 255)!
	}
}

// ============================================================
// Existing types (kept for backward compatibility)
// ============================================================

// RendererOpts holds initialization options for the Renderer.
pub struct RendererOpts {
pub:
	// Font grid to use.
	font_grid &font.SharedGrid = unsafe { nil }
	// Initial configuration.
	config DerivedConfig
	// Initial size.
	size Size
}

// State holds shared renderer state protected by a mutex.
pub struct State {
pub mut:
	terminal  voidptr
	preedit   ?Preedit
	mouse     MouseState
	inspector ?voidptr
	mutex     sync.Mutex
}

pub struct MouseState {
pub mut:
	point ?Coordinate
	mods  gg.Modifier
}

pub struct Coordinate {
pub mut:
	x u32
	y u32
}

pub struct Preedit {
pub mut:
	codepoints []PreeditCodepoint
}

pub struct PreeditCodepoint {
pub:
	codepoint u32
	wide      bool
}

pub fn (p Preedit) width() int {
	mut w := 0
	for cp in p.codepoints {
		w += if cp.wide { 2 } else { 1 }
	}
	return w
}

// Thread manages the renderer thread and its mailbox.
pub struct Thread {
pub mut:
	wakeup  Wakeup
	mailbox Mailbox
}

pub fn Thread.init() !Thread {
	return Thread{}
}

pub fn (mut t Thread) deinit() {}

pub struct Wakeup {}

pub fn (w Wakeup) notify() ! {
	// stub: wakes up the renderer thread
}

pub struct Mailbox {}

// push attempts to push a message. Returns number of items pushed (0 or 1).
pub fn (m Mailbox) push(msg Message) int {
	_ = msg
	return 1
}

pub struct Message {
pub:
	kind MessageKind
}

pub enum MessageKind {
	visible
	focus
	font_grid
	inspector
	change_config
	search_viewport_matches
	search_selected_match
}

pub fn Message.init_change_config(config voidptr) !Message {
	return Message{kind: .change_config}
}

pub fn (m Message) deinit() {}

// Health status of the renderer.
pub enum Health {
	healthy
	unhealthy
}

// CursorStyle describes how the cursor should be rendered.
pub enum CursorStyle {
	block
	block_hollow
	bar
	underline
	lock
}

// Size holds all sizing information.
pub struct Size {
pub mut:
	screen  ScreenSize
	cell    CellSize
	padding Padding
}

pub struct ScreenSize {
pub mut:
	width  u32
	height u32
}

pub fn (a ScreenSize) equals(b ScreenSize) bool {
	return a.width == b.width && a.height == b.height
}

pub struct CellSize {
pub mut:
	width  u32
	height u32
}

pub struct Padding {
pub mut:
	top    u32
	bottom u32
	left   u32
	right  u32
}

// Add two paddings together.
pub fn (a Padding) add(b Padding) Padding {
	return Padding{
		top: a.top + b.top
		bottom: a.bottom + b.bottom
		left: a.left + b.left
		right: a.right + b.right
	}
}

pub fn (s Size) grid() GridSize {
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	cols := if s.cell.width > 0 { usable_w / s.cell.width } else { u32(0) }
	rows := if s.cell.height > 0 { usable_h / s.cell.height } else { u32(0) }
	return GridSize{columns: cols, rows: rows}
}

pub struct GridSize {
pub mut:
	columns u32
	rows    u32
}

// Get the terminal rendering area size (grid area only).
pub fn (s &Size) terminal_size() ScreenSize {
	g := GridSize{
		columns: if s.cell.width > 0 {
			usable_w := if s.screen.width > s.padding.left + s.padding.right {
				s.screen.width - s.padding.left - s.padding.right
			} else {
				u32(0)
			}
			usable_w / s.cell.width
		} else {
			u32(0)
		}
		rows: if s.cell.height > 0 {
			usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
				s.screen.height - s.padding.top - s.padding.bottom
			} else {
				u32(0)
			}
			usable_h / s.cell.height
		} else {
			u32(0)
		}
	}
	return ScreenSize{
		width: g.columns * s.cell.width
		height: g.rows * s.cell.height
	}
}

pub fn (s Size) terminal_width() u32 {
	g := GridSize{
		columns: if s.cell.width > 0 {
			usable_w := if s.screen.width > s.padding.left + s.padding.right {
				s.screen.width - s.padding.left - s.padding.right
			} else {
				u32(0)
			}
			usable_w / s.cell.width
		} else {
			u32(0)
		}
		rows: u32(0)
	}
	return g.columns * s.cell.width
}

// Compute the blank padding (space between the grid and the edge of the screen).
pub fn (s &Size) blank_padding(grid GridSize) Padding {
	term := s.terminal_size()
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > term.width { usable_w - term.width } else { u32(0) }
	extra_h := if usable_h > term.height { usable_h - term.height } else { u32(0) }
	return Padding{
		left: s.padding.left + extra_w / 2
		right: s.padding.right + (extra_w - extra_w / 2)
		top: s.padding.top + extra_h / 2
		bottom: s.padding.bottom + (extra_h - extra_h / 2)
	}
}

pub fn (mut s Size) balance_padding(explicit Padding) {
	g := s.grid()
	total_w := g.columns * s.cell.width
	total_h := g.rows * s.cell.height
	usable_w := if s.screen.width > explicit.left + explicit.right {
		s.screen.width - explicit.left - explicit.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > explicit.top + explicit.bottom {
		s.screen.height - explicit.top - explicit.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > total_w { usable_w - total_w } else { u32(0) }
	extra_h := if usable_h > total_h { usable_h - total_h } else { u32(0) }
	s.padding = Padding{
		left: explicit.left + extra_w / 2
		right: explicit.right + (extra_w - extra_w / 2)
		top: explicit.top + extra_h / 2
		bottom: explicit.bottom + (extra_h - extra_h / 2)
	}
}

// This is called early right after surface creation.
pub fn surface_init() ! {
	// stub: initialize surface for rendering
}

// This is called just prior to spinning up the renderer thread for
// final main thread setup requirements.
pub fn (r &Renderer) finalize_surface_init() ! {
	// stub: finalize surface init on main thread
}

// Callback called by renderer.Thread when it begins.
pub fn (r &Renderer) thread_enter() ! {
	// stub: enter rendering thread
}

// Callback called by renderer.Thread when it exits.
pub fn (r &Renderer) thread_exit() {
	// stub: exit rendering thread
}

// Called by renderer.Thread when it starts the main loop.
pub fn (mut r Renderer) loop_enter() ! {
	// stub: enter main loop
}

// Called by renderer.Thread when it exits the main loop.
pub fn (mut r Renderer) loop_exit() {
	// stub: exit main loop
}

// This is called by the GTK apprt after the surface is
// reinitialized due to any of the events mentioned in
// the doc comment for display_unrealized.
pub fn (mut r Renderer) display_realized() ! {
	// stub: reinitialize GPU resources after display realize
	r.mark_dirty()
}

// This is called by the GTK apprt when the surface is being destroyed.
// This can happen because the surface is being closed but also when
// moving the window between displays or splitting.
pub fn (mut r Renderer) display_unrealized() {
	// stub: deinitialize GPU resources on display unrealize
}
