module input

// A binding maps some input trigger to an action. When the trigger
// occurs, the action is performed.

// Binding represents a complete key binding: trigger + action + flags.
pub struct Binding {
pub:
	// The trigger that needs to be performed to execute the action.
	trigger Trigger
	// The action to take if this binding matches.
	action Action
	// Boolean flags that can be set per binding.
	flags Flags
}

pub fn (a Binding) == (b Binding) bool {
	return a.trigger.equal(b.trigger) && a.action.equal(b.action) && a.flags == b.flags
}

// BindingError represents binding parsing errors.
pub enum BindingError {
	invalid_format
	invalid_action
	unexpected_chain
	unexpected_sequence
}

// Flags are the full binding-scoped flags that can be set per binding.
pub struct Flags {
pub:
	// True if this binding should consume the input when the
	// action is triggered.
	consumed bool = true
	// True if this binding should be forwarded to all active surfaces
	// in the application.
	all bool
	// True if this binding is global. Global bindings should work system-wide
	// and not just while the terminal is focused.
	global bool
	// True if this binding should only be triggered if the action can be
	// performed. If the action can't be performed then the binding acts as
	// if it doesn't exist.
	performable bool
}

// cval converts flags to a packed u8 value.
pub fn (f Flags) cval() u8 {
	mut result := u8(0)
	if f.consumed {
		result |= 0b0001
	}
	if f.all {
		result |= 0b0010
	}
	if f.global {
		result |= 0b0100
	}
	if f.performable {
		result |= 0b1000
	}
	return result
}

// TriggerKey represents the key part of a trigger. It can be either a
// physical key or a unicode codepoint, or a catch-all.
pub struct TriggerKey {
pub:
	typ      TriggerKeyType
	physical Key  // used when typ == .physical
	unicode  u32  // used when typ == .unicode
}

pub enum TriggerKeyType {
	physical
	unicode
	catch_all
}

pub fn TriggerKey.new_physical(k Key) TriggerKey {
	return TriggerKey{
		typ: .physical
		physical: k
	}
}

pub fn TriggerKey.new_unicode(cp u32) TriggerKey {
	return TriggerKey{
		typ: .unicode
		unicode: cp
	}
}

pub fn TriggerKey.new_catch_all() TriggerKey {
	return TriggerKey{
		typ: .catch_all
	}
}

pub fn (a TriggerKey) == (b TriggerKey) bool {
	if a.typ != b.typ {
		return false
	}
	return match a.typ {
		.physical { a.physical == b.physical }
		.unicode { a.unicode == b.unicode }
		.catch_all { true }
	}
}

// Trigger is the associated key state that can trigger an action.
pub struct Trigger {
pub:
	// The key that has to be pressed for a binding to take action.
	key TriggerKey = TriggerKey.new_physical(.unidentified)
	// The key modifiers that must be active for this to match.
	mods Mods
}

pub fn (a Trigger) == (b Trigger) bool {
	return a.equal(b)
}

// Returns true if this trigger has no key set.
pub fn (t Trigger) is_key_unset() bool {
	return match t.key.typ {
		.physical { t.key.physical == .unidentified }
		.unicode, .catch_all { false }
	}
}

// Returns true if two triggers are equal.
pub fn (self Trigger) equal(other Trigger) bool {
	if self.mods != other.mods {
		return false
	}
	return self.key == other.key
}

// Returns true if two triggers are equal using folded codepoints
// (case-insensitive for unicode keys).
pub fn (self Trigger) folded_equal(other Trigger) bool {
	if self.mods != other.mods {
		return false
	}
	if self.key.typ != other.key.typ {
		return false
	}
	return match self.key.typ {
		.physical { self.key.physical == other.key.physical }
		.unicode {
			folded_codepoint(self.key.unicode) == folded_codepoint(other.key.unicode)
		}
		.catch_all { true }
	}
}

// folded_codepoint returns the case-folded version of a codepoint.
// For ASCII alphabetic characters, returns lowercase.
fn folded_codepoint(cp u32) u32 {
	if cp >= u32(`A`) && cp <= u32(`Z`) {
		return cp + 32
	}
	return cp
}

// hash returns a hash code for the trigger.
pub fn (t Trigger) hash() u64 {
	mut h := u64(0)
	h = h * 31 + u64(t.key.typ)
	match t.key.typ {
		.physical { h = h * 31 + u64(t.key.physical) }
		.unicode { h = h * 31 + u64(folded_codepoint(t.key.unicode)) }
		.catch_all {}
	}
	if t.mods.shift {
		h = h * 31 + 1
	}
	if t.mods.ctrl {
		h = h * 31 + 2
	}
	if t.mods.alt {
		h = h * 31 + 3
	}
	if t.mods.super_ {
		h = h * 31 + 4
	}
	return h
}

// format returns the trigger as a string (e.g. "ctrl+a", "shift+key_a").
pub fn (t Trigger) format() string {
	mut parts := []string{}
	if t.mods.super_ {
		parts << 'super'
	}
	if t.mods.ctrl {
		parts << 'ctrl'
	}
	if t.mods.alt {
		parts << 'alt'
	}
	if t.mods.shift {
		parts << 'shift'
	}
	match t.key.typ {
		.physical {
			parts << t.key.physical.key_name()
		}
		.unicode {
			if t.key.unicode < 128 {
				parts << [u8(t.key.unicode)].bytestr()
			} else {
				// encode as utf-8
				parts << rune(t.key.unicode).str()
			}
		}
		.catch_all {
			parts << 'catch_all'
		}
	}
	return parts.join('+')
}

