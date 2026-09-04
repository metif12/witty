@[has_globals]
module gtk

// tab_linux.v - The GObject Tab *widget* class for the GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/tab.zig.
//
// A Tab is the content of a single AdwTabPage: it holds a SplitTree (which in
// turn holds one or more terminal surfaces) plus the tab's title/tooltip state.
// In ghostty this is a `GhosttyTab` GObject class (a gtk.Box) defined with a
// `.ui`/blueprint template, GObject property/signal registration, and
// template-child bindings.
//
// As with the other GTK classes in this apprt, V has no GObject
// class-registration or `.ui`-template machinery, and this `gtk` submodule
// CANNOT import witty's root `module main` where the real core `Surface` lives.
// Therefore:
//
//   * The class is modeled as a plain V struct `Tab` that wraps the
//     GObject/GtkWidget pointer and holds the fields that were in the Zig
//     `Private` struct. Methods are `pub fn` on that struct.
//   * The split tree it contains is the `SplitTreeWidget` from
//     split_tree_class_linux.v.
//   * GObject type registration, signal/property wiring, `.ui`/blueprint
//     templates, and the AdwTabView/AdwTabPage action plumbing are STUBBED with
//     `// TODO(gtk)` and minimal type-checking bodies.
//   * Calls into core surfaces dispatch to the real `core.Surface`. `Config`
//     and `NewSurfaceContext` are reused from window_linux.v.
//
// What is genuinely TRANSLATED: the active-surface / surface-tree / split-tree
// content accessors, the needs-confirm-quit delegation, the tab-view / tab-page
// ancestor lookups, the close/ring-bell/next-page/previous-page action logic,
// and the computed-title string building (bell/zoom prefixes + override/terminal/
// config/default precedence). The GObject template/signal machinery is stubbed.

import core
import datastruct

// --- New Adw C bindings unique to this file -------------------------------
//
// AdwTabView / AdwTabPage functions used by the tab-page action logic. Grep-
// verified that none of these `fn C.` decls already exist in the module.

fn C.adw_tab_page_get_selected(page AdwTabPage) int

fn C.adw_tab_page_set_needs_attention(page AdwTabPage, needs_attention int)

fn C.adw_tab_view_select_next_page(view AdwTabView) int

fn C.adw_tab_view_select_previous_page(view AdwTabView) int

fn C.adw_tab_view_close_page(view AdwTabView, page AdwTabPage)

fn C.adw_tab_view_close_other_pages(view AdwTabView, page AdwTabPage)

fn C.adw_tab_view_close_pages_after(view AdwTabView, page AdwTabPage)

fn C.adw_tab_view_get_type() GType

fn C.gtk_widget_get_ancestor(widget GtkWidget, widget_type GType) GtkWidget

fn C.gtk_widget_set_hexpand(widget GtkWidget, expand int)

fn C.gtk_widget_set_vexpand(widget GtkWidget, expand int)

fn C.gtk_orientable_set_orientation(orientable voidptr, orientation int)

__global g_tab_type = GType(0)

fn tab_class_init(klass voidptr, class_data voidptr) {
	_ = klass
	_ = class_data
}

fn tab_instance_init(instance voidptr, klass voidptr) {
	_ = instance
	_ = klass
	C.gtk_orientable_set_orientation(instance, 1)
	C.gtk_widget_set_hexpand(GtkWidget(instance), 1)
	C.gtk_widget_set_vexpand(GtkWidget(instance), 1)
}

pub fn tab_get_type() GType {
	if g_tab_type == GType(0) {
		parent := C.gtk_box_get_type()
		mut query := C.GTypeQuery{}
		C.g_type_query(parent, &query)
		info := C.GTypeInfo{
			class_size: u16(query.class_size)
			instance_size: u16(query.instance_size)
			class_init: voidptr(tab_class_init)
			instance_init: voidptr(tab_instance_init)
		}
		g_tab_type = C.g_type_register_static(parent, c'GhosttyTab', &info, 0)
	}
	return g_tab_type
}

// --- CloseTabMode ---------------------------------------------------------

// CloseTabMode mirrors `apprt.action.CloseTabMode`: which set of tabs the
// tab.close action targets.
pub enum CloseTabMode {
	// Close only this tab.
	this
	// Close all tabs other than this one.
	other
	// Close all tabs to the right of this one.
	right
}

// --- Tab ------------------------------------------------------------------

// Tab is the V model of the `GhosttyTab` GObject class. It wraps the
// GObject/GtkWidget pointer and carries the state that lived in the Zig
// `Private` struct. The GObject/template machinery it would normally register
// is stubbed (see the class-registration TODO block at the end).
@[heap]
pub struct Tab {
pub mut:
	// The GtkWidget (gtk.Box) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The configuration this tab is using.
	config &Config = unsafe { nil }
	window &Window = unsafe { nil }

