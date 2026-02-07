module kitty

// Tests for Kitty graphics protocol image storage.
//
// Source: graphics_storage.zig tests

import terminal

// Helper: create a terminal with given cols and rows.
fn make_terminal(cols u16, rows u16) !terminal.Terminal {
	return terminal.Terminal.init(terminal.Options{ cols: cols, rows: rows })!
}

// Helper: track a pin in the terminal for placement.
// In our simplified model, we just convert active coordinates to a Pin.
fn track_pin(t &terminal.Terminal, x u32, y u32) terminal.Pin {
	return terminal.Pin{
		x: x
		y: u32(t.screens.active.pages.active_start) + y
	}
}

fn test_storage_add_placement_with_zero_placement_id() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 0, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })
	s.add_placement(1, 0, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	assert s.placement_count() == 2
	assert s.image_count() == 2

	// verify the placement is what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .internal, id: 0 }
	}) != none
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .internal, id: 1 }
	}) != none
}

fn test_storage_delete_all_placements_and_images() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .all, data: DeleteData(DeleteAll{ delete: true }) })
	assert s.dirty
	assert s.image_count() == 0
	assert s.placement_count() == 0
}

fn test_storage_delete_all_placements_and_images_preserves_limit() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.total_limit = 5000
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .all, data: DeleteData(DeleteAll{ delete: true }) })
	assert s.dirty
	assert s.image_count() == 0
	assert s.placement_count() == 0
	assert s.total_limit == 5000
}

fn test_storage_delete_all_placements() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .all, data: DeleteData(DeleteAll{ delete: false }) })
	assert s.dirty
	assert s.placement_count() == 0
	assert s.image_count() == 3
}

fn test_storage_delete_all_placements_by_image_id() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .id
		data: DeleteData(DeleteById{ image_id: 2 })
	})
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 3
}

fn test_storage_delete_all_placements_by_image_id_and_unused_images() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .id
		data: DeleteData(DeleteById{ delete: true, image_id: 2 })
	})
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 2
}

fn test_storage_delete_placement_by_specific_id() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .id
		data: DeleteData(DeleteById{
			delete: true
			image_id: 1
			placement_id: 2
		})
	})
	assert s.dirty
	assert s.placement_count() == 2
	assert s.image_count() == 3
}

fn test_storage_delete_intersecting_cursor() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	t.screens.active.cursor_absolute(12, 12)

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .intersect_cursor, data: DeleteData(false) })
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 2

	// verify the placement is what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 2 }
	}) != none
}

fn test_storage_delete_intersecting_cursor_plus_unused() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	t.screens.active.cursor_absolute(12, 12)

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .intersect_cursor, data: DeleteData(true) })
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 2

	// verify the placement is what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 2 }
	}) != none
}

fn test_storage_delete_intersecting_cursor_hits_multiple() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	t.screens.active.cursor_absolute(26, 26)

	s.dirty = false
	s.delete(&t, FullDelete{ kind: .intersect_cursor, data: DeleteData(true) })
	assert s.dirty
	assert s.placement_count() == 0
	assert s.image_count() == 1
}

fn test_storage_delete_by_column() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .column
		data: DeleteData(DeleteColumn{ delete: false, x: 60 })
	})
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 2

	// verify the placement is what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 1 }
	}) != none
}

fn test_storage_delete_by_column_1x1() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 1, height: 1 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 0) }) })
	s.add_placement(1, 3, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 2, 0) }) })

	s.delete(&t, FullDelete{
		kind: .column
		data: DeleteData(DeleteColumn{ delete: false, x: 2 })
	})
	assert s.placement_count() == 2
	assert s.image_count() == 1

	// verify the placements are what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 1 }
	}) != none
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 3 }
	}) != none
}

fn test_storage_delete_by_row() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 50, height: 50 })!
	s.add_image(Image{ id: 2, width: 25, height: 25 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 25, 25) }) })

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .row
		data: DeleteData(DeleteRow{ delete: false, y: 60 })
	})
	assert s.dirty
	assert s.placement_count() == 1
	assert s.image_count() == 2

	// verify the placement is what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 1 }
	}) != none
}

