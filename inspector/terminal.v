module inspector

import cimgui
import terminal

// DetachableHeader is the state from Ghostty's inspector/widgets.zig. Its
// rendering is performed by cimgui so the native ImVec2 layout is preserved.
pub struct DetachableHeader {
mut:
	detached     bool
	dock         bool = true
	window_first bool = true
}

// DetachableHeaderState is the state for Ghostty's callback-based detachable
// header helper. first_show is internal and resets whenever the window closes.
pub struct DetachableHeaderState {
pub mut:
	show_window bool
mut:
	first_show bool
}

// help_marker draws a disabled marker and its hover tooltip. The explicit
// context is the V binding equivalent of Ghostty's current ImGui context.
pub fn help_marker(context cimgui.Context, text string) {
	context.help_marker(text)
}

// detachable_header renders content either beneath a collapsing header or in
// a detached window. V's generic callback is the direct counterpart of the
// source anytype context and comptime callback.
pub fn detachable_header[T](context cimgui.Context, label string, mut state DetachableHeaderState, value T, content_fn fn (T)) {
	mode, show_window, first_show := context.detachable_header_state_begin(label,
		state.show_window, state.first_show)
	state.show_window = show_window
	state.first_show = first_show
	defer {
		context.detachable_header_state_end(mode)
	}
	if mode & 2 != 0 {
		content_fn(value)
	}
}

// window_end closes a detached window begun by window.
//
// The explicit context is the V binding equivalent of Ghostty's process-wide
// cimgui functions.
pub fn (self &DetachableHeader) window_end(context cimgui.Context) {
	_ = self
	context.end_window()
}

// window begins the detached representation of this header. none means the
// header is attached and no window was created; otherwise the returned value
// reports whether the detached window's contents are visible.
pub fn (mut self DetachableHeader) window(context cimgui.Context, label string) ?bool {
	state, detached, first := context.detachable_window(label, self.detached, self.window_first,
		self.dock)
	self.detached = detached
	self.window_first = first
	if state < 0 {
		return none
	}
	return state == 1
}

// header draws the attached collapsing header and updates the detach state.
pub fn (mut self DetachableHeader) header(context cimgui.Context, label string) bool {
	open, detached := context.detachable_header(label, self.detached)
	self.detached = detached
	return open
}

pub struct TerminalInfo {
mut:
	show_palette  bool
	misc_header   DetachableHeader
	layout_header DetachableHeader
	mouse_header  DetachableHeader
	color_header  DetachableHeader
	modes_header  DetachableHeader
	screens       map[terminal.ScreenKey]ScreenInfo
}

pub fn (mut self TerminalInfo) draw(context cimgui.Context, open bool, mut term terminal.Terminal) {
	if open {
		self.draw_open(context, mut term)
	}

	if visible := self.misc_header.window(context, 'Terminal Misc') {
		if visible {
			draw_terminal_misc(context, term)
		}
		self.misc_header.window_end(context)
	}

	if visible := self.layout_header.window(context, 'Terminal Layout') {
		if visible {
			draw_terminal_layout(context, mut term)
		}
		self.layout_header.window_end(context)
	}

	if visible := self.mouse_header.window(context, 'Terminal Mouse') {
		if visible {
			draw_terminal_mouse(context, term)
		}
		self.mouse_header.window_end(context)
	}

	if visible := self.color_header.window(context, 'Terminal Color') {
		if visible {
			self.show_palette = draw_terminal_color(context, term, self.show_palette)
		}
		self.color_header.window_end(context)
	}

	if visible := self.modes_header.window(context, 'Terminal Modes') {
		if visible {
			draw_terminal_modes(context, term)
		}
		self.modes_header.window_end(context)
	}

	if self.show_palette {
		visible, palette_open := context.begin_window_open('256-Color Palette', self.show_palette)
		self.show_palette = palette_open
		if visible {
			draw_terminal_palette(context, 'palette', term.colors.palette.current)
		}
		context.end_window()
	}

	self.draw_screen_window(context, .primary, mut term)
	self.draw_screen_window(context, .alternate, mut term)
}

fn (mut self TerminalInfo) draw_open(context cimgui.Context, mut term terminal.Terminal) {
	draw_terminal_screens(context, mut term, mut self.screens)

	if self.misc_header.header(context, 'Misc') {
		draw_terminal_misc(context, term)
	}

	if self.layout_header.header(context, 'Layout') {
		draw_terminal_layout(context, mut term)
	}

	if self.mouse_header.header(context, 'Mouse') {
		draw_terminal_mouse(context, term)
	}

	if self.color_header.header(context, 'Color') {
		self.show_palette = draw_terminal_color(context, term, self.show_palette)
	}

	if self.modes_header.header(context, 'Modes') {
		draw_terminal_modes(context, term)
	}
}

fn (mut self TerminalInfo) draw_screen_window(context cimgui.Context, key terminal.ScreenKey, mut term terminal.Terminal) {
	if key !in self.screens {
		return
	}
	mut screen := term.screens.get(key) or {
		self.screens.delete(key)
		return
	}
	context.set_next_window_size_max(400, 300)
	visible, still_open := context.begin_window_open('Screen: ${key}', true)
	mut info := self.screens[key]
	info.draw(context, visible, mut screen, key, term.screens.active_key,
		term.flags.modify_other_keys_2(), term.colors.palette.current)
	context.end_window()
	if still_open {
		self.screens[key] = info
	} else {
		self.screens.delete(key)
	}
}

