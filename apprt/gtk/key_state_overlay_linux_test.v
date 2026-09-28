module gtk

fn test_key_state_overlay_optional_properties_and_native_lifetime() {
	// The overlay is a real GTK widget. Skip only when the test process has no
	// display, as the other GTK object-lifecycle tests do.
	if !C.gtk_init_check() {
		eprintln('skipping: GTK could not open a display')
		return
	}
	C.adw_init()

	mut overlay := new_key_state_overlay()
	assert overlay.get_tables() == none
	assert overlay.get_sequence() == none
	assert !overlay.get_has_tables()
	assert !overlay.get_has_sequence()

	tables := StringList.create(['base', 'copy'])
	sequence := StringList.create(['ctrl+x', 'c'])
	overlay.set_tables(tables)
	overlay.set_sequence(sequence)
	assert (overlay.get_tables() or { panic('missing tables') }).strings == ['base', 'copy']
	assert (overlay.get_sequence() or { panic('missing sequence') }).strings == [
		'ctrl+x',
		'c',
	]
	assert overlay.get_has_tables()
	assert overlay.get_has_sequence()

	overlay.set_tables(none)
	overlay.set_sequence(none)
	assert overlay.get_tables() == none
	assert overlay.get_sequence() == none

	mut weak := weak_ref_empty()
	weak.set(GObject(overlay.widget))
	overlay.unref()
	finalized := weak.get()
	assert isnil(finalized)
}
