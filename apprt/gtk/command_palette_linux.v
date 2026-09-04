module gtk

// command_palette_linux.v - The GTK command palette.
//
// Translated from ghostty/src/apprt/gtk/class/command_palette.zig.
//
// A searchable command palette shown as an `adw.Dialog` modal over a window.
// Ghostty builds the widget from a blueprint and GObject list model; Witty
// constructs the same controls directly and keeps the command model in V. The
// palette collects two kinds of commands from the config:
//
//   * "jump" commands (one per open surface, "Focus: <title>"), and
//   * "regular" commands from `command-palette-entry`, filtered by
//     `isActionSupportedOnGtk`.
//
// It sorts them (case-insensitive, colon-normalized), filters against either
// title or action key, and on activation either presents the jumped-to surface
// or dispatches the selected action to the owning window.
//
// Reuses: `input.Command` / `input.Action` (input/command.v, input/binding.v),
// `Config` (window_linux.v), `SurfaceWidget` (surface_class_linux.v),
// `Window` (window_linux.v), `WeakRef` (weak_ref_linux.v),
// and `accel_from_trigger` (key_linux.v).

import input

// --- New C bindings unique to this file -----------------------------------
//
// `AdwDialog` and `adw_dialog_present` are declared in dialog_linux.v and
// reused here (grep-checked to avoid redeclaration).

pub type GtkListBox = voidptr

pub type GtkListBoxRow = voidptr

fn C.adw_dialog_new() AdwDialog

fn C.adw_dialog_set_child(dialog AdwDialog, child GtkWidget)

fn C.adw_dialog_set_content_width(dialog AdwDialog, width int)

fn C.adw_header_bar_new() GtkWidget

fn C.adw_header_bar_set_title_widget(header GtkWidget, title_widget GtkWidget)

fn C.gtk_search_entry_new() GtkSearchEntry

fn C.gtk_scrolled_window_new() GtkScrolledWindow

fn C.gtk_scrolled_window_set_min_content_height(scrolled GtkScrolledWindow, height int)

fn C.gtk_list_box_new() GtkListBox

fn C.gtk_list_box_append(box GtkListBox, child GtkWidget)

fn C.gtk_list_box_remove(box GtkListBox, child GtkWidget)

fn C.gtk_list_box_set_activate_on_single_click(box GtkListBox, single bool)

fn C.gtk_list_box_set_selection_mode(box GtkListBox, mode int)

fn C.gtk_list_box_set_show_separators(box GtkListBox, show bool)

fn C.gtk_list_box_get_row_at_index(box GtkListBox, index int) GtkListBoxRow

fn C.gtk_list_box_get_selected_row(box GtkListBox) GtkListBoxRow

fn C.gtk_list_box_select_row(box GtkListBox, row GtkListBoxRow)

fn C.gtk_list_box_row_get_index(row GtkListBoxRow) int

fn C.gtk_widget_get_first_child(widget GtkWidget) GtkWidget

fn C.gtk_widget_set_tooltip_text(widget GtkWidget, text &char)

fn C.gtk_label_set_xalign(label GtkWidget, xalign f32)

fn C.gtk_label_set_ellipsize(label GtkWidget, mode int)

fn C.gtk_label_set_single_line_mode(label GtkWidget, single_line_mode bool)

fn C.gtk_shortcut_label_new(accelerator &char) GtkWidget

fn C.adw_dialog_close(dialog AdwDialog) bool

fn C.gtk_widget_get_realized(widget GtkWidget) bool

// --- CommandDataKind ------------------------------------------------------

// CommandDataKind mirrors the tag of the Zig `Private.CommandData` union
// (regular vs jump).
pub enum CommandDataKind {
	regular
	jump
}

// --- Command --------------------------------------------------------------

// Command is the V model corresponding to Ghostty's `GhosttyCommand` GObject
// wrapper. Fields mirror the Zig `Private` struct, flattened (V has no
// tagged-union field ergonomics matching the Zig union): `kind` selects which
// of the regular/jump fields are live.
@[heap]
pub struct Command {
pub mut:
	// The config this command was built from. nil means "unset".
	config &Config = unsafe { nil }

	// Which kind of command this is.
	kind CommandDataKind = .regular