fn draw_terminal_screens(context cimgui.Context, mut term terminal.Terminal, mut screens map[terminal.ScreenKey]ScreenInfo) {
	if !context.begin_table('screens', 3, cimgui.table_flags_borders_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}
	context.table_setup_column('Screen', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('Status', cimgui.table_column_width_fixed, 0)
	context.table_setup_column('', cimgui.table_column_width_fixed, 0)
	context.screens_table_headers('A terminal can have multiple screens, only one of which is active at a time. Each screen has its own grid, contents, and other state. This section allows you to inspect the different screens managed by the terminal.')

	for key in [terminal.ScreenKey.primary, .alternate] {
		initialized := term.screens.get(key) != none
		active := term.screens.active_key == key
		context.table_next_row()
		context.table_set_column(0)
		context.text(key.str())
		context.table_set_column(1)
		if active {
			context.text_colored(cimgui.Color{ r: 0.4, g: 1.0, b: 0.4 }, 'active')
		} else if initialized {
			context.text_colored(cimgui.Color{ r: 0.6, g: 0.6, b: 0.6 }, 'initialized')
		} else {
			context.text_colored(cimgui.Color{ r: 0.4, g: 0.4, b: 0.4 }, '(not initialized)')
		}
		context.table_set_column(2)
		context.push_id_int(int(key))
		context.begin_disabled(!initialized)
		if context.button('View') && key !in screens {
			screens[key] = ScreenInfo{}
		}
		context.end_disabled()
		context.pop_id()
	}
}

fn draw_terminal_misc(context cimgui.Context, term &terminal.Terminal) {
	if !context.begin_table('table_misc', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}

	draw_terminal_label(context, 'Working Directory',
		'The current working directory reported by the shell.')
	context.table_set_column(1)
	if term.pwd.len > 0 {
		context.text(term.pwd)
	} else {
		context.text_disabled('(none)')
	}

	draw_terminal_label(context, 'Focused', 'Whether the terminal itself is currently focused.')
	context.table_set_column(1)
	context.checkbox('##focused', term.flags.focused())

	draw_terminal_label(context, 'Previous Char',
		'The previously printed character, used only for the REP sequence.')
	context.table_set_column(1)
	if previous := term.previous_char {
		context.text('U+${previous:04X}')
	} else {
		context.text_disabled('(none)')
	}
}

fn draw_terminal_layout(context cimgui.Context, mut term terminal.Terminal) {
	if !context.begin_table('table_layout', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}

	draw_terminal_label(context, 'Grid', 'The size of the terminal grid in columns and rows.')
	context.table_set_column(1)
	context.text('${term.cols}c x ${term.rows}r')

	draw_terminal_label(context, 'Pixels', 'The size of the terminal grid in pixels.')
	context.table_set_column(1)
	context.text('${term.width_px}w x ${term.height_px}h')

	draw_terminal_label(context, 'Scroll Region',
		'The scrolling region boundaries (top, bottom, left, right).')
	context.table_set_column(1)
	context.push_item_width_for_text('00000')
	defer {
		context.pop_item_width()
	}

	mut override := term.scrolling_region
	mut changed := false
	max_row := if term.rows > 0 { term.rows - 1 } else { u16(0) }
	max_col := if term.cols > 0 { term.cols - 1 } else { u16(0) }

	context.align_text_to_frame_padding()
	context.text('T:')
	context.same_line()
	mut input_changed, mut updated := context.input_u16('##scroll_top', override.top)
	if input_changed {
		override.top = if updated > max_row { max_row } else { updated }
		changed = true
	}

	context.same_line()
	context.text('B:')
	context.same_line()
	input_changed, updated = context.input_u16('##scroll_bottom', override.bottom)
	if input_changed {
		override.bottom = if updated > max_row { max_row } else { updated }
		changed = true
	}

	context.same_line()
	context.text('L:')
	context.same_line()
	input_changed, updated = context.input_u16('##scroll_left', override.left)
	if input_changed {
		override.left = if updated > max_col { max_col } else { updated }
		changed = true
	}

	context.same_line()
	context.text('R:')
	context.same_line()
	input_changed, updated = context.input_u16('##scroll_right', override.right)
	if input_changed {
		override.right = if updated > max_col { max_col } else { updated }
		changed = true
	}

	if changed && override.top < override.bottom && override.left < override.right {
		term.scrolling_region = override
	}
}

fn draw_terminal_mouse(context cimgui.Context, term &terminal.Terminal) {
	if !context.begin_table('table_mouse', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}

	draw_terminal_label(context, 'Event Mode',
		'The mouse event reporting mode set by the application.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.flags.mouse_event().str()))

	draw_terminal_label(context, 'Format', 'The mouse event encoding format.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.flags.mouse_format().str()))

	draw_terminal_label(context, 'Shape', 'The current mouse cursor shape set by the application.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.mouse_shape.str()))

	draw_terminal_label(context, 'Shift Capture',
		'XTSHIFTESCAPE state for capturing shift in mouse protocol.')
	context.table_set_column(1)
	if term.flags.mouse_shift_capture() == .null_ {
		context.text_disabled('(unset)')
	} else {
		context.text(terminal_enum_name(term.flags.mouse_shift_capture().str()))
	}
}

fn draw_terminal_color(context cimgui.Context, term &terminal.Terminal, show_palette bool) bool {
	mut updated_show_palette := show_palette
	context.text_wrapped('Color state for the terminal. Note these colors only apply to the palette and unstyled colors. Many modern terminal applications use direct RGB colors which are not reflected here.')
	context.separator()

	if !context.begin_table('table_color', 2, 0) {
		return updated_show_palette
	}
	defer {
		context.end_table()
	}

	draw_terminal_label(context, 'Background', 'Unstyled cell background color.')
	context.table_set_column(1)
	draw_dynamic_rgb(context, 'bg_color', term.colors.background)

	draw_terminal_label(context, 'Foreground', 'Unstyled cell foreground color.')
	context.table_set_column(1)
	draw_dynamic_rgb(context, 'fg_color', term.colors.foreground)

	draw_terminal_label(context, 'Cursor', 'Cursor coloring set by escape sequences.')
	context.table_set_column(1)
	draw_dynamic_rgb(context, 'cursor_color', term.colors.cursor)

	draw_terminal_label(context, 'Palette', 'The 256-color palette.')
	context.table_set_column(1)
	if context.button('View') {
		updated_show_palette = true
	}
	return updated_show_palette
}

fn draw_terminal_modes(context cimgui.Context, term &terminal.Terminal) {
	if !context.begin_table('table_modes', 3, cimgui.table_flags_row_bg_sizing_fixed_fit) {
		return
	}
	defer {
		context.end_table()
	}

	context.table_setup_column('', cimgui.table_column_no_resize, 0)
	context.table_setup_column('Number', cimgui.table_column_prefer_sort_ascending, 0)
	context.table_setup_column('Name', cimgui.table_column_width_stretch, 0)
	context.table_headers_row()

	$for enum_value in terminal.Mode.values {
		mode := enum_value.value
		context.table_next_row()
		context.push_id_int(int(mode))
		context.table_set_column(0)
		context.checkbox('##checkbox', term.modes.get(mode))
		context.table_set_column(1)
		prefix := if terminal.mode_is_ansi(mode) { '' } else { '?' }
		context.text('${prefix}${terminal.mode_value(mode)}')
		context.table_set_column(2)
		context.text(enum_value.name)
		context.pop_id()
	}
}

fn draw_dynamic_rgb(context cimgui.Context, label string, rgb terminal.DynamicRGB) bool {
	columns := if rgb.override_color != none { 2 } else { 1 }
	if !context.begin_table(label, columns, 1 << 13) {
		return false
	}
	defer {
		context.end_table()
	}

	if rgb.override_color != none {
		context.table_setup_column('##label', cimgui.table_column_width_fixed, 0)
	}
	context.table_setup_column('##value', cimgui.table_column_width_stretch, 0)

	if color := rgb.override_color {
		context.table_next_row()
		context.table_set_column(0)
		context.text('override:')
		context.same_line()
		help_marker(context, 'Overridden color set by escape sequences.')
		context.table_set_column(1)
		context.color_edit3('##override', cimgui_color(color), cimgui.color_edit_flags_none)
	}

	context.table_next_row()
	context.table_set_column(0)
	if color := rgb.default_color {
		if rgb.override_color != none {
			context.text('default:')
			context.same_line()
			help_marker(context, 'Default color from configuration.')
			context.table_set_column(1)
		}
		context.color_edit3('##default', cimgui_color(color), cimgui.color_edit_flags_none)
	} else {
		context.text_disabled('(unset)')
	}
	return false
}

fn draw_terminal_palette(context cimgui.Context, label string, palette [256]terminal.RGB) {
	context.push_id_str(label)
	defer {
		context.pop_id()
	}
	for row in 0 .. 16 {
		for col in 0 .. 16 {
			index := row * 16 + col
			palette_color := palette[index]
			if col > 0 {
				context.same_line()
			}
			context.push_id_int(index)
			context.color_edit3('##color', cimgui_color(palette_color),
				cimgui.color_edit_flags_no_inputs)
			if context.item_hovered_delay_short() {
				context.tooltip('${index}: #${palette_color.r:02X}${palette_color.g:02X}${palette_color.b:02X}')
			}
			context.pop_id()
		}
	}
}

fn draw_terminal_label(context cimgui.Context, label string, help string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.same_line()
	help_marker(context, help)
}

fn terminal_enum_name(value string) string {
	return if value.ends_with('_') { value[..value.len - 1] } else { value }
}

fn cimgui_color(color terminal.RGB) cimgui.Color {
	return cimgui.Color{
		r: f32(color.r) / 255.0
		g: f32(color.g) / 255.0
		b: f32(color.b) / 255.0
	}
}
