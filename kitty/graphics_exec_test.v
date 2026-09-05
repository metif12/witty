module kitty

import terminal

fn make_graphics_terminal() !terminal.Terminal {
	mut t := terminal.Terminal.init(terminal.Options{
		rows: 5
		cols: 5
	})!
	t.width_px = 50
	t.height_px = 100
	return t
}

fn test_graphics_execute_persists_transmitted_image() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	cmd := Parser.parse_string('a=t,f=24,t=d,i=1,s=1,v=1;////')!
	response := execute(mut t, &cmd) or { panic('expected transmit response') }
	assert response.ok()
	assert response.id == 1

	storage := terminal_storage(&t) or { panic('expected image storage') }
	assert storage.image_count() == 1
	image := storage.image_by_id(1) or { panic('expected transmitted image') }
	assert image.data == [u8(255), 255, 255]
}

fn test_graphics_execute_chunked_quiet_inheritance() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	// The first chunk suppresses successful responses with q=1.
	first := Parser.parse_string('a=t,f=24,t=d,i=1,s=1,v=2,m=1,q=1;////')!
	assert execute(mut t, &first) == none
	storage_loading := terminal_storage(&t) or { panic('expected image storage') }
	assert storage_loading.loading != none

	// With q omitted, the final chunk inherits q=1 from the first chunk.
	last := Parser.parse_string('m=0;////')!
	assert execute(mut t, &last) == none
	storage := terminal_storage(&t) or { panic('expected image storage') }
	assert storage.loading == none
	image := storage.image_by_id(1) or { panic('expected completed image') }
	assert image.data.len == 6
}

fn test_graphics_execute_chunked_q0_responds_on_final_chunk() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	first := Parser.parse_string('a=t,f=24,t=d,s=1,v=2,c=10,r=1,m=1,i=1,q=0;////')!
	assert execute(mut t, &first) == none

	last := Parser.parse_string('m=0;////')!
	response := execute(mut t, &last) or { panic('expected final response') }
	assert response.ok()
}

fn test_graphics_execute_chunk_can_increase_quiet_level() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	first := Parser.parse_string('a=t,f=24,t=d,s=1,v=2,c=10,r=1,m=1,i=1,q=0;////')!
	assert execute(mut t, &first) == none

	last := Parser.parse_string('m=0,q=1;////')!
	assert execute(mut t, &last) == none
}

fn test_graphics_execute_defaults_to_rgba() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	cmd := Parser.parse_string('a=t,t=d,i=1,s=1,v=2,c=10,r=1;///////////')!
	response := execute(mut t, &cmd) or { panic('expected transmit response') }
	assert response.ok()
	storage := terminal_storage(&t) or { panic('expected image storage') }
	image := storage.image_by_id(1) or { panic('expected transmitted image') }
	assert image.format == .rgba
}

fn test_graphics_execute_accepts_extreme_protocol_integers() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	max_id := Parser.parse_string('a=p,i=4294967295')!
	max_id_response := execute(mut t, &max_id) or { panic('expected display error') }
	assert !max_id_response.ok()
	assert max_id_response.message == 'ENOENT: image not found'

	min_z := Parser.parse_string('a=p,i=1,z=-2147483648')!
	min_z_response := execute(mut t, &min_z) or { panic('expected display error') }
	assert !min_z_response.ok()
	assert min_z_response.message == 'ENOENT: image not found'
}

fn test_graphics_execute_implicit_transmits_do_not_respond() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := Parser.parse_string('a=t,f=24,t=d,s=1,v=2,c=10,r=1,i=0,I=0;////////')!
	assert execute(mut t, &transmit) == none

	transmit_display := Parser.parse_string('a=T,f=24,t=d,s=1,v=2,c=10,r=1,i=0,I=0;////////')!
	assert execute(mut t, &transmit_display) == none
}

