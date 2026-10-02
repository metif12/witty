module inspector

import cimgui
import buildcfg
import font
import input
import renderer
import terminal
import encoding.utf8.validate

const max_key_events = 50

// setup configures the current inspector ImGui context. Runtime-owned context
// creation and backend initialization happen outside this function, matching
// Ghostty's Inspector.setup boundary.
pub fn setup(context cimgui.Context) {
	context.inspector_setup(font.embedded_regular)
}

// KeyEvent is one keyboard event captured by the terminal inspector. It owns
// the cloned UTF-8, binding, and PTY data stored in its fields.
pub struct KeyEvent {
pub mut:
	event          input.KeyEvent
	binding        []input.Action
	pty            []u8
	imgui_selected bool
}

pub fn KeyEvent.init(event input.KeyEvent) KeyEvent {
	return KeyEvent{
		event: input.KeyEvent{
			...event
			utf8: event.utf8.clone()
		}
	}
}

pub fn (mut event KeyEvent) deinit() {
	event.event.utf8 = ''
	event.binding.clear()
	event.pty.clear()
}

// label is the text used for an event in the inspector's key stream.
pub fn (event &KeyEvent) label() string {
	mut result := match event.event.action {
		.press { 'Press: ' }
		.release { 'Release: ' }
		.repeat { 'Repeat: ' }
	}

	if event.event.mods.shift() {
		result += 'Shift+'
	}
	if event.event.mods.ctrl() {
		result += 'Ctrl+'
	}
	if event.event.mods.alt() {
		result += 'Alt+'
	}
	if event.event.mods.super_() {
		result += 'Super+'
	}
	result += if event.event.key == .unidentified && event.event.utf8.len > 0 {
		event.event.utf8
	} else {
		event.event.key.str()
	}
	if event.event.composing {
		result += ' (composing)'
	}
	return result
}

// utf8_codepoints formats the event text exactly as the key detail widget.
pub fn (event &KeyEvent) utf8_codepoints() string {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 1024}
	}
	if validate.utf8_string(event.event.utf8) {
		for cp in event.event.utf8.runes() {
			writer.write('U+${u32(cp):X} ') or { break }
		}
	} else {
		writer.write('(invalid utf-8)') or {}
	}
	writer.write('\x00') or {}
	return writer.written_text()
}

// PTY text uses the source stream's 256-byte diagnostic writer.
pub fn (event &KeyEvent) pty_text() string {
	return event.pty_table_text()
}

// Inspector owns the inspection streams associated with one terminal surface.
pub struct Inspector {
pub mut:
	// This must remain the first field: renderer.RenderState treats its opaque
	// inspector pointer as this cycle-breaking bridge prefix.
	renderer_bridge  renderer.InspectorOverlayBridge
	key_events       []KeyEvent
	mouse            InspectorMouse
	terminal_info    TerminalInfo
	vt_stream        VTStream
	renderer         RendererInfo
	show_demo_window bool = true
}

pub struct InspectorMouse {
pub mut:
	last_xpos  f64
	last_ypos  f64
	last_point ?terminal.Pin
}

pub struct RendererInfo {
mut:
	features []renderer.OverlayFeature
}

// overlay_features returns an owned copy of the renderer debug overlays in
// their activation order, matching Ghostty's AutoArrayHashMap values view.
pub fn (self &RendererInfo) overlay_features() []renderer.OverlayFeature {
	return self.features.clone()
}

// deinit releases the renderer inspector's owned feature list.
pub fn (mut self RendererInfo) deinit() {
	self.features.clear()
}

fn (mut self RendererInfo) set_feature(feature renderer.OverlayFeature, enabled bool) {
	index := self.features.index(feature)
	if enabled {
		if index < 0 {
			self.features << feature
		}
	} else if index >= 0 {
		self.features.delete(index)
	}
}