	// --- regular data ---
	// The underlying input command (title/description/action live here).
	command input.Command
	// Cached, lazily-computed derived strings. Empty means "not yet computed".
	action_str     string
	action_key_str string

	// --- jump data ---
	// Weak reference to the target surface (so we don't keep it alive).
	jump_surface     WeakRef = weak_ref_empty()
	jump_surface_ptr &SurfaceWidget = unsafe { nil }
	// Cached lazily-computed jump title/description.
	jump_title       string
	jump_description string
	// A stable sort key for jump commands (the surface pointer in ghostty).
	sort_key usize
}

// command_new creates a new regular command wrapping an input.Command. Mirrors
// `Command.new`.
pub fn command_new(config &Config, command input.Command) &Command {
	mut self := &Command{
		config: unsafe { nil }
		kind: .regular
		command: command.clone()
	}
	if !isnil(config) {
		self.config = config_ref(config)
	}
	return self
}

// command_new_jump creates a new jump command focusing a specific surface.
// Mirrors `Command.newJump`.
pub fn command_new_jump(config &Config, surface &SurfaceWidget) &Command {
	mut self := &Command{
		config: unsafe { nil }
		kind: .jump
		// TODO: replace with a surface id once witty adds one (matches ghostty's
		// `@intFromPtr(surface)`).
		sort_key: usize(voidptr(surface))
		jump_surface_ptr: surface
	}
	if !isnil(config) {
		self.config = config_ref(config)
	}
	self.jump_surface.set(GObject(surface.widget))
	return self
}

// config_ref is a small non-mut wrapper around `Config.ref()` so callers that
// hold an immutable `&Config` can bump the refcount without V flagging the
// parameter as needing `mut`. The underlying `ref()` does not mutate the
// config; this just satisfies the checker.
fn config_ref(config &Config) &Config {
	mut c := config
	return c.ref()
}

// --- Property getters -----------------------------------------------------

// prop_get_action_key returns a stable string key for the action, or `none` for
// jump commands. Mirrors `propGetActionKey`.
pub fn (mut self Command) prop_get_action_key() ?string {
	if self.kind != .regular {
		return none
	}
	if self.action_key_str.len > 0 {
		return self.action_key_str
	}
	self.action_key_str = self.command.action.format()
	return self.action_key_str
}

// prop_get_action returns the GTK accelerator string for this command's action
// (e.g. "<Ctrl>c"), or `none` if there is no keybind. Mirrors `propGetAction`.
pub fn (mut self Command) prop_get_action() ?string {
	if self.kind != .regular {
		return none
	}
	if self.action_str.len > 0 {
		return self.action_str
	}
	if isnil(self.config) {
		return none
	}

	cfg := self.config.get()
	trigger := cfg.keybind.set.get_trigger(self.command.action) or { return none }
	accel := accel_from_trigger(trigger) or { return none }
	self.action_str = accel
	return self.action_str
}

// prop_get_title returns the display title. For jump commands this is
// "Focus: <surface title>" (or "Focus: Untitled"). Mirrors `propGetTitle`.
pub fn (mut self Command) prop_get_title() ?string {
	if self.kind == .regular {
		return self.command.title
	}

	// jump
	if self.jump_title.len > 0 {
		return self.jump_title
	}
	obj := self.jump_surface.get()
	if isnil(obj) {
		return none
	}
	defer {
		object_unref(obj)
	}
	if isnil(self.jump_surface_ptr) {
		return none
	}
	surface := self.jump_surface_ptr
	surface_title := surface.get_title() or { 'Untitled' }
	self.jump_title = 'Focus: ${surface_title}'
	return self.jump_title
}

// prop_get_description returns the (optional) description. For jump commands
// this is the surface pwd when it isn't already part of the title. Mirrors
// `propGetDescription`.
pub fn (mut self Command) prop_get_description() ?string {
	if self.kind == .regular {
		return self.command.description
	}

	// jump
	if self.jump_description.len > 0 {
		return self.jump_description
	}
	obj := self.jump_surface.get()
	if isnil(obj) {
		return none
	}
	defer {
		object_unref(obj)
	}
	if isnil(self.jump_surface_ptr) {
		return none
	}
	surface := self.jump_surface_ptr
	title := surface.get_title() or { 'Untitled' }
	if pwd := surface.get_pwd() {
		if !title.contains(pwd) {
			self.jump_description = pwd
		}
	}
	if self.jump_description.len == 0 {
		return none
	}
	return self.jump_description
}

