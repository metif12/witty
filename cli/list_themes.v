module cli

import ascii
import os
import strings
import time
import net.urllib
import configpkg
import themepkg
import tui
import vaxis
import zf
import global_state

// When the number of filtered themes is less than or equal to this threshold,
// the window position will be reset to 0 to show all results from the top.
// This ensures better visibility for small result sets while maintaining
// scroll position for larger lists.
const small_list_threshold = 10

// ColorScheme filters which themes to show by color scheme.
pub enum ColorScheme as u8 {
	all
	dark
	light
}

// Options are the command-line flags for list-themes.
pub struct Options {
pub mut:
	// If true, print the full path to the theme.
	path bool
	// If true, force a plain list of themes.
	plain bool
	// Specifies the color scheme of the themes to include in the list.
	color ColorScheme = .all
}

pub fn (opts Options) deinit() {
	_ = opts
}

pub fn (opts Options) help() ! {
	_ = opts
	action_options_help()!
}

// ThemeListElement represents a single discovered theme.
pub struct ThemeListElement {
pub mut:
	location themepkg.Location
	path     string
	theme    string
	rank     ?f64
}

// less_than compares two theme list elements by name, case-insensitive.
// TODO: use Unicode-aware comparison
fn theme_list_less_than(a &ThemeListElement, b &ThemeListElement) int {
	return ascii.order_ignore_case(a.theme, b.theme)
}

// to_uri converts the theme path to a file:// URI string.
pub fn (self &ThemeListElement) to_uri() string {
	return urllib.URL{
		scheme: 'file'
		path:   self.path
	}.str()
}

// Event is the union of possible input events for the TUI preview.
pub type Event = KeyPressEvent | MouseEvent | ColorSchemeEvent | WinsizeEvent

pub struct KeyPressEvent {
pub:
	key vaxis.Key
}

pub struct MouseEvent {
pub:
	mouse vaxis.Mouse
}

pub struct ColorSchemeEvent {
pub:
	scheme vaxis.Scheme
}

pub struct WinsizeEvent {
pub:
	winsize vaxis.Winsize
}

// PreviewMode tracks which mode the TUI preview is in.
enum PreviewMode as u8 {
	normal
	help
	search
	save
}

// Preview is the TUI preview state for interactively browsing themes.
pub struct Preview {
mut:
	should_quit  bool
	themes       []ThemeListElement
	filtered     []usize
	current      usize
	window       usize
	hex          bool
	mode         PreviewMode  = .normal
	color_scheme vaxis.Scheme = .light
	width_method vaxis.GWidthMethod = .wcwidth
	mouse        ?vaxis.Mouse
	text_input   vaxis.TextInput
	winsize      vaxis.Winsize
	theme_filter ColorScheme
}

// Preview.init creates a new Preview with the given themes and filter. The
// source's allocator and terminal scratch-buffer arguments are omitted because
// V owns both resources.
pub fn Preview.init(themes []ThemeListElement, theme_filter ColorScheme) !Preview {
	mut p := Preview{
		themes:       themes
		theme_filter: theme_filter
		text_input:   vaxis.TextInput.new()
		winsize:      vaxis.terminal_size()
		color_scheme: .light
	}
	p.update_filtered()!
	return p
}

// deinit releases the preview-owned filtering and text-input state.
pub fn (mut self Preview) deinit() {
	self.filtered.clear()
	self.text_input.deinit()
}

// update_filtered rebuilds the filtered index list based on search text and theme filter.
fn (mut self Preview) update_filtered() ! {
	// Remember current selection's name for re-selection after filtering
	relative := if self.current > self.window { self.current - self.window } else { 0 }
	mut selected := ''
	if self.filtered.len > 0 && self.current < self.filtered.len {
		selected = self.themes[self.filtered[self.current]].theme
	}

	old_filtered := self.filtered.clone()
	self.filtered.clear()

	mut theme_config := configpkg.Config.default_config()

	search_text := self.text_input.get_text()
	if search_text.len > 0 {
		query := ascii.lower_string(search_text)
		tokens := query.split(' ').filter(it.len > 0)

		for i, mut theme in self.themes {
			theme_config.load_file(theme.path)!
			if !should_include_theme(self.theme_filter, theme_config) {
				continue
			}
			r := zf.rank(theme.theme, tokens, zf.RankOptions{
				to_lower: true
				plain:    true
			})
			if r != none {
				theme.rank = r
				self.filtered << usize(i)
			}
		}
	} else {
		for i, mut theme in self.themes {
			theme_config.load_file(theme.path)!
			if should_include_theme(self.theme_filter, theme_config) {
				self.filtered << usize(i)
				theme.rank = none
			}
		}
	}

	// Check if the filtered list changed
	if old_filtered == self.filtered {
		return
	}

	if self.filtered.len == 0 {
		self.current = 0
		self.window = 0
		return
	}

	// Try to keep the same theme selected
	if selected.len > 0 {
		for idx, filt_idx in self.filtered {
			if self.themes[filt_idx].theme == selected {
				idx_usize := usize(idx)
				// Keep the relative position but ensure all search results are visible
				new_window := if idx_usize > relative { idx_usize - relative } else { usize(0) }
				// If the new window would hide some results at the top, adjust it
				self.current = idx_usize
				self.window = if self.filtered.len <= small_list_threshold {
					usize(0)
				} else {
					new_window
				}
				return
			}
		}
	}

	self.current = 0
	self.window = 0
}

// up moves the selection up by count items.
fn (mut self Preview) up(count usize) {
	if self.filtered.len == 0 {
		self.current = 0
		return
	}
	self.current = if self.current > count { self.current - count } else { 0 }
}

