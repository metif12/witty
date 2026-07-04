module gtk

// key_state_overlay_linux.v - The GObject KeyStateOverlay widget class for the
// GTK apprt.
//
// Translated from ghostty/src/apprt/gtk/class/key_state_overlay.zig.
//
// An overlay that displays the current key-table stack and the pending
// key-sequence, so users can see what key bindings are active and which keys
// they've pressed in a multi-key sequence. It is a draggable `adw.Bin` that
// snaps between top-center and bottom-center of its parent (horizontal
// alignment is always center for this overlay).
//
// FOLLOWING THE ESTABLISHED PATTERN: GObject registration, `.ui`/blueprint
// template, and property/signal machinery are stubbed with `// TODO(gtk)`; the
// real state logic (tables/sequence StringLists, has-* derivations, the
// chevron/has-state/text closures, and the drag-end vertical realignment) is
// translated. The class is a plain V struct wrapping the GObject/GtkWidget ptr.
//
// Reuses: `Align` (resize_overlay_linux.v), `StringList` (ext_slice_linux.v),
// `GtkWidget` (c_gtk_linux.v). GtkWidget allocation/parent/queue-resize C
// helpers are declared in search_overlay_linux.v and reused here.

// --- KeyStateOverlay ------------------------------------------------------

// KeyStateOverlay is the V model of the `GhosttyKeyStateOverlay` GObject class.
// Fields mirror the Zig `Private` struct. The Zig `?*ext.StringList` optionals
// are modeled as `&StringList` that may be nil.
@[heap]
pub struct KeyStateOverlay {
pub mut:
	// The GtkWidget (adw.Bin) pointer for this instance.
	widget GtkWidget = unsafe { nil }

	// The key-table stack. nil means "unset".
	tables &StringList = unsafe { nil }

	// The pending key sequence. nil means "unset".
	sequence &StringList = unsafe { nil }

	// Target vertical alignment for the overlay (top vs bottom center).
	valign_target Align = .end
}

// new_key_state_overlay creates a new KeyStateOverlay. Mirrors instance `init`.
pub fn new_key_state_overlay() &KeyStateOverlay {
	return &KeyStateOverlay{}
}

// --- Property getters/setters ---------------------------------------------

// get_tables returns the key-table StringList. Mirrors `getTables`.
pub fn (self &KeyStateOverlay) get_tables() &StringList {
	return self.tables
}

// get_sequence returns the key-sequence StringList. Mirrors `getSequence`.
pub fn (self &KeyStateOverlay) get_sequence() &StringList {
	return self.sequence
}

// set_tables replaces the key-table StringList, destroying the old one (which
// this object owns). Mirrors `setTables`.
pub fn (mut self KeyStateOverlay) set_tables(value &StringList) {
	if !isnil(self.tables) {
		mut old := self.tables
		old.destroy()
		self.tables = unsafe { nil }
	}
	if !isnil(value) {
		unsafe {
			self.tables = value
		}
	}
	// TODO(gtk): notifyByPspec(properties.tables) + (properties.has-tables).
}

// set_sequence replaces the key-sequence StringList, destroying the old one.
// Mirrors `setSequence`.
pub fn (mut self KeyStateOverlay) set_sequence(value &StringList) {
	if !isnil(self.sequence) {
		mut old := self.sequence
		old.destroy()
		self.sequence = unsafe { nil }
	}
	if !isnil(value) {
		unsafe {
			self.sequence = value
		}
	}
	// TODO(gtk): notifyByPspec(properties.sequence) + (properties.has-sequence).
}

// get_has_tables reports whether there is at least one key table. Mirrors
// `getHasTables`.
pub fn (self &KeyStateOverlay) get_has_tables() bool {
	if isnil(self.tables) {
		return false
	}
	return self.tables.strings.len > 0
}

// get_has_sequence reports whether there is a pending key sequence. Mirrors
// `getHasSequence`.
pub fn (self &KeyStateOverlay) get_has_sequence() bool {
	if isnil(self.sequence) {
		return false
	}
	return self.sequence.strings.len > 0
}

// --- Closures (label/visibility helpers) ----------------------------------

// show_chevron reports whether the separating chevron should be shown (only
// when BOTH tables and a sequence are present). Mirrors `closureShowChevron`.
pub fn (self &KeyStateOverlay) show_chevron(has_tables bool, has_sequence bool) bool {
	return has_tables && has_sequence
}

// has_state reports whether the overlay has anything to show at all. Mirrors
// `closureHasState`.
pub fn (self &KeyStateOverlay) has_state(has_tables bool, has_sequence bool) bool {
	return has_tables || has_sequence
}

// tables_text joins the key-table stack with " > " separators, or `none` if
// there are no tables. Mirrors `closureTablesText`.
pub fn (self &KeyStateOverlay) tables_text(list &StringList) ?string {
	if isnil(list) {
		return none
	}
	if list.strings.len == 0 {
		return none
	}
	mut sb := ''
	for i, s in list.strings {
		if i > 0 {
			sb += ' > '
		}
		sb += s
	}
	return sb
}

// sequence_text joins the pending key sequence with " " separators, or `none`
// if there is no sequence. Mirrors `closureSequenceText`.
pub fn (self &KeyStateOverlay) sequence_text(list &StringList) ?string {
	if isnil(list) {
		return none
	}
	if list.strings.len == 0 {
		return none
	}
	mut sb := ''
	for i, s in list.strings {
		if i > 0 {
			sb += ' '
		}
		sb += s
	}
	return sb
}

// --- Template callbacks ---------------------------------------------------

// on_drag_end is the "drag-end" template callback on the drag gesture. The key
// state overlay only moves between top-center and bottom-center; horizontal
// alignment is always center. Mirrors `onDragEnd`.
pub fn (mut self KeyStateOverlay) on_drag_end(offset_y f64) {
	parent := C.gtk_widget_get_parent(self.widget)
	if isnil(parent) {
		return
	}

	parent_height := f64(C.gtk_widget_get_allocated_height(parent))
	self_height := f64(C.gtk_widget_get_allocated_height(self.widget))

	self_y := if self.valign_target == .start { f64(0) } else { parent_height - self_height }
	new_y := self_y + offset_y + (self_height / 2)

	new_valign := if new_y > parent_height / 2 { Align.end } else { Align.start }

	if new_valign != self.valign_target {
		self.valign_target = new_valign
		// TODO(gtk): notifyByPspec(properties.valign-target).
		C.gtk_widget_queue_resize(self.widget)
	}
}

// --- Virtual methods ------------------------------------------------------

// finalize releases the owned StringLists. Mirrors the `finalize` virtual
// method.
pub fn (mut self KeyStateOverlay) finalize() {
	if !isnil(self.tables) {
		mut t := self.tables
		t.destroy()
	}
	if !isnil(self.sequence) {
		mut s := self.sequence
		s.destroy()
	}
	// TODO(gtk): chain up to parent finalize.
}

// --- GObject class registration (stub) ------------------------------------
//
// TODO(gtk): In ghostty this class is registered via gobject.ext.defineClass.
// classInit loads the `key-state-overlay` blueprint `.ui` template, wires the
// template callbacks (on_drag_end, show_chevron, has_state, tables_text,
// sequence_text), registers the tables / has-tables / sequence / has-sequence /
// valign-target properties, and wires dispose/finalize. V has no such
// machinery, so all of that is stubbed; the handlers above are plain methods
// instead of C template callbacks.