// --- Command accessors ----------------------------------------------------

// get_action returns a copy of the action for regular commands, or `none` for
// jump commands. Mirrors `getAction`.
pub fn (self &Command) get_action() ?input.Action {
	if self.kind != .regular {
		return none
	}
	return self.command.action
}

// is_jump reports whether this is a jump command. Mirrors `isJump`.
pub fn (self &Command) is_jump() bool {
	return self.kind == .jump
}

// present_jump_surface presents the jump target while holding the strong
// GObject reference returned by the weak reference. Mirrors the caller-owned
// reference returned by Ghostty's `getJumpSurface`.
fn (mut self Command) present_jump_surface() bool {
	if self.kind != .jump {
		return false
	}
	obj := self.jump_surface.get()
	if isnil(obj) {
		return false
	}
	defer {
		object_unref(obj)
	}
	if isnil(self.jump_surface_ptr) {
		return false
	}
	self.jump_surface_ptr.present()
	return true
}

// dispose releases the config reference and clears the weak surface ref.
// Mirrors the `dispose` virtual method.
pub fn (mut self Command) dispose() {
	if !isnil(self.config) {
		self.config.unref()
		self.config = unsafe { nil }
	}
	if self.kind == .jump {
		self.jump_surface.set(unsafe { nil })
		self.jump_surface_ptr = unsafe { nil }
	}
}

// --- CommandPalette -------------------------------------------------------

// CommandPalette is the V-owned model and GTK widget set corresponding to
// Ghostty's `GhosttyCommandPalette` GObject class.
@[heap]
pub struct CommandPalette {
pub mut:
	// The dialog widget used as this instance's root.
	widget GtkWidget = unsafe { nil }

	// The configuration this palette is using. nil means "unset".
	config &Config = unsafe { nil }

	// The dialog object containing the palette UI.
	dialog AdwDialog = unsafe { nil }

	// The search input text field.
	search GtkSearchEntry = unsafe { nil }

	// Programmatic equivalent of the blueprint list view. GtkListBox preserves
	// the same row activation and single-selection behavior while V owns the
	// command wrappers directly.
	list GtkListBox = unsafe { nil }

	// The command list and indices currently visible after filtering.
	commands         []&Command
	visible_commands []int
	window           &Window = unsafe { nil }
	app              &Application = unsafe { nil }
}

// new_command_palette creates a new CommandPalette. Mirrors
// `CommandPalette.new`, including ownership of the initially-floating dialog.
pub fn new_command_palette() &CommandPalette {
	dialog := C.adw_dialog_new()
	C.g_object_ref_sink(GObject(dialog))
	C.adw_dialog_set_content_width(dialog, 700)

	toolbar := C.adw_toolbar_view_new()
	C.adw_toolbar_view_set_top_bar_style(toolbar, int(AdwToolbarStyle.flat))
	header := C.adw_header_bar_new()
	search := C.gtk_search_entry_new()
	C.gtk_widget_set_hexpand(search, 1)
	C.g_object_set(GObject(search), c'placeholder-text', c'Execute a command…', unsafe { nil })
	C.gtk_widget_add_css_class(search, c'command-palette-search')
	C.adw_header_bar_set_title_widget(header, search)
	C.adw_toolbar_view_add_top_bar(toolbar, header)

	scrolled := C.gtk_scrolled_window_new()
	C.gtk_scrolled_window_set_min_content_height(scrolled, 300)
	list := C.gtk_list_box_new()
	C.gtk_list_box_set_selection_mode(list, 1)
	C.gtk_list_box_set_activate_on_single_click(list, true)
	C.gtk_list_box_set_show_separators(list, true)
	C.gtk_widget_add_css_class(GtkWidget(list), c'rich-list')
	C.gtk_scrolled_window_set_child(scrolled, GtkWidget(list))
	C.adw_toolbar_view_set_content(toolbar, GtkWidget(scrolled))
	C.adw_dialog_set_child(dialog, GtkWidget(toolbar))

	mut self := &CommandPalette{
		widget: GtkWidget(dialog)
		dialog: dialog
		search: search
		list: list
	}
	C.g_signal_connect_data(dialog, c'closed', GCallback(voidptr(command_palette_dialog_closed_cb)), self, unsafe { nil }, 0)
	C.g_signal_connect_data(search, c'stop-search', GCallback(voidptr(command_palette_search_stopped_cb)), self, unsafe { nil }, 0)
	C.g_signal_connect_data(search, c'activate', GCallback(voidptr(command_palette_search_activated_cb)), self, unsafe { nil }, 0)
	C.g_signal_connect_data(search, c'search-changed', GCallback(voidptr(command_palette_search_changed_cb)), self, unsafe { nil }, 0)
	C.g_signal_connect_data(list, c'row-activated', GCallback(voidptr(command_palette_row_activated_cb)), self, unsafe { nil }, 0)
	return self
}

