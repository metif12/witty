module gtk

// command_palette_linux.v - The GObject CommandPalette widget class for the GTK
// apprt.
//
// Translated from ghostty/src/apprt/gtk/class/command_palette.zig.
//
// A fuzzy command palette shown as an `adw.Dialog` modal over a window. It is
// backed by a `gio.ListStore` of `Command` wrapper objects (a second GObject
// class, `GhosttyCommand`, defined in the same Zig file), fed into a
// `gtk.SingleSelection` -> `gtk.ListView`. The palette collects two kinds of
// commands from the config:
//
//   * "jump" commands (one per open surface, "Focus: <title>"), and
//   * "regular" commands from `command-palette-entry`, filtered by
//     `isActionSupportedOnGtk`.
//
// It sorts them (case-insensitive, colon-normalized), and on activation either
// presents the jumped-to surface or emits a `trigger` signal carrying the
// selected action.
//
// FOLLOWING THE ESTABLISHED PATTERN: GObject registration, `.ui`/blueprint
// template, ListStore/SingleSelection/ListView model plumbing, and
// property/signal machinery are stubbed with `// TODO(gtk)`. The real logic is
// translated: the Command wrapper (regular/jump data), action-key / action /
// title / description derivation, GTK-supported-action filtering, the
// colon-normalized comparison, and the activation dispatch. Fuzzy filtering
// reuses witty's `zf` matcher (the .zig template does GTK-side filtering; we
// provide an equivalent `filter` that ranks visible commands by the search
// text).
//
// Reuses: `input.Command` / `input.Action` (input/command.v, input/binding.v),
// `Config` (window_linux.v), `SurfaceWidget` (surface_class_linux.v),
// `Window` (window_linux.v), `WeakRef` (weak_ref_linux.v),
// `accel_from_trigger` (key_linux.v), and the `zf` fuzzy matcher (zf/zf.v).

import input
import zf

// --- New C bindings unique to this file -----------------------------------
//
// `AdwDialog` and `adw_dialog_present` are declared in dialog_linux.v and
// reused here (grep-checked to avoid redeclaration).

// GtkListView*.
pub type GtkListView = voidptr

// GtkSingleSelection*.
pub type GtkSingleSelection = voidptr

// GioListStore*.
pub type GioListStore = voidptr

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

// Command is the V model of the `GhosttyCommand` GObject wrapper class. GTK list
// models only accept GObject-hierarchy objects, hence the wrapper. Fields mirror
// the Zig `Private` struct, flattened (V has no tagged-union field ergonomics
// matching the Zig union): `kind` selects which of the regular/jump fields are
// live.
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
	jump_surface WeakRef = weak_ref_empty()
	// Cached lazily-computed jump title/description.
	jump_title       string
	jump_description  string
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
	}
	if !isnil(config) {
		self.config = config_ref(config)
	}
	self.jump_surface.set(GObject(voidptr(surface)))
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
// jump commands. Mirrors `propGetActionKey`. Ghostty formats the action via its
// `{f}` formatter; witty has no Action string formatter, so we use the action
// tag name (which is stable and unique per action tag).
pub fn (mut self Command) prop_get_action_key() ?string {
	if self.kind != .regular {
		return none
	}
	if self.action_key_str.len > 0 {
		return self.action_key_str
	}
	self.action_key_str = self.command.action.tag.str()
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

	// TODO(gtk): pull the keybind set off the config and look up the trigger for
	// this action, i.e. `cfg.keybind.set.getTrigger(action)`. witty's placeholder
	// Config (window_linux.v) does not yet carry a keybind Set, so we cannot do
	// the faithful lookup. The structure is preserved: once the config exposes a
	// keybind Set, restore the two lines below.
	//
	//   trigger := cfg.keybind_set().get_trigger(self.command.action) or { return none }
	//   accel := accel_from_trigger(trigger) or { return none }
	//   self.action_str = accel
	//   return self.action_str
	return none
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
	surface := self.jump_surface_get() or { return none }
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
	surface := self.jump_surface_get() or { return none }
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

// jump_surface_get resolves the weakly-referenced target surface, or `none` if
// it has been destroyed. Mirrors `getJumpSurface` (minus the strong-ref
// semantics, which the GObject WeakRef provides).
fn (mut self Command) jump_surface_get() ?&SurfaceWidget {
	obj := self.jump_surface.get()
	if isnil(obj) {
		return none
	}
	return unsafe { &SurfaceWidget(obj) }
}

// get_jump_surface returns the jump target surface, or `none`. Mirrors
// `getJumpSurface`.
pub fn (mut self Command) get_jump_surface() ?&SurfaceWidget {
	if self.kind != .jump {
		return none
	}
	return self.jump_surface_get()
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
	}
}

