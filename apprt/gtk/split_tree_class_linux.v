module gtk

// split_tree_class_linux.v - The GObject SplitTree *widget* class for the GTK
// apprt.
//
// Translated from ghostty/src/apprt/gtk/class/split_tree.zig.
//
// This is the GTK4 GObject widget that displays a tree of terminal surfaces
// divided by draggable splits. The actual immutable tree data structure (the
// layout/navigation/split/resize arithmetic) is witty's `datastruct.SplitTree`
// (see witty/datastruct/split_tree.v); this widget WRAPS that data structure
// and builds a GtkPaned-based widget tree from it, writing user resize actions
// back into the tree.
//
// Witty keeps the immutable surface tree in V and constructs the equivalent
// GtkBox/AdwBin/GtkPaned graph directly. This avoids depending on Ghostty's Zig
// blueprint bindings while retaining the same actions and lifecycle.

import datastruct

// --- New C bindings unique to this file -----------------------------------
//
// GtkPaned / GtkOrientable / AdwBin / GLib idle-source functions used by the
// widget-tree build and the paned<->ratio conversion. Grep-verified that none
// of these `fn C.` decls already exist in the module.

// GtkPaned*.
pub type GtkPaned = voidptr

// GtkOrientation. The two values we care about (0 = horizontal, 1 = vertical).
pub type GtkOrientation = int

// GtkPaned
fn C.gtk_paned_set_start_child(paned GtkPaned, child GtkWidget)

fn C.gtk_paned_set_end_child(paned GtkPaned, child GtkWidget)

fn C.gtk_paned_set_orientation(paned GtkPaned, orientation GtkOrientation)

fn C.gtk_paned_get_position(paned GtkPaned) int

fn C.gtk_paned_set_position(paned GtkPaned, position int)

fn C.gtk_paned_new(orientation GtkOrientation) GtkPaned

// AdwBin
fn C.adw_bin_set_child(bin AdwBin, child GtkWidget)

// GtkWidget extra helpers (not declared elsewhere in the module)
fn C.gtk_widget_get_parent(widget GtkWidget) GtkWidget

fn C.gtk_label_new(text &char) GtkWidget

// GLib idle source
fn C.g_idle_add(function voidptr, data voidptr) u32

// --- SurfaceTree alias -----------------------------------------------------

// SurfaceTree is the surface split-tree data model. In ghostty this is
// `Surface.Tree` (a `SplitTree(*Surface)`); here it is the same immutable tree
// data structure parameterized on the local `SurfaceWidget` view type.
pub type SurfaceTree = datastruct.SplitTree[SurfaceWidget]

// --- SplitTreeWidget ------------------------------------------------------

// SplitTreeWidget is the V model of the `GhosttySplitTree` GObject class. It
// wraps the GtkWidget pointer and carries the state that lived in Ghostty's
// private GObject storage.
@[heap]
pub struct SplitTreeWidget {
pub mut:
	// The GtkWidget (gtk.Box) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	window &Window = unsafe { nil }
	config &Config = unsafe { nil }

	// The tree data structure containing all of our surface views. `none`
	// (modeled with the has_tree flag) means an empty tree. In ghostty this is
	// `?*Surface.Tree`; we store the value inline and track presence.
	tree     SurfaceTree
	has_tree bool

	// The adw.Bin that holds the rendered widget tree (template child).
	tree_bin AdwBin = unsafe { nil }

	// Last focused surface in the tree. We need this to handle various tree
	// change states. In ghostty this is a WeakRef(Surface); here a plain
	// (weak) pointer that we clear when the surface goes away.
	last_focused &SurfaceWidget = unsafe { nil }

	// The source that we use to rebuild the tree. Also used to debounce
	// updates. 0 means "none".
	rebuild_source u32

	// Whether we want a rebuild to happen at the next tick that our surface
	// tree has no surfaces with parents. See prop_tree for details.
	rebuild_pending bool

	// State about a pending surface close for the close dialog. -1 means none.
	pending_close int = -1

	// Keep wrapper state alive for the GObjects referenced by tree nodes.
	surfaces         []&SurfaceWidget
	scrolled_windows []&SurfaceScrolledWindow
	splits           []&SplitTreeSplit
}

// --- Construction ---------------------------------------------------------

