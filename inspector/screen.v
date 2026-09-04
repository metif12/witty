module inspector

import cimgui
import kitty
import terminal

struct ScreenInfo {}

fn (mut self ScreenInfo) draw(context cimgui.Context, open bool, mut screen terminal.Screen, key terminal.ScreenKey, active_key terminal.ScreenKey, modify_other_keys_2 bool, palette [256]terminal.RGB) {
	_ = self
	dockspace_id := context.get_id('Screen Dockspace')
	assert context.screen_dockspace(dockspace_id)

	info_open := context.begin_window('Info')
	if info_open {
		if context.collapsing_header_default_open('Cursor') {
			draw_screen_cursor(context, screen.cursor)
			context.separator()
			draw_style(context, screen.cursor.style, palette)
		}
		if context.collapsing_header_default_open('Keyboard') {
			draw_screen_keyboard(context, screen, modify_other_keys_2)
		}
		if context.collapsing_header_default_open('Semantic Prompt') {
			draw_screen_semantic_prompt(context, screen.semantic_prompt)
		}
		if context.collapsing_header_default_open('Kitty Graphics') {
			draw_screen_kitty_graphics(context, screen)
		}
		if context.collapsing_header_default_open('Other Screen State') {
			draw_screen_internal_state(context, screen)
		}
	}
	context.end_window()

	if !open {
		return
	}
	if key != active_key {
		context.text_colored(cimgui.Color{ r: 1.0, g: 0.8, b: 0.0 }, '⚠ Viewing inactive screen')
		context.separator()
	}
}