// parse parses a single trigger string (e.g. "ctrl+a", "shift+key_a").
pub fn Trigger.parse(input_str string) !Trigger {
	if input_str.len == 0 {
		return error('InvalidFormat')
	}
	mut result := Trigger{}
	mut rem := input_str
	for rem.len > 0 {
		idx := rem.index_u8(`+`)
		part, next := if idx >= 0 {
			rem[..idx], rem[idx + 1..]
		} else {
			rem, ''
		}
		rem = next

		// Check if it's a modifier
		if part == 'shift' {
			if result.mods.shift {
				return error('InvalidFormat')
			}
			result = Trigger{
				...result
				mods: Mods{
					...result.mods
					shift: true
				}
			}
			continue
		}
		if part == 'ctrl' {
			if result.mods.ctrl {
				return error('InvalidFormat')
			}
			result = Trigger{
				...result
				mods: Mods{
					...result.mods
					ctrl: true
				}
			}
			continue
		}
		if part == 'alt' {
			if result.mods.alt {
				return error('InvalidFormat')
			}
			result = Trigger{
				...result
				mods: Mods{
					...result.mods
					alt: true
				}
			}
			continue
		}
		if part == 'super' {
			if result.mods.super_ {
				return error('InvalidFormat')
			}
			result = Trigger{
				...result
				mods: Mods{
					...result.mods
					super_: true
				}
			}
			continue
		}

		// Check modifier aliases
		if alias := mod_alias(part) {
			if alias == 'super_' {
				if result.mods.super_ {
					return error('InvalidFormat')
				}
				result = Trigger{
					...result
					mods: Mods{
						...result.mods
						super_: true
					}
				}
				continue
			}
			if alias == 'alt' {
				if result.mods.alt {
					return error('InvalidFormat')
				}
				result = Trigger{
					...result
					mods: Mods{
						...result.mods
						alt: true
					}
				}
				continue
			}
			if alias == 'ctrl' {
				if result.mods.ctrl {
					return error('InvalidFormat')
				}
				result = Trigger{
					...result
					mods: Mods{
						...result.mods
						ctrl: true
					}
				}
				continue
			}
		}

		// Anything after this point is a key and we only support single keys.
		if !result.is_key_unset() {
			return error('InvalidFormat')
		}

		// If the part is empty it means it is actually a literal `+`,
		// which we treat as a Unicode character.
		if part.len == 0 {
			result = Trigger{
				...result
				key: TriggerKey.new_unicode(u32(`+`))
			}
			continue
		}

		// Check if it's a known physical key name
		if k := key_from_name(part) {
			if k != .unidentified {
				result = Trigger{
					...result
					key: TriggerKey.new_physical(k)
				}
				continue
			}
		}

		// If we have exactly one unicode codepoint, use that as a key.
		if result.is_key_unset() {
			runes := part.runes()
			if runes.len == 1 {
				result = Trigger{
					...result
					key: TriggerKey.new_unicode(u32(runes[0]))
				}
				continue
			}
		}

		// Look for a matching W3C name
		if w3c_key := key_from_w3c(part) {
			result = Trigger{
				...result
				key: TriggerKey.new_physical(w3c_key)
			}
			continue
		}

		// Check for catch_all
		if part == 'catch_all' {
			result = Trigger{
				...result
				key: TriggerKey.new_catch_all()
			}
			continue
		}

		// Check backwards compatible keys
		if old_key := backwards_compatible_key(part) {
			result = Trigger{
				...result
				key: old_key
			}
			continue
		}

		// We didn't recognize this value
		return error('InvalidFormat')
	}

	return result
}

// --- Action ---

// ActionTag enumerates all the possible binding action types.
pub enum ActionTag {
	// Ignore this key combination.
	ignore
	// Unbind a previously bound key binding.
	unbind
	// Send a CSI sequence.
	csi
	// Send an ESC sequence.
	esc
	// Send the specified text.
	text
	// Send data to the pty depending on whether cursor key mode is enabled
	// (application) or disabled (normal).
	cursor_key
	// Reset the terminal.
	reset
	// Copy the selected text to the clipboard.
	copy_to_clipboard
	// Paste the contents of the default clipboard.
	paste_from_clipboard
	// Paste the contents of the selection clipboard.
	paste_from_selection
	// If there is a URL under the cursor, copy it to the default clipboard.
	copy_url_to_clipboard
	// Copy the terminal title to the clipboard.
	copy_title_to_clipboard
	// Increase the font size by the specified amount in points.
	increase_font_size
	// Decrease the font size by the specified amount in points.
	decrease_font_size
	// Reset the font size to the original configured size.
	reset_font_size
	// Set the font size to the specified size in points.
	set_font_size
	// Start a search for the given text.
	search
	// Start a search for the current text selection.
	search_selection
	// Navigate the search results.
	navigate_search
	// Start a search if it isn't started already.
	start_search
	// End the current search if any and hide any GUI elements.
	end_search
	// Clear the screen and all scrollback.
	clear_screen
	// Select all text on the screen.
	select_all
	// Scroll to the top of the screen.
	scroll_to_top
	// Scroll to the bottom of the screen.
	scroll_to_bottom
	// Scroll to the selected text.
	scroll_to_selection
	// Scroll to the given absolute row.
	scroll_to_row
	// Scroll the screen up by one page.
	scroll_page_up
	// Scroll the screen down by one page.
	scroll_page_down
	// Scroll the screen by the specified fraction of a page.
	scroll_page_fractional
	// Scroll the screen by the specified amount of lines.
	scroll_page_lines
	// Adjust the current selection.
	adjust_selection
	// Jump the viewport forward or back by the given number of prompts.
	jump_to_prompt
	// Write the entire scrollback into a temporary file with the specified action.
	write_scrollback_file
	// Write the contents of the screen into a temporary file.
	write_screen_file
	// Write the currently selected text into a temporary file.
	write_selection_file
	// Open a new window.
	new_window
	// Open a new tab.
	new_tab
	// Go to the previous tab.
	previous_tab
	// Go to the next tab.
	next_tab
	// Go to the last tab.
	last_tab
	// Go to the tab with the specific index.
	goto_tab
	// Moves a tab by a relative offset.
	move_tab
	// Toggle the tab overview.
	toggle_tab_overview
	// Change the title of the current focused surface via a pop-up prompt.
	prompt_surface_title
	// Change the title of the current tab/window via a pop-up prompt.
	prompt_tab_title
	// Create a new split in the specified direction.
	new_split
	// Focus on a split.
	goto_split
	// Focus on a window.
	goto_window
	// Zoom in or out of the current split.
	toggle_split_zoom
	// Toggle read-only mode for the current surface.
	toggle_readonly
	// Resize the current split.
	resize_split
	// Equalize the size of all splits.
	equalize_splits
	// Reset the window to the default size.
	reset_window_size
	// Control the visibility of the terminal inspector.
	inspector
	// Show the GTK inspector.
	show_gtk_inspector
	// Show the on-screen keyboard.
	show_on_screen_keyboard
	// Open the configuration file.
	open_config
	// Reload the configuration.
	reload_config
	// Close the current surface.
	close_surface
	// Close the current tab.
	close_tab
	// Close the current window.
	close_window
	// Close all windows.
	close_all_windows
	// Maximize or unmaximize the current window.
	toggle_maximize
	// Fullscreen or unfullscreen the current window.
	toggle_fullscreen
	// Toggle window decorations.
	toggle_window_decorations
	// Toggle whether the window should float on top.
	toggle_window_float_on_top
	// Toggle secure input mode.
	toggle_secure_input
	// Toggle mouse reporting.
	toggle_mouse_reporting
	// Toggle the command palette.
	toggle_command_palette
	// Toggle the quick terminal.
	toggle_quick_terminal
	// Show or hide all windows.
	toggle_visibility
	// Toggle background opacity.
	toggle_background_opacity
	// Check for updates.
	check_for_updates
	// Undo the last undoable action.
	undo
	// Redo the last undoable action.
	redo
	// End the currently active key sequence.
	end_key_sequence
	// Activate a named key table.
	activate_key_table
	// Same as activate_key_table, but only for one use.
	activate_key_table_once
	// Deactivate the currently active key table.
	deactivate_key_table
	// Deactivate all active key tables.
	deactivate_all_key_tables
	// Quit the application.
	quit
	// Crash the application for testing.
	crash
}