// prop_config is the config-changed handler: it clears and rebuilds the command
// list from the new config. Mirrors `propConfig`.
pub fn (mut self CommandPalette) prop_config() {
	if isnil(self.config) {
		eprintln('command palette does not have a config!')
		return
	}

	// Clear existing entries.
	for mut command in self.commands {
		command.dispose()
	}
	self.commands = []&Command{}

	self.collect_jump_commands()
	self.collect_regular_commands()

	// Sort commands (colon-normalized, case-insensitive; sort_key tie-break).
	self.commands.sort_with_compare(fn (a &&Command, b &&Command) int {
		mut ca := unsafe { *a }
		mut cb := unsafe { *b }
		if compare_commands(mut ca, mut cb) {
			return -1
		}
		if compare_commands(mut cb, mut ca) {
			return 1
		}
		return 0
	})

	self.refresh_visible_commands('')
}

// collect_regular_commands collects regular commands from the config's
// `command-palette-entry`, filtering out actions unsupported on GTK. Mirrors
// `collectRegularCommands`.
fn (mut self CommandPalette) collect_regular_commands() {
	cfg := self.config.get()
	for command in cfg.command_palette_entry.items {
		if !is_action_supported_on_gtk(command.action) {
			continue
		}
		self.commands << command_new(self.config, command)
	}
}

// collect_jump_commands collects one jump command per open surface across all
// windows. Mirrors `collectJumpCommands`.
fn (mut self CommandPalette) collect_jump_commands() {
	if isnil(self.app) {
		return
	}
	for window in self.app.windows {
		for tab in window.tabs {
			for surface in tab.split_tree.surfaces {
				self.commands << command_new_jump(self.config, surface)
			}
		}
	}
}

// is_action_supported_on_gtk reports whether an action makes sense / is
// implemented on GTK. Mirrors `isActionSupportedOnGtk`.
fn is_action_supported_on_gtk(action input.Action) bool {
	return match action.tag {
		.close_all_windows, .toggle_secure_input, .check_for_updates, .redo, .undo, .reset_window_size, .toggle_window_float_on_top {
			false
		}
		else {
			true
		}
	}
}

// compare_commands returns true if command `a` should sort before `b`. Sorts
// alphabetically by title, case-insensitively, with ':' normalized to '\t' so
// "Foo:" sorts before "Foo Bar:". Ties fall back to sort_key for jump commands.
// Mirrors `compareCommands`.
fn compare_commands(mut a Command, mut b Command) bool {
	a_title := a.prop_get_title() or { return false }
	b_title := b.prop_get_title() or { return true }

	min_len := if a_title.len < b_title.len { a_title.len } else { b_title.len }
	for i in 0 .. min_len {
		// Normalize ':' to '\t' so it sorts before space.
		a_char := if a_title[i] == `:` { u8(`\t`) } else { a_title[i] }
		b_char := if b_title[i] == `:` { u8(`\t`) } else { b_title[i] }
		a_lower := ascii_to_lower(a_char)
		b_lower := ascii_to_lower(b_char)
		if a_lower != b_lower {
			return a_lower < b_lower
		}
	}

	// If one title is a prefix of the other, the shorter comes first.
	if a_title.len != b_title.len {
		return a_title.len < b_title.len
	}

	// Titles are equal: use sort_key as a tie-breaker for jump commands. A
	// regular command in either slot means "not less than" (matches the Zig
	// `.regular => return false`).
	if a.kind != .jump || b.kind != .jump {
		return false
	}
	return a.sort_key < b.sort_key
}

