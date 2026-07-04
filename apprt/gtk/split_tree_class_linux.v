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
// As with the other GTK classes in this apprt, V has no GObject
// class-registration or `.ui`-template machinery, and this `gtk` submodule
// CANNOT import witty's root `module main` where the real core `Surface` lives.
// Therefore:
//
//   * The class is modeled as a plain V struct `SplitTreeWidget` that wraps the
//     GObject/GtkWidget pointer and holds the fields that were in the Zig
//     `Private` struct. (The name is `SplitTreeWidget`, not `SplitTree`, to
//     avoid colliding with `datastruct.SplitTree`.)
//   * The surface tree data model (`Surface.Tree` in ghostty) is
//     `datastruct.SplitTree[SurfaceWidget]` here — the same generic immutable
//     tree, parameterized on the local `SurfaceWidget` view type. The
//     `SurfaceWidget` methods that the tree's `T` interface requires
//     (`ref`/`unref`/`eql`/`split_tree_label`) are defined at the bottom of
//     this file.
//   * GObject type registration, signal/property wiring, and `.ui`/blueprint
//     templates are STUBBED with `// TODO(gtk)` and minimal type-checking
//     bodies.
//   * Calls into core surfaces / the application use the `CoreSurface` /
//     `Application` placeholders (the real ones are unimportable here).
//
// What is genuinely TRANSLATED: the tree navigation glue (new_split, resize,
// goto), the active-surface-handle lookup, the has-surfaces / is-zoomed /
// is-split derived state, tree get/set with normalization, the close-request /
// close-confirmation next-focus arithmetic, the rebuild-from-tree widget
// construction (build_tree), and the SplitTreeSplit paned<->ratio conversion
// (the pixel<->ratio math in on_idle). The GObject template/signal machinery is
// stubbed.

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

// AdwBin
fn C.adw_bin_set_child(bin AdwBin, child GtkWidget)

// GtkWidget extra helpers (not declared elsewhere in the module)
fn C.gtk_widget_get_parent(widget GtkWidget) GtkWidget

// GLib idle source
fn C.g_idle_add(function voidptr, data voidptr) u32

// --- SurfaceTree alias -----------------------------------------------------

// SurfaceTree is the surface split-tree data model. In ghostty this is
// `Surface.Tree` (a `SplitTree(*Surface)`); here it is the same immutable tree
// data structure parameterized on the local `SurfaceWidget` view type.
pub type SurfaceTree = datastruct.SplitTree[SurfaceWidget]

// --- SplitTreeWidget ------------------------------------------------------

// SplitTreeWidget is the V model of the `GhosttySplitTree` GObject class. It
// wraps the GObject/GtkWidget pointer and carries the state that lived in the
// Zig `Private` struct. The GObject/template machinery it would normally
// register is stubbed (see the class-registration TODO block at the end).
@[heap]
pub struct SplitTreeWidget {
pub mut:
	// The GtkWidget (gtk.Box) pointer for this instance.
	widget GtkWidget = unsafe { nil }

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
}

// --- Construction ---------------------------------------------------------

// new_split_tree_widget creates a new SplitTreeWidget. Mirrors the GObject
// `init`: it sets up basic state (actions/template wiring is stubbed).
pub fn new_split_tree_widget() &SplitTreeWidget {
	mut w := &SplitTreeWidget{}
	w.pending_close = -1
	w.init_action_map()
	return w
}

// init_action_map registers the "split-tree" action group. Mirrors
// `initActionMap`. The gio.SimpleAction callbacks are the methods below; here
// we register no-op placeholders because the C-callback trampoline machinery
// is out of scope.
fn (mut self SplitTreeWidget) init_action_map() {
	// TODO(gtk): build the [new-split, equalize, zoom] Action set and
	// ext.actions.add_as_group(self, self.widget, "split-tree", ...). The
	// action callbacks are action_new_split / action_equalize / action_zoom.
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

	// TODO(gtk): notifyByPspec(properties.tree).
	self.prop_tree()
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
	mut surface := new_surface_widget()

	// Inherit from the parent if asked to.
	if p := parent_ {
		if p.has_core() {
			// TODO(gtk): surface.set_parent(p.core(), .split).
		}
	}

	// TODO(gtk): bind the "is-split" property of the new surface to ours.

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

	// Handle zoom preservation on navigation.
	if self.tree.zoomed >= 0 {
		// TODO(gtk): honor config.@"split-preserve-zoom".navigation. Default
		// (no preservation) clears zoom on navigation.
		self.tree.zoom(-1)

		// TODO(gtk): notifyByPspec(properties.tree / properties.is-zoomed) to
		// trigger a relayout.
	}

	return true
}

// --- Surface signal wiring (stubs) ----------------------------------------

// connect_surface_handlers connects per-surface close/focus/parent handlers.
// Mirrors `connectSurfaceHandlers`.
fn (self &SplitTreeWidget) connect_surface_handlers() {
	// TODO(gtk): for each surface, connect Surface "close-request" ->
	// surface_close_request, notify::focused -> prop_surface_focused, and
	// notify::parent -> prop_surface_parent.
}