// Action holds a binding action along with its parameter value.
pub struct Action {
pub:
	tag ActionTag
	// String parameter for csi, esc, text, search, activate_key_table, activate_key_table_once.
	str_param string
	// Float parameter for increase_font_size, decrease_font_size, set_font_size, scroll_page_fractional.
	float_param f32
	// Int parameter for jump_to_prompt, scroll_page_lines.
	int_param i32
	// Unsigned int parameter for scroll_to_row, goto_tab, move_tab.
	uint_param u64
	// Enum parameters stored as ints.
	enum_param i32
	// Second parameter for tuple types (e.g. resize_split).
	enum_param2 i32
}

pub fn (a Action) == (b Action) bool {
	return a.equal(b)
}

// equal returns true if two actions are equal.
pub fn (a Action) equal(b Action) bool {
	if a.tag != b.tag {
		return false
	}
	return match a.tag {
		.csi, .esc, .text, .search, .activate_key_table, .activate_key_table_once {
			a.str_param == b.str_param
		}
		.increase_font_size, .decrease_font_size, .set_font_size, .scroll_page_fractional {
			a.float_param == b.float_param
		}
		.jump_to_prompt, .scroll_page_lines {
			a.int_param == b.int_param
		}
		.scroll_to_row, .goto_tab, .move_tab {
			a.uint_param == b.uint_param
		}
		.new_split, .goto_split, .goto_window, .navigate_search, .adjust_selection,
		.copy_to_clipboard, .inspector, .close_tab, .crash {
			a.enum_param == b.enum_param
		}
		.write_scrollback_file, .write_screen_file, .write_selection_file {
			a.enum_param == b.enum_param && a.enum_param2 == b.enum_param2
		}
		.resize_split {
			a.enum_param == b.enum_param && a.enum_param2 == b.enum_param2
		}
		else {
			// Void actions (ignore, unbind, reset, paste_from_clipboard, etc.) are equal if tags match.
			true
		}
	}
}

// hash returns a hash code for the action.
pub fn (a Action) hash() u64 {
	mut h := u64(0)
	h = h * 31 + u64(a.tag)
	match a.tag {
		.csi, .esc, .text, .search, .activate_key_table, .activate_key_table_once {
			for c in a.str_param {
				h = h * 31 + u64(c)
			}
		}
		.increase_font_size, .decrease_font_size, .set_font_size, .scroll_page_fractional {
			// Hash the float bits
			bits := unsafe { *(&u32(&a.float_param)) }
			h = h * 31 + u64(bits)
		}
		.jump_to_prompt, .scroll_page_lines {
			h = h * 31 + u64(u32(a.int_param))
		}
		.scroll_to_row, .goto_tab, .move_tab {
			h = h * 31 + a.uint_param
		}
		.new_split, .goto_split, .goto_window, .navigate_search, .adjust_selection,
		.copy_to_clipboard, .inspector, .close_tab, .crash {
			h = h * 31 + u64(u32(a.enum_param))
		}
		.write_scrollback_file, .write_screen_file, .write_selection_file, .resize_split {
			h = h * 31 + u64(u32(a.enum_param))
			h = h * 31 + u64(u32(a.enum_param2))
		}
		else {}
	}
	return h
}

// Convenience constructors for common actions.
pub fn Action.new(tag ActionTag) Action {
	return Action{
		tag: tag
	}
}

pub fn Action.new_str(tag ActionTag, s string) Action {
	return Action{
		tag: tag
		str_param: s
	}
}

pub fn Action.new_float(tag ActionTag, f f32) Action {
	return Action{
		tag: tag
		float_param: f
	}
}

pub fn Action.new_int(tag ActionTag, i i32) Action {
	return Action{
		tag: tag
		int_param: i
	}
}

pub fn Action.new_uint(tag ActionTag, u u64) Action {
	return Action{
		tag: tag
		uint_param: u
	}
}

pub fn Action.new_enum(tag ActionTag, e i32) Action {
	return Action{
		tag: tag
		enum_param: e
	}
}

pub fn Action.new_enum2(tag ActionTag, e1 i32, e2 i32) Action {
	return Action{
		tag: tag
		enum_param: e1
		enum_param2: e2
	}
}

// SplitDirection values for new_split.
pub enum SplitDirection {
	right
	down
	left
	up
	auto_
}

// SplitFocusDirection values for goto_split.
pub enum SplitFocusDirection {
	previous
	next
	up
	left
	down
	right
}

// parse_split_focus_direction parses with backwards compatibility for "top"/"bottom".
pub fn parse_split_focus_direction(s string) !SplitFocusDirection {
	return match s {
		'previous' { .previous }
		'next' { .next }
		'up' { .up }
		'left' { .left }
		'down' { .down }
		'right' { .right }
		'top' { .up }
		'bottom' { .down }
		else { error('InvalidFormat') }
	}
}

