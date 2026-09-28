module gtk

import configpkg

fn test_weak_ref_does_not_keep_gobject_alive() {
	mut inner := configpkg.Config.default_config()
	defer {
		inner.deinit()
	}
	mut config := config_new(inner)
	mut weak := weak_ref_empty()
	weak.set(config.obj)

	acquired := weak.get()
	assert acquired == config.obj
	object_unref(acquired)

	config.unref()
	finalized := weak.get()
	assert isnil(finalized)
}
