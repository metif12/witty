module configpkg

// Config represents the full ghostty configuration.
pub struct Config {
pub mut:
	font_size                      f32             = 13.0
	abnormal_command_exit_runtime  u32             = 250
	clipboard_read                 ClipboardAccess = .allow
	clipboard_write                ClipboardAccess = .allow
	clipboard_trim_trailing_spaces bool
	clipboard_paste_protection     bool                    = true
	clipboard_paste_bracketed_safe bool                    = true
	copy_on_select                 CopyOnSelect            = .false_
	confirm_close_surface          ConfirmCloseSurface     = .true_
	cursor_click_to_move           bool
	desktop_notifications          bool                    = true
	mouse_hide_while_typing        bool                    = true
	mouse_reporting                bool                    = true
	mouse_shift_capture            MouseShiftCapture       = .false_
	selection_clear_on_copy        bool                    = true
	selection_clear_on_typing      bool                    = true
	vt_kam_allowed                 bool
	wait_after_command             bool
	window_padding_top             u32
	window_padding_bottom          u32
	window_padding_left            u32
	window_padding_right           u32
	window_padding_balance         bool
	window_height                  u32
	window_width                   u32
	title                          ?string
	title_report                   bool            = true
	command                        ?Command
	initial_command                ?Command
	working_directory              ?string
	env                            RepeatableStringMap
	initial_input                  ?string
	term                           string = 'xterm-256color'
	shell_integration              ShellIntegration        = .detect
	shell_integration_features     ShellIntegrationFeatures
	link_previews                  LinkPreviews            = .false_
	scroll_to_bottom               ScrollToBottom
	// Renderer-related fields
	font_thicken          bool
	font_thicken_strength u8
	font_shaping_break    FontShapingBreak = .none_
	cursor_color          ?TerminalColor
	cursor_opacity        f64              = 1.0
	cursor_text           ?TerminalColor
	background_opacity    f64              = 1.0
	background_opacity_cells bool
	minimum_contrast      f64
	window_padding_color  WindowPaddingColor = .background
	window_vsync          bool               = true
	window_colorspace     WindowColorspace   = .srgb
	alpha_blending        AlphaBlending      = .none_
	background_blur       BackgroundBlur     = .none_
	custom_shader         RepeatablePath
	background_image      ?Path
	background_image_opacity  f32 = 1.0
	background_image_position BackgroundImagePosition = .center
	background_image_fit      BackgroundImageFit      = .contain
	background_image_repeat   bool
	faint_opacity             f64 = 0.5
	bold_color                ?BoldColor
	selection_background      ?TerminalColor
	selection_foreground      ?TerminalColor
	search_background         TerminalColor
	search_foreground         TerminalColor
	search_selected_background TerminalColor
	search_selected_foreground TerminalColor
	link                       LinkConfig
	// Theme color fields used by list-themes preview
	foreground  ColorRGB = ColorRGB{ r: 0xff, g: 0xff, b: 0xff }
	background  ColorRGB = ColorRGB{ r: 0x00, g: 0x00, b: 0x00 }
	palette     Palette  = Palette.default_palette()
	diagnostics []Diagnostic
}

pub fn (c Config) change_conditional_state(state ConditionalState) !Config {
	mut copy := c
	return copy
}

pub fn (mut c Config) deinit() {
	// stub
}

// clone creates a shallow copy of the config.
pub fn (c Config) clone() Config {
	return c
}

// ============================================================
// Types used by renderer DerivedConfig
// ============================================================

// FontShapingBreak controls where font shaping breaks runs.
pub enum FontShapingBreak {
	none_
	character
	grapheme
}

// TerminalColor can be an explicit color or derived from cell fg/bg.
pub enum TerminalColor {
	color
	cell_foreground
	cell_background
}

// WindowPaddingColor determines how the padding area is colored.
pub enum WindowPaddingColor {
	background
	extend
	extend_always
}

// WindowColorspace for color rendering.
pub enum WindowColorspace {
	srgb
	display_p3
}

// AlphaBlending mode for the renderer.
pub enum AlphaBlending {
	none_
	linear
	linear_corrected
}

// Returns true if this blending mode uses linear blending.
pub fn (b AlphaBlending) is_linear() bool {
	return b == .linear || b == .linear_corrected
}

// BackgroundBlur for window transparency effects.
pub enum BackgroundBlur {
	none_
	macos_glass_regular
	macos_glass_clear
}

// BackgroundImagePosition for the background image.
pub enum BackgroundImagePosition {
	top_left
	top_center
	top_right
	center_left
	center
	center_right
	bottom_left
	bottom_center
	bottom_right
}

// BackgroundImageFit for the background image.
pub enum BackgroundImageFit {
	contain
	cover
	stretch
	none_
}