// --- Dialog / activation --------------------------------------------------

// toggle shows or hides the palette dialog. When shown it is modal over the
// given window and the search bar is focused. Mirrors `toggle`.
pub fn (mut self CommandPalette) toggle(window &Window) {
	// If the dialog is already realized (shown), close it.
	if C.gtk_widget_get_realized(self.dialog) {
		self.close()
		return
	}
	self.window = unsafe { window }
	self.prop_config()
	C.gtk_editable_set_text(GtkWidget(self.search), c'')

	// Window holds the AdwApplicationWindow in `obj`; present it as the parent.
	C.adw_dialog_present(self.dialog, window.obj)

	// Focus the search bar.
	C.gtk_widget_grab_focus(self.search)
}

// close closes the dialog. Mirrors `close`.
fn (self &CommandPalette) close() {
	C.adw_dialog_close(self.dialog)
}

// dialog_closed resets the search for the next presentation. Ghostty releases
// the dialog's self-reference here; Witty's wrapper instead remains owned by
// the Window until window disposal.
pub fn (mut self CommandPalette) dialog_closed() {
	if !isnil(self.search) {
		C.gtk_editable_set_text(GtkWidget(self.search), c'')
	}
}

// search_stopped is the search "stop-search" template callback (ESC). Mirrors
// `searchStopped`.
pub fn (self &CommandPalette) search_stopped() {
	self.close()
}

// search_activated is the search "activate" template callback (Enter). Mirrors
// `searchActivated`: activates the currently selected row.
pub fn (mut self CommandPalette) search_activated() {
	self.activated(self.model_selected())
}

// row_activated is the list-view "activate" template callback. Mirrors
// `rowActivated`.
pub fn (mut self CommandPalette) row_activated(pos u32) {
	self.activated(pos)
}

// activated dispatches activation of the command at the given (visible)
// position: jump commands present their surface, regular commands emit the
// `trigger` signal with the action. Mirrors `activated`.
fn (mut self CommandPalette) activated(pos u32) {
	// Close before running the action so a follow-up dialog (e.g. the change
	// title dialog) doesn't displace us before we register as closed.
	self.close()

	// Resolve the command at `pos` from the visible list.
	if pos >= u32(self.visible_commands.len) {
		return
	}
	command_index := self.visible_commands[pos]
	if command_index < 0 || command_index >= self.commands.len {
		return
	}
	mut cmd := self.commands[command_index]

	// Jump commands present their surface.
	if cmd.is_jump() {
		cmd.present_jump_surface()
		return
	}

	// Regular command: emit the trigger signal with the action.
	action := cmd.get_action() or { return }
	self.emit_trigger(action)
}

// model_selected returns the currently selected position in the selection
// model. Mirrors `priv.model.getSelected()`.
fn (self &CommandPalette) model_selected() u32 {
	if isnil(self.list) {
		return u32(-1)
	}
	row := C.gtk_list_box_get_selected_row(self.list)
	if isnil(row) {
		return u32(-1)
	}
	return u32(C.gtk_list_box_row_get_index(row))
}

// emit_trigger emits the "trigger" signal with the selected action. Mirrors the
// `signals.trigger.impl.emit(...)` call.
fn (self &CommandPalette) emit_trigger(action input.Action) {
	if !isnil(self.window) {
		mut window := unsafe { self.window }
		window.perform_input_action(action)
	}
}

