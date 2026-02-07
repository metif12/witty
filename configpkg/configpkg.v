module configpkg

// Config represents the full ghostty configuration.
pub struct Config {
pub mut:
	font_size                    f32    = 13.0
	abnormal_command_exit_runtime u32   = 250
	clipboard_read               ClipboardAccess = .allow
	clipboard_write              ClipboardAccess = .allow
	clipboard_trim_trailing_spaces bool
	clipboard_paste_protection   bool = true
	clipboard_paste_bracketed_safe bool = true
	copy_on_select               CopyOnSelect    = .false_
	confirm_close_surface        ConfirmCloseSurface = .true_
	cursor_click_to_move         bool
	desktop_notifications        bool = true
	mouse_hide_while_typing      bool = true
	mouse_reporting              bool = true
	mouse_shift_capture          MouseShiftCapture = .false_
	selection_clear_on_copy      bool = true
	selection_clear_on_typing    bool = true
	vt_kam_allowed               bool
	wait_after_command           bool
	window_padding_top           u32
	window_padding_bottom        u32
	window_padding_left          u32
	window_padding_right         u32
	window_padding_balance       bool
	window_height                u32
	window_width                 u32
	title                        ?string
	title_report                 bool = true
	command                      ?Command
	initial_command              ?Command
	working_directory            ?string
	term                         string = 'xterm-256color'
	shell_integration            ShellIntegration = .detect
	shell_integration_features   u32
	link_previews                LinkPreviews = .false_
	scroll_to_bottom             ScrollToBottom
}

pub fn (c Config) change_conditional_state(state ConditionalState) !Config {
	mut copy := c
	return copy
}

pub fn (mut c Config) deinit() {
	// stub
}

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