// BoldColor configuration.
pub struct BoldColor {
pub:
	bright bool = true
}

// RepeatablePath holds a list of file paths.
pub struct RepeatablePath {
pub mut:
	items []string
}

pub fn (a &RepeatablePath) equal(b &RepeatablePath) bool {
	if a.items.len != b.items.len {
		return false
	}
	for i, item in a.items {
		if item != b.items[i] {
			return false
		}
	}
	return true
}

pub fn (p RepeatablePath) clone() !RepeatablePath {
	return RepeatablePath{
		items: p.items.clone()
	}
}

// Path represents a config file path.
pub struct Path {
pub:
	path string
}

pub fn (a &Path) equal(b &Path) bool {
	return a.path == b.path
}

pub fn (p Path) clone() !Path {
	return Path{
		path: p.path
	}
}

// LinkConfig for configurable link detection.
pub struct LinkConfig {
pub:
	links LinkList
}

pub struct LinkList {
pub:
	items []LinkEntry
}

pub struct LinkEntry {
pub:
	pattern string
}

// ============================================================
// Existing types
// ============================================================

// Command represents a command to execute. It can be either a shell
// command string (parsed by /bin/sh) or a direct argument list.
pub type Command = ShellCmd | DirectCmd

// ShellCmd is a shell command string like "bash --norc".
pub struct ShellCmd {
pub:
	shell string
}

// DirectCmd is a direct command with pre-parsed arguments.
pub struct DirectCmd {
pub:
	direct []string
}

// arg_iterator returns an iterator over the command's arguments.
// For shell commands, this splits on whitespace with basic quoting support.
// For direct commands, this iterates the args directly.
pub fn (c Command) arg_iterator() ArgIterator {
	match c {
		ShellCmd {
			return ArgIterator{
				kind: .shell
				shell_str: c.shell
				pos: 0
			}
		}
		DirectCmd {
			return ArgIterator{
				kind: .direct
				direct_args: c.direct
				direct_idx: 0
			}
		}
	}
}

// clone creates a copy of the command.
pub fn (c Command) clone() Command {
	match c {
		ShellCmd {
			return Command(ShellCmd{ shell: c.shell.clone() })
		}
		DirectCmd {
			return Command(DirectCmd{ direct: c.direct.clone() })
		}
	}
}

// string_val returns the command as a string.
pub fn (c Command) string_val() string {
	match c {
		ShellCmd { return c.shell }
		DirectCmd { return c.direct.join(' ') }
	}
}

// ArgIterator iterates over the arguments of a command.
pub struct ArgIterator {
mut:
	kind     ArgIterKind
	// For shell commands
	shell_str string
	pos       int
	// For direct commands
	direct_args []string
	direct_idx  int
}

enum ArgIterKind {
	shell
	direct
}

// next returns the next argument, or none if exhausted.
pub fn (mut it ArgIterator) next() ?string {
	match it.kind {
		.shell {
			return it.next_shell_arg()
		}
		.direct {
			if it.direct_idx >= it.direct_args.len {
				return none
			}
			arg := it.direct_args[it.direct_idx]
			it.direct_idx++
			return arg
		}
	}
}

// next_shell_arg parses the next argument from a shell command string,
// handling basic quoting (single and double quotes).
fn (mut it ArgIterator) next_shell_arg() ?string {
	s := it.shell_str
	// Skip whitespace
	for it.pos < s.len && s[it.pos] == ` ` {
		it.pos++
	}
	if it.pos >= s.len {
		return none
	}
	mut result := []u8{}
	for it.pos < s.len {
		ch := s[it.pos]
		if ch == ` ` {
			break
		}
		if ch == `"` || ch == `'` {
			// Quoted string
			quote := ch
			it.pos++
			for it.pos < s.len && s[it.pos] != quote {
				result << s[it.pos]
				it.pos++
			}
			if it.pos < s.len {
				it.pos++ // skip closing quote
			}
		} else {
			result << ch
			it.pos++
		}
	}
	if result.len == 0 {
		return none
	}
	return result.bytestr()
}

// RepeatableStringMap holds key-value string pairs for environment overrides.
pub struct RepeatableStringMap {
pub mut:
	entries []StringMapEntry
}

pub struct StringMapEntry {
pub:
	key   string
	value string
}

// iterator returns an iterator over the string map entries.
pub fn (m RepeatableStringMap) iterator() RepeatableStringMapIterator {
	return RepeatableStringMapIterator{
		entries: m.entries
		idx: 0
	}
}

pub struct RepeatableStringMapIterator {
	entries []StringMapEntry
mut:
	idx int
}