	// The title of this tab. Usually bound to the active surface.
	title ?string

	// The tooltip of this tab. Usually bound to the active surface.
	tooltip ?string

	// The split tree widget that holds this tab's surface(s) (template child).
	split_tree &SplitTreeWidget = unsafe { nil }
}

// --- Construction ---------------------------------------------------------

// new_tab creates a new Tab. Mirrors the GObject `init`: it pulls the config
// from the application if unset and creates the initial surface in the split
// tree. Template/action wiring is stubbed.
pub fn new_tab(window &Window, config &Config) &Tab {
	obj := C.g_object_new(tab_get_type(), &char(unsafe { nil }))
	split_tree := new_split_tree_widget(window, config)
	C.gtk_box_append(GtkWidget(obj), split_tree.widget)
	mut self := &Tab{
		widget: GtkWidget(obj)
		config: config
		window: window
		split_tree: split_tree
	}

	// Init our actions.
	self.init_action_map()
	self.split_tree.new_split(.right, none)

	return self
}

// init_action_map registers the "tab" action group. Mirrors `initActionMap`.
// The gio.SimpleAction callback trampolines are out of scope; the action logic
// lives in the action_* methods below.
fn (mut self Tab) init_action_map() {
	// TODO(gtk): build the [close, ring-bell, next-page, previous-page] Action
	// set and ext.actions.add_as_group(self, self.widget, "tab", ...).
}

// set_parent sets the parent of this tab page (only affects the first surface).
// Mirrors `setParent`.
pub fn (mut self Tab) set_parent(parent &core.Surface) {
	self.set_parent_with_context(parent, .tab)
}

// set_parent_with_context sets the parent using the given context. Mirrors
// `setParentWithContext`. Reuses `NewSurfaceContext` from window_linux.v.
pub fn (mut self Tab) set_parent_with_context(parent &core.Surface, context NewSurfaceContext) {
	if mut surface := self.get_active_surface() {
		surface.set_parent(parent, context)
	}
}

// --- Properties -----------------------------------------------------------

// get_active_surface returns the currently active surface, or `none`. See the
// "active-surface" property. Mirrors `getActiveSurface`. Does not ref.
pub fn (mut self Tab) get_active_surface() ?&SurfaceWidget {
	if isnil(self.split_tree) {
		return none
	}
	return self.split_tree.get_active_surface()
}

// get_surface_tree returns the surface tree of this tab, or `none`. Mirrors
// `getSurfaceTree`.
pub fn (mut self Tab) get_surface_tree() ?&datastruct.SplitTree[SurfaceWidget] {
	if isnil(self.split_tree) {
		return none
	}
	return self.split_tree.get_tree()
}

// get_split_tree returns the split tree widget in this tab. Mirrors
// `getSplitTree`.
pub fn (self &Tab) get_split_tree() &SplitTreeWidget {
	return self.split_tree
}

// get_needs_confirm_quit returns true if this tab needs confirmation before
// quitting. Mirrors `getNeedsConfirmQuit`.
pub fn (self &Tab) get_needs_confirm_quit() bool {
	if isnil(self.split_tree) {
		return false
	}
	return self.split_tree.get_needs_confirm_quit()
}

// get_tab_view returns the AdwTabView holding this tab, if any. Mirrors
// `getTabView`. Uses the widget ancestor lookup.
fn (self &Tab) get_tab_view() AdwTabView {
	if isnil(self.widget) {
		return AdwTabView(unsafe { nil })
	}
	return AdwTabView(C.gtk_widget_get_ancestor(self.widget, C.adw_tab_view_get_type()))
}

// get_tab_page returns the AdwTabPage holding this tab, if any. Mirrors
// `getTabPage`.
fn (self &Tab) get_tab_page() AdwTabPage {
	tab_view := self.get_tab_view()
	if isnil(tab_view) {
		return AdwTabPage(unsafe { nil })
	}
	return C.adw_tab_view_get_page(tab_view, self.widget)
}

// --- Title / tooltip ------------------------------------------------------

// get_title returns the tab title, if any. Mirrors the "title" property getter.
pub fn (self &Tab) get_title() ?string {
	return self.title
}

// set_title sets the tab title. Mirrors the "title" property setter.
pub fn (mut self Tab) set_title(title ?string) {
	self.title = title
	// TODO(gtk): notifyByPspec(properties.title).
}

// get_tooltip returns the tab tooltip, if any. Mirrors the "tooltip" property.
pub fn (self &Tab) get_tooltip() ?string {
	return self.tooltip
}

