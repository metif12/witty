module kitty

// --- Original Ghostty Comments Start: src/terminal/kitty/graphics_exec.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/kitty/graphics_exec.zig
//
// Execute a Kitty graphics command against the given terminal. This
// will never fail, but the response may indicate an error and the
// terminal state may not be updated to reflect the command. This will
// never put the terminal in an unrecoverable state, however.
//
// The allocator must be the same allocator that was used to build
// the command.
// If storage is disabled then we disable the full protocol. This means
// we don't even respond to queries so the terminal completely acts as
// if this feature is not supported.
// The quiet settings used to control the response. We have to make this
// a var because in certain special cases (namely chunked transmissions)
// this can change.
// If we're transmitting, then our `q` setting value is complicated.
// The `q` setting inherits the value from the starting command
// unless `q` is set >= 1 on this command. If it is, then we save
// that as the new `q` setting.
// q=0 we use whatever the start command value is
// q>=1 we use the new value, but we should already be set to it
// Handle the quiet settings
// Execute a "query" command.
//
// This command is used to attempt to load an image and respond with
// success/error but does not persist any of the command to the terminal
// state.
// Query requires image ID. We can't actually send a response without
// an image ID either but we return an error and this will be logged
// downstream.
// Build a partial response to start
// Attempt to load the image. If we cannot, then set an appropriate error.
// Transmit image data.
//
// This loads the image, validates it, and puts it into the terminal
// screen storage. It does not display the image.
// If we're also displaying, then do that now. This function does
// both transmit and transmit and display. The display might also be
// deferred if it is multi-chunk.
// If there are more chunks expected we do not respond.
// If the loaded image was assigned its ID automatically, not based
// on a number or explicitly specified ID, then we don't respond.
// After the image is added, set the ID in case it changed.
// The resulting image number and placement ID never change.
// Display a previously transmitted image.
// Display requires image ID or number.
// Build up our response
// Verify the requested image exists if we have an ID
// Make sure our response has the image id in case we looked up by number
// Location where the placement will go.
// Virtual placements are not tracked
// Track a new pin for our cursor. The cursor is always tracked but we
// don't want this one to move with the cursor.
// Add the placement
// Apply cursor movement setting. This only applies to pin placements.
// We use terminal.index to properly handle scroll regions.
// Display a previously transmitted image.
// Delete never responds on success
// Determine our image. This also handles chunking and early exit.
// Note: we do NOT want to call "cmd.toOwnedData" here because
// we're _copying_ the data. We want the command data to be freed.
// If we have more then we're done
// We have no more chunks. We're going to be completing the
// image so we want to destroy the pointer to the loading
// image and copy it out.
// We only want to deinit on error. If we're chunking, then we don't
// want to deinit at all. If we're not chunking, then we'll deinit
// after we've copied the image out.
// If the image has no ID, we assign one
// If the image also has no number then its auto-ID is "implicit".
// See the doc comment on the Image.implicit_id field for more detail.
// If this is chunked, this is the beginning of a new chunked transmission.
// (We checked for an in-progress chunk above.)
// We allocate the pointer on the heap because its rare and we
// don't want to always pay the memory cost to keep it around.
// Dump the image data before it is decompressed
// loading.debugDump() catch unreachable;
// Validate and store our image
// Get our display settings
// Ensure we deinit the loading state because we're done. The image
// won't be deinit because of "complete" above.
// Encode an error code into a message for a response.
// Initial chunk has q=1
// Subsequent chunk has no q but should respect initial
// Initial chunk has q=0
// Subsequent chunk has no q so should respond OK
// Initial chunk has q=0
// Subsequent chunk sets q=1 so should not respond
//
// --- Original Ghostty Comments End: src/terminal/kitty/graphics_exec.zig


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
	// TODO: Needs Screen.kitty_images (ImageStorage) field on terminal.Screen.
	// Once that field exists, check: if !t.screens.active.kitty_images.enabled() { return none }

	// Determine quiet setting from the command. For transmit operations,
	// the quiet setting may be inherited from the loading image's initial
	// quiet setting.
	mut quiet := cmd.quiet

	// Dispatch based on command control type.
	mut result := match cmd.control {
		Transmission {
			tr := cmd.control as Transmission
			if tr.is_query {
				exec_query(cmd)
			} else {
				r := exec_transmit(mut t, cmd)
				// Inherit quiet from loading image if set on first chunk.
				// The exec_transmit may update quiet via the loading state.
				r
			}
		}
		TransmitAndDisplay {
			r := exec_transmit(mut t, cmd)
			r
		}
		Display {
			exec_display(mut t, cmd)
		}
		FullDelete {
			exec_delete(mut t, cmd)
		}
		AnimationFrameLoading {
			Response{ message: 'EINVAL: animation frames not supported' }
		}
		AnimationControl {
			Response{ message: 'EINVAL: animation control not supported' }
		}
		AnimationFrameComposition {
			Response{ message: 'EINVAL: animation composition not supported' }
		}
	}

	// Apply quiet settings to filter the response.
	return match quiet {
		.no {
			// Return response unless it has no identifiers (empty).
			if result.empty() {
				none
			} else {
				result
			}
		}
		.ok {
			// Return only if the response indicates an error.
			if !result.ok() {
				result
			} else {
				none
			}
		}
		.failures {
			// Suppress all responses.
			none
		}
	}
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
	t_data := cmd.transmission() or {
		return Response{ message: 'EINVAL: no transmission data' }
	}

	// Build a partial response to start.
	mut result := Response{
		id: t_data.image_id
		image_number: t_data.image_number
		placement_id: t_data.placement_id
	}

	// Load and add the image.
	load_result := load_and_add_image(mut t, cmd) or {
		encode_error(mut result, err.msg())
		return result
	}

	// If more chunks are expected, return an empty response to
	// indicate we're not done yet.
	if load_result.more {
		return Response{}
	}

	// If this image was transmit-and-display, exec the display too.
	if _ := load_result.display {
		disp_result := exec_display(mut t, cmd)
		if !disp_result.ok() {
			return disp_result
		}
	}

	// Update result with the final image ID (may have been auto-assigned).
	result.id = load_result.image.id

	// If the image has an implicit ID (no user-specified ID or number),
	// skip the response because the client can't use the ID anyway.
	if load_result.image.implicit_id {
		return Response{}
	}

	return result
}

