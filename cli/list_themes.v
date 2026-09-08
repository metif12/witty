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
pub enum ColorScheme {
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
		path: self.path
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
enum PreviewMode {
	normal
	help
	search
	save
}

// Preview is the TUI preview state for interactively browsing themes.
struct Preview {
mut:
	should_quit  bool
	themes       []ThemeListElement
	filtered     []int
	current      int
	window       int
	hex          bool
	mode         PreviewMode = .normal
	color_scheme vaxis.Scheme = .light
	search_text  string
	text_input   vaxis.TextInput
	winsize      vaxis.Winsize
	theme_filter ColorScheme
}

// Preview.new creates a new Preview with the given themes and filter.
fn Preview.new(themes []ThemeListElement, theme_filter ColorScheme) Preview {
	mut p := Preview{
		themes: themes
		theme_filter: theme_filter
		text_input: vaxis.TextInput.new()
		winsize: vaxis.terminal_size()
		color_scheme: vaxis.detect_color_scheme()
	}
	p.update_filtered()
	return p
}

// update_filtered rebuilds the filtered index list based on search text and theme filter.
fn (mut self Preview) update_filtered() {
	// Remember current selection's name for re-selection after filtering
	relative := if self.current > self.window { self.current - self.window } else { 0 }
	mut selected := ''
	if self.filtered.len > 0 && self.current < self.filtered.len {
		selected = self.themes[self.filtered[self.current]].theme
	}

	old_filtered := self.filtered.clone()
	self.filtered.clear()

	mut theme_config := configpkg.Config.default_config()

	if self.search_text.len > 0 {
		query := ascii.lower_string(self.search_text)
		tokens := query.split(' ').filter(it.len > 0)

		for i, mut theme in self.themes {
			theme_config.load_file(theme.path)
			if !should_include_theme(self.theme_filter, theme_config) {
				continue
			}
			r := zf.rank(theme.theme, tokens, zf.RankOptions{
				to_lower: true
				plain: true
			})
			if r != none {
				theme.rank = r
				self.filtered << i
			}
		}
	} else {
		for i, mut theme in self.themes {
			theme_config.load_file(theme.path)
			if should_include_theme(self.theme_filter, theme_config) {
				self.filtered << i
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
				// Keep the relative position but ensure all search results are visible
				new_window := if idx > relative { idx - relative } else { 0 }
				// If the new window would hide some results at the top, adjust it
				self.current = idx
				self.window = if self.filtered.len <= small_list_threshold {
					0
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
fn (mut self Preview) up(count int) {
	if self.filtered.len == 0 {
		self.current = 0
		return
	}
	self.current = if self.current > count { self.current - count } else { 0 }
}

// down moves the selection down by count items.
fn (mut self Preview) down(count int) {
	if self.filtered.len == 0 {
		self.current = 0
		return
	}
	self.current += count
	if self.current >= self.filtered.len {
		self.current = self.filtered.len - 1
	}
}

// update processes a single input event.
fn (mut self Preview) update(event Event) {
	match event {
		KeyPressEvent {
			key := event.key
			if key.matches(u32(`c`), vaxis.Modifiers{ ctrl: true }) {
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
					if key.matches(u32(`h`), vaxis.Modifiers{ ctrl: true }) {
						self.mode = .help
					}
					if key.matches(u32(`/`), vaxis.Modifiers{}) {
						self.mode = .search
					}
					if key.matches_any([vaxis.enter, vaxis.kp_enter], vaxis.Modifiers{}) {
						self.mode = .save
					}
					if key.matches_any([u32(`x`), u32(`/`)], vaxis.Modifiers{ ctrl: true }) {
						self.text_input.clear_retaining_capacity()
						self.search_text = ''
						self.update_filtered()
					}
					if key.matches_any([vaxis.home, vaxis.kp_home], vaxis.Modifiers{}) {
						self.current = 0
					}
					if key.matches_any([vaxis.end, vaxis.kp_end], vaxis.Modifiers{}) {
						if self.filtered.len > 0 {
							self.current = self.filtered.len - 1
						}
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
					if self.filtered.len > 0 && key.matches(u32(`c`), vaxis.Modifiers{}) {
						vaxis.copy_to_system_clipboard(self.themes[self.filtered[self.current]].theme)
					} else if self.filtered.len > 0
						&& key.matches(u32(`c`), vaxis.Modifiers{ shift: true }) {
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
						self.update_filtered()
					}
				}
				.help {
					if key.matches(u32(`q`), vaxis.Modifiers{}) {
						self.should_quit = true
					}
					if key.matches_any([u32(`?`), vaxis.escape, vaxis.f1], vaxis.Modifiers{}) {
						self.mode = .normal
					}
					if key.matches(u32(`h`), vaxis.Modifiers{ ctrl: true }) {
						self.mode = .normal
					}
				}
				.search {
					if key.matches_any([vaxis.escape, vaxis.enter], vaxis.Modifiers{}) {
						self.mode = .normal
						return
					}
					if key.matches_any([u32(`x`), u32(`/`)], vaxis.Modifiers{ ctrl: true }) {
						self.text_input.clear_retaining_capacity()
						self.search_text = ''
						self.update_filtered()
						return
					}
					self.text_input.update(key)
					self.search_text = self.text_input.get_text()
					self.update_filtered()
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
			if self.mode == .normal {
				if event.mouse.button == .wheel_up {
					self.up(1)
				} else if event.mouse.button == .wheel_down {
					self.down(1)
				} else if event.mouse.button == .left && event.mouse.type_ == .release
					&& event.mouse.col < min_int(32, int(self.winsize.cols)) {
					selection := self.window + event.mouse.row
					if selection < self.filtered.len {
						self.current = selection
					}
				}
			}
		}
		WinsizeEvent {
			self.winsize = event.winsize
		}
	}
}

// ui_fg returns the foreground color for the UI based on color scheme.
fn (self &Preview) ui_fg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0x00), 0x00, 0x00]! } }
		.dark { vaxis.Color{ rgb: [u8(0xff), 0xff, 0xff]! } }
	}
}

// ui_bg returns the background color for the UI based on color scheme.
fn (self &Preview) ui_bg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0xff), 0xff, 0xff]! } }
		.dark { vaxis.Color{ rgb: [u8(0x00), 0x00, 0x00]! } }
	}
}