// SurfaceInfo is the runtime-neutral projection consumed by Ghostty's Surface
// inspector widget. Core creates it while holding the renderer-state mutex.
pub struct SurfaceInfo {
pub:
	screen_width     u32
	screen_height    u32
	grid_columns     u32
	grid_rows        u32
	cell_width       u32
	cell_height      u32
	padding_top      u32
	padding_bottom   u32
	padding_left     u32
	padding_right    u32
	font_points      f32
	font_pixels      f64
	hover_grid_x     u32
	hover_grid_y     u32
	hover_terminal_x i64
	hover_terminal_y i64
	click_pressed    [input.mouse_button_max]bool
	click_grid_x     u32
	click_grid_y     u32
	left_click_xpos  f64
	left_click_ypos  f64
}

pub fn Inspector.init() !Inspector {
	return Inspector{
		renderer_bridge: renderer.InspectorOverlayBridge{
			overlay_features_fn: inspector_overlay_features
			record_pty_read_fn:  inspector_record_pty_read
		}
		key_events:      []KeyEvent{cap: 2}
		vt_stream:       VTStream.init()
	}
}

fn inspector_overlay_features(ptr voidptr) []renderer.OverlayFeature {
	if isnil(ptr) {
		return []renderer.OverlayFeature{}
	}
	insp := unsafe { &Inspector(ptr) }
	return insp.renderer.overlay_features()
}

fn inspector_record_pty_read(ptr voidptr, t &terminal.Terminal, data []u8) ! {
	if isnil(ptr) {
		return
	}
	mut insp := unsafe { &Inspector(ptr) }
	insp.vt_stream.record_pty_read(t, data)!
}

pub fn (mut self Inspector) deinit() {
	self.clear_key_events()
	self.vt_stream.deinit()
	self.renderer.deinit()
}

pub fn (mut self Inspector) clear_key_events() {
	for mut event in self.key_events {
		event.deinit()
	}
	self.key_events.clear()
}

// renderer_info returns the mutable renderer inspector panel, matching the
// source convenience accessor.
pub fn (mut self Inspector) renderer_info() &RendererInfo {
	return &self.renderer
}

// record_pty_read advances the inspector's parallel parser for every byte in
// the read before the real terminal parser mutates its state. V's translated
// parser owns its event allocations, so no allocator argument is required.
pub fn (mut self Inspector) record_pty_read(term &terminal.Terminal, data []u8) ! {
	self.vt_stream.record_pty_read(term, data)!
}

// record_key_event appends to Ghostty's bounded 50-event stream, evicting and
// deinitializing the oldest event after the limit is reached.
pub fn (mut self Inspector) record_key_event(event KeyEvent) bool {
	if self.key_events.len == max_key_events {
		mut oldest := self.key_events[0]
		oldest.deinit()
		self.key_events.delete(0)
	}
	self.key_events << event
	return true
}

// render draws the inspector UI into the active Dear ImGui frame. The context
// handle is passed across the apprt/core boundary to avoid reversing their
// dependency direction.
pub fn (mut self Inspector) render(context_handle voidptr, surface_info SurfaceInfo, mut term terminal.Terminal) {
	if isnil(context_handle) {
		return
	}
	context := cimgui.Context{
		handle: context_handle
	}
	first_render := create_main_dockspace(context)

	open_terminal := context.begin_window('Terminal')
	self.terminal_info.draw(context, open_terminal, mut term)
	context.end_window()

	open_surface := context.begin_window('Surface')
	draw_surface_info(context, open_surface, surface_info)
	context.end_window()

	open := context.begin_window('Keyboard')
	self.draw_key_stream(context, open)
	context.end_window()

	open_termio := context.begin_window('Terminal IO')
	if open_termio {
		self.vt_stream.draw(context, term.colors.palette.current)
	}
	context.end_window()

	open_renderer := context.begin_window('Renderer')
	self.renderer.draw(context, open_renderer)
	context.end_window()

	if buildcfg.slow_runtime_safety && self.show_demo_window {
		self.show_demo_window = context.show_demo_window(self.show_demo_window)
	}

	if first_render {
		// Ghostty focuses the terminal panel when the complete dockspace is first
		// built. Keeping that exact target also preserves focus when the remaining
		// panels are drawn later in this frame.
		context.set_window_focus('Terminal')
	}
}