fn test_graphics_quiet_inheritance_only_applies_to_transmissions() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	base := Parser.parse_string('a=t,f=24,t=d,i=1,s=1,v=1;////')!
	assert (execute(mut t, &base) or { panic('expected base response') }).ok()
	first_chunk := Parser.parse_string('a=t,f=24,t=d,i=2,s=1,v=2,m=1,q=1;////')!
	assert execute(mut t, &first_chunk) == none

	// A display issued while another image is loading uses its own q=0; it
	// must not inherit the in-progress transmission's q=1.
	display := Parser.parse_string('a=p,i=1,p=3,c=1,r=1,C=1')!
	response := execute(mut t, &display) or { panic('expected display response') }
	assert response.ok()
	assert response.id == 1
}

fn test_graphics_execute_display_and_delete_use_persistent_storage() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := Parser.parse_string('a=t,f=24,t=d,i=7,s=1,v=1;////')!
	assert (execute(mut t, &transmit) or { panic('expected transmit response') }).ok()

	display := Parser.parse_string('a=p,i=7,p=9,c=1,r=1,C=1')!
	display_response := execute(mut t, &display) or { panic('expected display response') }
	assert display_response.ok()
	assert display_response.id == 7
	storage_after_display := terminal_storage(&t) or { panic('expected image storage') }
	assert storage_after_display.placement_count() == 1

	delete_cmd := Parser.parse_string('a=d,d=I,i=7')!
	assert execute(mut t, &delete_cmd) == none
	storage_after_delete := terminal_storage(&t) or { panic('expected image storage') }
	assert storage_after_delete.placement_count() == 0
	assert storage_after_delete.image_count() == 0
}

fn test_graphics_execute_respects_disabled_storage() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}
	set_terminal_storage_limit(mut t, 0)

	query := Parser.parse_string('a=q,f=24,t=d,i=1,s=1,v=1;////')!
	assert execute(mut t, &query) == none
	storage := terminal_storage(&t) or { panic('expected disabled storage') }
	assert !storage.enabled()
	assert storage.image_count() == 0
}

fn test_graphics_storage_follows_screen_reset_and_switch_lifecycle() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := Parser.parse_string('a=t,f=24,t=d,i=1,s=1,v=1;////')!
	assert (execute(mut t, &transmit) or { panic('expected transmit response') }).ok()
	mut primary_storage := terminal_storage(&t) or { panic('expected primary storage') }
	assert primary_storage.image_count() == 1

	// DEC RIS clears images but preserves the screen's configured limit and
	// leaves the renderer-facing dirty bit set.
	t.screens.active.reset()
	primary_storage = terminal_storage(&t) or { panic('expected reset storage') }
	assert primary_storage.image_count() == 0
	assert primary_storage.total_limit == t.kitty_image_limit
	assert primary_storage.dirty

	primary_storage.dirty = false
	t.switch_screen(.alternate)!
	t.switch_screen(.primary)!
	primary_storage = terminal_storage(&t) or { panic('expected switched primary storage') }
	assert primary_storage.dirty
}

fn test_graphics_storage_follows_terminal_clear_and_scroll_lifecycle() ! {
	mut t := make_graphics_terminal()!
	defer {
		deinit_terminal_storage(mut t)
		t.deinit()
	}

	transmit := Parser.parse_string('a=t,f=24,t=d,i=1,s=1,v=1;////')!
	assert (execute(mut t, &transmit) or { panic('expected transmit response') }).ok()
	display := Parser.parse_string('a=p,i=1,p=1,c=1,r=1,C=1')!
	assert (execute(mut t, &display) or { panic('expected display response') }).ok()
	mut storage := terminal_storage(&t) or { panic('expected storage') }
	assert storage.image_count() == 1
	assert storage.placement_count() == 1

	storage.dirty = false
	t.screens.active.scroll(terminal.ScrollTop{})
	assert storage.dirty

	t.erase_display(.complete, false)
	storage = terminal_storage(&t) or { panic('expected storage after clear') }
	assert storage.placement_count() == 0
	assert storage.image_count() == 0
	assert storage.dirty
}
