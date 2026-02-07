module kitty

// Kitty graphics protocol execution.
//
// Source: kitty/graphics_exec.zig
//
// Executes Kitty graphics commands against the terminal state. This
// handles query, transmit, display, and delete operations, and manages
// the quiet settings for controlling responses.

import terminal

// Execute a Kitty graphics command against the given terminal. This
// will never fail, but the response may indicate an error and the
// terminal state may not be updated to reflect the command. This will
// never put the terminal in an unrecoverable state, however.
//
// The allocator must be the same allocator that was used to build
// the command.
pub fn execute(mut t terminal.Terminal, cmd &Command) ?Response {
	// If storage is disabled then we disable the full protocol. This means
	// we don't even respond to queries so the terminal completely acts as
	// if this feature is not supported.
	if !t.screens.active.kitty_images.enabled() {
		return none
	}

	// The quiet settings used to control the response. We have to make this
	// a var because in certain special cases (namely chunked transmissions)
	// this can change.
	mut quiet := cmd.quiet

	resp_ := match cmd.control {
		Transmission {
			tr := cmd.control as Transmission
			if tr.is_query {
				// Query
				?Response(exec_query(cmd))
			} else {
				// Transmit
				// If we're transmitting, then our `q` setting value is complicated.
				// The `q` setting inherits the value from the starting command
				// unless `q` is set >= 1 on this command.
				storage := &t.screens.active.kitty_images
				if loading := storage.loading {
					match cmd.quiet {
						.no {
							// q=0 we use whatever the start command value is
							quiet = loading.quiet
						}
						.ok, .failures {
							// q>=1 we use the new value
							loading.quiet = cmd.quiet
						}
					}
				}
				?Response(exec_transmit(mut t, cmd))
			}
		}
		TransmitAndDisplay {
			// Transmit and display
			storage := &t.screens.active.kitty_images
			if loading := storage.loading {
				match cmd.quiet {
					.no {
						quiet = loading.quiet
					}
					.ok, .failures {
						loading.quiet = cmd.quiet
					}
				}
			}
			?Response(exec_transmit(mut t, cmd))
		}
		Display {
			?Response(exec_display(mut t, cmd))
		}
		FullDelete {
			?Response(exec_delete(mut t, cmd))
		}
		AnimationFrameLoading, AnimationControl, AnimationFrameComposition {
			// Animation actions are not yet implemented.
			?Response(Response{ message: 'ERROR: unimplemented action' })
		}
	}

	// Handle the quiet settings
	if resp := resp_ {
		if !resp.ok() {
			// Log erroneous response (would be log.warn in full impl)
			_ = resp.message
		}

		return match quiet {
			.no {
				if resp.empty() { ?Response(none) } else { ?Response(resp) }
			}
			.ok {
				if resp.ok() { ?Response(none) } else { ?Response(resp) }
			}
			.failures {
				?Response(none)
			}
		}
	}

	return none
}

// Execute a "query" command.
//
// This command is used to attempt to load an image and respond with
// success/error but does not persist any of the command to the terminal
// state.
fn exec_query(cmd &Command) Response {
	t := cmd.transmission() or {
		return Response{ message: 'EINVAL: no transmission data' }
	}

	// Query requires image ID. We can't actually send a response without
	// an image ID either but we return an error and this will be logged
	// downstream.
	if t.image_id == 0 {
		return Response{ message: 'EINVAL: image ID required' }
	}

	// Build a partial response to start.
	mut result := Response{
		id: t.image_id
		image_number: t.image_number
		placement_id: t.placement_id
	}

	// Attempt to load the image. If we cannot, then set an appropriate error.
	mut loading := LoadingImage.init_from_cmd(cmd) or {
		encode_error(mut result, err.msg())
		return result
	}
	loading.destroy()

	return result
}

// Transmit image data.
//
// This loads the image, validates it, and puts it into the terminal
// screen storage. It does not display the image (unless the command
// is transmit_and_display).
fn exec_transmit(mut t terminal.Terminal, cmd &Command) Response {
	tr := cmd.transmission() or {
		return Response{ message: 'EINVAL: no transmission data' }
	}
	mut result := Response{
		id: tr.image_id
		image_number: tr.image_number
		placement_id: tr.placement_id
	}
	if tr.image_id > 0 && tr.image_number > 0 {
		return Response{ message: 'EINVAL: image ID and number are mutually exclusive' }
	}

	load := load_and_add_image(mut t, cmd) or {
		encode_error(mut result, err.msg())
		return result
	}

	// If we're also displaying, then do that now. This function does
	// both transmit and transmit and display. The display might also be
	// deferred if it is multi-chunk.
	if d := load.display {
		if load.more {
			// Should not happen - assert in original
		} else {
			mut d_copy := d
			d_copy.image_id = load.image.id
			result = exec_display(mut t, &Command{
				control: Control(d_copy)
				quiet: cmd.quiet
			})
		}
	}

	// If there are more chunks expected we do not respond.
	if load.more {
		return Response{}
	}

	// If the loaded image was assigned its ID automatically, not based
	// on a number or explicitly specified ID, then we don't respond.
	if load.image.implicit_id {
		return Response{}
	}

	// After the image is added, set the ID in case it changed.
	// The resulting image number and placement ID never change.
	result.id = load.image.id

	return result
}