fn draw_screen_cursor(context cimgui.Context, cursor terminal.Cursor) {
	if !context.begin_table('table_cursor', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	draw_terminal_label(context, 'Position (x, y)', 'The current cursor position in the terminal grid (0-indexed).')
	context.table_set_column(1)
	context.text('(${cursor.x}, ${cursor.y})')

	draw_terminal_label(context, 'Hyperlink', 'The active OSC8 hyperlink for newly printed characters.')
	context.table_set_column(1)
	if hyperlink := cursor.hyperlink_state {
		context.text(hyperlink.uri)
	} else {
		context.text_disabled('(none)')
	}

	draw_terminal_label(context, 'Pending Wrap', "The 'last column flag' (LCF). If set, the next character will force a soft-wrap to the next line.")
	context.table_set_column(1)
	context.checkbox('##pending_wrap', cursor.pending_wrap)

	draw_terminal_label(context, 'Protected', 'If enabled, new characters will have the protected attribute set, preventing erasure by certain sequences.')
	context.table_set_column(1)
	context.checkbox('##protected', cursor.is_protected)
}

fn draw_screen_keyboard(context cimgui.Context, screen &terminal.Screen, modify_other_keys_2 bool) {
	if !context.begin_table('table_keyboard', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	kitty_flags := screen.kitty_keyboard.current()
	draw_screen_row(context, 'Mode', if kitty_flags != 0 { 'kitty' } else { 'legacy' })
	if kitty_flags != 0 {
		for flag in [
			KittyFlagInfo{ name: 'disambiguate_escape_codes', mask: 1 },
			KittyFlagInfo{ name: 'report_event_types', mask: 2 },
			KittyFlagInfo{ name: 'report_alternate_keys', mask: 4 },
			KittyFlagInfo{ name: 'report_all_keys_as_escape_codes', mask: 8 },
			KittyFlagInfo{ name: 'report_associated_text', mask: 16 },
		] {
			draw_screen_row(context, flag.name, (kitty_flags & flag.mask != 0).str())
		}
	} else {
		draw_screen_row(context, 'Xterm modify keys', modify_other_keys_2.str())
	}
}

struct KittyFlagInfo {
	name string
	mask u32
}

fn draw_screen_semantic_prompt(context cimgui.Context, prompt terminal.SemanticPrompt) {
	if !context.begin_table('##semantic_prompt', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	draw_terminal_label(context, 'Seen', 'Whether any semantic prompt markers (OSC 133) have been seen in this screen.')
	context.table_set_column(1)
	context.checkbox('##seen', prompt.seen)

	draw_terminal_label(context, 'Click Handling', "How click events are handled in prompts. Set via 'cl' or 'click_events' options in OSC 133.")
	context.table_set_column(1)
	match prompt.click {
		.none { context.text_disabled('(none)') }
		.click_events { context.text('click_events') }
		.cl_line { context.text('cl=line') }
		.cl_multiple { context.text('cl=multiple') }
		.cl_conservative_vertical { context.text('cl=conservative_vertical') }
		.cl_smart_vertical { context.text('cl=smart_vertical') }
	}
}

fn draw_screen_kitty_graphics(context cimgui.Context, screen &terminal.Screen) {
	storage := kitty.screen_storage(screen) or {
		context.text_disabled('(Kitty graphics are disabled)')
		return
	}
	if !storage.enabled() {
		context.text_disabled('(Kitty graphics are disabled)')
		return
	}
	if !context.begin_table('##kitty_graphics', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	draw_screen_row(context, 'Memory Usage', '${storage.total_bytes} bytes (${storage.total_bytes / 1024} KiB)')
	draw_screen_row(context, 'Memory Limit', '${storage.total_limit} bytes (${storage.total_limit / 1024} KiB)')
	draw_screen_row(context, 'Image Count', storage.images.len.str())
	draw_screen_row(context, 'Placement Count', storage.placements.len.str())
	draw_screen_row(context, 'Image Loading', (storage.loading != none).str())
}

fn draw_screen_internal_state(context cimgui.Context, screen &terminal.Screen) {
	if !context.begin_table('##terminal_state', 2, 0) {
		return
	}
	defer {
		context.end_table()
	}
	page_bytes := usize(screen.pages.screen_rows.len) * usize(screen.pages.cols) * sizeof(terminal.CellData)
	max_bytes := usize(screen.pages.rows + screen.pages.max_scrollback) * usize(screen.pages.cols) * sizeof(terminal.CellData)
	draw_screen_row(context, 'Memory Usage', '${page_bytes} bytes (${page_bytes / 1024} KiB)')
	draw_screen_row(context, 'Memory Limit', '${max_bytes} bytes (${max_bytes / 1024} KiB)')
	viewport := if screen.pages.viewport == .pinned { 'pin' } else { screen.pages.viewport.str() }
	draw_screen_row(context, 'Viewport Location', viewport)
}

fn draw_style(context cimgui.Context, style terminal.CellStyle, palette [256]terminal.RGB) {
	if !context.begin_table('style', 2, 0) {
		return
	}
	draw_terminal_label(context, 'Foreground', 'The foreground (text) color')
	context.table_set_column(1)
	draw_style_color(context, 'fg', style.fg_color, style.fg_palette, terminal.RGB{ r: style.fg_r, g: style.fg_g, b: style.fg_b }, palette)
	draw_terminal_label(context, 'Background', 'The background (cell) color')
	context.table_set_column(1)
	draw_style_color(context, 'bg', style.bg_color, style.bg_palette, terminal.RGB{ r: style.bg_r, g: style.bg_g, b: style.bg_b }, palette)
	draw_terminal_label(context, 'Underline', 'The underline color, if underlines are enabled.')
	context.table_set_column(1)
	draw_style_color(context, 'underline', style.underline_color, style.underline_palette, terminal.RGB{ r: style.underline_r, g: style.underline_g, b: style.underline_b }, palette)

	draw_style_flag(context, style.flags.bold, 'bold', 'Text will be rendered with bold weight.')
	draw_style_flag(context, style.flags.italic, 'italic', 'Text will be rendered in italic style.')
	draw_style_flag(context, style.flags.faint, 'faint', 'Text will be rendered with reduced intensity.')
	draw_style_flag(context, style.flags.blink, 'blink', 'Text will blink.')
	draw_style_flag(context, style.flags.inverse, 'inverse', 'Foreground and background colors are swapped.')
	draw_style_flag(context, style.flags.invisible, 'invisible', 'Text will be invisible (hidden).')
	draw_style_flag(context, style.flags.strikethrough, 'strikethrough', 'Text will have a line through it.')
	context.end_table()
	context.text_disabled('(Any styles not shown are not currently set)')
}

fn draw_style_flag(context cimgui.Context, enabled bool, name string, help string) {
	if !enabled {
		return
	}
	draw_terminal_label(context, name, help)
	context.table_set_column(1)
	context.text('true')
}

fn draw_style_color(context cimgui.Context, id string, kind terminal.ColorType, palette_index u8, rgb terminal.RGB, palette [256]terminal.RGB) {
	context.push_id_str(id)
	defer {
		context.pop_id()
	}
	match kind {
		.none { context.text('default') }
		.palette {
			context.text('Palette ${palette_index}')
			context.color_edit3('color_fg', cimgui_color(palette[int(palette_index)]), cimgui.color_edit_flags_style)
		}
		.rgb {
			context.color_edit3('color_fg', cimgui_color(rgb), cimgui.color_edit_flags_style)
		}
	}
}

fn draw_screen_row(context cimgui.Context, label string, value string) {
	context.table_next_row()
	context.table_set_column(0)
	context.text(label)
	context.table_set_column(1)
	context.text(value)
}
