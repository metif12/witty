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
import terminal

fn storage_mark_dirty(storage_ptr voidptr, _ &terminal.Screen) {
	mut storage := unsafe { &ImageStorage(storage_ptr) }
	storage.dirty = true
}

fn storage_reset(storage_ptr voidptr, screen &terminal.Screen) {
	mut storage := unsafe { &ImageStorage(storage_ptr) }
	limit := storage.total_limit
	storage.deinit(screen)
	fresh := ImageStorage{
		total_limit: limit
		dirty: true
	}
	unsafe {
		*storage = fresh
	}
}

fn storage_deinit(storage_ptr voidptr, screen &terminal.Screen) {
	mut storage := unsafe { &ImageStorage(storage_ptr) }
	storage.deinit(screen)
}

fn storage_clear(storage_ptr voidptr, screen &terminal.Screen) {
	mut storage := unsafe { &ImageStorage(storage_ptr) }
	storage.clear_screen_images(screen)
}

// terminal.Screen keeps this value opaque to avoid a terminal -> kitty ->
// terminal import cycle. The actual value and all of its behavior remain the
// canonical ImageStorage implementation in this module.
fn active_storage(mut t terminal.Terminal) &ImageStorage {
	if t.screens.active.kitty_images == unsafe { nil } {
		storage := &ImageStorage{
			total_limit: t.kitty_image_limit
		}
		t.screens.active.kitty_images = voidptr(storage)
		t.screens.active.kitty_images_reset = storage_reset
		t.screens.active.kitty_images_deinit = storage_deinit
		t.screens.active.kitty_images_dirty = storage_mark_dirty
		t.screens.active.kitty_images_clear = storage_clear
	}
	return unsafe { &ImageStorage(t.screens.active.kitty_images) }
}

// terminal_storage exposes the active screen's storage to the renderer.
pub fn terminal_storage(t &terminal.Terminal) ?&ImageStorage {
	if t.screens.active.kitty_images == unsafe { nil } {
		return none
	}
	return unsafe { &ImageStorage(t.screens.active.kitty_images) }
}

// screen_storage exposes one screen's opaque storage to inspector and
// renderer code without introducing terminal's intentional kitty import cycle.
pub fn screen_storage(screen &terminal.Screen) ?&ImageStorage {
	if screen.kitty_images == unsafe { nil } {
		return none
	}
	return unsafe { &ImageStorage(screen.kitty_images) }
}

fn deinit_screen_storage(mut screen terminal.Screen) {
	if screen.kitty_images == unsafe { nil } {
		return
	}
	mut storage := unsafe { &ImageStorage(screen.kitty_images) }
	storage.deinit(&screen)
	screen.kitty_images = unsafe { nil }
	screen.kitty_images_reset = unsafe { nil }
	screen.kitty_images_deinit = unsafe { nil }
	screen.kitty_images_dirty = unsafe { nil }
	screen.kitty_images_clear = unsafe { nil }
}

// deinit_terminal_storage releases both primary and alternate screen state.
// Call this before terminal.Terminal.deinit clears the opaque pointers.
pub fn deinit_terminal_storage(mut t terminal.Terminal) {
	if mut primary := t.screens.get(.primary) {
		deinit_screen_storage(mut primary)
	}
	if mut alternate := t.screens.get(.alternate) {
		deinit_screen_storage(mut alternate)
	}
}

// set_terminal_storage_limit updates the configured limit and all storage
// instances that have already been materialized.
pub fn set_terminal_storage_limit(mut t terminal.Terminal, limit usize) {
	t.kitty_image_limit = limit
	if mut primary := t.screens.get(.primary) {
		if primary.kitty_images != unsafe { nil } {
			mut storage := unsafe { &ImageStorage(primary.kitty_images) }
			storage.set_limit(primary, limit)
		}
	}
	if mut alternate := t.screens.get(.alternate) {
		if alternate.kitty_images != unsafe { nil } {
			mut storage := unsafe { &ImageStorage(alternate.kitty_images) }
			storage.set_limit(alternate, limit)
		}
	}
}

// clear_active_images implements the emulator-level clear used by Cmd+K.
pub fn clear_active_images(mut t terminal.Terminal) {
	mut storage := active_storage(mut t)
	storage.delete(&t, FullDelete{
		kind: .all
		data: DeleteData(DeleteAll{
			delete: true
		})
	})
}