pub enum GotoWindow {
	previous
	next
}

pub enum NavigateSearch {
	previous
	next
}

pub enum AdjustSelection {
	left
	right
	up
	down
	page_up
	page_down
	home
	end_
	beginning_of_line
	end_of_line
}

pub enum SplitResizeDirection {
	up
	down
	left
	right
}

pub enum CopyToClipboard {
	plain
	vt
	html
	mixed
}

pub enum WriteScreenAction {
	copy
	paste
	open
}

pub enum WriteScreenFormat {
	plain
	vt
	html
}

pub struct WriteScreen {
pub:
	action WriteScreenAction
	emit   WriteScreenFormat
}

pub enum InspectorMode {
	toggle
	show
	hide
}

pub enum CloseTabMode {
	this
	other
	right
}

pub enum CrashThread {
	main_thread
	io
	render
}

// ActionScope indicates whether an action runs at app or surface level.
pub enum ActionScope {
	app
	surface
}

// scope returns the scope of an action.
pub fn (a Action) scope() ActionScope {
	return match a.tag {
		.ignore, .unbind { .app }
		.open_config, .reload_config, .close_all_windows, .quit,
		.toggle_quick_terminal, .toggle_visibility, .check_for_updates,
		.show_gtk_inspector { .app }
		.new_window, .undo, .redo { .app }
		else { .surface }
	}
}