// new_split_tree_widget creates a new SplitTreeWidget. Mirrors the GObject
// `init`: it sets up the widget graph, action group, and basic state.
pub fn new_split_tree_widget(window &Window, config &Config) &SplitTreeWidget {
	tree_bin := C.adw_bin_new()
	widget := C.gtk_box_new(1, 0)
	C.gtk_widget_set_hexpand(GtkWidget(tree_bin), 1)
	C.gtk_widget_set_vexpand(GtkWidget(tree_bin), 1)
	C.gtk_box_append(widget, GtkWidget(tree_bin))
	mut w := &SplitTreeWidget{
		widget: widget
		window: window
		config: config
		tree_bin: tree_bin
	}
	w.pending_close = -1
	w.init_action_map()
	return w
}

// init_action_map registers the "split-tree" action group. Mirrors
// `initActionMap`.
fn (mut self SplitTreeWidget) init_action_map() {
	string_type := C.g_variant_type_new(c's')
	actions := [
		Action.new('new-split', GCallback(voidptr(split_tree_action_new_split_cb)), string_type),
		Action.new('equalize', GCallback(voidptr(split_tree_action_equalize_cb)), unsafe { nil }),
		Action.new('zoom', GCallback(voidptr(split_tree_action_zoom_cb)), unsafe { nil }),
	]
	add_as_group(voidptr(self), self.widget, 'split-tree', actions)
	C.g_variant_type_free(string_type)
}

fn split_tree_action_new_split_cb(action GSimpleAction, parameter GVariant, data voidptr) {
	_ = action
	if isnil(data) || isnil(parameter) {
		return
	}
	mut length := usize(0)
	value := C.g_variant_get_string(parameter, &length)
	if isnil(value) {
		return
	}
	mut self := unsafe { &SplitTreeWidget(data) }
	self.action_new_split(unsafe { cstring_to_vstring(value) })
}

fn split_tree_action_equalize_cb(action GSimpleAction, parameter GVariant, data voidptr) {
	_ = action
	_ = parameter
	if !isnil(data) {
		mut self := unsafe { &SplitTreeWidget(data) }
		self.action_equalize()
	}
}

fn split_tree_action_zoom_cb(action GSimpleAction, parameter GVariant, data voidptr) {
	_ = action
	_ = parameter
	if !isnil(data) {
		mut self := unsafe { &SplitTreeWidget(data) }
		self.action_zoom()
	}
}

// --- Tree get/set ---------------------------------------------------------

// get_tree returns the tree data model, or `none` if empty. Does not clone.
// Mirrors `getTree`.
pub fn (mut self SplitTreeWidget) get_tree() ?&datastruct.SplitTree[SurfaceWidget] {
	if !self.has_tree {
		return none
	}
	return &self.tree
}

// set_tree sets the tree data model. In ghostty this clones the given tree; the
// datastruct tree is ref-counted so we clone to take our own reference. Empty
// trees are normalized to "no tree". Mirrors `setTree`.
pub fn (mut self SplitTreeWidget) set_tree(tree_ ?&datastruct.SplitTree[SurfaceWidget]) {
	// Normalize: empty trees become "no tree".
	mut new_has := false
	mut new_tree := datastruct.SplitTree.empty[SurfaceWidget]()
	if t := tree_ {
		if !t.is_empty() {
			new_tree = t.clone()
			new_has = true
		}
	}

	// Emit the "changed" signal so handlers see both before and after values.
	// TODO(gtk): signals.changed.emit(self, priv.tree, new_tree).

	// Free the old tree (unref its views) and disconnect surface handlers.
	if self.has_tree {
		self.disconnect_surface_handlers()
		self.tree.free()
		self.has_tree = false
	}

	if new_has {
		self.tree = new_tree
		self.has_tree = true
		self.connect_surface_handlers()
	}

	// Ghostty binds SplitTree.is-split to every Surface.is-split. Keep the
	// programmatic widget graph synchronized whenever the immutable tree is
	// replaced, including when the last split is closed.
	is_split := self.get_is_split()
	for mut surface in self.surfaces {
		surface.set_is_split(is_split)
	}

	// TODO(gtk): notifyByPspec(properties.tree).
	self.prop_tree()
	self.sync_tab()
}

// sync_tab replaces the split-tree property notifications consumed by the Tab
// blueprint with a direct update of the owning V wrapper.
fn (self &SplitTreeWidget) sync_tab() {
	if isnil(self.window) {
		return
	}
	mut window := unsafe { self.window }
	for mut tab in window.tabs {
		if tab.split_tree == self {
			tab.prop_split_tree()
			return
		}
	}
}

