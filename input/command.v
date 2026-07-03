module input

// --- Original Ghostty Comments Start: src/input/command.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/input/command.zig
//
// A command is a named binding action that can be executed from
// something like a command palette.
//
// A command must be associated with a binding; all commands can be
// mapped to traditional `keybind` configurations. This restriction
// makes it so that there is nothing special about commands and likewise
// it makes it trivial and consistent to define custom commands.
//
// For apprt implementers: a command palette doesn't have to make use
// of all the fields here. We try to provide as much information as
// possible to make it easier to implement a command palette in the way
// that makes the most sense for the application.
// ghostty_command_s
// Convert this command to a C struct at comptime.
// Convert this command to a C struct at runtime.
//
// This shares memory with the original command.
//
// The action string is allocated using the provided allocator. You can
// free the slice directly if you need to but we recommend an arena
// for this.
// Implements a comparison function for std.mem.sortUnstable
// and similar functions. The sorting is defined by Ghostty
// to be what we prefer. If a caller wants some other sorting,
// they should do it themselves.
// Defaults in C-compatible form.
// Returns the set of commands associated with this action key by
// default. Not all actions should have commands. As a general guideline,
// an action should have a command only if it is useful and reasonable
// to appear in a command palette.
// This is implemented as a function and switch rather than a
// flat comptime const because we want to ensure we get a compiler
// error when a new binding is added so that the contributor has
// to consider whether that new binding should have commands or not.
// Note: the use of `comptime` prefix on the return values
// ensures that the data returned is all in the binary and
// and not pointing to the stack.
// No commands because they're parameterized and there
// aren't obvious values users would use. It is possible that
// these may have commands in the future if there are very
// common values that users tend to use.
// No commands because I'm not sure they make sense in a command
// palette context.
// No commands for obvious reasons
// All generated commands should have the same action as the
// action passed in.
// This just ensures that defaults is analyzed and works.
//
// --- Original Ghostty Comments End: src/input/command.zig


// Command is a named binding action that can be executed from
// something like a command palette.
//
// A command must be associated with a binding; all commands can be
// mapped to traditional keybind configurations. This restriction
// makes it so that there is nothing special about commands and likewise
// it makes it trivial and consistent to define custom commands.
pub struct Command {
pub:
	// The action to perform when this command is triggered.
	action Action
	// The human-readable title of the command.
	title string
	// A longer description of what the command does.
	description string
}

// clone creates a deep copy of a Command.
pub fn (c Command) clone() Command {
	return Command{
		action: c.action
		title: c.title
		description: c.description
	}
}

// equal returns true if two commands are equal.
pub fn (a Command) equal(b Command) bool {
	return a.action.equal(b.action) && a.title == b.title && a.description == b.description
}

// less_than implements comparison for sorting commands alphabetically by title.
pub fn (a Command) less_than(b Command) bool {
	return a.title.to_lower() < b.title.to_lower()
}

// command_defaults is the set of default commands, built by iterating over
// every action and collecting the commands it contributes, then sorting them
// alphabetically by title (case-insensitive). This mirrors the Zig `defaults`
// comptime constant which does the same via `actionCommands` per Action.Key.
pub const command_defaults = build_command_defaults()

// build_command_defaults assembles and sorts the default command list.
// Faithful to Zig `defaults`.
fn build_command_defaults() []Command {
	mut result := []Command{}
	// Iterate every action tag and append its default commands. Faithful to
	// the Zig loop over `@typeInfo(Action.Key).@"enum".fields`.
	for tag in all_action_tags {
		result << action_commands(tag)
	}

	// Sort alphabetically by title, case-insensitive (Command.less_than).
	result.sort_with_compare(fn (a &Command, b &Command) int {
		la := a.title.to_lower()
		lb := b.title.to_lower()
		if la < lb {
			return -1
		}
		if la > lb {
			return 1
		}
		return 0
	})

	return result
}