// parse parses an action string like "ignore", "csi:A", "new_split:right".
pub fn Action.parse(input_str string) !Action {
	colon_idx := input_str.index_u8(`:`)
	action_name := if colon_idx >= 0 { input_str[..colon_idx] } else { input_str }

	if action_name.len == 0 {
		return error('InvalidFormat')
	}

	param := if colon_idx >= 0 { input_str[colon_idx + 1..] } else { '' }
	has_param := colon_idx >= 0

	// Match action name to tag. For void actions, no parameter is allowed.
	// For parameterized actions, parse the parameter.
	return match action_name {
		// Void actions (no parameter)
		'ignore' {
			if has_param { return error('InvalidFormat') }
			Action.new(.ignore)
		}
		'unbind' {
			if has_param { return error('InvalidFormat') }
			Action.new(.unbind)
		}
		'reset' {
			if has_param { return error('InvalidFormat') }
			Action.new(.reset)
		}
		'paste_from_clipboard' {
			if has_param { return error('InvalidFormat') }
			Action.new(.paste_from_clipboard)
		}
		'paste_from_selection' {
			if has_param { return error('InvalidFormat') }
			Action.new(.paste_from_selection)
		}
		'copy_url_to_clipboard' {
			if has_param { return error('InvalidFormat') }
			Action.new(.copy_url_to_clipboard)
		}
		'copy_title_to_clipboard' {
			if has_param { return error('InvalidFormat') }
			Action.new(.copy_title_to_clipboard)
		}
		'reset_font_size' {
			if has_param { return error('InvalidFormat') }
			Action.new(.reset_font_size)
		}
		'search_selection' {
			if has_param { return error('InvalidFormat') }
			Action.new(.search_selection)
		}
		'start_search' {
			if has_param { return error('InvalidFormat') }
			Action.new(.start_search)
		}
		'end_search' {
			if has_param { return error('InvalidFormat') }
			Action.new(.end_search)
		}
		'clear_screen' {
			if has_param { return error('InvalidFormat') }
			Action.new(.clear_screen)
		}
		'select_all' {
			if has_param { return error('InvalidFormat') }
			Action.new(.select_all)
		}
		'scroll_to_top' {
			if has_param { return error('InvalidFormat') }
			Action.new(.scroll_to_top)
		}
		'scroll_to_bottom' {
			if has_param { return error('InvalidFormat') }
			Action.new(.scroll_to_bottom)
		}
		'scroll_to_selection' {
			if has_param { return error('InvalidFormat') }
			Action.new(.scroll_to_selection)
		}
		'scroll_page_up' {
			if has_param { return error('InvalidFormat') }
			Action.new(.scroll_page_up)
		}
		'scroll_page_down' {
			if has_param { return error('InvalidFormat') }
			Action.new(.scroll_page_down)
		}
		'new_window' {
			if has_param { return error('InvalidFormat') }
			Action.new(.new_window)
		}
		'new_tab' {
			if has_param { return error('InvalidFormat') }
			Action.new(.new_tab)
		}
		'previous_tab' {
			if has_param { return error('InvalidFormat') }
			Action.new(.previous_tab)
		}
		'next_tab' {
			if has_param { return error('InvalidFormat') }
			Action.new(.next_tab)
		}
		'last_tab' {
			if has_param { return error('InvalidFormat') }
			Action.new(.last_tab)
		}
		'toggle_tab_overview' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_tab_overview)
		}
		'prompt_surface_title' {
			if has_param { return error('InvalidFormat') }
			Action.new(.prompt_surface_title)
		}
		'prompt_tab_title' {
			if has_param { return error('InvalidFormat') }
			Action.new(.prompt_tab_title)
		}
		'toggle_split_zoom' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_split_zoom)
		}
		'toggle_readonly' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_readonly)
		}
		'equalize_splits' {
			if has_param { return error('InvalidFormat') }
			Action.new(.equalize_splits)
		}
		'reset_window_size' {
			if has_param { return error('InvalidFormat') }
			Action.new(.reset_window_size)
		}
		'show_gtk_inspector' {
			if has_param { return error('InvalidFormat') }
			Action.new(.show_gtk_inspector)
		}
		'show_on_screen_keyboard' {
			if has_param { return error('InvalidFormat') }
			Action.new(.show_on_screen_keyboard)
		}
		'open_config' {
			if has_param { return error('InvalidFormat') }
			Action.new(.open_config)
		}
		'reload_config' {
			if has_param { return error('InvalidFormat') }
			Action.new(.reload_config)
		}
		'close_surface' {
			if has_param { return error('InvalidFormat') }
			Action.new(.close_surface)
		}
		'close_window' {
			if has_param { return error('InvalidFormat') }
			Action.new(.close_window)
		}
		'close_all_windows' {
			if has_param { return error('InvalidFormat') }
			Action.new(.close_all_windows)
		}
		'toggle_maximize' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_maximize)
		}
		'toggle_fullscreen' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_fullscreen)
		}
		'toggle_window_decorations' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_window_decorations)
		}
		'toggle_window_float_on_top' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_window_float_on_top)
		}
		'toggle_secure_input' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_secure_input)
		}
		'toggle_mouse_reporting' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_mouse_reporting)
		}
		'toggle_command_palette' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_command_palette)
		}
		'toggle_quick_terminal' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_quick_terminal)
		}
		'toggle_visibility' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_visibility)
		}
		'toggle_background_opacity' {
			if has_param { return error('InvalidFormat') }
			Action.new(.toggle_background_opacity)
		}
		'check_for_updates' {
			if has_param { return error('InvalidFormat') }
			Action.new(.check_for_updates)
		}
		'undo' {
			if has_param { return error('InvalidFormat') }
			Action.new(.undo)
		}
		'redo' {
			if has_param { return error('InvalidFormat') }
			Action.new(.redo)
		}
		'end_key_sequence' {
			if has_param { return error('InvalidFormat') }
			Action.new(.end_key_sequence)
		}
		'deactivate_key_table' {
			if has_param { return error('InvalidFormat') }
			Action.new(.deactivate_key_table)
		}
		'deactivate_all_key_tables' {
			if has_param { return error('InvalidFormat') }
			Action.new(.deactivate_all_key_tables)
		}
		'quit' {
			if has_param { return error('InvalidFormat') }
			Action.new(.quit)
		}
		// String actions
		'csi' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.csi, param)
		}
		'esc' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.esc, param)
		}
		'text' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.text, param)
		}
		'search' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.search, param)
		}
		'activate_key_table' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.activate_key_table, param)
		}
		'activate_key_table_once' {
			if !has_param { return error('InvalidFormat') }
			Action.new_str(.activate_key_table_once, param)
		}
		// Float actions
		'increase_font_size' {
			if !has_param { return error('InvalidFormat') }
			Action.new_float(.increase_font_size, strconv_parse_float(param)!)
		}
		'decrease_font_size' {
			if !has_param { return error('InvalidFormat') }
			Action.new_float(.decrease_font_size, strconv_parse_float(param)!)
		}
		'set_font_size' {
			if !has_param { return error('InvalidFormat') }
			Action.new_float(.set_font_size, strconv_parse_float(param)!)
		}
		'scroll_page_fractional' {
			if !has_param { return error('InvalidFormat') }
			Action.new_float(.scroll_page_fractional, strconv_parse_float(param)!)
		}
		// Int actions
		'jump_to_prompt' {
			if !has_param { return error('InvalidFormat') }
			Action.new_int(.jump_to_prompt, strconv_parse_int(param)!)
		}
		'scroll_page_lines' {
			if !has_param { return error('InvalidFormat') }
			Action.new_int(.scroll_page_lines, strconv_parse_int(param)!)
		}
		// Unsigned int actions
		'scroll_to_row' {
			if !has_param { return error('InvalidFormat') }
			Action.new_uint(.scroll_to_row, strconv_parse_uint(param)!)
		}
		'goto_tab' {
			if !has_param { return error('InvalidFormat') }
			Action.new_uint(.goto_tab, strconv_parse_uint(param)!)
		}
		'move_tab' {
			if !has_param { return error('InvalidFormat') }
			Action.new_uint(.move_tab, strconv_parse_uint(param)!)
		}
		// Enum actions with defaults
		'copy_to_clipboard' {
			if !has_param {
				Action.new_enum(.copy_to_clipboard, i32(CopyToClipboard.mixed))
			} else {
				Action.new_enum(.copy_to_clipboard, i32(parse_copy_to_clipboard(param)!))
			}
		}
		'new_split' {
			if !has_param {
				Action.new_enum(.new_split, i32(SplitDirection.auto_))
			} else {
				Action.new_enum(.new_split, i32(parse_split_direction(param)!))
			}
		}
		'close_tab' {
			if !has_param {
				Action.new_enum(.close_tab, i32(CloseTabMode.this))
			} else {
				Action.new_enum(.close_tab, i32(parse_close_tab_mode(param)!))
			}
		}
		// Enum actions (required parameter)
		'navigate_search' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.navigate_search, i32(parse_navigate_search(param)!))
		}
		'adjust_selection' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.adjust_selection, i32(parse_adjust_selection(param)!))
		}
		'goto_split' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.goto_split, i32(parse_split_focus_direction(param)!))
		}
		'goto_window' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.goto_window, i32(parse_goto_window(param)!))
		}
		'inspector' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.inspector, i32(parse_inspector_mode(param)!))
		}
		'crash' {
			if !has_param { return error('InvalidFormat') }
			Action.new_enum(.crash, i32(parse_crash_thread(param)!))
		}
		// Tuple actions (resize_split: direction,amount)
		'resize_split' {
			if !has_param { return error('InvalidFormat') }
			parse_resize_split(param)!
		}
		// WriteScreen actions
		'write_scrollback_file' {
			if !has_param { return error('InvalidFormat') }
			parse_write_screen(.write_scrollback_file, param)!
		}
		'write_screen_file' {
			if !has_param { return error('InvalidFormat') }
			parse_write_screen(.write_screen_file, param)!
		}
		'write_selection_file' {
			if !has_param { return error('InvalidFormat') }
			parse_write_screen(.write_selection_file, param)!
		}
		// cursor_key can't be set currently
		'cursor_key' {
			return error('InvalidAction')
		}
		else {
			return error('InvalidAction')
		}
	}
}

// --- Enum parsers ---

fn parse_split_direction(s string) !SplitDirection {
	return match s {
		'right' { .right }
		'down' { .down }
		'left' { .left }
		'up' { .up }
		'auto' { .auto_ }
		else { error('InvalidFormat') }
	}
}

fn parse_copy_to_clipboard(s string) !CopyToClipboard {
	return match s {
		'plain' { .plain }
		'vt' { .vt }
		'html' { .html }
		'mixed' { .mixed }
		else { error('InvalidFormat') }
	}
}

fn parse_navigate_search(s string) !NavigateSearch {
	return match s {
		'previous' { .previous }
		'next' { .next }
		else { error('InvalidFormat') }
	}
}