// --- Derived state (properties) -------------------------------------------

// get_has_surfaces returns whether the tree has any surfaces. Mirrors
// `getHasSurfaces`.
pub fn (self &SplitTreeWidget) get_has_surfaces() bool {
	if !self.has_tree {
		return false
	}
	return !self.tree.is_empty()
}

// get_is_zoomed returns whether the tree has a zoomed node. Mirrors
// `getIsZoomed`.
pub fn (self &SplitTreeWidget) get_is_zoomed() bool {
	if !self.has_tree {
		return false
	}
	return self.tree.zoomed >= 0
}

// get_is_split returns whether the root node is a split. Mirrors `getIsSplit`.
pub fn (self &SplitTreeWidget) get_is_split() bool {
	if !self.has_tree {
		return false
	}
	return self.tree.is_split()
}

// get_needs_confirm_quit returns true if any surface in the tree needs
// confirmation before quitting. Mirrors `getNeedsConfirmQuit`.
pub fn (self &SplitTreeWidget) get_needs_confirm_quit() bool {
	if !self.has_tree {
		return false
	}
	mut it := self.tree.iterator()
	for {
		entry := it.next() or { break }
		mut view := entry.view
		if view.has_core() {
			mut core := view.core()
			if core.needs_confirm_quit() {
				return true
			}
		}
	}
	return false
}

// --- Active surface -------------------------------------------------------

// get_active_surface returns the currently active surface, or `none`. Mirrors
// `getActiveSurface`. Does not ref.
pub fn (mut self SplitTreeWidget) get_active_surface() ?&SurfaceWidget {
	if !self.has_tree {
		return none
	}
	handle := self.get_active_surface_handle() or { return none }
	node := self.tree.nodes[handle]
	if node is datastruct.Leaf[SurfaceWidget] {
		return node.view
	}
	return none
}

// get_active_surface_handle returns the tree handle (node index) of the active
// surface, or `none`. The active surface is the focused surface, falling back
// to the last-focused surface. Mirrors `getActiveSurfaceHandle`.
fn (mut self SplitTreeWidget) get_active_surface_handle() ?int {
	if !self.has_tree {
		return none
	}

	// Prefer the currently-focused surface.
	mut it := self.tree.iterator()
	for {
		entry := it.next() or { break }
		if entry.view.get_focused() {
			return entry.handle
		}
	}

	// Otherwise fall back to the last-focused surface, if it's still in the
	// tree. This keeps background actions (bell etc.) working.
	if !isnil(self.last_focused) {
		mut it2 := self.tree.iterator()
		for {
			entry := it2.next() or { break }
			mut view := entry.view
			if view.eql(self.last_focused) {
				return entry.handle
			}
		}
	}

	return none
}

// get_last_focused_surface returns the last-focused surface in the tree, or
// `none`. Mirrors `getLastFocusedSurface`.
pub fn (self &SplitTreeWidget) get_last_focused_surface() ?&SurfaceWidget {
	if isnil(self.last_focused) {
		return none
	}
	return self.last_focused
}

// get_tree_has_parents returns whether any surface in the tree currently has a
// GTK parent. We can only rebuild the widget tree when every surface has been
// unparented. Mirrors `getTreeHasParents`.
fn (self &SplitTreeWidget) get_tree_has_parents() bool {
	if !self.has_tree {
		return false
	}
	mut it := self.tree.iterator()
	for {
		entry := it.next() or { break }
		w := entry.view.as_widget()
		parent := C.gtk_widget_get_parent(w)
		if !isnil(parent) {
			return true
		}
	}
	return false
}

// --- Mutations ------------------------------------------------------------

// new_split creates a new split in the given direction from the currently
// active surface. If the tree is empty this creates a new tree with a new
// surface (ignoring direction). The `parent_` surface is used as the parent of
// the new surface. Mirrors `newSplit`.
pub fn (mut self SplitTreeWidget) new_split(direction datastruct.Direction, parent_ ?&SurfaceWidget) {
	// Create our new surface.
	mut surface := new_surface_widget(self.window, self, self.config)
	self.surfaces << surface

	// Inherit from the parent if asked to.
	if p := parent_ {
		if p.has_core() {
			surface.set_parent(p.core(), .split)
		}
	}
	surface.set_is_split(self.get_is_split())

	// Create a single-node tree from the new surface.
	single_tree := datastruct.SplitTree.new[SurfaceWidget](surface)

	// Move focus to the new surface no matter what.
	self.last_focused = surface

	// If we have no tree yet, this single tree becomes our tree.
	if !self.has_tree {
		self.set_tree(&single_tree)
		return
	}

	// Split relative to the active surface (root if none).
	handle := self.get_active_surface_handle() or { datastruct.handle_root }

	// Create the split! Always split equally for new splits.
	new_tree := self.tree.split_(handle, direction, 0.5, &single_tree)
	self.set_tree(&new_tree)
}