// all_action_tags enumerates every ActionTag so we can build defaults by
// iterating over all actions, matching the Zig comptime enum-field iteration.
const all_action_tags = [
	ActionTag.ignore,
	.unbind,
	.csi,
	.esc,
	.text,
	.cursor_key,
	.reset,
	.copy_to_clipboard,
	.paste_from_clipboard,
	.paste_from_selection,
	.copy_url_to_clipboard,
	.copy_title_to_clipboard,
	.increase_font_size,
	.decrease_font_size,
	.reset_font_size,
	.set_font_size,
	.search,
	.search_selection,
	.navigate_search,
	.start_search,
	.end_search,
	.clear_screen,
	.select_all,
	.scroll_to_top,
	.scroll_to_bottom,
	.scroll_to_selection,
	.scroll_to_row,
	.scroll_page_up,
	.scroll_page_down,
	.scroll_page_fractional,
	.scroll_page_lines,
	.adjust_selection,
	.jump_to_prompt,
	.write_scrollback_file,
	.write_screen_file,
	.write_selection_file,
	.new_window,
	.new_tab,
	.previous_tab,
	.next_tab,
	.last_tab,
	.goto_tab,
	.move_tab,
	.toggle_tab_overview,
	.prompt_surface_title,
	.prompt_tab_title,
	.new_split,
	.goto_split,
	.goto_window,
	.toggle_split_zoom,
	.toggle_readonly,
	.resize_split,
	.equalize_splits,
	.reset_window_size,
	.inspector,
	.show_gtk_inspector,
	.show_on_screen_keyboard,
	.open_config,
	.reload_config,
	.close_surface,
	.close_tab,
	.close_window,
	.close_all_windows,
	.toggle_maximize,
	.toggle_fullscreen,
	.toggle_window_decorations,
	.toggle_window_float_on_top,
	.toggle_secure_input,
	.toggle_mouse_reporting,
	.toggle_command_palette,
	.toggle_quick_terminal,
	.toggle_visibility,
	.toggle_background_opacity,
	.check_for_updates,
	.undo,
	.redo,
	.end_key_sequence,
	.activate_key_table,
	.activate_key_table_once,
	.deactivate_key_table,
	.deactivate_all_key_tables,
	.quit,
	.crash,
]

// cmd is a small helper to build a Command from an action, title and
// description, matching the Zig `.{ .action = ..., .title = ..., .description = ... }`.
fn cmd(action Action, title string, description string) Command {
	return Command{
		action: action
		title: title
		description: description
	}
}