// draw renders the source renderer-info widget.
pub fn (mut self RendererInfo) draw(context cimgui.Context, open bool) {
	if !open {
		return
	}

	context.set_next_item_open(true)
	if !context.collapsing_header('Overlays') {
		return
	}

	context.separator_text('Hyperlinks')
	mut hyperlinks := self.features.contains(.highlight_hyperlinks)
	_, hyperlinks = context.checkbox('Overlay Hyperlinks', hyperlinks)
	context.same_line()
	help_marker(context, 'When enabled, highlights OSC8 hyperlinks.')
	self.set_feature(.highlight_hyperlinks, hyperlinks)

	context.separator_text('Semantic Prompts')
	mut semantic_prompts := self.features.contains(.semantic_prompts)
	_, semantic_prompts = context.checkbox('Overlay Semantic Prompts', semantic_prompts)
	context.same_line()
	help_marker(context, 'When enabled, highlights OSC 133 semantic prompts.')
	self.set_feature(.semantic_prompts, semantic_prompts)

	context.indent()
	defer {
		context.unindent()
	}
	context.text_disabled('Colors:')

	prompt_rgb := renderer.OverlayColor.semantic_prompt.rgb()
	_ = context.color_button('##prompt_color', cimgui.Color{
		r: f32(prompt_rgb.r) / 255.0
		g: f32(prompt_rgb.g) / 255.0
		b: f32(prompt_rgb.b) / 255.0
	})
	context.same_line()
	context.text('Prompt')

	input_rgb := renderer.OverlayColor.semantic_input.rgb()
	_ = context.color_button('##input_color', cimgui.Color{
		r: f32(input_rgb.r) / 255.0
		g: f32(input_rgb.g) / 255.0
		b: f32(input_rgb.b) / 255.0
	})
	context.same_line()
	context.text('Input')
}

fn draw_surface_info(context cimgui.Context, open bool, info SurfaceInfo) {
	if !open {
		return
	}
	if context.collapsing_header('Help') {
		context.text_wrapped('This window displays information about the surface (window). A surface is the graphical area that displays the terminal content. It includes dimensions, font sizing, and mouse state information specific to this window instance.')
	}

	context.separator_text('Dimensions')
	draw_dimensions_table(context, info)
	context.separator_text('Font')
	draw_font_table(context, info)
	context.separator_text('Mouse')
	draw_mouse_table(context, info)
}

fn draw_dimensions_table(context cimgui.Context, info SurfaceInfo) {
	_ = context.begin_table('table_size', 2, 0)
	defer {
		context.end_table()
	}
	draw_info_row(context, 'Screen Size', '${info.screen_width}px x ${info.screen_height}px')
	draw_info_row(context, 'Grid Size', '${info.grid_columns}c x ${info.grid_rows}r')
	draw_info_row(context, 'Cell Size', '${info.cell_width}px x ${info.cell_height}px')
	draw_info_row(context, 'Window Padding',
		'T=${info.padding_top} B=${info.padding_bottom} L=${info.padding_left} R=${info.padding_right} px')
}

fn draw_font_table(context cimgui.Context, info SurfaceInfo) {
	_ = context.begin_table('table_font', 2, 0)
	defer {
		context.end_table()
	}
	draw_info_row(context, 'Size (Points)', '${info.font_points:.2f} pt')
	draw_info_row(context, 'Size (Pixels)', '${info.font_pixels:.2f} px')
}

fn draw_mouse_table(context cimgui.Context, info SurfaceInfo) {
	_ = context.begin_table('table_mouse', 2, 0)
	defer {
		context.end_table()
	}
	draw_info_row(context, 'Hover Grid', 'row=${info.hover_grid_y}, col=${info.hover_grid_x}')
	draw_info_row(context, 'Hover Point',
		'(${info.hover_terminal_x}px, ${info.hover_terminal_y}px)')

	context.table_next_row()
	context.table_set_column(0)
	context.text('Click State')
	context.table_set_column(1)
	mut any_click := false
	for pressed in info.click_pressed {
		if pressed {
			any_click = true
			break
		}
	}
	if !any_click {
		context.text('none')
	} else {
		labels := ['?', 'L', 'R', 'M', '{4}', '{5}', '{6}', '{7}', '{8}', '{9}', '{10}']
		for i, pressed in info.click_pressed {
			if pressed {
				context.same_line()
				context.text(labels[i])
			}
		}
	}

	draw_info_row(context, 'Click Grid', 'row=${info.click_grid_y}, col=${info.click_grid_x}')
	draw_info_row(context, 'Click Point',
		'(${u32(info.left_click_xpos)}px, ${u32(info.left_click_ypos)}px)')
}