// set_tooltip sets the tab tooltip. Mirrors the "tooltip" property setter.
pub fn (mut self Tab) set_tooltip(tooltip ?string) {
	self.tooltip = tooltip
	// TODO(gtk): notifyByPspec(properties.tooltip).
}

// --- Signal handlers ------------------------------------------------------

// prop_split_tree handles the split tree's "notify::tree". Mirrors
// `propSplitTree`: notifies the surface-tree property and, if the tree is now
// empty, requests the tab be closed.
pub fn (mut self Tab) prop_split_tree() {
	// TODO(gtk): notifyByPspec(properties.surface-tree).

	// If our tree is empty we close the tab.
	empty := if tree := self.get_surface_tree() {
		tree.is_empty()
	} else {
		true
	}
	if empty {
		// TODO(gtk): signals.close-request.emit(self).
		return
	}
}

// prop_active_surface handles the split tree's "notify::active-surface".
// Mirrors `propActiveSurface`.
pub fn (mut self Tab) prop_active_surface() {
	// TODO(gtk): notifyByPspec(properties.active-surface).
}

// --- Actions --------------------------------------------------------------

// action_close handles the "tab.close" action for the given mode. Mirrors
// `actionClose`: it looks up this tab's page in the tab view and delegates to
// the parent (which emits a close-page signal the parent can intercept).
pub fn (mut self Tab) action_close(mode CloseTabMode) {
	tab_view := self.get_tab_view()
	if isnil(tab_view) {
		return
	}
	page := C.adw_tab_view_get_page(tab_view, self.widget)

	match mode {
		.this { C.adw_tab_view_close_page(tab_view, page) }
		.other { C.adw_tab_view_close_other_pages(tab_view, page) }
		.right { C.adw_tab_view_close_pages_after(tab_view, page) }
	}
}

// action_ring_bell handles the "tab.ring-bell" action. Mirrors `actionRingBell`:
// marks the page as needing attention only if it isn't the selected page.
pub fn (mut self Tab) action_ring_bell() {
	page := self.get_tab_page()
	if isnil(page) {
		return
	}
	// If already selected, don't mark it as needing attention.
	if C.adw_tab_page_get_selected(page) != 0 {
		return
	}
	C.adw_tab_page_set_needs_attention(page, 1)
}

// action_next_page selects the next tab page. Mirrors `actionNextPage`.
pub fn (mut self Tab) action_next_page() {
	tab_view := self.get_tab_view()
	if isnil(tab_view) {
		return
	}
	C.adw_tab_view_select_next_page(tab_view)
}

// action_previous_page selects the previous tab page. Mirrors
// `actionPreviousPage`.
pub fn (mut self Tab) action_previous_page() {
	tab_view := self.get_tab_view()
	if isnil(tab_view) {
		return
	}
	C.adw_tab_view_select_previous_page(tab_view)
}

// --- Computed title -------------------------------------------------------

// computed_title builds the display title for this tab. Faithful translation of
// `closureComputedTitle`: the plain title is the override, else the terminal
// title, else the config title, else a default; a zoom/bell prefix is added
// per config.
pub fn (self &Tab) computed_title(config_ &Config, terminal_ ?string, override_ ?string, zoomed bool, bell_ringing bool) string {
	default_title := 'Witty'

	// The plain title: override, else terminal, else config title, else default.
	plain := if o := override_ {
		o
	} else if t := terminal_ {
		t
	} else {
		config_title(config_) or { default_title }
	}
	if isnil(config_) {
		return plain
	}
	cfg := config_.get()

	// Build the final title with any prefixes.
	mut result := ''

	// Bell prefix.
	if bell_ringing && cfg.bell_features.title {
		result += '🔔 ' // bell emoji (U+1F514)
	}

	// Zoom prefix.
	if zoomed {
		result += '🔍 ' // magnifying glass emoji (U+1F50D)
	}

	result += plain
	return result
}

// config_title returns the configured static title, if any. Helper for
// computed_title. Mirrors the inner `config_title` block of the closure.
fn config_title(config_ &Config) ?string {
	if isnil(config_) {
		return none
	}
	return config_.get().title
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty, the class is registered via
// gobject.ext.defineClass(...) with an instanceInit (init), classInit
// (Class.init), and a Private struct. classInit loads the "tab" blueprint `.ui`
// template, binds the `split_tree` template child, binds the template callbacks
// (computed_title -> computed_title, notify_active_surface -> prop_active_surface,
// notify_tree -> prop_split_tree), and registers the active-surface / config /
// split-tree / surface-tree / title / tooltip properties and the "close-request"
// signal, plus dispose/finalize virtual methods.
//
// V has no such machinery, so all of that is stubbed. The handlers above are
// plain methods rather than C template callbacks.