// Execute a Kitty graphics command against the given terminal. This
// will never fail, but the response may indicate an error and the
// terminal state may not be updated to reflect the command. This will
// never put the terminal in an unrecoverable state, however.
//
// The allocator must be the same allocator that was used to build
// the command.
pub fn execute(mut t terminal.Terminal, cmd &Command) ?Response {
	mut storage := active_storage(mut t)
	if !storage.enabled() {
		return none
	}

	// The quiet setting can change only for transmissions: later chunks
	// inherit the initial chunk's value unless they explicitly raise q.
	mut quiet := cmd.quiet

	// Dispatch based on command control type.
	mut result := match cmd.control {
		Transmission {
			tr := cmd.control as Transmission
			if tr.is_query {
				exec_query(cmd)
			} else {
				if mut loading := storage.loading {
					match cmd.quiet {
						.no {
							quiet = loading.quiet
						}
						.ok, .failures {
							loading.quiet = cmd.quiet
						}
					}
				}
				exec_transmit(mut t, cmd)
			}
		}
		TransmitAndDisplay {
			if mut loading := storage.loading {
				match cmd.quiet {
					.no {
						quiet = loading.quiet
					}
					.ok, .failures {
						loading.quiet = cmd.quiet
					}
				}
			}
			exec_transmit(mut t, cmd)
		}
		Display {
			exec_display(mut t, cmd)
		}
		FullDelete {
			exec_delete(mut t, cmd)
		}
		AnimationFrameLoading {
			Response{ message: 'ERROR: unimplemented action' }
		}
		AnimationControl {
			Response{ message: 'ERROR: unimplemented action' }
		}
		AnimationFrameComposition {
			Response{ message: 'ERROR: unimplemented action' }
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
		result = exec_display(mut t, &disp_cmd)
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

	mut storage := active_storage(mut t)
	img_opt := if d.image_id != 0 {
		storage.image_by_id(d.image_id)
	} else {
		storage.image_by_number(d.image_number)
	}
	img := img_opt or {
		result.message = 'ENOENT: image not found'
		return result
	}
	result.id = img.id

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

	storage.add_placement(img.id, result.placement_id, p)

	// Apply cursor movement setting. This only applies to pin placements.
	if p.location is PlacementPin && d.cursor_movement == .after {
		pin := (p.location as PlacementPin).pin
		cols, rows := p.grid_size(img, &t)
		for _ in 0 .. rows {
			t.index() or { break }
		}
		t.set_cursor_pos(usize(t.screens.active.cursor.y), usize(pin.x + cols + 1))
	}

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

	mut storage := active_storage(mut t)
	storage.delete(&t, del)

	// Delete never responds on success.
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
	mut storage := active_storage(mut t)

	if mut loading_ptr := storage.loading {
		loading_ptr.add_data(cmd.data)!
		if t_data.more_chunks {
			return LoadResult{
				image: loading_ptr.image
				more: true
			}
		}

		display := loading_ptr.display
		img := loading_ptr.complete() or {
			loading_ptr.destroy()
			storage.loading = none
			return err
		}
		storage.loading = none
		storage.add_image(img)!
		return LoadResult{
			image: img
			display: display
		}
	}

	// No loading in progress - create a new LoadingImage from the command.
	mut loading := LoadingImage.init_from_cmd(cmd)!

	// If the image has no ID, we assign one.
	if loading.image.id == 0 {
		loading.image.id = storage.next_image_id
		storage.next_image_id = if storage.next_image_id == u32(0xffffffff) {
			u32(0)
		} else {
			storage.next_image_id + 1
		}

		// If the image also has no number then its auto-ID is "implicit".
		// See the doc comment on the Image.implicit_id field for detail.
		if t_data.image_number == 0 {
			loading.image.implicit_id = true
		}
	}

	// If this is chunked, this is the beginning of a new chunked transmission.
	if t_data.more_chunks {
		storage.loading = &loading
		return LoadResult{
			image: loading.image
			more: true
		}
	}

	// Single-shot transfer - validate and complete the image immediately.
	display := loading.display
	img := loading.complete()!
	storage.add_image(img)!

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