// action_commands returns the set of commands associated with this action tag
// by default. Not all actions have commands. Faithful to Zig `actionCommands`.
fn action_commands(action ActionTag) []Command {
	return match action {
		.reset {
			[cmd(Action.new(.reset), 'Reset Terminal', 'Reset the terminal to a clean state.')]
		}
		.copy_to_clipboard {
			[
				cmd(Action.new_enum(.copy_to_clipboard, i32(CopyToClipboard.mixed)),
					'Copy to Clipboard',
					'Copy the selected text to the clipboard in both plain and styled formats.'),
				cmd(Action.new_enum(.copy_to_clipboard, i32(CopyToClipboard.plain)),
					'Copy Selection as Plain Text to Clipboard',
					'Copy the selected text as plain text to the clipboard.'),
				cmd(Action.new_enum(.copy_to_clipboard, i32(CopyToClipboard.vt)),
					'Copy Selection as ANSI Sequences to Clipboard',
					'Copy the selected text as ANSI escape sequences to the clipboard.'),
				cmd(Action.new_enum(.copy_to_clipboard, i32(CopyToClipboard.html)),
					'Copy Selection as HTML to Clipboard',
					'Copy the selected text as HTML to the clipboard.'),
			]
		}
		.copy_url_to_clipboard {
			[cmd(Action.new(.copy_url_to_clipboard), 'Copy URL to Clipboard',
				'Copy the URL under the cursor to the clipboard.')]
		}
		.copy_title_to_clipboard {
			[cmd(Action.new(.copy_title_to_clipboard), 'Copy Terminal Title to Clipboard',
				'Copy the terminal title to the clipboard. If the terminal title is not set this has no effect.')]
		}
		.paste_from_clipboard {
			[cmd(Action.new(.paste_from_clipboard), 'Paste from Clipboard',
				'Paste the contents of the main clipboard.')]
		}
		.paste_from_selection {
			[cmd(Action.new(.paste_from_selection), 'Paste from Selection',
				'Paste the contents of the selection clipboard.')]
		}
		.start_search {
			[cmd(Action.new(.start_search), 'Start Search', "Start a search if one isn't already active.")]
		}
		.search_selection {
			[cmd(Action.new(.search_selection), 'Search Selection',
				'Start a search for the current text selection.')]
		}
		.end_search {
			[cmd(Action.new(.end_search), 'End Search',
				'End the current search if any and hide any GUI elements.')]
		}
		.navigate_search {
			[
				cmd(Action.new_enum(.navigate_search, i32(NavigateSearch.next)),
					'Next Search Result', 'Navigate to the next search result, if any.'),
				cmd(Action.new_enum(.navigate_search, i32(NavigateSearch.previous)),
					'Previous Search Result', 'Navigate to the previous search result, if any.'),
			]
		}
		.increase_font_size {
			[cmd(Action.new_float(.increase_font_size, 1), 'Increase Font Size',
				'Increase the font size by 1 point.')]
		}
		.decrease_font_size {
			[cmd(Action.new_float(.decrease_font_size, 1), 'Decrease Font Size',
				'Decrease the font size by 1 point.')]
		}
		.reset_font_size {
			[cmd(Action.new(.reset_font_size), 'Reset Font Size', 'Reset the font size to the default.')]
		}
		.clear_screen {
			[cmd(Action.new(.clear_screen), 'Clear Screen', 'Clear the screen and scrollback.')]
		}
		.select_all {
			[cmd(Action.new(.select_all), 'Select All', 'Select all text on the screen.')]
		}
		.scroll_to_top {
			[cmd(Action.new(.scroll_to_top), 'Scroll to Top', 'Scroll to the top of the screen.')]
		}
		.scroll_to_bottom {
			[cmd(Action.new(.scroll_to_bottom), 'Scroll to Bottom', 'Scroll to the bottom of the screen.')]
		}
		.scroll_to_selection {
			[cmd(Action.new(.scroll_to_selection), 'Scroll to Selection', 'Scroll to the selected text.')]
		}
		.scroll_page_up {
			[cmd(Action.new(.scroll_page_up), 'Scroll Page Up', 'Scroll the screen up by a page.')]
		}
		.scroll_page_down {
			[cmd(Action.new(.scroll_page_down), 'Scroll Page Down', 'Scroll the screen down by a page.')]
		}
		.write_screen_file {
			write_file_commands(.write_screen_file, 'Screen', 'screen')
		}
		.write_selection_file {
			write_file_commands(.write_selection_file, 'Selection', 'selection')
		}
		.new_window {
			[cmd(Action.new(.new_window), 'New Window', 'Open a new window.')]
		}
		.new_tab {
			[cmd(Action.new(.new_tab), 'New Tab', 'Open a new tab.')]
		}
		.move_tab {
			[
				cmd(Action.new_uint(.move_tab, u64(-1)), 'Move Tab Left', 'Move the current tab to the left.'),
				cmd(Action.new_uint(.move_tab, 1), 'Move Tab Right', 'Move the current tab to the right.'),
			]
		}
		.toggle_tab_overview {
			[cmd(Action.new(.toggle_tab_overview), 'Toggle Tab Overview', 'Toggle the tab overview.')]
		}
		.prompt_surface_title {
			[cmd(Action.new(.prompt_surface_title), 'Change Terminal Title...',
				'Prompt for a new title for the current terminal.')]
		}
		.prompt_tab_title {
			[cmd(Action.new(.prompt_tab_title), 'Change Tab Title...',
				'Prompt for a new title for the current tab.')]
		}
		.new_split {
			[
				cmd(Action.new_enum(.new_split, i32(SplitDirection.left)), 'Split Left',
					'Split the terminal to the left.'),
				cmd(Action.new_enum(.new_split, i32(SplitDirection.right)), 'Split Right',
					'Split the terminal to the right.'),
				cmd(Action.new_enum(.new_split, i32(SplitDirection.up)), 'Split Up',
					'Split the terminal up.'),
				cmd(Action.new_enum(.new_split, i32(SplitDirection.down)), 'Split Down',
					'Split the terminal down.'),
			]
		}
		.goto_split {
			[
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.previous)),
					'Focus Split: Previous', 'Focus the previous split, if any.'),
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.next)),
					'Focus Split: Next', 'Focus the next split, if any.'),
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.left)),
					'Focus Split: Left', 'Focus the split to the left, if it exists.'),
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.right)),
					'Focus Split: Right', 'Focus the split to the right, if it exists.'),
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.up)),
					'Focus Split: Up', 'Focus the split above, if it exists.'),
				cmd(Action.new_enum(.goto_split, i32(SplitFocusDirection.down)),
					'Focus Split: Down', 'Focus the split below, if it exists.'),
			]
		}
		.goto_window {
			[
				cmd(Action.new_enum(.goto_window, i32(GotoWindow.previous)), 'Focus Window: Previous',
					'Focus the previous window, if any.'),
				cmd(Action.new_enum(.goto_window, i32(GotoWindow.next)), 'Focus Window: Next',
					'Focus the next window, if any.'),
			]
		}
		.toggle_split_zoom {
			[cmd(Action.new(.toggle_split_zoom), 'Toggle Split Zoom',
				'Toggle the zoom state of the current split.')]
		}
		.toggle_readonly {
			[cmd(Action.new(.toggle_readonly), 'Toggle Read-Only Mode',
				'Toggle read-only mode for the current surface.')]
		}
		.equalize_splits {
			[cmd(Action.new(.equalize_splits), 'Equalize Splits', 'Equalize the size of all splits.')]
		}
		.reset_window_size {
			[cmd(Action.new(.reset_window_size), 'Reset Window Size', 'Reset the window size to the default.')]
		}
		.inspector {
			[cmd(Action.new_enum(.inspector, i32(InspectorMode.toggle)), 'Toggle Inspector',
				'Toggle the inspector.')]
		}
		.show_gtk_inspector {
			[cmd(Action.new(.show_gtk_inspector), 'Show the GTK Inspector', 'Show the GTK inspector.')]
		}
		.show_on_screen_keyboard {
			[cmd(Action.new(.show_on_screen_keyboard), 'Show On-Screen Keyboard',
				'Show the on-screen keyboard if present.')]
		}
		.open_config {
			[cmd(Action.new(.open_config), 'Open Config', 'Open the config file.')]
		}
		.reload_config {
			[cmd(Action.new(.reload_config), 'Reload Config', 'Reload the config file.')]
		}
		.close_surface {
			[cmd(Action.new(.close_surface), 'Close Terminal', 'Close the current terminal.')]
		}
		.close_tab {
			[
				cmd(Action.new_enum(.close_tab, i32(CloseTabMode.this)), 'Close Tab', 'Close the current tab.'),
				cmd(Action.new_enum(.close_tab, i32(CloseTabMode.other)), 'Close Other Tabs',
					'Close all tabs in this window except the current one.'),
				cmd(Action.new_enum(.close_tab, i32(CloseTabMode.right)), 'Close Tabs to the Right',
					'Close all tabs to the right of the current one.'),
			]
		}
		.close_window {
			[cmd(Action.new(.close_window), 'Close Window', 'Close the current window.')]
		}
		.close_all_windows {
			[cmd(Action.new(.close_all_windows), 'Close All Windows', 'Close all windows.')]
		}
		.toggle_maximize {
			[cmd(Action.new(.toggle_maximize), 'Toggle Maximize',
				'Toggle the maximized state of the current window.')]
		}
		.toggle_fullscreen {
			[cmd(Action.new(.toggle_fullscreen), 'Toggle Fullscreen',
				'Toggle the fullscreen state of the current window.')]
		}
		.toggle_window_decorations {
			[cmd(Action.new(.toggle_window_decorations), 'Toggle Window Decorations',
				'Toggle the window decorations.')]
		}
		.toggle_window_float_on_top {
			[cmd(Action.new(.toggle_window_float_on_top), 'Toggle Float on Top',
				'Toggle the float on top state of the current window.')]
		}
		.toggle_secure_input {
			[cmd(Action.new(.toggle_secure_input), 'Toggle Secure Input', 'Toggle secure input mode.')]
		}
		.toggle_mouse_reporting {
			[cmd(Action.new(.toggle_mouse_reporting), 'Toggle Mouse Reporting',
				'Toggle whether mouse events are reported to terminal applications.')]
		}
		.toggle_background_opacity {
			[cmd(Action.new(.toggle_background_opacity), 'Toggle Background Opacity',
				'Toggle the background opacity of a window that started transparent.')]
		}
		.check_for_updates {
			[cmd(Action.new(.check_for_updates), 'Check for Updates',
				'Check for updates to the application.')]
		}
		.undo {
			[cmd(Action.new(.undo), 'Undo', 'Undo the last action.')]
		}
		.redo {
			[cmd(Action.new(.redo), 'Redo', 'Redo the last undone action.')]
		}
		.quit {
			[cmd(Action.new(.quit), 'Quit', 'Quit the application.')]
		}
		.text {
			[cmd(Action.new_str(.text, '👻'), 'Ghostty', 'Put a little Ghostty in your terminal.')]
		}
		// No commands because they're parameterized and there aren't obvious
		// values users would use, or they don't make sense in a command
		// palette, or for obvious reasons (ignore/unbind). Faithful to the
		// combined `=> comptime &.{}` arms in Zig.
		else {
			[]Command{}
		}
	}
}

