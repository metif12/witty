module inspector

import cimgui
import terminal

// DetachableHeader is the state from Ghostty's inspector/widgets.zig. Its
// rendering is performed by cimgui so the native ImVec2 layout is preserved.
struct DetachableHeader {
mut:
	detached     bool
	dock         bool = true
	window_first bool = true
}

struct TerminalInfo {
mut:
	show_palette  bool
	misc_header   DetachableHeader
	layout_header DetachableHeader
	mouse_header  DetachableHeader
	color_header  DetachableHeader
	modes_header  DetachableHeader
}

fn (mut self TerminalInfo) draw(context cimgui.Context, open bool, mut term terminal.Terminal) {
	if open {
		self.draw_open(context, mut term)
	}

	mut state, mut detached, mut first := context.detachable_window('Terminal Misc', self.misc_header.detached, self.misc_header.window_first, self.misc_header.dock)
	self.misc_header.detached = detached
	self.misc_header.window_first = first
	if state >= 0 {
		if state == 1 {
			draw_terminal_misc(context, term)
		}
		context.end_window()
	}

	state, detached, first = context.detachable_window('Terminal Layout', self.layout_header.detached, self.layout_header.window_first, self.layout_header.dock)
	self.layout_header.detached = detached
	self.layout_header.window_first = first
	if state >= 0 {
		if state == 1 {
			draw_terminal_layout(context, mut term)
		}
		context.end_window()
	}

	state, detached, first = context.detachable_window('Terminal Mouse', self.mouse_header.detached, self.mouse_header.window_first, self.mouse_header.dock)
	self.mouse_header.detached = detached
	self.mouse_header.window_first = first
	if state >= 0 {
		if state == 1 {
			draw_terminal_mouse(context, term)
		}
		context.end_window()
	}

	state, detached, first = context.detachable_window('Terminal Color', self.color_header.detached, self.color_header.window_first, self.color_header.dock)
	self.color_header.detached = detached
	self.color_header.window_first = first
	if state >= 0 {
		if state == 1 {
			self.show_palette = draw_terminal_color(context, term, self.show_palette)
		}
		context.end_window()
	}

	state, detached, first = context.detachable_window('Terminal Modes', self.modes_header.detached, self.modes_header.window_first, self.modes_header.dock)
	self.modes_header.detached = detached
	self.modes_header.window_first = first
	if state >= 0 {
		if state == 1 {
			draw_terminal_modes(context, term)
		}
		context.end_window()
	}

	if self.show_palette {
		visible, palette_open := context.begin_window_open('256-Color Palette', self.show_palette)
		self.show_palette = palette_open
		if visible {
			draw_terminal_palette(context, 'palette', term.colors.palette.entries)
		}
		context.end_window()
	}
}

fn (mut self TerminalInfo) draw_open(context cimgui.Context, mut term terminal.Terminal) {
	mut open, mut detached := context.detachable_header('Misc', self.misc_header.detached)
	self.misc_header.detached = detached
	if open {
		draw_terminal_misc(context, term)
	}

	open, detached = context.detachable_header('Layout', self.layout_header.detached)
	self.layout_header.detached = detached
	if open {
		draw_terminal_layout(context, mut term)
	}

	open, detached = context.detachable_header('Mouse', self.mouse_header.detached)
	self.mouse_header.detached = detached
	if open {
		draw_terminal_mouse(context, term)
	}

	open, detached = context.detachable_header('Color', self.color_header.detached)
	self.color_header.detached = detached
	if open {
		self.show_palette = draw_terminal_color(context, term, self.show_palette)
	}

	open, detached = context.detachable_header('Modes', self.modes_header.detached)
	self.modes_header.detached = detached
	if open {
		draw_terminal_modes(context, term)
	}
}

fn draw_terminal_misc(context cimgui.Context, term &terminal.Terminal) {
	if !context.begin_table('table_misc', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}

	draw_terminal_label(context, 'Working Directory', 'The current working directory reported by the shell.')
	context.table_set_column(1)
	if term.pwd.len > 0 {
		context.text(term.pwd)
	} else {
		context.text_disabled('(none)')
	}

	draw_terminal_label(context, 'Focused', 'Whether the terminal itself is currently focused.')
	context.table_set_column(1)
	context.checkbox('##focused', term.flags.focused)

	draw_terminal_label(context, 'Previous Char', 'The previously printed character, used only for the REP sequence.')
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

	draw_terminal_label(context, 'Scroll Region', 'The scrolling region boundaries (top, bottom, left, right).')
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

	draw_terminal_label(context, 'Event Mode', 'The mouse event reporting mode set by the application.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.flags.mouse_event.str()))

	draw_terminal_label(context, 'Format', 'The mouse event encoding format.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.flags.mouse_format.str()))

	draw_terminal_label(context, 'Shape', 'The current mouse cursor shape set by the application.')
	context.table_set_column(1)
	context.text(terminal_enum_name(term.mouse_shape.str()))

	draw_terminal_label(context, 'Shift Capture', 'XTSHIFTESCAPE state for capturing shift in mouse protocol.')
	context.table_set_column(1)
	if term.flags.mouse_shift_capture == .null_ {
		context.text_disabled('(unset)')
	} else {
		context.text(terminal_enum_name(term.flags.mouse_shift_capture.str()))
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
		context.help_marker('Overridden color set by escape sequences.')
		context.table_set_column(1)
		context.color_edit3('##override', cimgui_color(color), cimgui.color_edit_flags_none)
	}

	context.table_next_row()
	context.table_set_column(0)
	if color := rgb.default_color {
		if rgb.override_color != none {
			context.text('default:')
			context.same_line()
			context.help_marker('Default color from configuration.')
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
			color := palette[index]
			if col > 0 {
				context.same_line()
			}
			context.push_id_int(index)
			context.color_edit3('##color', cimgui_color(color), cimgui.color_edit_flags_no_inputs)
			if context.item_hovered_delay_short() {
				context.tooltip('${index}: #${color.r:02X}${color.g:02X}${color.b:02X}')
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
	context.help_marker(help)
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