fn draw_info_row(context cimgui.Context, label string, value string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	context.text(value)
}

fn create_main_dockspace(context cimgui.Context) bool {
	dockspace_id := context.get_id('Main Dockspace')
	needs_setup := !context.dock_node_exists(dockspace_id)
	if needs_setup {
		assert context.dock_node_add(dockspace_id)
		context.dock_node_set_main_viewport_size(dockspace_id)
		for name in ['Dear ImGui Demo', 'Terminal', 'Surface', 'Keyboard', 'Terminal IO', 'Renderer'] {
			context.dock_window(name, dockspace_id)
		}
		context.dock_finish(dockspace_id)
	}
	assert context.dock_space_over_main_viewport(dockspace_id)
	return needs_setup
}

fn (mut self Inspector) draw_key_stream(context cimgui.Context, open bool) {
	if !open {
		return
	}
	if self.key_events.len == 0 {
		context.text('No recorded key events. Press a key with the terminal focused to record it.')
		return
	}

	if context.button('Clear') {
		self.clear_key_events()
	}
	context.separator()

	if !context.begin_table('table_key_events', 6, cimgui.table_flags_key_stream) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_scroll_freeze(0, 1)
	context.table_setup_column('Action', cimgui.table_column_width_fixed, 80)
	context.table_setup_column('Key', cimgui.table_column_width_fixed, 160)
	context.table_setup_column('Mods', cimgui.table_column_width_fixed, 150)
	context.table_setup_column('UTF-8', cimgui.table_column_width_fixed, 80)
	context.table_setup_column('PTY Encoding', cimgui.table_column_width_stretch, 0)
	context.table_setup_column('Binding', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()

	for offset in 0 .. self.key_events.len {
		index := self.key_events.len - offset - 1
		mut event := &self.key_events[index]
		context.push_id(voidptr(event))

		context.table_next_row()
		row_min_y := context.cursor_screen_y()
		context.table_set_bg_color(1, action_color(event.event.action))

		context.table_set_column(0)
		context.text_colored(action_text_color(event.event.action), event.event.action.str())

		context.table_set_column(1)
		key_name := if event.event.key == .unidentified && event.event.utf8.len > 0 {
			event.event.utf8
		} else {
			event.event.key.str()
		}
		context.text_colored(rgba_color(key_color(event.event.key)), key_name)
		if event.event.composing {
			context.same_line()
			context.text_colored(cimgui.Color{ r: 1.0, g: 0.6, b: 0.0 }, '*')
			if context.item_hovered() {
				context.tooltip('Composing (dead key)')
			}
		}

		context.table_set_column(2)
		draw_modifiers(context, event.event.mods)

		context.table_set_column(3)
		if event.event.utf8.len == 0 {
			context.text_disabled('-')
		} else {
			context.text(event.utf8_table_codepoints())
		}

		context.table_set_column(4)
		if event.pty.len == 0 {
			context.text_disabled('-')
		} else {
			context.text(event.pty_table_text())
		}

		context.table_set_column(5)
		if event.binding.len == 0 {
			context.text_disabled('-')
		} else {
			context.text(event.binding_table_text())
		}

		row_max_y := context.cursor_screen_y()
		mouse_y := context.mouse_y()
		if mouse_y >= row_min_y && mouse_y < row_max_y {
			context.table_set_bg_color(2, 0x1affffff)
		}
		context.pop_id()
	}
}

fn draw_modifiers(context cimgui.Context, mods input.Mods) {
	if mods.empty() {
		context.text_disabled('-')
		return
	}
	mut hovered := false
	if mods.shift() {
		_ = context.small_button('S')
		hovered = hovered || context.item_hovered()
		context.same_line()
	}
	if mods.ctrl() {
		_ = context.small_button('C')
		hovered = hovered || context.item_hovered()
		context.same_line()
	}
	if mods.alt() {
		_ = context.small_button('A')
		hovered = hovered || context.item_hovered()
		context.same_line()
	}
	if mods.super_() {
		_ = context.small_button('M')
		hovered = hovered || context.item_hovered()
		context.same_line()
	}
	context.new_line()
	if hovered {
		context.tooltip(modifiers_tooltip(mods))
	}
}

fn modifiers_tooltip(mods input.Mods) string {
	mut names := []string{cap: 4}
	if mods.shift() {
		names << 'Shift'
	}
	if mods.ctrl() {
		names << 'Ctrl'
	}
	if mods.alt() {
		names << 'Alt'
	}
	if mods.super_() {
		names << 'Super'
	}
	return names.join('+')
}

fn action_color(action input.KeyAction) u32 {
	return match action {
		.press { 0x1a4a6f4a }
		.release { 0x1a6a5a5a }
		.repeat { 0x1a4a5a6f }
	}
}

fn action_text_color(action input.KeyAction) cimgui.Color {
	return match action {
		.press {
			cimgui.Color{
				r: 0.4
				g: 1.0
				b: 0.4
			}
		}
		.release {
			cimgui.Color{
				r: 0.6
				g: 0.6
				b: 1.0
			}
		}
		.repeat {
			cimgui.Color{
				r: 1.0
				g: 1.0
				b: 0.4
			}
		}
	}
}

fn key_color(key input.Key) u32 {
	hue := f32(u32(key) * 47) / 256.0
	return hsv_to_rgba(hue, 0.5, 0.9, 1.0)
}

fn hsv_to_rgba(h f32, s f32, v f32, a f32) u32 {
	i := u32(h * 6.0)
	f := h * 6.0 - f32(i)
	p := v * (1.0 - s)
	q := v * (1.0 - f * s)
	t := v * (1.0 - (1.0 - f) * s)
	mut r := f32(0)
	mut g := f32(0)
	mut b := f32(0)
	match i % 6 {
		0 {
			r = v
			g = t
			b = p
		}
		1 {
			r = q
			g = v
			b = p
		}
		2 {
			r = p
			g = v
			b = t
		}
		3 {
			r = p
			g = q
			b = v
		}
		4 {
			r = t
			g = p
			b = v
		}
		else {
			r = v
			g = p
			b = q
		}
	}

	return (u32(a * 255.0) << 24) | (u32(b * 255.0) << 16) | (u32(g * 255.0) << 8) | u32(r * 255.0)
}

fn rgba_color(value u32) cimgui.Color {
	return cimgui.Color{
		r: f32(value & 0xff) / 255.0
		g: f32((value >> 8) & 0xff) / 255.0
		b: f32((value >> 16) & 0xff) / 255.0
		a: f32((value >> 24) & 0xff) / 255.0
	}
}

fn (event &KeyEvent) utf8_table_codepoints() string {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 128}
	}
	if validate.utf8_string(event.event.utf8) {
		for cp in event.event.utf8.runes() {
			writer.write('U+${u32(cp):X} ') or { break }
		}
	} else {
		writer.write('?') or {}
	}
	writer.write('\x00') or {}
	return writer.written_text()
}

fn (event &KeyEvent) pty_table_text() string {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 256}
	}
	for byte in event.pty {
		if byte == 0x1b {
			writer.write('ESC ') or { break }
		} else if byte > 0x20 && byte < 0x7f {
			writer.write(byte.ascii_str()) or { break }
		} else {
			writer.write('0x${byte:X} ') or { break }
		}
	}
	writer.write('\x00') or {}
	return writer.written_text()
}

fn (event &KeyEvent) binding_table_text() string {
	mut writer := FixedDiagnosticWriter{
		data: []u8{len: 256}
	}
	for index, action in event.binding {
		if index > 0 { writer.write(', ') or { break } }
		writer.write(action.tag().str()) or { break }
	}
	writer.write('\x00') or {}
	return writer.written_text()
}