// resize resizes the active surface's nearest split matching the given
// direction by `amount` pixels. Returns true if a resize happened. Mirrors
// `resize`: it converts the pixel amount into a grid-relative ratio using the
// current pixel dimensions of the tree bin, then delegates to the tree's
// immutable resize.
pub fn (mut self SplitTreeWidget) resize(direction datastruct.Direction, amount u16) bool {
	// Avoid useless work.
	if amount == 0 {
		return false
	}
	if !self.has_tree {
		return false
	}
	active := self.get_active_surface_handle() or { return false }

	// Get the dimensions needed to turn the pixel amount into a percentage.
	bin_widget := GtkWidget(self.tree_bin)
	width := C.gtk_widget_get_width(bin_widget)
	height := C.gtk_widget_get_height(bin_widget)
	if width == 0 || height == 0 {
		return false
	}
	width_f := f64(width)
	height_f := f64(height)
	amount_f := f64(amount)

	// Positive is right/down, negative is left/up.
	ratio := match direction {
		.right { amount_f / width_f }
		.left { -(amount_f / width_f) }
		.down { amount_f / height_f }
		.up { -(amount_f / height_f) }
	}

	layout := match direction {
		.left, .right { datastruct.Layout.horizontal }
		.up, .down { datastruct.Layout.vertical }
	}

	new_tree := self.tree.resize(active, layout, f32(ratio))
	self.set_tree(&new_tree)
	return true
}

// goto_ moves focus from the currently focused surface in the given direction.
// Returns true if focus switched to a new surface. Mirrors `goto`. (Named with
// a trailing underscore to match the datastruct method and avoid the keyword.)
pub fn (mut self SplitTreeWidget) goto_(to datastruct.Goto) bool {
	if !self.has_tree {
		return false
	}
	active := self.get_active_surface_handle() or { return false }

	target := self.tree.goto_(active, to)
	if target < 0 {
		return false
	}

	// If we aren't changing targets then we did nothing.
	if active == target {
		return false
	}

	// Grab focus on the target surface.
	node := self.tree.nodes[target]
	mut surface := &SurfaceWidget(unsafe { nil })
	if node is datastruct.Leaf[SurfaceWidget] {
		surface = node.view
	} else {
		return false
	}
	surface.grab_focus()

	// Record the new last-focused so a subsequent tree change refocuses right.
	self.last_focused = surface

	// Handle zoom preservation on navigation. Witty's pinned configuration
	// currently has no split-preserve-zoom field, so it has Ghostty's default
	// behavior and clears zoom when navigating.
	if self.tree.zoomed >= 0 {
		self.tree.zoom(-1)
		self.prop_tree()
	}

	return true
}

// --- Surface lifecycle wiring ---------------------------------------------

// connect_surface_handlers connects per-surface close/focus/parent handlers.
// Mirrors `connectSurfaceHandlers`.
fn (self &SplitTreeWidget) connect_surface_handlers() {
	// SurfaceWidget owns a direct pointer to this tree and forwards close,
	// focus, and parent changes without crossing an untyped GSignal boundary.
}

// disconnect_surface_handlers disconnects the per-surface handlers.
// Mirrors `disconnectSurfaceHandlers`.
fn (self &SplitTreeWidget) disconnect_surface_handlers() {
	// Direct owner links are stable for the lifetime of the tab.
}

// --- Action handlers ------------------------------------------------------

// action_new_split handles the "split-tree.new-split" action. Mirrors
// `actionNewSplit`. The direction is parsed from the action's string parameter.
pub fn (mut self SplitTreeWidget) action_new_split(dir string) {
	direction := match dir {
		'left' { datastruct.Direction.left }
		'right' { datastruct.Direction.right }
		'down' { datastruct.Direction.down }
		'up' { datastruct.Direction.up }
		else {
			eprintln('invalid split direction for split-tree.new-split: ${dir}')
			return
		}
	}
	self.new_split(direction, self.get_active_surface())
}