// Display a previously transmitted image.
fn exec_display(mut t terminal.Terminal, cmd &Command) Response {
	d := cmd.display() or {
		return Response{ message: 'EINVAL: no display data' }
	}

	// Display requires image ID or number.
	if d.image_id == 0 && d.image_number == 0 {
		return Response{ message: 'EINVAL: image ID or number required' }
	}

	// Build up our response.
	mut result := Response{
		id: d.image_id
		image_number: d.image_number
		placement_id: d.placement_id
	}

	// Verify the requested image exists if we have an ID.
	storage := &t.screens.active.kitty_images
	img := if d.image_id != 0 {
		storage.image_by_id(d.image_id) or {
			result.message = 'ENOENT: image not found'
			return result
		}
	} else {
		storage.image_by_number(d.image_number) or {
			result.message = 'ENOENT: image not found'
			return result
		}
	}

	// Make sure our response has the image id in case we looked up by number.
	result.id = img.id

	// Location where the placement will go.
	location := if d.virtual_placement {
		if d.parent_id > 0 {
			result.message = 'EINVAL: virtual placement cannot refer to a parent'
			return result
		}
		PlacementLocation(PlacementVirtual{})
	} else {
		// XTODO: Track a new pin for our cursor. The cursor is always tracked but we
		// don't want this one to move with the cursor.
		// For now, use the cursor position directly.
		PlacementLocation(PlacementPin{
			pin: terminal.Pin{
				x: t.screens.active.cursor.x
				y: u32(t.screens.active.cursor.y)
			}
		})
	}

	// Add the placement.
	p := Placement{
		location: location
		x_offset: d.x_offset
		y_offset: d.y_offset
		source_x: d.x
		source_y: d.y
		source_width: d.width
		source_height: d.height
		columns: d.columns
		rows: d.rows
		z: d.z
	}
	t.screens.active.kitty_images.add_placement(img.id, result.placement_id, p)

	// XTODO: Apply cursor movement setting. This only applies to pin placements.
	// In full implementation, for cursor_movement == .after, we'd use
	// terminal.index to properly handle scroll regions and then setCursorPos.

	return result
}

// Delete a previously transmitted image.
fn exec_delete(mut t terminal.Terminal, cmd &Command) Response {
	fd := cmd.control as FullDelete
	t.screens.active.kitty_images.delete(t, fd)

	// Delete never responds on success.
	return Response{}
}

// Internal result from loading and adding an image.
struct LoadResult {
	image   Image
	more    bool
	display ?Display
}

fn load_and_add_image(mut t terminal.Terminal, cmd &Command) !LoadResult {
	tr := cmd.transmission() or { return error('no transmission') }
	mut storage := &t.screens.active.kitty_images

	// Determine our image. This also handles chunking and early exit.
	mut loading := if l := storage.loading {
		// Existing loading in progress - add data to it.
		// Note: we do NOT want to call "cmd.toOwnedData" here because
		// we're _copying_ the data. We want the command data to be freed.
		l.add_data(cmd.data)!

		// If we have more then we're done.
		if tr.more_chunks {
			return LoadResult{ image: l.image, more: true }
		}

		// We have no more chunks. We're going to be completing the
		// image so we want to destroy the pointer to the loading
		// image and copy it out.
		result := *l
		storage.loading = none
		result
	} else {
		LoadingImage.init_from_cmd(cmd)!
	}

	// If the image has no ID, we assign one.
	if loading.image.id == 0 {
		loading.image.id = storage.next_image_id
		storage.next_image_id += 1

		// If the image also has no number then its auto-ID is "implicit".
		// See the doc comment on the Image.implicit_id field for more detail.
		if loading.image.number == 0 {
			loading.image.implicit_id = true
		}
	}

	// If this is chunked, this is the beginning of a new chunked transmission.
	// (We checked for an in-progress chunk above.)
	if tr.more_chunks {
		// We allocate the pointer on the heap because its rare and we
		// don't want to always pay the memory cost to keep it around.
		storage.loading = &loading
		return LoadResult{ image: loading.image, more: true }
	}

	// Validate and store our image.
	mut img := loading.complete()!
	storage.add_image(img)!

	// Get our display settings.
	display_ := loading.display

	// Ensure we deinit the loading state because we're done. The image
	// won't be deinit because of "complete" above.
	loading.destroy()

	return LoadResult{ image: img, display: display_ }
}

// Encode an error message into a response.
fn encode_error(mut r Response, err_msg string) {
	if err_msg.contains('out of memory') || err_msg.contains('OutOfMemory') {
		r.message = 'ENOMEM: out of memory'
	} else if err_msg.contains('decompression') {
		r.message = 'EINVAL: decompression failed'
	} else if err_msg.contains('file path too long') {
		r.message = 'EINVAL: file path too long'
	} else if err_msg.contains('temporary file not in temp dir') {
		r.message = 'EINVAL: temporary file not in temp dir'
	} else if err_msg.contains('temporary file not named correctly') {
		r.message = 'EINVAL: temporary file not named correctly'
	} else if err_msg.contains('unsupported format') {
		r.message = 'EINVAL: unsupported format'
	} else if err_msg.contains('non-direct medium') || err_msg.contains('unsupported medium') {
		r.message = 'EINVAL: unsupported medium'
	} else if err_msg.contains('unsupported pixel depth') || err_msg.contains('unsupported depth') {
		r.message = 'EINVAL: unsupported pixel depth'
	} else if err_msg.contains('dimensions required') {
		r.message = 'EINVAL: dimensions required'
	} else if err_msg.contains('dimensions too large') {
		r.message = 'EINVAL: dimensions too large'
	} else if err_msg.contains('invalid data') || err_msg.contains('InvalidData') {
		r.message = 'EINVAL: invalid data'
	} else {
		r.message = 'EINVAL: internal error'
	}
}
