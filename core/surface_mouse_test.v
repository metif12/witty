module core

import input
import terminal

fn test_surface_mouse_ignores_unrelated_keys_and_overridden_states() {
	assert SurfaceMouse{
		physical_key: .unidentified
		mouse_shape: .progress
	}.key_to_mouse_shape() == none
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_shape: .progress
		over_link: true
	}.key_to_mouse_shape() == none
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_shape: .progress
		hidden: true
	}.key_to_mouse_shape() == none
}

fn test_surface_mouse_tracking_transitions_use_canonical_types() {
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .default_
	}.key_to_mouse_shape()? == .default_
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .default_
		mods: input.Mods{ shift: true }
	}.key_to_mouse_shape()? == .text
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .default_
		mods: input.Mods{ ctrl: true, super_: true, alt: true, shift: true }
	}.key_to_mouse_shape()? == .crosshair
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .crosshair
		mods: input.Mods{ shift: true }
	}.key_to_mouse_shape()? == .text
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .crosshair
	}.key_to_mouse_shape()? == .default_
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .text
		mods: input.Mods{ ctrl: true, super_: true, alt: true, shift: true }
	}.key_to_mouse_shape()? == .crosshair
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_event: terminal.MouseEvents.x10
		mouse_shape: .text
	}.key_to_mouse_shape()? == .default_
}

fn test_surface_mouse_non_tracking_transitions_use_rectangle_state() {
	assert SurfaceMouse{
		physical_key: .shift_left
		mouse_shape: .text
	}.key_to_mouse_shape()? == .text
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_shape: .text
		mods: input.Mods{ ctrl: true, super_: true, alt: true }
	}.key_to_mouse_shape()? == .crosshair
	assert SurfaceMouse{
		physical_key: .alt_left
		mouse_shape: .crosshair
	}.key_to_mouse_shape()? == .text
}

fn test_rectangle_selection_modifier_contract() {
	assert is_rectangle_select_state(input.Mods{ ctrl: true, super_: true, alt: true })
	assert !is_rectangle_select_state(input.Mods{})
	assert !is_rectangle_select_state(input.Mods{ ctrl: true, super_: true })
}
