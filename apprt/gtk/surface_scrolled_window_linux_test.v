module gtk

import configpkg

fn test_surface_scrolled_window_scrollbar_policy_tracks_bound_config() {
	mut inner := configpkg.Config.default_config()
	inner.scrollbar = .system
	mut cfg := config_new(inner)
	mut scrolled := &SurfaceScrolledWindow{}

	assert scrolled.scrollbar_policy() == .automatic
	scrolled.set_config_reference(cfg)
	assert scrolled.scrollbar_policy() == .automatic
	assert surface_scrolled_window_scrollbar_policy_cb(unsafe { nil }, cfg.obj) == int(PolicyType.automatic)

	cfg.get_mut().scrollbar = .never
	assert scrolled.scrollbar_policy() == .never
	assert surface_scrolled_window_scrollbar_policy_cb(unsafe { nil }, cfg.obj) == int(PolicyType.never)

	scrolled.dispose()
	cfg.unref()
}

fn test_surface_scrolled_window_set_surface_updates_wrapper_state() {
	mut scrolled := &SurfaceScrolledWindow{}
	surface := &SurfaceWidget{}

	scrolled.set_surface(surface)
	assert scrolled.get_surface() == surface

	scrolled.set_surface(none)
	assert isnil(scrolled.get_surface())
}