fn (mut self CommandPalette) refresh_visible_commands(query string) {
	if isnil(self.list) {
		return
	}
	for {
		child := C.gtk_widget_get_first_child(GtkWidget(self.list))
		if isnil(child) {
			break
		}
		C.gtk_list_box_remove(self.list, child)
	}

	self.visible_commands = self.filter(query)
	for command_index in self.visible_commands {
		mut command := self.commands[command_index]
		row := C.gtk_box_new(0, 10)
		labels := C.gtk_box_new(1, 0)
		C.gtk_widget_set_hexpand(labels, 1)

		title := command.prop_get_title() or { '' }
		title_label := C.gtk_label_new(&char(title.str))
		C.gtk_label_set_xalign(title_label, 0)
		C.gtk_label_set_ellipsize(title_label, 3)
		C.gtk_label_set_single_line_mode(title_label, true)
		C.gtk_widget_add_css_class(title_label, c'title')
		C.gtk_box_append(labels, title_label)

		action_key := command.prop_get_action_key() or { '' }
		if action_key.len > 0 {
			action_label := C.gtk_label_new(&char(action_key.str))
			C.gtk_label_set_xalign(action_label, 0)
			C.gtk_label_set_ellipsize(action_label, 3)
			C.gtk_label_set_single_line_mode(action_label, true)
			C.gtk_widget_add_css_class(action_label, c'subtitle')
			C.gtk_widget_add_css_class(action_label, c'monospace')
			C.gtk_box_append(labels, action_label)
		}
		C.gtk_box_append(row, labels)

		accelerator := command.prop_get_action() or { '' }
		if accelerator.len > 0 {
			shortcut := C.gtk_shortcut_label_new(&char(accelerator.str))
			C.gtk_box_append(row, shortcut)
		}
		if description := command.prop_get_description() {
			C.gtk_widget_set_tooltip_text(row, &char(description.str))
		}
		C.gtk_list_box_append(self.list, row)
	}
	if self.visible_commands.len > 0 {
		first := C.gtk_list_box_get_row_at_index(self.list, 0)
		C.gtk_list_box_select_row(self.list, first)
	}
}

fn command_palette_dialog_closed_cb(dialog AdwDialog, data voidptr) {
	_ = dialog
	if !isnil(data) {
		mut self := unsafe { &CommandPalette(data) }
		self.dialog_closed()
	}
}

fn command_palette_search_stopped_cb(search GtkSearchEntry, data voidptr) {
	_ = search
	if !isnil(data) {
		self := unsafe { &CommandPalette(data) }
		self.search_stopped()
	}
}

fn command_palette_search_activated_cb(search GtkSearchEntry, data voidptr) {
	_ = search
	if !isnil(data) {
		mut self := unsafe { &CommandPalette(data) }
		self.search_activated()
	}
}

fn command_palette_search_changed_cb(search GtkSearchEntry, data voidptr) {
	if isnil(search) || isnil(data) {
		return
	}
	text_ptr := C.gtk_editable_get_text(GtkWidget(search))
	mut query := ''
	if !isnil(text_ptr) {
		query = unsafe { cstring_to_vstring(text_ptr) }
	}
	mut self := unsafe { &CommandPalette(data) }
	self.refresh_visible_commands(query)
}

fn command_palette_row_activated_cb(list GtkListBox, row GtkListBoxRow, data voidptr) {
	_ = list
	if isnil(row) || isnil(data) {
		return
	}
	mut self := unsafe { &CommandPalette(data) }
	self.row_activated(u32(C.gtk_list_box_row_get_index(row)))
}

// filter mirrors the blueprint's GtkAnyFilter of two default GtkStringFilters:
// a command remains visible when the case-insensitive query occurs in either
// its title or its serialized action key. Source ordering is preserved.
pub fn (mut self CommandPalette) filter(query string) []int {
	needle := query.to_lower()
	mut result := []int{cap: self.commands.len}
	for i, mut command in self.commands {
		if needle.len == 0 {
			result << i
			continue
		}
		title := command.prop_get_title() or { '' }
		action_key := command.prop_get_action_key() or { '' }
		if title.to_lower().contains(needle) || action_key.to_lower().contains(needle) {
			result << i
		}
	}
	return result
}

// --- helpers --------------------------------------------------------------

// ascii_to_lower lowercases a single ASCII byte. Mirrors std.ascii.toLower.
fn ascii_to_lower(c u8) u8 {
	if c >= `A` && c <= `Z` {
		return c + 32
	}
	return c
}

// dispose releases the command-owned config references and the palette's GTK
// object. Signal connections are owned by the dialog and disappear with it.
pub fn (mut self CommandPalette) dispose() {
	for mut command in self.commands {
		command.dispose()
	}
	self.commands.clear()
	self.visible_commands.clear()
	self.window = unsafe { nil }
	self.app = unsafe { nil }
	self.config = unsafe { nil }
	if !isnil(self.dialog) {
		object_unref(GObject(self.dialog))
	}
	self.widget = unsafe { nil }
	self.dialog = unsafe { nil }
	self.search = unsafe { nil }
	self.list = unsafe { nil }
}