// action_equalize handles the "split-tree.equalize" action. Mirrors
// `actionEqualize`.
pub fn (mut self SplitTreeWidget) action_equalize() {
	if !self.has_tree {
		return
	}
	new_tree := self.tree.equalize()
	self.set_tree(&new_tree)
}

// action_zoom handles the "split-tree.zoom" action: toggles the zoom of the
// active surface. Mirrors `actionZoom`.
pub fn (mut self SplitTreeWidget) action_zoom() {
	if !self.has_tree {
		return
	}
	if self.tree.zoomed >= 0 {
		self.tree.zoom(-1)
	} else {
		active := self.get_active_surface_handle() or { return }
		if self.tree.zoomed == active {
			return
		}
		self.tree.zoom(active)
	}
	self.prop_tree()
}

// --- Close handling -------------------------------------------------------

// surface_close_request handles a surface's "close-request" signal. Mirrors
// `surfaceCloseRequest`: records the pending-close handle and either closes
// immediately or shows a confirmation dialog.
pub fn (mut self SplitTreeWidget) surface_close_request(surface &SurfaceWidget) {
	// Reset pending close.
	self.pending_close = -1

	if !self.has_tree {
		return
	}

	// Find the surface in the tree.
	mut found := -1
	mut it := self.tree.iterator()
	for {
		entry := it.next() or { break }
		view := entry.view
		if view.eql(surface) {
			found = entry.handle
			break
		}
	}
	if found < 0 {
		return
	}
	self.pending_close = found

	// If we don't need to confirm, close immediately.
	if surface.has_core() {
		mut core := surface.core()
		if !core.needs_confirm_quit() {
			self.close_confirmation_close()
			return
		}
	} else {
		self.close_confirmation_close()
		return
	}

	mut dialog := close_confirmation_dialog_new(.surface)
	C.g_signal_connect_data(dialog.dialog.obj, c'close-request', GCallback(voidptr(split_tree_close_confirmed_cb)), voidptr(self), unsafe { nil }, 0)
	dialog.present(surface.as_widget())
}

fn split_tree_close_confirmed_cb(dialog GObject, data voidptr) {
	_ = dialog
	if isnil(data) {
		return
	}
	mut self := unsafe { &SplitTreeWidget(data) }
	self.close_confirmation_close()
}

// close_confirmation_close finalizes a pending surface close: it computes the
// next focus target (previous, else next), removes the surface from the tree,
// and sets the new last-focused. Mirrors `closeConfirmationClose`.
pub fn (mut self SplitTreeWidget) close_confirmation_close() {
	handle := self.pending_close
	self.pending_close = -1
	if handle < 0 {
		return
	}
	if !self.has_tree {
		return
	}
	mut closing := &SurfaceWidget(unsafe { nil })
	closing_node := self.tree.nodes[handle]
	if closing_node is datastruct.Leaf[SurfaceWidget] {
		closing = closing_node.view
	}

	// Figure out the next focus target: the "previous" surface unless we're
	// the leftmost, then the "next".
	mut next_focus := &SurfaceWidget(unsafe { nil })
	mut next_handle := self.tree.goto_(handle, datastruct.Goto(datastruct.GotoPrevious{}))
	if next_handle < 0 {
		next_handle = self.tree.goto_(handle, datastruct.Goto(datastruct.GotoNext{}))
	}
	if next_handle >= 0 && next_handle != handle {
		node := self.tree.nodes[next_handle]
		if node is datastruct.Leaf[SurfaceWidget] {
			next_focus = node.view
		}
	}

	// Tear down the core surface before publishing the empty/new tree. An empty
	// tree synchronously closes its tab, so doing this first prevents the tab
	// close path from deinitializing the same surface twice.
	new_tree := self.tree.remove(handle)
	if !isnil(closing) && !isnil(closing.core_surface_ref) && !isnil(closing.app)
		&& !isnil(closing.app.core_app) {
		mut app := unsafe { closing.app.core_app }
		app.delete_surface(closing.core_surface_ref)
		if closing.has_core() {
			mut core_surface := closing.core_surface
			core_surface.deinit()
			closing.core_surface = unsafe { nil }
		}
		for i, candidate in self.surfaces {
			if candidate == closing {
				self.surfaces.delete(i)
				break
			}
		}
	}
	self.set_tree(&new_tree)

	// Grab focus. We set last_focused because focus is set when the tree is
	// redrawn.
	if !isnil(next_focus) {
		self.last_focused = next_focus
	}
}