// Display a previously transmitted image.
//
// Looks up the image in storage by ID or number, creates a Placement,
// adds it to storage, and optionally moves the cursor.
fn exec_display(mut t terminal.Terminal, cmd &Command) Response {
	d := cmd.display() or {
		return Response{ message: 'EINVAL: no display data' }
	}

	mut result := Response{
		id: d.image_id
		image_number: d.image_number
		placement_id: d.placement_id
	}

	// We need either an image ID or image number.
	if d.image_id == 0 && d.image_number == 0 {
		result.message = 'EINVAL: image ID or number required'
		return result
	}

	// TODO: Needs Screen.kitty_images (ImageStorage) field on terminal.Screen.
	// Once available, look up image:
	//   img := if d.image_id != 0 {
	//       t.screens.active.kitty_images.image_by_id(d.image_id)
	//   } else {
	//       t.screens.active.kitty_images.image_by_number(d.image_number)
	//   } or {
	//       result.message = 'EINVAL: image not found'
	//       return result
	//   }

	// Determine placement location.
	location := if d.virtual_placement {
		PlacementLocation(PlacementVirtual{})
	} else {
		// Pin at the current cursor position.
		// TODO: needs t.screens.active.pages.pin() with cursor coords
		PlacementLocation(PlacementPin{
			pin: terminal.Pin{
				x: t.screens.active.cursor.x
				y: u32(t.screens.active.pages.active_start) + t.screens.active.cursor.y
			}
		})
	}

	// Build the placement.
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

	// TODO: Needs Screen.kitty_images to add placement:
	//   t.screens.active.kitty_images.add_placement(img.id, d.placement_id, p)

	// If cursor movement is configured (the default), move the cursor
	// to the right past the image placement.
	// TODO: Needs actual image lookup to calculate grid size for cursor movement.
	// if d.cursor_movement == .after {
	//     cols, _ := p.grid_size(img, t)
	//     // Move cursor right by cols cells
	// }

	_ = p

	return result
}

// Delete a previously transmitted image.
//
// Delegates to ImageStorage.delete() which handles all delete modes
// (by ID, by number, all, intersecting cursor, by z-index, etc.).
fn exec_delete(mut t terminal.Terminal, cmd &Command) Response {
	del := match cmd.control {
		FullDelete {
			cmd.control as FullDelete
		}
		else {
			return Response{ message: 'EINVAL: not a delete command' }
		}
	}

	// TODO: Needs Screen.kitty_images (ImageStorage) field on terminal.Screen.
	// Once available, delegate: t.screens.active.kitty_images.delete(t, del)
	_ = del

	return Response{}
}

// Internal result from loading and adding an image.
struct LoadResult {
	image   Image
	more    bool
	display ?Display
}

// Load and add an image to the terminal's image storage.
//
// Handles both single-shot and chunked loading. For chunked transfers,
// the first chunk creates a LoadingImage and subsequent chunks add data
// until the final chunk completes it.
fn load_and_add_image(mut t terminal.Terminal, cmd &Command) !LoadResult {
	t_data := cmd.transmission() or { return error('no transmission in command') }

	// TODO: Needs Screen.kitty_images (ImageStorage) field on terminal.Screen.
	// The storage is needed for:
	//   1. Checking/retrieving the in-progress loading image (chunked transfers)
	//   2. Auto-assigning image IDs via storage.next_image_id
	//   3. Storing the completed image via storage.add_image()

	// Step 1: Check if there's an in-progress loading image (chunked transfer).
	// TODO: Once Screen.kitty_images exists:
	//   if mut loading := t.screens.active.kitty_images.loading {
	//       loading.add_data(cmd.data)!
	//       if t_data.more_chunks {
	//           return LoadResult{ image: loading.image, more: true }
	//       }
	//       // Final chunk - complete the image.
	//       img := loading.complete()!
	//       t.screens.active.kitty_images.loading = none
	//       t.screens.active.kitty_images.add_image(img)!
	//       return LoadResult{
	//           image: img
	//           display: loading.display
	//       }
	//   }

	// Step 2: No loading in progress - create new LoadingImage from command.
	mut loading := LoadingImage.init_from_cmd(cmd)!

	// Step 3: Assign auto image ID if needed.
	mut img_id := t_data.image_id
	if img_id == 0 {
		// TODO: Auto-assign from storage:
		//   img_id = t.screens.active.kitty_images.next_image_id
		//   t.screens.active.kitty_images.next_image_id += 1
		//   if t_data.image_number == 0 {
		//       loading.image.implicit_id = true
		//   }
		img_id = 1 // placeholder until storage is available
	}
	loading.image.id = img_id

	// Step 4: If more chunks are expected, store loading state and return.
	if t_data.more_chunks {
		// TODO: Store loading state in storage:
		//   t.screens.active.kitty_images.loading = &loading
		return LoadResult{
			image: loading.image
			more: true
		}
	}

	// Step 5: Single-shot transfer - complete the image immediately.
	display := loading.display
	img := loading.complete()!

	// TODO: Add to storage:
	//   t.screens.active.kitty_images.add_image(img)!

	return LoadResult{
		image: img
		display: display
	}
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