// ui_standard returns a standard style with UI fg/bg.
fn (self &Preview) ui_standard() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_fg()
		bg: self.ui_bg()
	}
}

// ui_hover_bg returns the hover background color.
fn (self &Preview) ui_hover_bg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0xbb), 0xbb, 0xbb]! } }
		.dark { vaxis.Color{ rgb: [u8(0x22), 0x22, 0x22]! } }
	}
}

// ui_highlighted returns a style for hovered items.
fn (self &Preview) ui_highlighted() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_fg()
		bg: self.ui_hover_bg()
	}
}

// ui_selected_fg returns the foreground color for selected items.
fn (self &Preview) ui_selected_fg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0x00), 0xaa, 0x00]! } }
		.dark { vaxis.Color{ rgb: [u8(0x00), 0xaa, 0x00]! } }
	}
}

// ui_selected_bg returns the background color for selected items.
fn (self &Preview) ui_selected_bg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0xaa), 0xaa, 0xaa]! } }
		.dark { vaxis.Color{ rgb: [u8(0x33), 0x33, 0x33]! } }
	}
}

// ui_selected returns a style for selected items.
fn (self &Preview) ui_selected() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_selected_fg()
		bg: self.ui_selected_bg()
	}
}

// ui_err_fg returns the foreground color for error messages.
fn (self &Preview) ui_err_fg() vaxis.Color {
	return match self.color_scheme {
		.light { vaxis.Color{ rgb: [u8(0xff), 0x00, 0x00]! } }
		.dark { vaxis.Color{ rgb: [u8(0xff), 0x00, 0x00]! } }
	}
}

// ui_err returns a style for error messages.
fn (self &Preview) ui_err() vaxis.Style {
	return vaxis.Style{
		fg: self.ui_err_fg()
		bg: self.ui_bg()
	}
}

