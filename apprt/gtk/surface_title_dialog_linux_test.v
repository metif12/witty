module gtk

fn test_surface_title_dialog_initial_value_property() {
	if !C.gtk_init_check() {
		eprintln('skipping: GTK could not open a display')
		return
	}
	C.adw_init()

	mut dialog := surface_title_dialog_new(none)
	assert dialog.get_initial_value() == none

	dialog.set_initial_value('first title')
	assert dialog.get_initial_value() or { '' } == 'first title'
	dialog.set_initial_value('replacement')
	assert dialog.get_initial_value() or { '' } == 'replacement'
	dialog.set_initial_value(none)
	assert dialog.get_initial_value() == none

	mut weak := weak_ref_empty()
	weak.set(dialog.obj)
	dialog.unref()
	finalized := weak.get()
	assert isnil(finalized)
	weak.clear()
}
