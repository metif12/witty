module gtk

import apprt
import configpkg
import core

fn test_compute_fraction_clamps_out_of_range_progress() {
	assert compute_fraction(100) == 1.0
	assert compute_fraction(255) == 1.0
	assert compute_fraction(0) == 0.0
	assert compute_fraction(50) == 0.5
}

fn test_source_public_surface_callbacks_are_callable() {
	mut surface := SurfaceWidget{}
	assert surface.core() == none
	assert surface.get_h_adjustment() == none
	assert surface.get_v_adjustment() == none
	assert !surface.show_on_screen_keyboard(none)
	assert surface.control_inspector(.hide)
	assert !surface.child_exited(apprt.ChildExited{})
	assert surface.child_exited

	action_prompt_title(unsafe { nil }, unsafe { nil }, unsafe { nil })
	action_notify_on_next_command_finish(unsafe { nil }, unsafe { nil }, unsafe { nil })
}

fn test_surface_set_config_owns_native_reference() {
	mut cfg := config_new(configpkg.Config{})
	mut weak := weak_ref_empty()
	weak.set(cfg.obj)
	mut surface := SurfaceWidget{}

	surface.set_config(cfg)
	cfg.unref()
	retained := weak.get()
	assert !isnil(retained)
	object_unref(retained)

	// The native property accepts null during teardown; releasing it proves the
	// public setter retained its own reference rather than borrowing the caller.
	surface.set_config_reference(unsafe { nil })
	finalized := weak.get()
	assert isnil(finalized)
	weak.clear()
}

fn test_surface_readonly_notification_uses_core_state() {
	mut core_surface := &core.Surface{
		readonly: true
	}
	mut surface := SurfaceWidget{
		core_surface: core_surface
	}

	// The action payload is only a notification. The canonical state was
	// already changed by core.Surface before this GTK boundary is entered.
	assert surface.set_readonly(.off)
	assert surface.get_readonly()
}