// --- CommandPalette -------------------------------------------------------

// CommandPalette is the V model of the `GhosttyCommandPalette` GObject class.
// Fields mirror the Zig `Private` struct. The dialog / search / view / model /
// source are GObject/template widgets that are out of scope; they are held as
// opaque pointers so the translated logic can reference them.
@[heap]
pub struct CommandPalette {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The configuration this palette is using. nil means "unset".
	config &Config = unsafe { nil }

	// The dialog object containing the palette UI (template child).
	dialog AdwDialog = unsafe { nil }

	// The search input text field (template child).
	search GtkSearchEntry = unsafe { nil }

	// The list view showing each result row (template child).
	view GtkListView = unsafe { nil }

	// The selection model feeding the view (template child).
	model GtkSingleSelection = unsafe { nil }

	// The backing data source list (template child). This is where all command
	// data is ultimately stored.
	source GioListStore = unsafe { nil }

	// The V-side command list backing `source` (the GObject ListStore is
	// out of scope). Rebuilt by refresh_commands.
	commands []&Command
}

// new_command_palette creates a new CommandPalette. Mirrors `CommandPalette.new`
// (which also ref-sinks + refs for the caller; that refcounting is GObject
// machinery and is stubbed).
pub fn new_command_palette() &CommandPalette {
	return &CommandPalette{}
}

// prop_config is the config-changed handler: it clears and rebuilds the command
// list from the new config. Mirrors `propConfig`.
pub fn (mut self CommandPalette) prop_config() {
	if isnil(self.config) {
		eprintln('command palette does not have a config!')
		return
	}

	// Clear existing entries.
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

	// TODO(gtk): append each command's GObject into priv.source (gio.ListStore).
}

// collect_regular_commands collects regular commands from the config's
// `command-palette-entry`, filtering out actions unsupported on GTK. Mirrors
// `collectRegularCommands`.
fn (mut self CommandPalette) collect_regular_commands() {
	// TODO(gtk): iterate `cfg.@"command-palette-entry".value.items`. witty's
	// placeholder Config (window_linux.v) does not yet carry a
	// command-palette-entry list, so we fall back to the built-in default
	// command set (input.command_defaults), applying the same GTK-support
	// filter. When the config field lands, iterate it instead.
	for command in input.command_defaults {
		if !is_action_supported_on_gtk(command.action) {
			continue
		}
		self.commands << command_new(self.config, command)
	}
}

// collect_jump_commands collects one jump command per open surface across all
// windows. Mirrors `collectJumpCommands`.
fn (mut self CommandPalette) collect_jump_commands() {
	// TODO(gtk): iterate `Application.default().core().surfaces.items`, and for
	// each apprt surface build `Command.newJump(config, surface.gobj())`. The
	// core App surface list is out of scope from this module (it lives on
	// `main.App`), so no jump commands are collected here. The structure is
	// preserved for when the app surface list is reachable.
}

