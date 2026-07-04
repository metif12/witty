module gtk

// search_overlay_linux.v - The GObject SearchOverlay widget class for the GTK
// apprt.
//
// Translated from ghostty/src/apprt/gtk/class/search_overlay.zig.
//
// The search overlay is a draggable `adw.Bin` wrapping a `gtk.SearchEntry`. It
// tracks the active state, the total/selected match counts, and its target
// alignment (which corner of the parent it snaps to after a drag). It emits
// signals (stop-search / search-changed / next-match / previous-match) that the
// owning surface/window connects to drive the actual terminal search.
//
// FOLLOWING THE ESTABLISHED PATTERN: GObject registration, `.ui`/blueprint
// template, and property/signal machinery are stubbed with `// TODO(gtk)`; the
// real search-state logic (active toggle, total/selected tracking, drag-end
// realignment, match-label formatting, Enter/Shift-Enter handling) is
// translated. The class is a plain V struct wrapping the GObject/GtkWidget ptr.
//
// Reuses: `Align` (resize_overlay_linux.v), `GtkWidget` / `GdkEvent` /
// `GtkEventControllerKey` (c_gtk_linux.v / surface_class_linux.v).

// --- New C bindings unique to this file -----------------------------------
//
// GtkSearchEntry / GtkEditable helpers + GtkWidget allocation/parent helpers
// not declared elsewhere. grep-checked to avoid redeclaration.

// GtkSearchEntry*.
pub type GtkSearchEntry = voidptr

// GtkGestureDrag*.
pub type GtkGestureDrag = voidptr

fn C.gtk_editable_select_region(editable GtkWidget, start_pos int, end_pos int)
fn C.gtk_editable_get_text(editable GtkWidget) &char
fn C.gtk_editable_set_text(editable GtkWidget, text &char)
fn C.gtk_widget_get_parent(widget GtkWidget) GtkWidget
fn C.gtk_widget_get_allocated_width(widget GtkWidget) int
fn C.gtk_widget_get_allocated_height(widget GtkWidget) int
fn C.gtk_widget_queue_resize(widget GtkWidget)

// GDK keyvals used to detect Enter (`gdk_key_return` / `gdk_key_kp_enter`) are
// declared in key_linux.v and reused here.

// --- SearchOverlay --------------------------------------------------------

// SearchOverlay is the V model of the `GhosttySearchOverlay` GObject class.
// Fields mirror the Zig `Private` struct. Optional match counts use V's `?u64`
// (Zig's `?usize`).
@[heap]
pub struct SearchOverlay {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The search entry widget (template child).
	search_entry GtkSearchEntry = unsafe { nil }

	// True when a search is active, meaning we should show the overlay.
	active bool

	// Total number of search matches (`none` means unknown/none).
	search_total ?u64

	// Currently selected match index (`none` means none selected).
	search_selected ?u64

	// Target horizontal / vertical alignment for the overlay.
	halign_target Align = .end
	valign_target Align = .start
}

// new_search_overlay creates a new SearchOverlay. Mirrors instance `init`.
pub fn new_search_overlay() &SearchOverlay {
	return &SearchOverlay{}
}

// grab_focus focuses the search entry and selects all its text. Mirrors
// `grabFocus`.
pub fn (self &SearchOverlay) grab_focus() {
	C.gtk_widget_grab_focus(self.search_entry)
	// Select all text: -1 is distance from the end, selecting everything.
	C.gtk_editable_select_region(self.search_entry, 0, -1)
}

// set_search_active sets the active status. When transitioning from inactive to
// active, it re-emits the current search text so the search is (re)run. Mirrors
// `setSearchActive`.
pub fn (mut self SearchOverlay) set_search_active(active bool) {
	if !self.active && active {
		text := self.entry_text()
		self.emit_search_changed(text)
	}
	self.active = active
}

// get_search_active returns the active state. Mirrors `getSearchActive`.
pub fn (self &SearchOverlay) get_search_active() bool {
	return self.active
}

// set_search_contents sets the contents of the search entry and emits a
// search-changed signal. Mirrors `setSearchContents`.
pub fn (mut self SearchOverlay) set_search_contents(content string) {
	C.gtk_editable_set_text(self.search_entry, content.str)
	self.emit_search_changed(content)
}

// set_search_total sets the total number of matches, notifying property changes
// only when the value (or its presence) actually changes. Mirrors
// `setSearchTotal`.
pub fn (mut self SearchOverlay) set_search_total(total ?u64) {
	had_total := self.search_total != none
	if opt_u64_eq(self.search_total, total) {
		return
	}
	self.search_total = total
	// TODO(gtk): notifyByPspec(properties.search-total).
	now_total := total != none
	if had_total != now_total {
		// TODO(gtk): notifyByPspec(properties.has-search-total).
	}
}

// set_search_selected sets the currently selected match index. Mirrors
// `setSearchSelected`.
pub fn (mut self SearchOverlay) set_search_selected(selected ?u64) {
	had_selected := self.search_selected != none
	if opt_u64_eq(self.search_selected, selected) {
		return
	}
	self.search_selected = selected
	// TODO(gtk): notifyByPspec(properties.search-selected).
	now_selected := selected != none
	if had_selected != now_selected {
		// TODO(gtk): notifyByPspec(properties.has-search-selected).
	}
}

// get_search_total returns the total match count (0 if unknown). Mirrors
// `getSearchTotal`.
pub fn (self &SearchOverlay) get_search_total() u64 {
	return self.search_total or { 0 }
}

// get_has_search_total reports whether a total is known. Mirrors
// `getHasSearchTotal`.
pub fn (self &SearchOverlay) get_has_search_total() bool {
	return self.search_total != none
}