pub fn (mut it RepeatableStringMapIterator) next() ?StringMapEntry {
	if it.idx >= it.entries.len {
		return none
	}
	entry := it.entries[it.idx]
	it.idx++
	return entry
}

// ShellIntegrationFeatures controls which shell integration features are enabled.
pub struct ShellIntegrationFeatures {
pub:
	cursor        bool = true
	sudo          bool = true
	title         bool = true
	ssh_env       bool = true
	ssh_terminfo  bool = true
	path          bool = true
}

pub enum ShellIntegration {
	detect
	none_
	bash
	elvish
	fish
	nushell
	zsh
}

pub enum LinkPreviews {
	true_
	false_
}

pub enum ClipboardAccess {
	allow
	ask
	deny
}

pub enum CopyOnSelect {
	false_
	true_
	clipboard
}

pub enum ConfirmCloseSurface {
	always
	false_
	true_
}

pub enum MouseShiftCapture {
	never
	always
	false_
	true_
}

pub struct ConditionalState {
pub mut:
	theme Theme
}

pub enum Theme {
	light
	dark
}

pub struct ScrollToBottom {
pub:
	keystroke bool = true
}

pub struct Keybinds {
pub:
	set BindingSet
}

pub fn (k Keybinds) clone() !Keybinds {
	return k
}

pub struct BindingSet {}

pub fn (s BindingSet) get_event(event voidptr) ?BindingEntry {
	return none
}

pub struct BindingEntry {
pub:
	kind BindingEntryKind
}

pub enum BindingEntryKind {
	leader
	leaf
	leaf_chained
}

pub struct KeyRemapSet {}

pub fn (k KeyRemapSet) is_remapped(mods voidptr) bool {
	return false
}

pub fn (k KeyRemapSet) apply(mods voidptr) voidptr {
	return mods
}

pub fn (k KeyRemapSet) clone() !KeyRemapSet {
	return k
}

pub struct Duration {
pub:
	duration u64
}

pub struct NotifyOnCommandFinish {}

pub struct NotifyOnCommandFinishAction {}

// ============================================================
// Color types for theme preview
// ============================================================

// ColorRGB holds an 8-bit-per-channel color.
pub struct ColorRGB {
pub:
	r u8
	g u8
	b u8
}

// Palette holds the 256-color terminal palette.
pub struct Palette {
pub mut:
	value [256]ColorRGB
}

// default_palette returns a standard 256-color palette.
pub fn Palette.default_palette() Palette {
	mut p := Palette{}
	// Standard 16 colors (approximate)
	colors_16 := [
		ColorRGB{0x00, 0x00, 0x00}, ColorRGB{0xaa, 0x00, 0x00},
		ColorRGB{0x00, 0xaa, 0x00}, ColorRGB{0xaa, 0x55, 0x00},
		ColorRGB{0x00, 0x00, 0xaa}, ColorRGB{0xaa, 0x00, 0xaa},
		ColorRGB{0x00, 0xaa, 0xaa}, ColorRGB{0xaa, 0xaa, 0xaa},
		ColorRGB{0x55, 0x55, 0x55}, ColorRGB{0xff, 0x55, 0x55},
		ColorRGB{0x55, 0xff, 0x55}, ColorRGB{0xff, 0xff, 0x55},
		ColorRGB{0x55, 0x55, 0xff}, ColorRGB{0xff, 0x55, 0xff},
		ColorRGB{0x55, 0xff, 0xff}, ColorRGB{0xff, 0xff, 0xff},
	]
	for i, c in colors_16 {
		p.value[i] = c
	}
	// 216-color cube (indices 16..231)
	for i in 16 .. 232 {
		idx := i - 16
		r := u8((idx / 36) * 51)
		g := u8(((idx / 6) % 6) * 51)
		b := u8((idx % 6) * 51)
		p.value[i] = ColorRGB{r, g, b}
	}
	// Grayscale ramp (indices 232..255)
	for i in 232 .. 256 {
		v := u8(8 + (i - 232) * 10)
		p.value[i] = ColorRGB{v, v, v}
	}
	return p
}

// Diagnostic represents a configuration loading problem.
pub struct Diagnostic {
pub:
	message string
}

pub fn (d Diagnostic) str() string {
	return d.message
}

// load_file loads a theme configuration file and merges it into this config.
// XTODO: needs real config file parser to load theme key=value pairs.
pub fn (mut c Config) load_file(path string) {
	// Stub: in the real implementation this would parse the file
	// and apply theme colors to foreground, background, palette, etc.
}

// default_config creates a Config with default values.
pub fn Config.default_config() Config {
	return Config{}
}

// preferred_default_file_path returns the preferred default config file path.
pub fn preferred_default_file_path() string {
	// XTODO: implement XDG config path resolution
	return ''
}