// down moves the selection down by count items.
fn (mut self Preview) down(count usize) {
	if self.filtered.len == 0 {
		self.current = 0
		return
	}
	self.current += count
	if self.current >= usize(self.filtered.len) {
		self.current = usize(self.filtered.len - 1)
	}
}

// update processes a single input event.
pub fn (mut self Preview) update(event Event) ! {
	match event {
		KeyPressEvent {
			key := event.key
			if key.matches(u32(`c`), vaxis.Modifiers.init(false, false, true, false, false, false,
				false, false))
			{
				self.should_quit = true
			}
			match self.mode {
				.normal {
					if key.matches_any([u32(`q`), vaxis.escape], vaxis.Modifiers{}) {
						self.should_quit = true
					}
					if key.matches_any([u32(`?`), vaxis.f1], vaxis.Modifiers{}) {
						self.mode = .help
					}
					if key.matches(u32(`h`), vaxis.Modifiers.init(false, false, true, false, false,
						false, false, false))
					{
						self.mode = .help
					}
					if key.matches(u32(`/`), vaxis.Modifiers{}) {
						self.mode = .search
					}
					if key.matches_any([vaxis.enter, vaxis.kp_enter], vaxis.Modifiers{}) {
						self.mode = .save
					}
					if key.matches_any([u32(`x`), u32(`/`)], vaxis.Modifiers.init(false, false,
						true, false, false, false, false, false))
					{
						self.text_input.clear_retaining_capacity()
						self.update_filtered()!
					}
					if key.matches_any([vaxis.home, vaxis.kp_home], vaxis.Modifiers{}) {
						self.current = 0
					}
					if key.matches_any([vaxis.end, vaxis.kp_end], vaxis.Modifiers{}) {
						assert self.filtered.len > 0
						self.current = usize(self.filtered.len - 1)
					}
					if key.matches_any([u32(`j`), u32(`+`), vaxis.down, vaxis.kp_down, vaxis.kp_add], vaxis.Modifiers{}) {
						self.down(1)
					}
					if key.matches_any([vaxis.page_down, vaxis.kp_down], vaxis.Modifiers{}) {
						self.down(20)
					}
					if key.matches_any([u32(`k`), u32(`-`), vaxis.up, vaxis.kp_up, vaxis.kp_subtract], vaxis.Modifiers{}) {
						self.up(1)
					}
					if key.matches_any([vaxis.page_up, vaxis.kp_page_up], vaxis.Modifiers{}) {
						self.up(20)
					}
					if key.matches_any([u32(`h`), u32(`x`)], vaxis.Modifiers{}) {
						self.hex = true
					}
					if key.matches(u32(`d`), vaxis.Modifiers{}) {
						self.hex = false
					}
					if key.matches(u32(`c`), vaxis.Modifiers{}) {
						vaxis.copy_to_system_clipboard(self.themes[self.filtered[self.current]].theme)
					} else if key.matches(u32(`c`), vaxis.Modifiers.init(true, false, false, false,
						false, false, false, false))
					{
						vaxis.copy_to_system_clipboard(self.themes[self.filtered[self.current]].path)
					}
					if key.matches(u32(`f`), vaxis.Modifiers{}) {
						match self.theme_filter {
							.all {
								self.theme_filter = .dark
							}
							.dark {
								self.theme_filter = .light
							}
							.light {
								self.theme_filter = .all
							}
						}

						self.update_filtered()!
					}
				}
				.help {
					if key.matches(u32(`q`), vaxis.Modifiers{}) {
						self.should_quit = true
					}
					if key.matches_any([u32(`?`), vaxis.escape, vaxis.f1], vaxis.Modifiers{}) {
						self.mode = .normal
					}
					if key.matches(u32(`h`), vaxis.Modifiers.init(false, false, true, false, false,
						false, false, false))
					{
						self.mode = .normal
					}
				}
				.search {
					if key.matches_any([vaxis.escape, vaxis.enter], vaxis.Modifiers{}) {
						self.mode = .normal
						return
					}
					if key.matches_any([u32(`x`), u32(`/`)], vaxis.Modifiers.init(false, false,
						true, false, false, false, false, false))
					{
						self.text_input.clear_retaining_capacity()
						self.update_filtered()!
						return
					}
					self.text_input.update(key)
					self.update_filtered()!
				}
				.save {
					if key.matches(u32(`q`), vaxis.Modifiers{}) {
						self.should_quit = true
					}
					if key.matches_any([vaxis.escape, vaxis.enter, vaxis.kp_enter], vaxis.Modifiers{}) {
						self.mode = .normal
					}
					if key.matches(u32(`w`), vaxis.Modifiers{}) {
						self.save_selected_theme()
					}
				}
			}
		}
		ColorSchemeEvent {
			self.color_scheme = event.scheme
		}
		MouseEvent {
			self.mouse = event.mouse
		}
		WinsizeEvent {
			self.winsize = event.winsize
		}
	}
}

// ui_fg returns the foreground color for the UI based on color scheme.
pub fn (self &Preview) ui_fg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0x00), 0x00, 0x00]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0xff), 0xff, 0xff]!
			}
		}
	}
}

// ui_bg returns the background color for the UI based on color scheme.
pub fn (self &Preview) ui_bg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0xff), 0xff, 0xff]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0x00), 0x00, 0x00]!
			}
		}
	}
}

// ui_standard returns a standard style with UI fg/bg.
pub fn (self &Preview) ui_standard() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_fg()
		bg: self.ui_bg()
	}
}

// ui_hover_bg returns the hover background color.
pub fn (self &Preview) ui_hover_bg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0xbb), 0xbb, 0xbb]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0x22), 0x22, 0x22]!
			}
		}
	}
}

// ui_highlighted returns a style for hovered items.
pub fn (self &Preview) ui_highlighted() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_fg()
		bg: self.ui_hover_bg()
	}
}