fn parse_adjust_selection(s string) !AdjustSelection {
	return match s {
		'left' { .left }
		'right' { .right }
		'up' { .up }
		'down' { .down }
		'page_up' { .page_up }
		'page_down' { .page_down }
		'home' { .home }
		'end' { .end_ }
		'beginning_of_line' { .beginning_of_line }
		'end_of_line' { .end_of_line }
		else { error('InvalidFormat') }
	}
}

fn parse_goto_window(s string) !GotoWindow {
	return match s {
		'previous' { .previous }
		'next' { .next }
		else { error('InvalidFormat') }
	}
}

fn parse_inspector_mode(s string) !InspectorMode {
	return match s {
		'toggle' { .toggle }
		'show' { .show }
		'hide' { .hide }
		else { error('InvalidFormat') }
	}
}

fn parse_close_tab_mode(s string) !CloseTabMode {
	return match s {
		'this' { .this }
		'other' { .other }
		'right' { .right }
		else { error('InvalidFormat') }
	}
}

fn parse_crash_thread(s string) !CrashThread {
	return match s {
		'main' { .main_thread }
		'io' { .io }
		'render' { .render }
		else { error('InvalidFormat') }
	}
}

fn parse_resize_split(s string) !Action {
	comma_idx := s.index_u8(`,`)
	if comma_idx < 0 {
		return error('InvalidFormat')
	}
	dir_str := s[..comma_idx]
	amount_str := s[comma_idx + 1..]
	if amount_str.len == 0 {
		return error('InvalidFormat')
	}
	// Check for extra commas
	if amount_str.index_u8(`,`) >= 0 {
		return error('InvalidFormat')
	}
	dir := match dir_str {
		'up' { SplitResizeDirection.up }
		'down' { SplitResizeDirection.down }
		'left' { SplitResizeDirection.left }
		'right' { SplitResizeDirection.right }
		else { return error('InvalidFormat') }
	}
	amount := amount_str.u16()
	if amount == 0 && amount_str != '0' {
		return error('InvalidFormat')
	}
	return Action.new_enum2(.resize_split, i32(dir), i32(amount))
}

fn parse_write_screen(tag ActionTag, s string) !Action {
	if s.len == 0 {
		return error('InvalidFormat')
	}
	comma_idx := s.index_u8(`,`)
	if comma_idx < 0 {
		// No comma: just action, default to plain format
		action_e := match s {
			'copy' { WriteScreenAction.copy }
			'paste' { WriteScreenAction.paste }
			'open' { WriteScreenAction.open }
			else { return error('InvalidFormat') }
		}
		return Action.new_enum2(tag, i32(action_e), i32(WriteScreenFormat.plain))
	}
	action_str := s[..comma_idx]
	format_str := s[comma_idx + 1..]
	if action_str.len == 0 || format_str.len == 0 {
		return error('InvalidFormat')
	}
	// Check for extra commas
	if format_str.index_u8(`,`) >= 0 {
		return error('InvalidFormat')
	}
	action_e := match action_str {
		'copy' { WriteScreenAction.copy }
		'paste' { WriteScreenAction.paste }
		'open' { WriteScreenAction.open }
		else { return error('InvalidFormat') }
	}
	format_e := match format_str {
		'plain' { WriteScreenFormat.plain }
		'vt' { WriteScreenFormat.vt }
		'html' { WriteScreenFormat.html }
		else { return error('InvalidFormat') }
	}
	return Action.new_enum2(tag, i32(action_e), i32(format_e))
}

// --- String/number parsers ---

fn strconv_parse_float(s string) !f32 {
	return f32(s.f64())
}

fn strconv_parse_int(s string) !i32 {
	v := s.int()
	// int() returns 0 on failure, disambiguate
	if v == 0 && s != '0' && s != '+0' && s != '-0' {
		return error('InvalidFormat')
	}
	return i32(v)
}

fn strconv_parse_uint(s string) !u64 {
	v := s.u64()
	if v == 0 && s != '0' {
		return error('InvalidFormat')
	}
	return v
}

// --- Parser ---

// ParserElem is a single element yielded by the binding parser.
// It can be a leader trigger (in a sequence), a final binding, or a chained action.
pub struct ParserElem {
pub:
	typ     ParserElemType
	trigger Trigger  // used for .leader and .binding
	binding Binding  // used for .binding
	action  Action   // used for .chain
}

pub enum ParserElemType {
	leader
	binding
	chain
}

// Parser is the full binding parser. It yields elements to support
// multi-key sequences without allocation.
pub struct Parser {
pub mut:
	trigger_it SequenceIterator
	action     Action
	flags      Flags
	chain      bool
}

// SequenceIterator yields each trigger in a sequence of triggers.
// For example, "ctrl+a>ctrl+b" yields "ctrl+a" and then "ctrl+b".
pub struct SequenceIterator {
pub mut:
	input string
	i     int
}

// next returns the next trigger in the sequence.
// Returns none when done, or error on parse failure.
pub fn (mut self SequenceIterator) next() !Trigger {
	if self.done() {
		return error('done')
	}
	rem := self.input[self.i..]
	idx := rem.index_u8(`>`)
	part_end := if idx >= 0 { idx } else { rem.len }
	part := rem[..part_end]
	self.i += part_end + 1
	return Trigger.parse(part)!
}

// done returns true if there are no more triggers to parse.
pub fn (self &SequenceIterator) done() bool {
	return self.i > self.input.len
}

// Parser.init creates a new parser from a raw binding string like "ctrl+a=ignore".
pub fn Parser.init(raw_input string) !Parser {
	flags, start_idx := parse_flags(raw_input)!
	inp := raw_input[start_idx..]

	// Find the equal sign. Need to ignore equal signs that are part of the trigger.
	mut eql_idx := -1
	mut offset := 0
	for {
		rest := inp[offset..]
		oi := rest.index_u8(`=`)
		if oi < 0 {
			break
		}
		idx := offset + oi
		// Check for '=+' or '==' patterns (trigger contains =)
		if idx < inp.len - 1 && (inp[idx + 1] == `+` || inp[idx + 1] == `=`) {
			offset = idx + 1
			continue
		}
		// This looks like the real equal sign
		eql_idx = idx
		break
	}

	if eql_idx < 0 {
		return error('InvalidFormat')
	}

	// Detect chains. Chains must not have flags.
	is_chain := inp[..eql_idx] == 'chain'
	if is_chain && start_idx > 0 {
		return error('InvalidFormat')
	}

	trigger_input := if is_chain { 'a' } else { inp[..eql_idx] }
	action := Action.parse(inp[eql_idx + 1..])!

	return Parser{
		trigger_it: SequenceIterator{
			input: trigger_input
		}
		action: action
		flags: flags
		chain: is_chain
	}
}