// deinit_surfaces releases every core surface owned by this tab. It is called
// only after AdwTabView has accepted a page close; detached/moved pages keep
// their surfaces alive.
pub fn (mut self SplitTreeWidget) deinit_surfaces() {
	for mut surface in self.surfaces {
		if isnil(surface) {
			continue
		}
		if !isnil(surface.core_surface_ref) && !isnil(surface.app)
			&& !isnil(surface.app.core_app) {
			mut app := unsafe { surface.app.core_app }
			app.delete_surface(surface.core_surface_ref)
		}
		if surface.has_core() {
			mut core_surface := surface.core_surface
			core_surface.deinit()
			surface.core_surface = unsafe { nil }
			surface.core_surface_ref = unsafe { nil }
		}
	}
	self.surfaces.clear()
	if self.has_tree {
		self.disconnect_surface_handlers()
		self.tree.free()
		self.has_tree = false
	}
}

// --- Focus / parent property handlers -------------------------------------

// prop_surface_focused handles a surface's notify::focused. Mirrors
// `propSurfaceFocused`: records the last-focused surface (never clears it).
pub fn (mut self SplitTreeWidget) prop_surface_focused(mut surface SurfaceWidget) {
	if !surface.get_focused() {
		return
	}
	self.last_focused = &surface
	self.sync_tab()
}

// prop_surface_parent handles a surface's notify::parent. Mirrors
// `propSurfaceParent`: once all surfaces are unparented, schedule the rebuild.
pub fn (mut self SplitTreeWidget) prop_surface_parent() {
	if !self.rebuild_pending {
		return
	}
	if self.get_tree_has_parents() {
		return
	}
	self.rebuild_pending = false
	self.rebuild_source = C.g_idle_add(voidptr(split_tree_rebuild_cb), self)
}

// prop_tree handles our own notify::tree. Mirrors `propTree`: it tears down the
// current bin child (forcing surfaces to unparent) and either rebuilds
// immediately (via an idle source) or waits for all surfaces to be unparented.
fn (mut self SplitTreeWidget) prop_tree() {
	// Cancel any pending rebuild so we start clean.
	if self.rebuild_source != 0 {
		C.g_source_remove(self.rebuild_source)
		self.rebuild_source = 0
	}

	// We need to wait for prior surfaces to lose their parent before adding
	// them to a new one (a GTK GLArea quirk).
	self.rebuild_pending = self.get_tree_has_parents()

	// Reset our bin, forcing prior surfaces to eventually unparent.
	if !isnil(self.tree_bin) {
		C.adw_bin_set_child(self.tree_bin, GtkWidget(unsafe { nil }))
	}
	if self.rebuild_pending {
		self.prop_surface_parent()
	}

	// If nothing needs unparenting, we can rebuild immediately (on idle).
	if !self.rebuild_pending && self.rebuild_source == 0 {
		self.rebuild_source = C.g_idle_add(voidptr(split_tree_rebuild_cb), self)
	}

	// Dependent properties.
	// TODO(gtk): notifyByPspec(properties.has-surfaces / properties.is-zoomed).
}

fn split_tree_rebuild_cb(data voidptr) int {
	if isnil(data) {
		return 0
	}
	mut self := unsafe { &SplitTreeWidget(data) }
	self.on_rebuild()
	return 0
}

// on_rebuild rebuilds the widget tree from the current data model. Mirrors
// `onRebuild`. In ghostty this is a glib idle callback; here it is a plain
// method (the C idle trampoline is stubbed).
pub fn (mut self SplitTreeWidget) on_rebuild() {
	self.rebuild_source = 0

	// Prior to rebuilding, all surfaces must be orphaned.
	if self.get_tree_has_parents() {
		return
	}

	if self.has_tree && !self.tree.is_empty() {
		root := if self.tree.zoomed >= 0 { self.tree.zoomed } else { datastruct.handle_root }
		child := self.build_tree(root)
		if !isnil(self.tree_bin) {
			C.adw_bin_set_child(self.tree_bin, child)
		}
	}

	// Refocus the last-focused surface (GTK resets focus during rebuild).
	if !isnil(self.last_focused) {
		self.last_focused.grab_focus()
	}

	// TODO(gtk): notifyByPspec(properties.is-split / properties.active-surface).
}