// write_file_commands builds the 9-entry command set for write_screen_file /
// write_selection_file. `noun` is the capitalized noun used in titles
// ("Screen"/"Selection") and `lower` is the lowercase noun used in
// descriptions. Faithful to the two nearly-identical Zig arms.
fn write_file_commands(tag ActionTag, noun string, lower string) []Command {
	// The plain-format entries (no ",format" suffix in Zig; emit .plain).
	return [
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.copy), i32(WriteScreenFormat.plain)),
			'Copy ${noun} to Temporary File and Copy Path',
			'Copy the ${lower} contents to a temporary file and copy the path to the clipboard.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.paste), i32(WriteScreenFormat.plain)),
			'Copy ${noun} to Temporary File and Paste Path',
			'Copy the ${lower} contents to a temporary file and paste the path to the file.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.open), i32(WriteScreenFormat.plain)),
			'Copy ${noun} to Temporary File and Open',
			'Copy the ${lower} contents to a temporary file and open it.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.copy), i32(WriteScreenFormat.html)),
			'Copy ${noun} as HTML to Temporary File and Copy Path',
			'Copy the ${lower} contents as HTML to a temporary file and copy the path to the clipboard.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.paste), i32(WriteScreenFormat.html)),
			'Copy ${noun} as HTML to Temporary File and Paste Path',
			'Copy the ${lower} contents as HTML to a temporary file and paste the path to the file.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.open), i32(WriteScreenFormat.html)),
			'Copy ${noun} as HTML to Temporary File and Open',
			'Copy the ${lower} contents as HTML to a temporary file and open it.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.copy), i32(WriteScreenFormat.vt)),
			'Copy ${noun} as ANSI Sequences to Temporary File and Copy Path',
			'Copy the ${lower} contents as ANSI escape sequences to a temporary file and copy the path to the clipboard.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.paste), i32(WriteScreenFormat.vt)),
			'Copy ${noun} as ANSI Sequences to Temporary File and Paste Path',
			'Copy the ${lower} contents as ANSI escape sequences to a temporary file and paste the path to the file.'),
		cmd(Action.new_enum2(tag, i32(WriteScreenAction.open), i32(WriteScreenFormat.vt)),
			'Copy ${noun} as ANSI Sequences to Temporary File and Open',
			'Copy the ${lower} contents as ANSI escape sequences to a temporary file and open it.'),
	]
}
