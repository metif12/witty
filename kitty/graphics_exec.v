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
//
// ============================================================================
// DEPENDENCY / BOUNDARY: Screen.kitty_images (ImageStorage)
// ============================================================================
// In Ghostty the persistent image storage lives on the active screen as
// `terminal.screens.active.kitty_images` (an ImageStorage). The witty
// `terminal.Screen` (terminal/screen.v) does NOT yet expose that field, and
// this agent is not permitted to edit screen.v.
//
// Everything that needs *persistent* storage across commands therefore
// cannot be wired here yet:
//   - execute():   `storage.enabled()` gate + chunked `q` inheritance
//   - transmit:    `storage.loading` chunk accumulation, `next_image_id`
//                  auto-assignment, `storage.add_image()`
//   - display:     `storage.image_by_id()/image_by_number()` lookup,
//                  `storage.add_placement()`, cursor movement using the
//                  looked-up image's grid size
//   - delete:      `storage.delete()`
//
// The ImageStorage type itself is fully implemented in graphics_storage.v;
// only the field on Screen is missing. Each site below is marked
// `STORAGE-DEP` and shows the exact call to make once the field exists.
// Until then we keep a guarded local path that performs all storage-
// independent work (validation, response shaping, placement construction).

import terminal

// Execute a Kitty graphics command against the given terminal. This
// will never fail, but the response may indicate an error and the
// terminal state may not be updated to reflect the command. This will
// never put the terminal in an unrecoverable state, however.
//
// The allocator must be the same allocator that was used to build
// the command.
pub fn execute(mut t terminal.Terminal, cmd &Command) ?Response {
	// STORAGE-DEP: if storage is disabled we disable the whole protocol, so
	// we don't even respond to queries and the terminal acts as if the
	// feature is unsupported:
	//   if !t.screens.active.kitty_images.enabled() { return none }

	// The quiet setting used to control the response. This is a var because
	// in certain special cases (namely chunked transmissions) it can change:
	// on a transmit the `q` value is inherited from the initial chunk's
	// loading image unless `q >= 1` is set on this command.
	// STORAGE-DEP: the inheritance reads/writes storage.loading.quiet:
	//   if loading := t.screens.active.kitty_images.loading {
	//       match cmd.quiet {
	//           .no { quiet = loading.quiet }        // q=0: use start value
	//           .ok, .failures { loading.quiet = cmd.quiet } // q>=1: adopt
	//       }
	//   }
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

	// Image ID and image number are mutually exclusive.
	if t_data.image_id > 0 && t_data.image_number > 0 {
		return Response{
			message: 'EINVAL: image ID and number are mutually exclusive'
		}
	}

	// Load and add the image.
	load_result := load_and_add_image(mut t, cmd) or {
		encode_error(mut result, err.msg())
		return result
	}

	// If we're also displaying, then do that now. This function does both
	// transmit and transmit-and-display. The display might also be deferred
	// if it is multi-chunk (in which case load_result.display is none until
	// the final chunk completes).
	if disp := load_result.display {
		// The display command inherits the just-assigned image ID.
		mut d_copy := disp
		d_copy.image_id = load_result.image.id
		disp_cmd := Command{
			control: Display(d_copy)
			quiet: cmd.quiet
		}
		return exec_display(mut t, &disp_cmd)
	}

	// If there are more chunks expected we do not respond.
	if load_result.more {
		return Response{}
	}

	// If the loaded image was assigned its ID automatically, not based on a
	// number or explicitly specified ID, then we don't respond.
	if load_result.image.implicit_id {
		return Response{}
	}

	// After the image is added, set the ID in case it changed. The resulting
	// image number and placement ID never change.
	result.id = load_result.image.id

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

	// STORAGE-DEP: verify the requested image exists and, if looked up by
	// number, echo back its concrete ID.
	//   storage := &t.screens.active.kitty_images
	//   img := if d.image_id != 0 {
	//       storage.image_by_id(d.image_id)
	//   } else {
	//       storage.image_by_number(d.image_number)
	//   } or {
	//       result.message = 'ENOENT: image not found'
	//       return result
	//   }
	//   result.id = img.id

	// Determine placement location.
	location := if d.virtual_placement {
		// Virtual placements are not tracked. They also cannot refer to a
		// parent placement.
		if d.parent_id > 0 {
			result.message = 'EINVAL: virtual placement cannot refer to a parent'
			return result
		}
		PlacementLocation(PlacementVirtual{})
	} else {
		// Pin at the current cursor position. In Zig a *new* pin is tracked
		// here (separate from the cursor's own tracked pin) so it doesn't
		// move with the cursor; the flat Pin model captures the position by
		// value which has the same effect.
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

	// STORAGE-DEP: add the placement to the active screen's image storage.
	//   storage.add_placement(img.id, result.placement_id, p) or {
	//       p.deinit(t.screens.active)
	//       encode_error(mut result, err.msg())
	//       return result
	//   }

	// Apply cursor movement setting. This only applies to pin placements.
	// STORAGE-DEP: the number of rows to advance the cursor comes from
	// p.grid_size(img, t), which needs the looked-up image.
	//   if p.location is PlacementPin {
	//       if d.cursor_movement == .after {
	//           _, rows := p.grid_size(img, t)
	//           // We use terminal.index() to properly handle scroll regions.
	//           for _ in 0 .. rows { t.index() or { break } }
	//           t.set_cursor_pos(t.screens.active.cursor.y,
	//               p.location.pin.x + cols + 1)
	//       }
	//   }

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

	// STORAGE-DEP: delegate to the storage, which handles every delete mode
	// (by ID, by number, all, intersecting cursor/cell, by z-index, column,
	// row, range, ...). The ImageStorage.delete() implementation already
	// exists in graphics_storage.v.
	//   t.screens.active.kitty_images.delete(t, del)
	_ = del
	_ = t

	// Delete never responds on success.
	return Response{}
}

// Internal result from loading and adding an image.
struct LoadResult {
	image   Image
	more    bool
	display ?Display
}

// Starting value for auto-assigned image IDs, matching
// ImageStorage.next_image_id (mid-way through the u32 range to avoid
// collisions with buggy programs).
//
// STORAGE-DEP: the real, monotonically-incrementing counter lives on the
// storage. Without Screen.kitty_images we can't persist it, so auto-ID'd
// images all receive this sentinel. Since such images are also marked
// implicit_id (when no number is given) they are never referenced by ID in
// a response, so the collision is harmless for the response path.
const auto_image_id_start = u32(2147483647)

// Load and add an image to the terminal's image storage.
//
// Handles both single-shot and chunked loading. For chunked transfers,
// the first chunk creates a LoadingImage and subsequent chunks add data
// until the final chunk completes it.
fn load_and_add_image(mut t terminal.Terminal, cmd &Command) !LoadResult {
	t_data := cmd.transmission() or { return error('no transmission in command') }

	// STORAGE-DEP (chunked transfers): if there is an in-progress loading
	// image on the storage, append this chunk to it, and on the final chunk
	// complete + add the image.
	//   storage := &t.screens.active.kitty_images
	//   if mut loading := storage.loading {
	//       loading.add_data(cmd.data)!
	//       if t_data.more_chunks {
	//           return LoadResult{ image: loading.image, more: true }
	//       }
	//       img := loading.complete()!
	//       storage.loading = none
	//       storage.add_image(img)!
	//       return LoadResult{ image: img, display: loading.display }
	//   }
	// Because we can't persist `storage.loading`, chunked transfers cannot be
	// reassembled across calls in this build: each chunk is treated as an
	// independent (first) chunk below.

	// No loading in progress - create a new LoadingImage from the command.
	mut loading := LoadingImage.init_from_cmd(cmd)!

	// If the image has no ID, we assign one.
	if loading.image.id == 0 {
		// STORAGE-DEP: id = storage.next_image_id; storage.next_image_id +%= 1
		loading.image.id = auto_image_id_start

		// If the image also has no number then its auto-ID is "implicit".
		// See the doc comment on the Image.implicit_id field for detail.
		if t_data.image_number == 0 {
			loading.image.implicit_id = true
		}
	}

	// If this is chunked, this is the beginning of a new chunked transmission.
	if t_data.more_chunks {
		// STORAGE-DEP: allocate the loading image on the heap and stash it:
		//   storage.loading = &loading
		return LoadResult{
			image: loading.image
			more: true
		}
	}

	// Single-shot transfer - validate and complete the image immediately.
	display := loading.display
	img := loading.complete()!

	// STORAGE-DEP: storage.add_image(img)!
	_ = t

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