// run is the TUI preview event loop.
fn (mut self Preview) run() {
	mut tty := vaxis.Tty.new()
	self.winsize = vaxis.terminal_size()
	self.color_scheme = vaxis.detect_color_scheme()
	vaxis.begin_session('👻 Ghostty Theme Preview 👻')
	defer {
		self.text_input.deinit()
		vaxis.end_session()
	}

	mut dirty := true
	for !self.should_quit {
		winsize := vaxis.terminal_size()
		if winsize != self.winsize {
			self.update(Event(WinsizeEvent{
				winsize: winsize
			}))
			dirty = true
		}

		mut handled_input := false
		for {
			event := tty.poll() or { break }
			match event {
				vaxis.Key {
					self.update(Event(KeyPressEvent{
						key: event
					}))
				}
				vaxis.Mouse {
					self.update(Event(MouseEvent{
						mouse: event
					}))
				}
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
fn (mut self Preview) draw() string {
	width := max_int(int(self.winsize.cols), 1)
	height := max_int(int(self.winsize.rows), 1)
	list_width := min_int(32, width)
	standard := self.ui_standard()

	if self.filtered.len == 0 {
		self.current = 0
		self.window = 0
	} else {
		end := self.window + height - 1
		if self.current > end {
			self.window = self.current - height + 1
		}
		if self.current < self.window {
			self.window = self.current
		}
		if self.window >= self.filtered.len {
			self.window = self.filtered.len - 1
		}
	}

	mut out := strings.new_builder(width * height * 2)
	out.write_string(vaxis.clear_screen())
	for row in 0 .. height {
		put_segment(mut out, row, 0, width, ' '.repeat(width), standard)
	}

	for row in 0 .. height {
		index := self.window + row
		if index >= self.filtered.len {
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
			put_link(mut out, row, 2, list_width, theme.theme, theme.to_uri(), standard)
		}
	}

	if width > list_width {
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
			text := '/ ${self.search_text}'
			put_segment(mut out, y + 1, x + 2, x + modal_width - 1, text, standard)
			out.write_string(vaxis.show_cursor(y + 1, min_int(x + 2 + text.runes().len, x + modal_width - 2)))
		}
		.save {
			if self.filtered.len > 0 {
				theme := self.themes[self.filtered[self.current]]
				draw_save_modal(mut out, width, height, theme.theme, standard)
			}
			out.write_string(vaxis.hide_cursor())
		}
	}

	return out.str()
}

// draw_preview renders the theme color preview pane.
fn (mut self Preview) draw_preview(x_off int, width int, height int) string {
	mut out := strings.new_builder(width * height)
	if self.filtered.len == 0 {
		text := 'No theme found!'
		put_segment(mut out, max_int(height / 2 - 1, 0), x_off + max_int((width - text.len) / 2, 0), x_off + width, text, self.ui_standard())
		return out.str()
	}

	theme := self.themes[self.filtered[self.current]]
	mut config := configpkg.Config.default_config()
	config.load_file(theme.path)
	fg := vaxis.Color{ rgb: [config.foreground.r, config.foreground.g, config.foreground.b]! }
	bg := vaxis.Color{ rgb: [config.background.r, config.background.g, config.background.b]! }
	standard := vaxis.Style{
		fg: fg
		bg: bg
	}
	bold := vaxis.Style{
		fg: fg
		bg: bg
		bold: true
	}
	title_style := vaxis.Style{
		fg: fg
		bg: bg
		bold: true
		italic: true
	}

	for row in 0 .. height {
		put_segment(mut out, row, x_off, x_off + width, ' '.repeat(width), standard)
	}
	put_link(mut out, 1, x_off + max_int((width - theme.theme.runes().len) / 2, 0), x_off + width, theme.theme, theme.to_uri(), title_style)
	put_link(mut out, 2, x_off + max_int((width - theme.path.runes().len) / 2, 0), x_off + width, theme.path, theme.to_uri(), standard)

	mut next_row := 4
	if config.diagnostics.len > 0 && next_row < height {
		put_segment(mut out, next_row, x_off + 2, x_off + width, 'Problems were encountered trying to load the theme:', self.ui_err())
		next_row++
		for diagnostic in config.diagnostics {
			if next_row >= height {
				break
			}
			put_segment(mut out, next_row, x_off + 2, x_off + width, diagnostic.message, self.ui_err())
			next_row++
		}
	}

	for i in 0 .. 16 {
		row := next_row + (i / 8) * 2
		col := x_off + (i % 8) * 8
		if row >= height || col >= x_off + width {
			continue
		}
		label := if self.hex { ' ${i:02x}' } else { '${i:3}' }
		put_segment(mut out, row, col, x_off + width, label, standard)
		palette_style := vaxis.Style{
			fg: color_from_palette(config, i)
			bg: bg
		}
		put_segment(mut out, row, col + 4, x_off + width, '████', palette_style)
		if row + 1 < height {
			put_segment(mut out, row + 1, col + 4, x_off + width, '████', palette_style)
		}
	}
	next_row += 5

	code_lines := [
		'→ bat ziggzagg.zig',
		'───────┬────────────────────────────────────────',
		'       │ File: ziggzagg.zig',
		'───────┼────────────────────────────────────────',
		'   1   │ const std = @import("std");',
		'   2   │',
		'   3   │ pub fn main() !void {',
		'   4   │     const stdout = std.Io.getStdOut().writer();',
		'   5   │     var i: usize = 1;',
		'   6   │     while (i <= 16) : (i += 1) {',
		'   7   │         if (i % 15 == 0) {',
		'   8   │             try stdout.writeAll("ZiggZagg\\n");',
		'   9   │         } else if (i % 3 == 0) {',
		'  10   │             try stdout.writeAll("Zigg\\n");',
		'  11   │         } else if (i % 5 == 0) {',
		'  12   │             try stdout.writeAll("Zagg\\n");',
		'  13   │         } else {',
		'  14   │             try stdout.print("{d}\\n", .{i});',
		'  15   │         }',
		'  16   │     }',
		'  17   │ }',
		'───────┴────────────────────────────────────────',
		'ghostty on  main [+] via  v0.13.0',
		'✦ at 10:36:15 →',
	]
	for i, line in code_lines {
		row := next_row + i
		if row >= height {
			break
		}
		style := match i {
			0 { vaxis.Style{ fg: color_from_palette(config, 4), bg: bg } }
			1, 2, 3, 21 { vaxis.Style{ fg: color_from_palette(config, 238), bg: bg } }
			22 { vaxis.Style{ fg: color_from_palette(config, 6), bg: bg } }
			23 { vaxis.Style{ fg: color_from_palette(config, 3), bg: bg } }
			else { standard }
		}
		put_segment(mut out, row, x_off + 2, x_off + width, line, style)
	}
	next_row += code_lines.len

	words := lorem_ipsum.split_any(' \n')
	mut row := next_row + 1
	mut col := x_off + 2
	for word in words {
		if word.len == 0 || row >= height {
			continue
		}
		word_width := word.runes().len
		if col + word_width >= x_off + width {
			row++
			col = x_off + 2
		}
		if row >= height {
			break
		}
		style := match word {
			'ipsum' { vaxis.Style{ fg: color_from_palette(config, 2), bg: bg } }
			'consectetur' { bold }
			'reprehenderit' { vaxis.Style{ fg: fg, bg: bg, italic: true } }
			'Praesent' { title_style }
			'auctor' { vaxis.Style{ fg: fg, bg: bg, ul_style: .single } }
			'dui' { vaxis.Style{ fg: fg, bg: bg, ul_style: .double_ } }
			'erat' { vaxis.Style{ fg: fg, bg: bg, ul_style: .dashed } }
			'enim' { vaxis.Style{ fg: fg, bg: bg, ul_style: .dotted } }
			'odio' { vaxis.Style{ fg: fg, bg: bg, ul_style: .curly } }
			else { standard }
		}
		put_segment(mut out, row, col, x_off + width, word, style)
		col += word_width + 1
	}
	return out.str()
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
		'^C, q, ESC — Quit.',
		'F1, ?, ^H   — Toggle help window.',
		'f            — Cycle through theme filters.',
		'k, ↑         — Move up 1 theme.',
		'ScrollUp     — Move up 1 theme.',
		'PgUp         — Move up 20 themes.',
		'j, ↓         — Move down 1 theme.',
		'ScrollDown   — Move down 1 theme.',
		'PgDown       — Move down 20 themes.',
		'h, x         — Show palette numbers in hexadecimal.',
		'd            — Show palette numbers in decimal.',
		'c            — Copy theme name to the clipboard.',
		'C            — Copy theme path to the clipboard.',
		'Home         — Go to the start of the list.',
		'End          — Go to the end of the list.',
		'/            — Start search.',
		'^X, ^/       — Clear search.',
		'⏎            — Save theme or close search window.',
		'w            — Write theme to auto config file.',
	]
	width := min_int(60, max_int(screen_width - 2, 1))
	height := min_int(help.len + 3, max_int(screen_height - 2, 1))
	x := max_int((screen_width - width) / 2, 0)
	y := max_int((screen_height - height) / 2, 0)
	draw_box(mut out, x, y, width, height, style)
	for i, line in help {
		if i + 1 >= height - 1 {
			break
		}
		put_segment(mut out, y + i + 1, x + 2, x + width - 1, line, style)
	}
}

fn draw_save_modal(mut out strings.Builder, screen_width int, screen_height int, theme string, style vaxis.Style) {
	instructions := [
		'To apply this theme, add the following line to your Ghostty configuration:',
		'',
		'theme = ${theme}',
		'',
		'Save the configuration file and then reload it to apply the new theme.',
		'',
		"Or press 'w' to write an auto theme file to your preferred config path.",
		'Then add the following line to your Ghostty configuration and reload:',
		'',
		'config-file = ?auto/theme.ghostty',
		'',
		'For more details on configuration and themes, visit:',
		'',
		'https://ghostty.org/docs/config/reference',
	]
	width := min_int(92, max_int(screen_width - 2, 1))
	height := min_int(instructions.len + 3, max_int(screen_height - 2, 1))
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
	return vaxis.Color{
		rgb: [c.r, c.g, c.b]!
	}
}

// preview launches the TUI preview for the given themes.
fn preview(themes []ThemeListElement, theme_filter ColorScheme) {
	mut app := Preview.new(themes, theme_filter)
	app.run()
}

// should_include_theme returns true if the theme should be listed based on the color filter.
// Determines dark/light by computing the luminance of the theme's background color.
pub fn should_include_theme(theme_filter ColorScheme, theme_config configpkg.Config) bool {
	rf := f32(theme_config.background.r) / 255.0
	gf := f32(theme_config.background.g) / 255.0
	bf := f32(theme_config.background.b) / 255.0
	luminance := 0.2126 * rf + 0.7152 * gf + 0.0722 * bf
	is_dark := luminance < 0.5
	return (theme_filter == .all) || (theme_filter == .dark && is_dark)
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
pub fn run_list_themes(args []string) int {
	mut opts := Options{}
	// Parse CLI arguments
	for arg in args {
		if arg == '--path' {
			opts.path = true
		} else if arg == '--plain' {
			opts.plain = true
		} else if arg == '--color=dark' {
			opts.color = .dark
		} else if arg == '--color=light' {
			opts.color = .light
		} else if arg == '--color=all' {
			opts.color = .all
		}
	}

	resources_dir := global_state.get_state().resources_dir.app()
	if resources_dir.len == 0 {
		eprintln('Could not find the Ghostty resources directory. Please ensure that Ghostty is installed correctly.')
	}

	mut count := 0
	mut themes := []ThemeListElement{}

	mut it := themepkg.LocationIterator.new()
	for {
		loc := it.next() or { break }
		entries := os.ls(loc.dir) or {
			eprintln('error trying to open ${loc.dir}')
			continue
		}
		for entry in entries {
			// Skip non-files and .DS_Store
			full_path := os.join_path(loc.dir, entry)
			if !os.is_file(full_path) {
				continue
			}
			if entry == '.DS_Store' {
				continue
			}
			count += 1
			themes << ThemeListElement{
				path: full_path
				location: loc.location
				theme: entry
			}
		}
	}

	if count == 0 {
		eprintln('No themes found, check to make sure that the themes were installed correctly.')
		return 1
	}

	themes.sort_with_compare(theme_list_less_than)

	if tui.can_pretty_print && !opts.plain && os.is_atty(1) > 0 {
		preview(themes, opts.color)
		return 0
	}

	mut theme_config := configpkg.Config.default_config()
	for theme in themes {
		theme_config.load_file(theme.path)
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