// build_tree builds the widget subtree for the node at `current`. Leaves become
// a SurfaceScrolledWindow around the surface; splits become a SplitTreeSplit
// (GtkPaned wrapper) with recursively-built children. Mirrors `buildTree`.
fn (mut self SplitTreeWidget) build_tree(current int) GtkWidget {
	node := self.tree.nodes[current]
	if node is datastruct.Leaf[SurfaceWidget] {
		mut scrolled := new_surface_scrolled_window()
		scrolled.set_surface(node.view)
		self.scrolled_windows << scrolled
		return scrolled.widget
	}
	if node is datastruct.Split {
		start_child := self.build_tree(node.left)
		end_child := self.build_tree(node.right)
		split := new_split_tree_split(self, current, node.layout, start_child, end_child)
		self.splits << split
		return split.widget
	}
	return GtkWidget(unsafe { nil })
}

// --- SplitTreeSplit -------------------------------------------------------

// SplitTreeSplit is the internal-only widget representing a single split in the
// tree. It wraps a gtk.Paned so that we can position the split by ratio (0..1)
// and write the updated ratio back to the tree when the user drags the divider.
// Mirrors the Zig `SplitTreeSplit`.
//
// This is an immutable widget: it isn't meant to be updated after creation.
@[heap]
pub struct SplitTreeSplit {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The handle of the node in the tree that this split represents.
	handle     int
	split_tree &SplitTreeWidget = unsafe { nil }

	// Source to reposition the split when properties change. 0 means none.
	idle u32

	// The gtk.Paned template child.
	paned GtkPaned = unsafe { nil }
}

// new_split_tree_split creates a new SplitTreeSplit for the given node handle,
// layout, and child widgets. Mirrors `SplitTreeSplit.new`.
pub fn new_split_tree_split(split_tree &SplitTreeWidget, handle int, layout datastruct.Layout, start_child GtkWidget, end_child GtkWidget) &SplitTreeSplit {
	orientation := match layout {
		.horizontal { GtkOrientation(0) }
		.vertical { GtkOrientation(1) }
	}
	paned := C.gtk_paned_new(orientation)
	bin := C.adw_bin_new()
	C.gtk_widget_add_css_class(GtkWidget(bin), c'split')
	C.adw_bin_set_child(bin, GtkWidget(paned))
	mut self := &SplitTreeSplit{
		widget: GtkWidget(bin)
		handle: handle
		split_tree: split_tree
		paned: paned
	}

	// Setup our paned fields.
	C.gtk_paned_set_start_child(self.paned, start_child)
	C.gtk_paned_set_end_child(self.paned, end_child)
	C.g_signal_connect_data(self.paned, c'notify::position', GCallback(voidptr(split_tree_split_changed_cb)), voidptr(self), unsafe { nil }, 0)
	C.g_signal_connect_data(self.paned, c'notify::max-position', GCallback(voidptr(split_tree_split_changed_cb)), voidptr(self), unsafe { nil }, 0)
	C.g_signal_connect_data(self.paned, c'notify::min-position', GCallback(voidptr(split_tree_split_changed_cb)), voidptr(self), unsafe { nil }, 0)
	self.refresh()

	return self
}

// refresh schedules an idle reposition of the split. Mirrors `refresh`.
fn (mut self SplitTreeSplit) refresh() {
	if self.idle == 0 {
		self.idle = C.g_idle_add(voidptr(split_tree_split_idle_cb), self)
	}
}

fn split_tree_split_changed_cb(paned GtkPaned, pspec voidptr, data voidptr) {
	_ = paned
	_ = pspec
	if !isnil(data) {
		mut self := unsafe { &SplitTreeSplit(data) }
		self.refresh()
	}
}

fn split_tree_split_idle_cb(data voidptr) int {
	if isnil(data) {
		return 0
	}
	mut self := unsafe { &SplitTreeSplit(data) }
	min := object_int_property(voidptr(self.paned), c'min-position')
	max := object_int_property(voidptr(self.paned), c'max-position')
	pos_set := object_bool_property(voidptr(self.paned), c'position-set')
	self.on_idle(min, max, pos_set)
	return 0
}

fn object_int_property(object voidptr, name &char) int {
	value := C.g_value_init(new_gvalue(), g_type_int)
	defer { C.g_value_unset(value) }
	C.g_object_get_property(GObject(object), name, value)
	return C.g_value_get_int(value)
}