// parse_flags extracts prefix flags like "unconsumed:", "global:", "all:", "performable:".
fn parse_flags(raw_input string) !(Flags, int) {
	mut flags := Flags{}
	mut start_idx := 0
	mut inp := raw_input

	for {
		idx := inp.index_u8(`:`)
		if idx < 0 {
			break
		}
		prefix := inp[..idx]

		if prefix == 'all' {
			if flags.all {
				return error('InvalidFormat')
			}
			flags = Flags{
				...flags
				all: true
			}
		} else if prefix == 'global' {
			if flags.global {
				return error('InvalidFormat')
			}
			flags = Flags{
				...flags
				global: true
			}
		} else if prefix == 'unconsumed' {
			if !flags.consumed {
				return error('InvalidFormat')
			}
			flags = Flags{
				...flags
				consumed: false
			}
		} else if prefix == 'performable' {
			if flags.performable {
				return error('InvalidFormat')
			}
			flags = Flags{
				...flags
				performable: true
			}
		} else {
			// Unknown prefix - let trigger-specific parsing handle it
			break
		}

		start_idx += idx + 1
		inp = inp[idx + 1..]
	}

	return flags, start_idx
}

// next yields the next parser element.
// Returns error('done') when no more elements.
pub fn (mut self Parser) next() !ParserElem {
	trigger := self.trigger_it.next() or {
		if err.msg() == 'done' {
			return error('done')
		}
		return err
	}

	if !self.trigger_it.done() {
		// Global/all bindings can't be sequences
		if self.flags.global || self.flags.all {
			return error('InvalidFormat')
		}
		return ParserElem{
			typ: .leader
			trigger: trigger
		}
	}

	// If we're a chain then return it as-is.
	if self.chain {
		return ParserElem{
			typ: .chain
			action: self.action
		}
	}

	// Out of triggers, yield the final action.
	return ParserElem{
		typ: .binding
		trigger: trigger
		binding: Binding{
			trigger: trigger
			action: self.action
			flags: self.flags
		}
	}
}

// reset resets the parser to the beginning.
pub fn (mut self Parser) reset() {
	self.trigger_it.i = 0
}

// parse_single parses a single, non-sequenced binding string.
// Convenience function primarily for tests.
pub fn parse_single(raw_input string) !Binding {
	mut p := Parser.init(raw_input)!
	elem := p.next() or {
		if err.msg() == 'done' {
			return error('InvalidFormat')
		}
		return err
	}
	return match elem.typ {
		.leader { error('UnexpectedSequence') }
		.binding { elem.binding }
		.chain { error('UnexpectedChain') }
	}
}

// less_than returns true if lhs should be sorted before rhs.
pub fn less_than(lhs Binding, rhs Binding) bool {
	lhs_count := mod_count(lhs.trigger.mods)
	rhs_count := mod_count(rhs.trigger.mods)

	if lhs_count != rhs_count {
		return lhs_count > rhs_count
	}

	lhs_int := mods_int(lhs.trigger.mods)
	rhs_int := mods_int(rhs.trigger.mods)
	if lhs_int != rhs_int {
		return lhs_int > rhs_int
	}

	lhs_key := trigger_key_int(lhs.trigger.key)
	rhs_key := trigger_key_int(rhs.trigger.key)
	return lhs_key < rhs_key
}

fn mod_count(m Mods) int {
	mut count := 0
	if m.super_ {
		count++
	}
	if m.ctrl {
		count++
	}
	if m.shift {
		count++
	}
	if m.alt {
		count++
	}
	return count
}

fn mods_int(m Mods) int {
	mut v := 0
	if m.shift {
		v |= 1
	}
	if m.ctrl {
		v |= 2
	}
	if m.alt {
		v |= 4
	}
	if m.super_ {
		v |= 8
	}
	return v
}

fn trigger_key_int(k TriggerKey) int {
	return match k.typ {
		.physical { int(k.physical) }
		.unicode { int(k.unicode) }
		.catch_all { -1 }
	}
}

// --- Set ---

// SetValue is the entry type for the forward mapping of trigger to action.
pub struct SetValue {
pub mut:
	typ          SetValueType
	leader       &Set = unsafe { nil }  // used when typ == .leader
	leaf_action  Action                 // used when typ == .leaf
	leaf_flags   Flags                  // used when typ == .leaf
	chain_actions []Action              // used when typ == .leaf_chained
	chain_flags  Flags                  // used when typ == .leaf_chained
}

pub enum SetValueType {
	leader
	leaf
	leaf_chained
}

// Set is a structure that contains a set of bindings and focuses on fast lookup.
pub struct Set {
pub mut:
	// Forward mapping: trigger -> value
	bindings []SetEntry
	// Reverse mapping: action -> trigger (most recent)
	reverse []ReverseEntry
}

pub struct SetEntry {
pub mut:
	trigger Trigger
	value   SetValue
}

pub struct ReverseEntry {
pub mut:
	action  Action
	trigger Trigger
}

// get returns a binding entry for a given trigger.
pub fn (s &Set) get(t Trigger) ?&SetEntry {
	for i in 0 .. s.bindings.len {
		if s.bindings[i].trigger.folded_equal(t) {
			return unsafe { &s.bindings[i] }
		}
	}
	return none
}

// get_trigger returns the trigger for a given action from the reverse map.
pub fn (s &Set) get_trigger(a Action) ?Trigger {
	for entry in s.reverse {
		if entry.action.equal(a) {
			return entry.trigger
		}
	}
	return none
}

// put adds a binding to the set. If the binding already exists then it is overwritten.
pub fn (mut s Set) put(t Trigger, action Action) {
	s.put_flags(t, action, Flags{})
}