fn test_storage_delete_by_row_1x1() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 100
	t.height_px = 100

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1, width: 1, height: 1 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 0) }) })
	s.add_placement(1, 2, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 1) }) })
	s.add_placement(1, 3, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 0, 2) }) })

	s.delete(&t, FullDelete{
		kind: .row
		data: DeleteData(DeleteRow{ delete: false, y: 2 })
	})
	assert s.placement_count() == 2
	assert s.image_count() == 1

	// verify the placements are what we expect
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 1 }
	}) != none
	assert s.get_placement(PlacementKey{
		image_id: 1
		placement_id: PlacementId{ tag: .external, id: 3 }
	}) != none
}

fn test_storage_delete_images_by_range_1() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	assert s.image_count() == 3
	assert s.placement_count() == 2

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .range
		data: DeleteData(DeleteRange{ delete: false, first: 1, last: 2 })
	})
	assert s.dirty
	assert s.image_count() == 3
	assert s.placement_count() == 0
}

fn test_storage_delete_images_by_range_2() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	assert s.image_count() == 3
	assert s.placement_count() == 2

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .range
		data: DeleteData(DeleteRange{ delete: true, first: 1, last: 2 })
	})
	assert s.dirty
	assert s.image_count() == 1
	assert s.placement_count() == 0
}

fn test_storage_delete_images_by_range_3() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	assert s.image_count() == 3
	assert s.placement_count() == 2

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .range
		data: DeleteData(DeleteRange{ delete: false, first: 1, last: 1 })
	})
	assert s.dirty
	assert s.image_count() == 3
	assert s.placement_count() == 0
}

fn test_storage_delete_images_by_range_4() ! {
	mut t := make_terminal(3, 3)!
	defer {
		t.deinit()
	}

	mut s := ImageStorage{}
	defer {
		s.deinit(t.screens.active)
	}
	s.add_image(Image{ id: 1 })!
	s.add_image(Image{ id: 2 })!
	s.add_image(Image{ id: 3 })!
	s.add_placement(1, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	s.add_placement(2, 1, Placement{ location: PlacementLocation(PlacementPin{ pin: track_pin(&t, 1, 1) }) })
	assert s.image_count() == 3
	assert s.placement_count() == 2

	s.dirty = false
	s.delete(&t, FullDelete{
		kind: .range
		data: DeleteData(DeleteRange{ delete: true, first: 1, last: 1 })
	})
	assert s.dirty
	assert s.image_count() == 1
	assert s.placement_count() == 0
}

fn test_storage_aspect_ratio_calculation() ! {
	mut t := make_terminal(100, 100)!
	defer {
		t.deinit()
	}
	t.width_px = 1000 // 10 px per col
	t.height_px = 2000 // 20 px per row

	// Case 1: Only columns specified
	{
		image := Image{ id: 1, width: 16, height: 9 }
		placement := Placement{
			location: PlacementLocation(PlacementVirtual{})
			columns: 10
			rows: 0
		}

		// Image is 16x9, set to a width of 10 columns, at 10px per column
		// that's 100px width. 100px * (9 / 16) = 56.25, which should round
		// to a height of 56px.
		calc_width, calc_height := placement.calculated_size(image, &t)
		assert calc_width == 100
		assert calc_height == 56
	}

	// Case 2: Only rows specified
	{
		image := Image{ id: 2, width: 16, height: 9 }
		placement := Placement{
			location: PlacementLocation(PlacementVirtual{})
			columns: 0
			rows: 5
		}

		// Image is 16x9, set to a height of 5 rows, at 20px per row that's
		// 100px height. 100px * (16 / 9) = 177.77..., which should round to
		// a width of 178px.
		calc_width, calc_height := placement.calculated_size(image, &t)
		assert calc_width == 178
		assert calc_height == 100
	}
}