fn object_bool_property(object voidptr, name &char) bool {
	value := C.g_value_init(new_gvalue(), g_type_boolean)
	defer { C.g_value_unset(value) }
	C.g_object_get_property(GObject(object), name, value)
	return C.g_value_get_boolean(value) != 0
}

// on_idle reconciles the paned position with the tree's desired ratio, and
// writes user drags back to the tree. Faithful translation of `onIdle`: the
// pixel<->ratio conversion and the "who wins" logic (desired vs. manual).
//
// `min`, `max`, and `pos_set` are the paned's min-position/max-position/
// position-set properties (read via GObject property getters in ghostty; passed
// in here to keep the arithmetic faithful without the gobject.Value plumbing).
pub fn (mut self SplitTreeSplit) on_idle(min int, max int, pos_set bool) {
	// Our idle source is always over.
	self.idle = 0

	if isnil(self.split_tree) || !self.split_tree.has_tree
		|| self.handle < 0 || self.handle >= self.split_tree.tree.nodes.len {
		return
	}
	node := self.split_tree.tree.nodes[self.handle]
	desired_ratio := if node is datastruct.Split {
		f64(node.ratio)
	} else {
		return
	}

	// We don't actually use min, but assert it's zero as ghostty does.
	if min != 0 {
		return
	}

	// If max is zero we can't do any math (fully-minimized nested split).
	if max == 0 {
		return
	}

	// Determine the current ratio from the paned position.
	pos := C.gtk_paned_get_position(self.paned)
	pos_f := f64(pos)
	max_f := f64(max)
	current_ratio := pos_f / max_f

	// If close enough, ignore the update (avoids constant lossy fp updates).
	if abs_f64(current_ratio - desired_ratio) < 0.001 {
		return
	}

	// If we've never set the position, set it to the desired ratio.
	if !pos_set {
		desired_pos := int(round_f64(max_f * desired_ratio))
		C.gtk_paned_set_position(self.paned, desired_pos)
		return
	}

	// Otherwise this is a manual human update; write it back to the tree.
	self.split_tree.tree.resize_in_place(self.handle, f32(current_ratio))
}

// --- SplitTreeSplit signal handlers ---------------------------------------

// prop_position handles the paned's notify::position. Mirrors `propPosition`.
pub fn (mut self SplitTreeSplit) prop_position() {
	self.refresh()
}

// prop_max_position handles the paned's notify::max-position. Mirrors
// `propMaxPosition`.
pub fn (mut self SplitTreeSplit) prop_max_position() {
	self.refresh()
}

// prop_min_position handles the paned's notify::min-position. Mirrors
// `propMinPosition`.
pub fn (mut self SplitTreeSplit) prop_min_position() {
	self.refresh()
}

// --- SurfaceWidget: datastruct.SplitTree[T] view interface ----------------
//
// The immutable `datastruct.SplitTree[T]` requires its view type `T` to
// implement ref/unref/eql/split_tree_label. `SurfaceWidget` is our `T`, so we
// provide those here. These wrap the GObject refcount and identity/label so the
// tree's clone/free/format logic works.

// ref increments the surface's GObject reference count and returns a new
// reference (a copy of the pointer). Mirrors `Surface.ref` used by the tree.
pub fn (mut self SurfaceWidget) ref() &SurfaceWidget {
	if !isnil(self.widget) {
		object_ref(self.widget)
	}
	return unsafe { &self }
}

// unref decrements the surface's GObject reference count. Mirrors
// `Surface.unref` used by the tree.
pub fn (mut self SurfaceWidget) unref() {
	if !isnil(self.widget) {
		object_unref(self.widget)
	}
}

// eql reports whether two surfaces are the same object. Mirrors the tree's `T`
// equality (pointer identity of the underlying widget).
pub fn (self &SurfaceWidget) eql(other &SurfaceWidget) bool {
	if isnil(other) {
		return false
	}
	return self == other
}

// split_tree_label returns a short debug label for the surface, used by the
// tree's ASCII diagram formatter.
pub fn (self &SurfaceWidget) split_tree_label() string {
	if title := self.title {
		return title
	}
	return 'surface'
}

// --- small numeric helper -------------------------------------------------

// round_f64 rounds to the nearest integer (ties away from zero), matching Zig's
// @round used in the split reposition math.
fn round_f64(v f64) f64 {
	if v < 0 {
		return f64(int(v - 0.5))
	}
	return f64(int(v + 0.5))
}