// get_search_selected returns the selected match index (0 if none). Mirrors
// `getSearchSelected`.
pub fn (self &SearchOverlay) get_search_selected() u64 {
	return self.search_selected or { 0 }
}

// get_has_search_selected reports whether a match is selected. Mirrors
// `getHasSearchSelected`.
pub fn (self &SearchOverlay) get_has_search_selected() bool {
	return self.search_selected != none
}

// match_label builds the "selected/total" label shown in the overlay. Mirrors
// `closureMatchLabel`: "0/0" when there is no total, otherwise
// "<selected+1>/<total>" (or "0/<total>" when nothing is selected yet).
pub fn (self &SearchOverlay) match_label() string {
	has_total := self.get_has_search_total()
	total := self.get_search_total()
	if !has_total || total == 0 {
		return '0/0'
	}
	numerator := if self.get_has_search_selected() {
		self.get_search_selected() + 1
	} else {
		u64(0)
	}
	return '${numerator}/${total}'
}

// --- Template callbacks ---------------------------------------------------

// entry_text returns the current text of the search entry. Helper used by the
// callbacks (Zig calls `getText()` inline).
fn (self &SearchOverlay) entry_text() string {
	c := C.gtk_editable_get_text(self.search_entry)
	if isnil(c) {
		return ''
	}
	return unsafe { cstring_to_vstring(c) }
}

// search_changed is the "search-changed" template callback on the entry.
// Mirrors `searchChanged`: re-emits the search-changed signal with the entry
// text.
pub fn (mut self SearchOverlay) search_changed() {
	self.emit_search_changed(self.entry_text())
}

// stop_search is the "stop-search" template callback. Mirrors `stopSearch`.
pub fn (self &SearchOverlay) stop_search() {
	// TODO(gtk): emit `stop-search` signal.
}

// next_match is the "next-match" template callback. Mirrors `nextMatch`.
pub fn (self &SearchOverlay) next_match() {
	// TODO(gtk): emit `next-match` signal.
}

// previous_match is the "previous-match" template callback. Mirrors
// `previousMatch`.
pub fn (self &SearchOverlay) previous_match() {
	// TODO(gtk): emit `previous-match` signal.
}

// emit_search_changed emits the "search-changed" signal with the given text.
// Mirrors the `signals.search-changed.impl.emit(...)` calls.
fn (self &SearchOverlay) emit_search_changed(text string) {
	_ = text
	// TODO(gtk): emit `search-changed` signal with text.
}

// search_entry_key_pressed is the "key-pressed" controller callback on the
// entry. On Enter it navigates to the next match (or previous, with Shift) and
// consumes the event. Mirrors `searchEntryKeyPressed`. Returns true when the
// event is handled.
pub fn (self &SearchOverlay) search_entry_key_pressed(keyval u32, keycode u32, gtk_mods u32) bool {
	if keyval == gdk_key_return || keyval == gdk_key_kp_enter {
		mods := translate_mods(gtk_mods)
		if mods.shift {
			self.previous_match()
		} else {
			self.next_match()
		}
		return true
	}
	return false
}

// on_drag_end is the "drag-end" template callback on the drag gesture. On drag
// end we move our halign/valign to whichever corner we crossed into (based on
// the parent midpoints). Mirrors `onDragEnd`.
pub fn (mut self SearchOverlay) on_drag_end(offset_x f64, offset_y f64) {
	parent := C.gtk_widget_get_parent(self.widget)
	if isnil(parent) {
		return
	}

	parent_width := f64(C.gtk_widget_get_allocated_width(parent))
	parent_height := f64(C.gtk_widget_get_allocated_height(parent))
	self_width := f64(C.gtk_widget_get_allocated_width(self.widget))
	self_height := f64(C.gtk_widget_get_allocated_height(self.widget))

	self_x := if self.halign_target == .start { f64(0) } else { parent_width - self_width }
	self_y := if self.valign_target == .start { f64(0) } else { parent_height - self_height }

	new_x := self_x + offset_x + (self_width / 2)
	new_y := self_y + offset_y + (self_height / 2)

	new_halign := if new_x > parent_width / 2 { Align.end } else { Align.start }
	new_valign := if new_y > parent_height / 2 { Align.end } else { Align.start }

	mut changed := false
	if new_halign != self.halign_target {
		self.halign_target = new_halign
		// TODO(gtk): notifyByPspec(properties.halign-target).
		changed = true
	}
	if new_valign != self.valign_target {
		self.valign_target = new_valign
		// TODO(gtk): notifyByPspec(properties.valign-target).
		changed = true
	}

	if changed {
		C.gtk_widget_queue_resize(self.widget)
	}
}

// --- helpers --------------------------------------------------------------

// opt_u64_eq compares two `?u64` for equality, treating `none == none` as true.
fn opt_u64_eq(a ?u64, b ?u64) bool {
	av := a or {
		return b == none
	}
	bv := b or {
		return false
	}
	return av == bv
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty this class is registered via gobject.ext.defineClass.
// classInit loads the `search-overlay` blueprint `.ui` template, binds the
// `search_entry` template child, wires the template callbacks (stop_search,
// search_changed, match_label_closure, next_match, previous_match,
// search_entry_key_pressed, on_drag_end), registers the active / search-total /
// has-search-total / search-selected / has-search-selected / halign-target /
// valign-target properties, registers the stop-search / search-changed /
// next-match / previous-match signals, and wires dispose/finalize. V has no
// such machinery, so all of that is stubbed; the handlers above are plain
// methods instead of C template callbacks.
