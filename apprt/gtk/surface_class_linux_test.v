module gtk

import apprt

fn test_compute_fraction_clamps_out_of_range_progress() {
	assert compute_fraction(100) == 1.0
	assert compute_fraction(255) == 1.0
	assert compute_fraction(0) == 0.0
	assert compute_fraction(50) == 0.5
}

fn test_source_public_surface_callbacks_are_callable() {
	mut surface := SurfaceWidget{}
	assert !surface.child_exited(apprt.ChildExited{})
	assert surface.child_exited

	action_prompt_title(unsafe { nil }, unsafe { nil }, unsafe { nil })
	action_notify_on_next_command_finish(unsafe { nil }, unsafe { nil }, unsafe { nil })
}