// is_action_supported_on_gtk reports whether an action makes sense / is
// implemented on GTK. Mirrors `isActionSupportedOnGtk`.
fn is_action_supported_on_gtk(action input.Action) bool {
	return match action.tag {
		.close_all_windows, .toggle_secure_input, .check_for_updates, .redo, .undo,
		.reset_window_size, .toggle_window_float_on_top {
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

	// TODO(gtk): present modal over `window.as(gtk.Widget)`. window_linux.v's
	// Window holds the AdwApplicationWindow in `obj`; we pass it as the parent.
	C.adw_dialog_present(self.dialog, window.obj)

	// Focus the search bar.
	C.gtk_widget_grab_focus(self.search)
}

// close closes the dialog. Mirrors `close`.
fn (self &CommandPalette) close() {
	C.adw_dialog_close(self.dialog)
}

// dialog_closed is the dialog "closed" template callback. Mirrors `dialogClosed`
// (which unrefs self; that refcounting is stubbed).
pub fn (self &CommandPalette) dialog_closed() {
	// TODO(gtk): self.unref().
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
	if pos >= u32(self.commands.len) {
		return
	}
	mut cmd := self.commands[pos]

	// Jump commands present their surface.
	if cmd.is_jump() {
		surface := cmd.get_jump_surface() or { return }
		surface.present()
		return
	}

	// Regular command: emit the trigger signal with the action.
	action := cmd.get_action() or { return }
	self.emit_trigger(action)
}

// model_selected returns the currently selected position in the selection
// model. Mirrors `priv.model.getSelected()`.
fn (self &CommandPalette) model_selected() u32 {
	// TODO(gtk): gtk_single_selection_get_selected(self.model).
	return 0
}

// emit_trigger emits the "trigger" signal with the selected action. Mirrors the
// `signals.trigger.impl.emit(...)` call.
fn (self &CommandPalette) emit_trigger(action input.Action) {
	_ = action
	// TODO(gtk): emit `trigger` signal with a pointer to the action.
}

// --- Fuzzy filtering (zf) -------------------------------------------------

// filter ranks the palette's commands against the search `query` and returns
// the matching command indices ordered best-first. Reuses witty's `zf` fuzzy
// matcher. An empty query returns all commands in their current (sorted) order.
//
// NOTE: ghostty performs filtering GTK-side via the blueprint template (a
// gtk.Filter over the model), which isn't part of the .zig class. This provides
// an equivalent so the palette's core "type to narrow" behavior is available in
// witty.
pub fn (self &CommandPalette) filter(query string) []int {
	if query.len == 0 {
		mut all := []int{cap: self.commands.len}
		for i in 0 .. self.commands.len {
			all << i
		}
		return all
	}

	// Split the query into whitespace-separated tokens (zf matches each token).
	tokens := query.fields()
	opts := zf.RankOptions{
		to_lower: true
		plain: false
	}

	// Collect (index, rank) for each command whose title matches all tokens.
	mut scored := []Scored{}
	for i, cmd in self.commands {
		title := cmd.title_for_filter()
		if r := zf.rank(title, tokens, opts) {
			scored << Scored{
				index: i
				rank: r
			}
		}
	}

	// Lower rank = better match.
	scored.sort_with_compare(fn (a &Scored, b &Scored) int {
		if a.rank < b.rank {
			return -1
		}
		if a.rank > b.rank {
			return 1
		}
		return 0
	})

	mut result := []int{cap: scored.len}
	for s in scored {
		result << s.index
	}
	return result
}

// Scored pairs a command index with its fuzzy rank (for filter sorting).
struct Scored {
	index int
	rank  f64
}

// title_for_filter returns a best-effort title for fuzzy matching without
// mutating cached state. Regular commands use their command title directly;
// jump commands use the cached title if present, else empty.
fn (self &Command) title_for_filter() string {
	if self.kind == .regular {
		return self.command.title
	}
	return self.jump_title
}

// --- helpers --------------------------------------------------------------

// ascii_to_lower lowercases a single ASCII byte. Mirrors std.ascii.toLower.
fn ascii_to_lower(c u8) u8 {
	if c >= `A` && c <= `Z` {
		return c + 32
	}
	return c
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty both `GhosttyCommandPalette` and `GhosttyCommand` are
// registered via gobject.ext.defineClass. The palette classInit ensures the
// Command type, loads the `command-palette` blueprint `.ui` template, binds the
// dialog/search/view/model/source template children, wires the closed /
// notify_config / search_stopped / search_activated / row_activated template
// callbacks, registers the `config` property and the `trigger` signal, and
// wires dispose. The Command classInit registers the config / action-key /
// action / title / description properties and dispose/finalize. V has no such
// machinery, so all of that is stubbed; the handlers above are plain methods
// and the ListStore is modeled by the `commands` slice.