// put_flags adds a binding to the set with explicit flags.
pub fn (mut s Set) put_flags(t Trigger, action Action, flags Flags) {
	track_reverse := !flags.performable

	// Check for existing entry
	for i in 0 .. s.bindings.len {
		if s.bindings[i].trigger.folded_equal(t) {
			old := s.bindings[i].value
			// Clean up old reverse mapping
			if old.typ == .leaf && track_reverse {
				t_hash := t.hash()
				for ri in 0 .. s.reverse.len {
					if s.reverse[ri].trigger.hash() == t_hash {
						s.reverse.delete(ri)
						break
					}
				}
			}
			s.bindings[i].value = SetValue{
				typ: .leaf
				leaf_action: action
				leaf_flags: flags
			}
			if track_reverse {
				s.set_reverse(action, t)
			}
			return
		}
	}

	// New entry
	s.bindings << SetEntry{
		trigger: t
		value: SetValue{
			typ: .leaf
			leaf_action: action
			leaf_flags: flags
		}
	}
	if track_reverse {
		s.set_reverse(action, t)
	}
}

fn (mut s Set) set_reverse(action Action, t Trigger) {
	for i in 0 .. s.reverse.len {
		if s.reverse[i].action.equal(action) {
			s.reverse[i].trigger = t
			return
		}
	}
	s.reverse << ReverseEntry{
		action: action
		trigger: t
	}
}

// remove removes a binding for a given trigger.
pub fn (mut s Set) remove(t Trigger) {
	for i in 0 .. s.bindings.len {
		if s.bindings[i].trigger.folded_equal(t) {
			entry := s.bindings[i].value
			s.bindings.delete(i)
			if entry.typ == .leaf {
				s.fixup_reverse_for_action(entry.leaf_action, t)
			}
			return
		}
	}
}

// fixup_reverse_for_action updates the reverse map after removing an action.
fn (mut s Set) fixup_reverse_for_action(action Action, old Trigger) {
	mut found_idx := -1
	for ri in 0 .. s.reverse.len {
		if s.reverse[ri].action.equal(action) {
			found_idx = ri
			break
		}
	}
	if found_idx < 0 {
		return
	}

	// If our value is not the same as the old trigger, ignore it
	if !s.reverse[found_idx].trigger.equal(old) {
		return
	}

	// Try to find another trigger that maps to the same action
	action_hash := action.hash()
	for entry in s.bindings {
		if entry.value.typ == .leaf && entry.value.leaf_action.hash() == action_hash {
			s.reverse[found_idx].trigger = entry.trigger
			return
		}
	}

	// No other trigger, remove the reverse mapping
	s.reverse.delete(found_idx)
}

// parse_and_put parses a user input binding and adds it to the set.
pub fn (mut s Set) parse_and_put(input_str string) ! {
	// Validate the full sequence first
	mut it := Parser.init(input_str)!
	for {
		_ = it.next() or {
			if err.msg() == 'done' {
				break
			}
			return err
		}
	}
	it.reset()

	// Now actually process
	s.parse_and_put_recurse(mut it) or {
		if err.msg() == 'SequenceUnbind' {
			return
		}
		return err
	}
}

fn (mut s Set) parse_and_put_recurse(mut it Parser) ! {
	elem := it.next() or {
		if err.msg() == 'done' {
			return error('UnexpectedEndOfInput')
		}
		return err
	}

	match elem.typ {
		.leader {
			t := elem.trigger
			// Check for existing leader
			for i in 0 .. s.bindings.len {
				if s.bindings[i].trigger.folded_equal(t) {
					if s.bindings[i].value.typ == .leader {
						mut inner := s.bindings[i].value.leader
						inner.parse_and_put_recurse(mut it) or {
							if err.msg() == 'SequenceUnbind' {
								if inner.bindings.len == 0 {
									s.bindings.delete(i)
									return error('SequenceUnbind')
								}
								return
							}
							return err
						}
						return
					}
					// Remove existing non-leader entry
					s.bindings.delete(i)
					break
				}
			}

			// Create new inner set
			mut next_set := &Set{}
			s.bindings << SetEntry{
				trigger: t
				value: SetValue{
					typ: .leader
					leader: next_set
				}
			}
			next_set.parse_and_put_recurse(mut it) or {
				if err.msg() == 'SequenceUnbind' {
					// Remove the leader we just added
					for i in 0 .. s.bindings.len {
						if s.bindings[i].trigger.folded_equal(t) {
							s.bindings.delete(i)
							break
						}
					}
					return
				}
				return err
			}
		}
		.binding {
			b := elem.binding
			if b.action.tag == .unbind {
				s.remove(b.trigger)
				return error('SequenceUnbind')
			}
			s.put_flags(b.trigger, b.action, b.flags)
		}
		.chain {
			action := elem.action
			if action.tag == .unbind {
				return error('InvalidFormat')
			}
			return error('InvalidFormat')
		}
	}
}

// get_event returns an entry for the given key event.
// It attempts to find a binding using multiple parts of the event:
//   1. Physical key (event.key)
//   2. UTF-8 text as unicode codepoint
//   3. Unshifted codepoint
//   4. catch_all with mods, then without mods
pub fn (s &Set) get_event(event KeyEvent) ?&SetEntry {
	mut trigger := Trigger{
		mods: event.mods.binding()
		key: TriggerKey.new_physical(event.key)
	}
	if v := s.get(trigger) {
		return v
	}

	// If our UTF-8 text is exactly one codepoint, try to match that.
	if event.utf8.len > 0 {
		runes := event.utf8.runes()
		if runes.len == 1 {
			trigger = Trigger{
				...trigger
				key: TriggerKey.new_unicode(u32(runes[0]))
			}
			if v := s.get(trigger) {
				return v
			}
		}
	}

	// Fallback to the unshifted codepoint
	if event.unshifted_codepoint > 0 {
		trigger = Trigger{
			...trigger
			key: TriggerKey.new_unicode(event.unshifted_codepoint)
		}
		if v := s.get(trigger) {
			return v
		}
	}

	// Fallback to catch_all with modifiers, then without
	trigger = Trigger{
		...trigger
		key: TriggerKey.new_catch_all()
	}
	if v := s.get(trigger) {
		return v
	}
	if !trigger.mods.empty() {
		trigger = Trigger{
			key: TriggerKey.new_catch_all()
		}
		if v := s.get(trigger) {
			return v
		}
	}

	return none
}