// ui_selected_fg returns the foreground color for selected items.
pub fn (self &Preview) ui_selected_fg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0x00), 0xaa, 0x00]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0x00), 0xaa, 0x00]!
			}
		}
	}
}

// ui_selected_bg returns the background color for selected items.
pub fn (self &Preview) ui_selected_bg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0xaa), 0xaa, 0xaa]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0x33), 0x33, 0x33]!
			}
		}
	}
}

// ui_selected returns a style for selected items.
pub fn (self &Preview) ui_selected() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_selected_fg()
		bg: self.ui_selected_bg()
	}
}

// ui_err_fg returns the foreground color for error messages.
pub fn (self &Preview) ui_err_fg() vaxis.Color {
	return match self.color_scheme {
		.light {
			vaxis.ColorRgb{
				rgb: [u8(0xff), 0x00, 0x00]!
			}
		}
		.dark {
			vaxis.ColorRgb{
				rgb: [u8(0xff), 0x00, 0x00]!
			}
		}
	}
}

// ui_err returns a style for error messages.
pub fn (self &Preview) ui_err() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_err_fg()
		bg: self.ui_bg()
	}
}

// run is the TUI preview event loop.
pub fn (mut self Preview) run() ! {
	mut tty := vaxis.Tty.new()
	self.winsize = vaxis.terminal_size()
	vaxis.begin_session('👻 Ghostty Theme Preview 👻')
	vaxis.query_color_scheme_update_capability()
	vaxis.query_unicode_capability()
	mut color_scheme_subscribed := false
	defer {
		if color_scheme_subscribed {
			vaxis.unsubscribe_from_color_scheme_updates()
		}
		vaxis.end_session()
	}

	mut dirty := true
	for !self.should_quit {
		winsize := vaxis.terminal_size()
		if winsize != self.winsize {
			self.update(Event(WinsizeEvent{
				winsize: winsize
			}))!
			dirty = true
		}

		mut handled_input := false
		for {
			event := tty.poll() or { break }
			match event {
				vaxis.Key {
					self.update(Event(KeyPressEvent{
						key: event
					}))!
				}
				vaxis.Mouse {
					self.update(Event(MouseEvent{
						mouse: event
					}))!
				}
				vaxis.ColorScheme {
					self.update(Event(ColorSchemeEvent{
						scheme: event.scheme
					}))!
				}
				vaxis.Winsize {
					self.update(Event(WinsizeEvent{
						winsize: event
					}))!
				}
				vaxis.CapabilityEvent {
					if event.capability == .color_scheme_updates && !color_scheme_subscribed {
						vaxis.subscribe_to_color_scheme_updates()
						color_scheme_subscribed = true
					} else if event.capability == .unicode && self.width_method != .unicode {
						self.width_method = .unicode
						vaxis.enable_unicode_mode()
					}
				}
				else {}
			}

			handled_input = true
			dirty = true
		}

		if dirty && !self.should_quit {
			print(self.draw())
			flush_stdout()
			dirty = false
		}
		if !handled_input {
			time.sleep(8 * time.millisecond)
		}
	}
}

// draw renders the full TUI interface.
pub fn (mut self Preview) draw() string {
	width := max_int(int(self.winsize.cols), 1)
	height := max_int(int(self.winsize.rows), 1)
	list_width := min_int(32, width)
	standard := self.ui_standard()
	mut highlight := ?usize(none)

	if mouse := self.mouse {
		self.mouse = none
		if self.mode == .normal {
			if mouse.button == .wheel_up {
				self.up(1)
			}
			if mouse.button == .wheel_down {
				self.down(1)
			}
			if int(mouse.col) < list_width && int(mouse.row) < height {
				if mouse.button == .left && mouse.type_ == .release {
					selection := self.window + usize(mouse.row)
					if selection < usize(self.filtered.len) {
						self.current = selection
					}
				}
				highlight = usize(mouse.row)
			}
		}
	}

	if self.filtered.len == 0 {
		self.current = 0
		self.window = 0
	} else {
		end := self.window + usize(height - 1)
		if self.current > end {
			self.window = self.current - usize(height) + 1
		}
		if self.current < self.window {
			self.window = self.current
		}
		if self.window >= usize(self.filtered.len) {
			self.window = usize(self.filtered.len - 1)
		}
	}

	mut out := strings.new_builder(width * height * 2)
	out.write_string(vaxis.clear_screen())
	for row in 0 .. height {
		put_segment(mut out, row, 0, width, ' '.repeat(width), standard)
	}

	for row in 0 .. height {
		index := self.window + usize(row)
		if index >= usize(self.filtered.len) {
			break
		}
		theme := self.themes[self.filtered[index]]
		if index == self.current {
			put_segment(mut out, row, 0, list_width, ' '.repeat(list_width), self.ui_selected())
			put_segment(mut out, row, 0, list_width, '❯ ', self.ui_selected())
			put_link(mut out, row, 2, list_width, theme.theme, theme.to_uri(), self.ui_selected())
			if list_width >= 2 {
				put_segment(mut out, row, list_width - 2, list_width, ' ❮', self.ui_selected())
			}
		} else {
			style := if highlighted := highlight {
				if highlighted == usize(row) { self.ui_highlighted() } else { standard }
			} else {
				standard
			}
			put_link(mut out, row, 2, list_width, theme.theme, theme.to_uri(), style)
		}
	}

	if self.filtered.len == 0 {
		out.write_string(self.draw_preview(0, width, height))
	} else if width > list_width {
		out.write_string(self.draw_preview(list_width, width - list_width, height))
	}

	match self.mode {
		.normal {
			out.write_string(vaxis.hide_cursor())
		}
		.help {
			draw_help_modal(mut out, width, height, standard)
			out.write_string(vaxis.hide_cursor())
		}
		.search {
			modal_width := min_int(max_int(width - 40, 20), max_int(width - 2, 1))
			x := max_int((width - modal_width) / 2, 0)
			y := max_int(height - 5, 0)
			draw_box(mut out, x, y, modal_width, 3, standard)
			child_width := max_int(modal_width - 2, 0)
			input := self.text_input.draw_with_style_method(child_width, standard,
				self.width_method)
			for cell in input.cells {
				put_segment(mut out, y + 1, x + 1 + int(cell.col), x + modal_width - 1, cell.text,
					input.style)
			}
			if child_width > 0 {
				out.write_string(vaxis.show_cursor(y + 1, x + 1 + int(input.cursor_col)))
			}
		}
		.save {
			theme := self.themes[self.filtered[self.current]]
			draw_save_modal(mut out, width, height, theme.theme, standard)
			out.write_string(vaxis.hide_cursor())
		}
	}

	return out.str()
}