// disconnect_surface_handlers disconnects the per-surface handlers.
// Mirrors `disconnectSurfaceHandlers`.
fn (self &SplitTreeWidget) disconnect_surface_handlers() {
	// TODO(gtk): g_signal_handlers_disconnect_matched for each surface, keyed
	// on `self` as user data.
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
	// TODO(gtk): notifyByPspec(properties.tree).
}

// --- Close handling -------------------------------------------------------

// surface_close_request handles a surface's "close-request" signal. Mirrors
// `surfaceCloseRequest`: records the pending-close handle and either closes
// immediately or shows a confirmation dialog.
pub fn (mut self SplitTreeWidget) surface_close_request(mut surface SurfaceWidget) {
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
		mut view := entry.view
		if view.eql(&surface) {
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

	// TODO(gtk): show a CloseConfirmationDialog(.surface) and connect its
	// "close-request" to close_confirmation_close.
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

	// Remove it from the tree.
	new_tree := self.tree.remove(handle)
	self.set_tree(&new_tree)

	// Grab focus. We set last_focused because focus is set when the tree is
	// redrawn.
	if !isnil(next_focus) {
		self.last_focused = next_focus
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
	// TODO(gtk): notifyByPspec(properties.active-surface).
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
	self.rebuild_source = C.g_idle_add(unsafe { nil }, self)
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

	// If nothing needs unparenting, we can rebuild immediately (on idle).
	if !self.rebuild_pending && self.rebuild_source == 0 {
		self.rebuild_source = C.g_idle_add(unsafe { nil }, self)
	}

	// Dependent properties.
	// TODO(gtk): notifyByPspec(properties.has-surfaces / properties.is-zoomed).
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
		// TODO(gtk): wrap in a SurfaceScrolledWindow. For now return the
		// surface widget directly.
		return node.view.widget
	}
	if node is datastruct.Split {
		start_child := self.build_tree(node.left)
		end_child := self.build_tree(node.right)
		split := new_split_tree_split(current, node.layout, start_child, end_child)
		return split.widget
	}
	return GtkWidget(unsafe { nil })
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty, the class is registered via
// gobject.ext.defineClass(...) with an instanceInit (init), classInit
// (Class.init), and a Private struct. classInit loads the "split-tree"
// blueprint `.ui` template, binds the `tree_bin` template child, binds the
// `notify_tree` template callback (-> prop_tree), and registers the
// active-surface / has-surfaces / is-zoomed / tree / is-split properties and
// the "changed" signal, plus dispose/finalize virtual methods.
//
// V has no such machinery, so all of that is stubbed. The handlers above are
// plain methods rather than C template callbacks.

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
	handle int

	// Source to reposition the split when properties change. 0 means none.
	idle u32

	// The gtk.Paned template child.
	paned GtkPaned = unsafe { nil }
}

// new_split_tree_split creates a new SplitTreeSplit for the given node handle,
// layout, and child widgets. Mirrors `SplitTreeSplit.new`.
pub fn new_split_tree_split(handle int, layout datastruct.Layout, start_child GtkWidget, end_child GtkWidget) &SplitTreeSplit {
	mut self := &SplitTreeSplit{}
	self.handle = handle

	// Setup our paned fields.
	if !isnil(self.paned) {
		C.gtk_paned_set_start_child(self.paned, start_child)
		C.gtk_paned_set_end_child(self.paned, end_child)
		orientation := match layout {
			.horizontal { GtkOrientation(0) }
			.vertical { GtkOrientation(1) }
		}
		C.gtk_paned_set_orientation(self.paned, orientation)
	}

	return self
}

// refresh schedules an idle reposition of the split. Mirrors `refresh`.
fn (mut self SplitTreeSplit) refresh() {
	if self.idle == 0 {
		self.idle = C.g_idle_add(unsafe { nil }, self)
	}
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

	// Find our SplitTree ancestor and the split node this widget represents.
	// TODO(gtk): get_ancestor(SplitTreeWidget) + look up the split node. We
	// need the tree to read the desired ratio; without the ancestor lookup
	// wired, we can't proceed, so bail. The math below documents the intent.
	desired_ratio := f64(0.5) // TODO(gtk): read from tree.nodes[handle].split.ratio

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
	// TODO(gtk): tree.resize_in_place(handle, f32(current_ratio)).
}

// --- SplitTreeSplit signal handlers (stubs) -------------------------------

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

// --- CoreSurface: needs_confirm_quit --------------------------------------

// needs_confirm_quit reports whether the surface has a running process that
// requires confirmation before closing. Mirrors `CoreSurface.needsConfirmQuit`.
// Placeholder: the real logic lives on `main.Surface` (unimportable here).
pub fn (self &CoreSurface) needs_confirm_quit() bool {
	return false
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
