module cli

import os
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
	la := a.theme.to_lower()
	lb := b.theme.to_lower()
	if la < lb {
		return -1
	}
	if la > lb {
		return 1
	}
	return 0
}

// to_uri converts the theme path to a file:// URI string.
pub fn (self &ThemeListElement) to_uri() string {
	// Simple file:// URI construction
	return 'file://${self.path}'
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
	theme_filter ColorScheme
}

// Preview.new creates a new Preview with the given themes and filter.
fn Preview.new(themes []ThemeListElement, theme_filter ColorScheme) Preview {
	mut p := Preview{
		themes:       themes
		theme_filter: theme_filter
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
		query := self.search_text.to_lower()
		tokens := query.split(' ').filter(it.len > 0)

		for i, mut theme in self.themes {
			theme_config.load_file(theme.path)
			if !should_include_theme(self.theme_filter, theme_config) {
				continue
			}
			r := zf.rank(theme.theme, tokens, zf.RankOptions{
				to_lower: true
				plain:    true
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
					if key.matches_any([u32(`j`), u32(`+`), vaxis.down, vaxis.kp_down, vaxis.kp_add],
						vaxis.Modifiers{})
					{
						self.down(1)
					}
					if key.matches_any([vaxis.page_down, vaxis.kp_down], vaxis.Modifiers{}) {
						self.down(20)
					}
					if key.matches_any([u32(`k`), u32(`-`), vaxis.up, vaxis.kp_up, vaxis.kp_subtract],
						vaxis.Modifiers{})
					{
						self.up(1)
					}
					if key.matches_any([vaxis.page_down, vaxis.kp_page_up], vaxis.Modifiers{}) {
						self.up(20)
					}
					if key.matches_any([u32(`h`), u32(`x`)], vaxis.Modifiers{}) {
						self.hex = true
					}
					if key.matches(u32(`d`), vaxis.Modifiers{}) {
						self.hex = false
					}
					// 'c' copies theme name, 'C' copies theme path
					// XTODO: clipboard copy needs vaxis.copyToSystemClipboard
					if key.matches(u32(`f`), vaxis.Modifiers{}) {
						match self.theme_filter {
							.all { self.theme_filter = .dark }
							.dark { self.theme_filter = .light }
							.light { self.theme_filter = .all }
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
						self.search_text = ''
						self.update_filtered()
						return
					}
					// XTODO: integrate with vaxis TextInput for character-by-character input
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
			// XTODO: mouse handling needs vaxis window hit testing
		}
		WinsizeEvent {
			// XTODO: window resize needs vaxis resize
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
	// XTODO: TUI preview requires vaxis event loop, alt screen, mouse mode,
	// terminal querying, and rendering pipeline. None of these have V equivalents yet.
	// The full draw() and drawPreview() methods render a split-pane TUI with:
	// - Left pane: scrollable theme list with selection indicator
	// - Right pane: preview of the selected theme's colors with a code sample
	// - Modal overlays for help, search, and save dialogs
}

// draw renders the full TUI interface.
fn (mut self Preview) draw() {
	// XTODO: requires vaxis Window, child windows, printSegment, fill, etc.
	// This method:
	// 1. Draws the theme list on the left (32 cols wide)
	// 2. Handles mouse hover highlighting
	// 3. Scrolls to keep current selection visible
	// 4. Draws the theme preview on the right (drawPreview)
	// 5. Shows modal overlays based on mode:
	//    - .normal: hides cursor
	//    - .help: shows key help overlay (F1/? to toggle)
	//    - .search: shows search input box
	//    - .save: shows save instructions dialog
}

// draw_preview renders the theme color preview pane.
fn (mut self Preview) draw_preview(x_off int, width int) {
	// XTODO: requires vaxis rendering.
	// This method renders:
	// 1. Theme name (bold italic, centered, as a hyperlink)
	// 2. Theme file path (centered, as a hyperlink)
	// 3. Config diagnostics (if any loading errors)
	// 4. 16-color palette grid (hex or decimal)
	// 5. A styled "bat" code preview (ziggzagg.zig)
	//    showing: const, fn, pub, while, if/else, strings with
	//    syntax highlighting colors from the theme palette
	// 6. A starship-style prompt line
	// 7. Lorem ipsum with various text styles (bold, italic,
	//    underline, double underline, dashed, curly, dotted)
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
	main_cfg_path := configpkg.preferred_default_file_path()
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
	// XTODO: requires vaxis TUI library
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

	resources_dir := global_state.state.resources_dir.app()
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