// draw_preview renders the theme color preview pane.
pub fn (mut self Preview) draw_preview(x_off int, width int, height int) string {
	mut out := strings.new_builder(width * height)
	if self.filtered.len == 0 {
		text := 'No theme found!'
		for row in 0 .. height {
			put_segment(mut out, row, x_off, x_off + width, ' '.repeat(width), self.ui_standard())
		}
		put_preview_segment(mut out, max_int(height / 2 - 1, 0), x_off + max_int((width -
			text.len) / 2, 0), x_off + width, height, text, self.ui_standard())
		return out.str()
	}

	theme := self.themes[self.filtered[self.current]]
	mut config := configpkg.Config.default_config()
	config.load_file(theme.path) or {
		standard := self.ui_standard()
		for row in 0 .. height {
			put_segment(mut out, row, x_off, x_off + width, ' '.repeat(width), standard)
		}
		middle := height / 2
		text := 'Unable to open ${theme.theme} from:'
		put_segment(mut out, max_int(middle - 1, 0), x_off + max_int((width -
			text.runes().len) / 2, 0), x_off + width, text, self.ui_err())
		put_link(mut out, middle, x_off + max_int((width - theme.path.runes().len) / 2, 0), x_off +
			width, theme.path, theme.to_uri(), self.ui_err())
		error_text := err.msg()
		put_segment(mut out, min_int(middle + 1, max_int(height - 1, 0)), x_off + max_int((width -
			error_text.runes().len) / 2, 0), x_off + width, error_text, self.ui_err())
		return out.str()
	}
	fg := vaxis.ColorRgb{
		rgb: [config.foreground.r, config.foreground.g, config.foreground.b]!
	}
	bg := vaxis.ColorRgb{
		rgb: [config.background.r, config.background.g, config.background.b]!
	}
	cursor_fg := preview_terminal_color(config.cursor_text, bg)
	cursor_bg := preview_terminal_color(config.cursor_color, fg)
	selection_fg := preview_terminal_color(config.selection_foreground, bg)
	selection_bg := preview_terminal_color(config.selection_background, fg)
	cursor := vaxis.Style{
		fg: cursor_fg
		bg: cursor_bg
	}
	standard_selection := vaxis.Style{
		fg: selection_fg
		bg: selection_bg
	}
	standard := vaxis.Style{
		fg: fg
		bg: bg
	}
	standard_bold := vaxis.Style{
		fg:   fg
		bg:   bg
		bold: true
	}
	standard_italic := vaxis.Style{
		fg:     fg
		bg:     bg
		italic: true
	}
	standard_bold_italic := vaxis.Style{
		fg:     fg
		bg:     bg
		bold:   true
		italic: true
	}
	standard_underline := vaxis.Style{
		fg:       fg
		bg:       bg
		ul_style: .single
	}
	standard_double_underline := vaxis.Style{
		fg:       fg
		bg:       bg
		ul_style: .double_
	}
	standard_dashed_underline := vaxis.Style{
		fg:       fg
		bg:       bg
		ul_style: .dashed
	}
	standard_curly_underline := vaxis.Style{
		fg:       fg
		bg:       bg
		ul_style: .curly
	}
	standard_dotted_underline := vaxis.Style{
		fg:       fg
		bg:       bg
		ul_style: .dotted
	}

	for row in 0 .. height {
		put_segment(mut out, row, x_off, x_off + width, ' '.repeat(width), standard)
	}
	put_link(mut out, 1, x_off + max_int((width - theme.theme.runes().len) / 2, 0), x_off + width,
		theme.theme, theme.to_uri(), standard_bold_italic)
	put_link(mut out, 2, x_off + max_int((width - theme.path.runes().len) / 2, 0), x_off + width,
		theme.path, theme.to_uri(), standard)

	mut next_row := 4
	if config.diagnostics.len > 0 && next_row < height {
		heading := 'Problems were encountered trying to load the theme:'
		put_preview_segment(mut out, next_row, x_off + max_int((width - heading.len) / 2, 0),
			x_off + width, height, heading, self.ui_err())
		for i, diagnostic in config.diagnostics {
			put_preview_segment(mut out, next_row + 2 + i, x_off + 2, x_off + width, height,
				diagnostic.format(), self.ui_err())
		}
		next_row += 2 + config.diagnostics.len
	}

	for i in 0 .. 16 {
		row := next_row + (i / 8) * 3
		col := x_off + (i % 8) * 8
		if row >= height || col >= x_off + width {
			continue
		}
		label := if self.hex { ' ${i:02x}' } else { '${i:3}' }
		put_preview_segment(mut out, row, col, x_off + width, height, label, standard)
		palette_style := vaxis.Style{
			fg: color_from_palette(config, i)
			bg: bg
		}
		put_preview_segment(mut out, row, col + 4, x_off + width, height, '████', palette_style)
		put_preview_segment(mut out, row + 1, col + 4, x_off + width, height, '████',
			palette_style)
	}
	next_row += 6

	color1 := preview_palette_style(config, 1, bg)
	color2 := preview_palette_style(config, 2, bg)
	color3 := preview_palette_style(config, 3, bg)
	color4 := preview_palette_style(config, 4, bg)
	color5 := preview_palette_style(config, 5, bg)
	color6 := preview_palette_style(config, 6, bg)
	color6ul := vaxis.Style{
		fg:       color_from_palette(config, 6)
		bg:       bg
		ul_style: .single
	}
	color10 := preview_palette_style(config, 10, bg)
	color12 := preview_palette_style(config, 12, bg)
	color238 := preview_palette_style(config, 238, bg)
	right := x_off + width
	sample_bottom := min_int(next_row + 24, height)
	self.put_preview_segments(mut out, next_row, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '→', style: color2 },
		PreviewSegment{ text: ' ', style: standard },
		PreviewSegment{ text: 'bat', style: color4 },
		PreviewSegment{ text: ' ', style: standard },
		PreviewSegment{ text: 'ziggzagg.zig', style: color6ul },
	])
	put_preview_segment(mut out, next_row + 1, x_off + 2, right, height,
		'───────┬${'─'.repeat(max_int(width - 10, 0))}', color238)
	self.put_preview_segments(mut out, next_row + 2, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '       │ ', style: color238 },
		PreviewSegment{ text: 'File: ', style: standard },
		PreviewSegment{ text: 'ziggzagg.zig', style: standard_bold },
	])
	put_preview_segment(mut out, next_row + 3, x_off + 2, right, height,
		'───────┼${'─'.repeat(max_int(width - 10, 0))}', color238)
	self.put_preview_segments(mut out, next_row + 4, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   1   │ ', style: color238 },
		PreviewSegment{ text: 'const', style: color5 },
		PreviewSegment{ text: ' std ', style: standard },
		PreviewSegment{ text: '= @import', style: color5 },
		PreviewSegment{ text: '(', style: standard },
		PreviewSegment{ text: '"std"', style: color10 },
		PreviewSegment{ text: ');', style: standard },
	])
	put_preview_segment(mut out, next_row + 5, x_off + 2, right, height, '   2   │', color238)
	self.put_preview_segments(mut out, next_row + 6, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   3   │ ', style: color238 },
		PreviewSegment{ text: 'pub ', style: color5 },
		PreviewSegment{ text: 'fn ', style: color12 },
		PreviewSegment{ text: 'main', style: color2 },
		PreviewSegment{ text: '() ', style: standard },
		PreviewSegment{ text: '!', style: color5 },
		PreviewSegment{ text: 'void', style: color12 },
		PreviewSegment{ text: ' {', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 7, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   4   │     ', style: color238 },
		PreviewSegment{ text: 'const ', style: color5 },
		PreviewSegment{ text: 'stdout ', style: standard },
		PreviewSegment{ text: '=', style: color5 },
		PreviewSegment{ text: ' std.Io.getStdOut().writer();', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 8, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   5   │     ', style: color238 },
		PreviewSegment{ text: 'var ', style: color5 },
		PreviewSegment{ text: 'i:', style: standard },
		PreviewSegment{ text: ' usize', style: color12 },
		PreviewSegment{ text: ' =', style: color5 },
		PreviewSegment{ text: ' 1', style: color4 },
		PreviewSegment{ text: ';', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 9, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   6   │     ', style: color238 },
		PreviewSegment{ text: 'while ', style: color5 },
		PreviewSegment{ text: '(i ', style: standard },
		PreviewSegment{ text: '<= ', style: color5 },
		PreviewSegment{ text: '16', style: color4 },
		PreviewSegment{ text: ') : (i ', style: standard },
		PreviewSegment{ text: '+= ', style: color5 },
		PreviewSegment{ text: '1', style: color4 },
		PreviewSegment{ text: ') {', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 10, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   7   │         ', style: color238 },
		PreviewSegment{ text: 'if ', style: color5 },
		PreviewSegment{ text: '(i ', style: standard },
		PreviewSegment{ text: '% ', style: color5 },
		PreviewSegment{ text: '15 ', style: color4 },
		PreviewSegment{ text: '== ', style: color5 },
		PreviewSegment{ text: '0', style: color4 },
		PreviewSegment{ text: ') {', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 11, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   8   │             ', style: color238 },
		PreviewSegment{ text: 'try ', style: color5 },
		PreviewSegment{ text: 'stdout.writeAll(', style: standard },
		PreviewSegment{ text: '"ZiggZagg', style: color10 },
		PreviewSegment{ text: '\\n', style: color12 },
		PreviewSegment{ text: '"', style: color10 },
		PreviewSegment{ text: ');', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 12, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '   9   │         ', style: color238 },
		PreviewSegment{ text: '} ', style: standard },
		PreviewSegment{ text: 'else if ', style: color5 },
		PreviewSegment{ text: '(i ', style: standard },
		PreviewSegment{ text: '% ', style: color5 },
		PreviewSegment{ text: '3 ', style: color4 },
		PreviewSegment{ text: '== ', style: color5 },
		PreviewSegment{ text: '0', style: color4 },
		PreviewSegment{ text: ') {', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 13, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  10   │             ', style: color238 },
		PreviewSegment{ text: 'try ', style: color5 },
		PreviewSegment{ text: 'stdout.writeAll(', style: standard },
		PreviewSegment{ text: '"Zigg', style: color10 },
		PreviewSegment{ text: '\\n', style: color12 },
		PreviewSegment{ text: '"', style: color10 },
		PreviewSegment{ text: ');', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 14, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  11   │         ', style: color238 },
		PreviewSegment{ text: '} ', style: standard },
		PreviewSegment{ text: 'else if ', style: color5 },
		PreviewSegment{ text: '(i ', style: standard },
		PreviewSegment{ text: '% ', style: color5 },
		PreviewSegment{ text: '5 ', style: color4 },
		PreviewSegment{ text: '== ', style: color5 },
		PreviewSegment{ text: '0', style: color4 },
		PreviewSegment{ text: ') {', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 15, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  12   │             ', style: color238 },
		PreviewSegment{ text: 'try ', style: color5 },
		PreviewSegment{ text: 'stdout.writeAll(', style: standard },
		PreviewSegment{ text: '"Zagg', style: color10 },
		PreviewSegment{ text: '\\n', style: color12 },
		PreviewSegment{ text: '"', style: color10 },
		PreviewSegment{ text: ');', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 16, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  13   │         ', style: color238 },
		PreviewSegment{ text: '} ', style: standard },
		PreviewSegment{ text: 'else ', style: color5 },
		PreviewSegment{ text: '{', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 17, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  14   │             ', style: color238 },
		PreviewSegment{ text: 'try ', style: color5 },
		PreviewSegment{ text: 'stdout.print("{d}\\n", .{i})', style: standard_selection },
		PreviewSegment{ text: ';', style: cursor },
	])
	self.put_preview_segments(mut out, next_row + 18, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  15   │         ', style: color238 },
		PreviewSegment{ text: '}', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 19, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  16   │     ', style: color238 },
		PreviewSegment{ text: '}', style: standard },
	])
	self.put_preview_segments(mut out, next_row + 20, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '  17   │ ', style: color238 },
		PreviewSegment{ text: '}', style: standard },
	])
	put_preview_segment(mut out, next_row + 21, x_off + 2, right, height,
		'───────┴${'─'.repeat(max_int(width - 10, 0))}', color238)
	self.put_preview_segments(mut out, next_row + 22, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: 'ghostty ', style: color6 },
		PreviewSegment{ text: 'on ', style: standard },
		PreviewSegment{ text: ' main ', style: color4 },
		PreviewSegment{ text: '[+] ', style: color1 },
		PreviewSegment{ text: 'via ', style: standard },
		PreviewSegment{ text: ' v0.13.0 ', style: color3 },
		PreviewSegment{ text: 'via ', style: standard },
		PreviewSegment{ text: '  impure (ghostty-env)', style: color4 },
	])
	self.put_preview_segments(mut out, next_row + 23, x_off + 2, right, sample_bottom, [
		PreviewSegment{ text: '✦ ', style: color4 },
		PreviewSegment{ text: 'at ', style: standard },
		PreviewSegment{ text: '10:36:15 ', style: color3 },
		PreviewSegment{ text: '→', style: color2 },
	])
	next_row += 24

	words := lorem_ipsum.split_any(' \n')
	mut row := next_row + 1
	mut col := x_off + 2
	mut word_index := 0
	for row < height && words.len > 0 {
		word := words[word_index]
		word_index = (word_index + 1) % words.len
		word_width := word.len
		if col + word_width > x_off + width {
			row++
			col = x_off + 2
		}
		if row >= height {
			break
		}
		style := match word {
			'ipsum' {
				vaxis.Style{
					fg: color_from_palette(config, 2)
					bg: bg
				}
			}
			'consectetur' {
				standard_bold
			}
			'reprehenderit' {
				standard_italic
			}
			'Praesent' {
				standard_bold_italic
			}
			'auctor' {
				standard_underline
			}
			'dui' {
				standard_double_underline
			}
			'erat' {
				standard_dashed_underline
			}
			'enim' {
				standard_dotted_underline
			}
			'odio' {
				standard_curly_underline
			}
			else {
				standard
			}
		}

		put_preview_segment(mut out, row, col, x_off + width, height, word, style)
		col += word_width + 1
	}
	return out.str()
}

struct PreviewSegment {
	text  string
	style vaxis.Style
}

fn preview_terminal_color(value ?configpkg.TerminalColor, fallback vaxis.Color) vaxis.Color {
	color := value or { return fallback }
	return match color {
		configpkg.TerminalColorColor {
			vaxis.ColorRgb{
				rgb: [color.color.r, color.color.g, color.color.b]!
			}
		}
		configpkg.TerminalColorCellForeground, configpkg.TerminalColorCellBackground {
			// Ghostty reads the tagged union's `.color` arm directly here.
			panic('theme preview requires an explicit terminal color')
		}
	}
}

fn preview_palette_style(config configpkg.Config, index int, bg vaxis.Color) vaxis.Style {
	return vaxis.Style{
		fg: color_from_palette(config, index)
		bg: bg
	}
}

fn put_preview_segment(mut out strings.Builder, row int, col int, right int, bottom int, text string, style vaxis.Style) {
	if row >= bottom {
		return
	}
	put_segment(mut out, row, col, right, text, style)
}

fn (self &Preview) put_preview_segments(mut out strings.Builder, row int, col int, right int, bottom int, segments []PreviewSegment) {
	if row < 0 || row >= bottom || col < 0 || col >= right {
		return
	}
	// Match pinned Window.print(.grapheme): segments share one cursor, widths
	// come from the window's negotiated method, and wrapping uses its left edge.
	left := col - 2
	mut current_row := row
	mut current_col := col
	for segment in segments {
		mut offset := 0
		for offset < segment.text.len {
			if current_col >= right {
				current_row++
				current_col = left
			}
			if current_row >= bottom {
				return
			}
			run_row := current_row
			run_col := current_col
			mut run := strings.new_builder(segment.text.len - offset)
			for offset < segment.text.len && current_col < right {
				length := vaxis.first_grapheme_byte_length(segment.text[offset..])
				if length == 0 {
					return
				}
				grapheme := segment.text[offset..offset + length]
				offset += length
				if grapheme == '\n' {
					current_row++
					current_col = left
					break
				}
				w := int(vaxis.gwidth(grapheme, self.width_method))
				if w == 0 {
					continue
				}
				run.write_string(grapheme)
				current_col += w
			}
			run_text := run.str()
			if run_text.len > 0 {
				out.write_string(vaxis.position(run_row, run_col))
				out.write_string(vaxis.styled(run_text, segment.style))
			}
		}
	}
}

fn put_segment(mut out strings.Builder, row int, col int, right int, text string, style vaxis.Style) {
	if row < 0 || col < 0 || col >= right {
		return
	}
	visible := vaxis.truncate(text, right - col)
	if visible.len == 0 {
		return
	}
	out.write_string(vaxis.position(row, col))
	out.write_string(vaxis.styled(visible, style))
}

fn put_link(mut out strings.Builder, row int, col int, right int, text string, uri string, style vaxis.Style) {
	if row < 0 || col < 0 || col >= right {
		return
	}
	visible := vaxis.truncate(text, right - col)
	if visible.len == 0 {
		return
	}
	out.write_string(vaxis.position(row, col))
	out.write_string(vaxis.hyperlink(visible, uri, style))
}

fn draw_box(mut out strings.Builder, x int, y int, width int, height int, style vaxis.Style) {
	if width < 2 || height < 2 {
		return
	}
	put_segment(mut out, y, x, x + width, '┌${'─'.repeat(width - 2)}┐', style)
	for row in y + 1 .. y + height - 1 {
		put_segment(mut out, row, x, x + width, '│${' '.repeat(width - 2)}│', style)
	}
	put_segment(mut out, y + height - 1, x, x + width, '└${'─'.repeat(width - 2)}┘', style)
}

fn draw_help_modal(mut out strings.Builder, screen_width int, screen_height int, style vaxis.Style) {
	help := [
		HelpEntry{ keys: '^C, q, ESC', help: 'Quit.' },
		HelpEntry{ keys: 'F1, ?, ^H', help: 'Toggle help window.' },
		HelpEntry{ keys: 'f', help: 'Cycle through theme filters.' },
		HelpEntry{ keys: 'k, ↑', help: 'Move up 1 theme.' },
		HelpEntry{ keys: 'ScrollUp', help: 'Move up 1 theme.' },
		HelpEntry{ keys: 'PgUp', help: 'Move up 20 themes.' },
		HelpEntry{ keys: 'j, ↓', help: 'Move down 1 theme.' },
		HelpEntry{ keys: 'ScrollDown', help: 'Move down 1 theme.' },
		HelpEntry{ keys: 'PgDown', help: 'Move down 20 themes.' },
		HelpEntry{ keys: 'h, x', help: 'Show palette numbers in hexadecimal.' },
		HelpEntry{ keys: 'd', help: 'Show palette numbers in decimal.' },
		HelpEntry{ keys: 'c', help: 'Copy theme name to the clipboard.' },
		HelpEntry{ keys: 'C', help: 'Copy theme path to the clipboard.' },
		HelpEntry{ keys: 'Home', help: 'Go to the start of the list.' },
		HelpEntry{ keys: 'End', help: 'Go to the end of the list.' },
		HelpEntry{ keys: '/', help: 'Start search.' },
		HelpEntry{ keys: '^X, ^/', help: 'Clear search.' },
		HelpEntry{ keys: '⏎', help: 'Save theme or close search window.' },
		HelpEntry{ keys: 'w', help: 'Write theme to auto config file.' },
	]
	width := min_int(60, max_int(screen_width - 2, 1))
	height := min_int(22, max_int(screen_height - 2, 1))
	x := max_int((screen_width - width) / 2, 0)
	y := max_int((screen_height - height) / 2, 0)
	draw_box(mut out, x, y, width, height, style)
	for i, entry in help {
		if i + 1 >= height - 1 {
			break
		}
		put_segment(mut out, y + i + 1, x + 2, x + width - 1, entry.keys, style)
		put_segment(mut out, y + i + 1, x + 15, x + width - 1, '—', style)
		put_segment(mut out, y + i + 1, x + 17, x + width - 1, entry.help, style)
	}
}

struct HelpEntry {
	keys string
	help string
}

fn draw_save_modal(mut out strings.Builder, screen_width int, screen_height int, theme string, style vaxis.Style) {
	instructions := [
		'To apply this theme, add the following line to your Ghostty configuration:',
		'',
		'theme = ${theme}',
		'',
		'Save the configuration file and then reload it to apply the new theme.',
		'',
		"Or press 'w' to write an auto theme file to your system's preferred default config path.",
		'Then add the following line to your Ghostty configuration and reload:',
		'',
		'config-file = ?auto/theme.ghostty',
		'',
		'For more details on configuration and themes, visit the Ghostty documentation:',
		'',
		'https://ghostty.org/docs/config/reference',
	]
	width := min_int(92, max_int(screen_width - 2, 1))
	height := min_int(17, max_int(screen_height - 2, 1))
	x := max_int((screen_width - width) / 2, 0)
	y := max_int((screen_height - height) / 2, 0)
	draw_box(mut out, x, y, width, height, style)
	for i, line in instructions {
		if i + 1 >= height - 1 {
			break
		}
		put_segment(mut out, y + i + 1, x + 2, x + width - 1, line, style)
	}
}

fn min_int(a int, b int) int {
	return if a < b { a } else { b }
}

fn max_int(a int, b int) int {
	return if a > b { a } else { b }
}

// save_selected_theme writes the selected theme to the auto config file.
fn (mut self Preview) save_selected_theme() {
	if self.filtered.len == 0 {
		return
	}
	idx := self.filtered[self.current]
	theme := self.themes[idx]
	write_auto_theme_file(theme.theme) or { return }
}

// The lorem ipsum text used in the theme preview.
const lorem_ipsum = $embed_file('lorem_ipsum.txt').to_string()

// resolve_auto_theme_path returns the path to the auto theme config file.
fn resolve_auto_theme_path() !string {
	main_cfg_path := configpkg.preferred_default_file_path()!
	if main_cfg_path.len == 0 {
		return error('no default config path')
	}
	base_dir := os.dir(main_cfg_path)
	return os.join_path(base_dir, 'auto', 'theme.ghostty')
}

// write_auto_theme_file writes a theme = <name> line to the auto theme config file.
fn write_auto_theme_file(theme_name string) ! {
	auto_path := resolve_auto_theme_path()!

	dir := os.dir(auto_path)
	if dir.len > 0 {
		os.mkdir_all(dir)!
	}

	os.write_file(auto_path, 'theme = ${theme_name}\n')!
}

// color returns a vaxis.Color from the config palette at the given index.
fn color_from_palette(cfg configpkg.Config, palette int) vaxis.Color {
	c := cfg.palette.value[palette]
	return vaxis.ColorRgb{
		rgb: [c.r, c.g, c.b]!
	}
}

// preview launches the TUI preview for the given themes.
fn preview(themes []ThemeListElement, theme_filter ColorScheme) ! {
	mut app := Preview.init(themes, theme_filter)!
	defer {
		app.deinit()
	}
	app.run()!
}

// should_include_theme returns true if the theme should be listed based on the color filter.
// Determines dark/light by computing the luminance of the theme's background color.
pub fn should_include_theme(theme_filter ColorScheme, theme_config configpkg.Config) bool {
	rf := f32(theme_config.background.r) / 255.0
	gf := f32(theme_config.background.g) / 255.0
	bf := f32(theme_config.background.b) / 255.0
	luminance := 0.2126 * rf + 0.7152 * gf + 0.0722 * bf
	is_dark := luminance < 0.5
	return theme_filter == .all || (theme_filter == .dark && is_dark)
		|| (theme_filter == .light && !is_dark)
}

// The `list-themes` command is used to preview or list all the available
// themes for Ghostty.
//
// If this command is run from a TTY, a TUI preview of the themes will be
// shown. While in the preview, `F1` will bring up a help screen and `ESC` will
// exit the preview. Other keys that can be used to navigate the preview are
// listed in the help screen.
//
// If this command is not run from a TTY, or the output is piped to another
// command, a plain list of theme names will be printed to the screen. A plain
// list can be forced using the `--plain` CLI flag.
//
// Two different directories will be searched for themes.
//
// The first directory is the `themes` subdirectory of your Ghostty
// configuration directory. This is `$XDG_CONFIG_HOME/ghostty/themes` or
// `~/.config/ghostty/themes`.
//
// The second directory is the `themes` subdirectory of the Ghostty resources
// directory. Ghostty ships with a multitude of themes that will be installed
// into this directory. On macOS, this directory is the
// `Ghostty.app/Contents/Resources/ghostty/themes`. On Linux, this directory
// is the `share/ghostty/themes` (wherever you installed the Ghostty "share"
// directory). If you're running Ghostty from the source, this is the
// `zig-out/share/ghostty/themes` directory.
//
// You can also set the `GHOSTTY_RESOURCES_DIR` environment variable to point
// to the resources directory.
//
// Flags:
//
//   * `--path`: Show the full path to the theme.
//
//   * `--plain`: Force a plain listing of themes.
//
//   * `--color`: Specify the color scheme of the themes included in the list.
//                This can be `dark`, `light`, or `all`. The default is `all`.
pub fn run_list_themes(args []string) !int {
	opts := parse_list_themes_options(args)!

	resources_dir := global_state.get_state().resources_dir.app()
	if resources_dir == none {
		eprintln('Could not find the Ghostty resources directory. Please ensure that Ghostty is installed correctly.')
	}

	mut count := 0
	mut themes := []ThemeListElement{}

	mut it := themepkg.LocationIterator.new()
	for {
		loc := it.next() or { break }
		if !os.exists(loc.dir) {
			continue
		}
		entries := os.ls(loc.dir) or {
			eprintln('error trying to open ${loc.dir}: ${err}')
			continue
		}
		for entry in entries {
			// Ghostty accepts regular files and symbolic-link directory entries.
			full_path := os.join_path(loc.dir, entry)
			if !os.is_file(full_path) && !os.is_link(full_path) {
				continue
			}
			if entry == '.DS_Store' {
				continue
			}
			count += 1
			themes << ThemeListElement{
				path:     full_path
				location: loc.location
				theme:    entry
			}
		}
	}

	if count == 0 {
		eprintln('No themes found, check to make sure that the themes were installed correctly.')
		return 1
	}

	themes.sort_with_compare(theme_list_less_than)

	if tui.can_pretty_print && !opts.plain && os.is_atty(1) > 0 {
		preview(themes, opts.color)!
		return 0
	}

	mut theme_config := configpkg.Config.default_config()
	for theme in themes {
		theme_config.load_file(theme.path)!
		if !should_include_theme(opts.color, theme_config) {
			continue
		}
		if opts.path {
			println('${theme.theme} (${theme.location}) ${theme.path}')
		} else {
			println('${theme.theme} (${theme.location})')
		}
	}

	// Don't forget to flush!
	// (V's println auto-flushes)
	return 0
}

fn parse_list_themes_options(args []string) !Options {
	return parse_action_options[Options](args)
}
