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
	term                           string = 'xterm-256color'
	shell_integration              ShellIntegration        = .detect
	shell_integration_features     u32
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

pub struct Command {
pub:
	args []string
}

pub fn (c Command) string_val() !string {
	return c.args.join(' ')
}

pub enum ShellIntegration {
	detect
	none_
	bash
	zsh
	fish
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
