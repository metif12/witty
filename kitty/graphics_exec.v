module kitty

// Kitty graphics protocol execution.
//
// Source: kitty/graphics_exec.zig
//
// Executes Kitty graphics commands against the terminal state. This
// handles query, transmit, display, and delete operations, and manages
// the quiet settings for controlling responses.
//
// XTODO: Full implementation requires ImageStorage to be integrated
// into the terminal.Screen struct (as a `kitty_images` field). Once
// that field exists, the execute/transmit/display/delete functions
// can access the storage through `t.screens.active.kitty_images`.

import terminal

// Execute a Kitty graphics command against the given terminal. This
// will never fail, but the response may indicate an error and the
// terminal state may not be updated to reflect the command. This will
// never put the terminal in an unrecoverable state, however.
//
// The allocator must be the same allocator that was used to build
// the command.
//
// XTODO: Requires Screen.kitty_images (ImageStorage) field.
// The algorithm is:
// 1. Check if storage is enabled; if not, return none (protocol disabled).
// 2. Determine quiet setting from the command.
// 3. Dispatch based on command control type:
//    - Transmission (query): exec_query
//    - Transmission (non-query): exec_transmit (inherits quiet from loading)
//    - TransmitAndDisplay: exec_transmit (inherits quiet from loading)
//    - Display: exec_display
//    - FullDelete: exec_delete
//    - Animation*: return unimplemented error
// 4. Apply quiet settings to filter the response:
//    - quiet=no: return response unless empty
//    - quiet=ok: return response only if error
//    - quiet=failures: suppress all responses
pub fn execute(mut t terminal.Terminal, cmd &Command) ?Response {
	// XTODO: Needs t.screens.active.kitty_images.enabled() check
	// and full dispatch logic. See algorithm above.
	_ = t
	_ = cmd
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
//
// XTODO: Requires Screen.kitty_images (ImageStorage) field.
// The algorithm is:
// 1. Extract transmission data from command.
// 2. Call load_and_add_image to load/chunk/store the image.
// 3. If also displaying (TransmitAndDisplay), call exec_display.
// 4. Handle chunked transmission (return empty response if more chunks).
// 5. Skip response for implicit IDs.
// 6. Return response with final image ID.
fn exec_transmit(mut t terminal.Terminal, cmd &Command) Response {
	_ = t
	_ = cmd
	return Response{ message: 'XTODO: needs Screen.kitty_images' }
}

// Display a previously transmitted image.
//
// XTODO: Requires Screen.kitty_images (ImageStorage) field.
// The algorithm is:
// 1. Extract display data from command.
// 2. Require image ID or number.
// 3. Look up image in storage by ID or number.
// 4. Determine placement location (virtual or pin at cursor).
// 5. Build Placement struct with source rect, columns, rows, z-index.
// 6. Add placement to storage.
// 7. Apply cursor movement if configured.
fn exec_display(mut t terminal.Terminal, cmd &Command) Response {
	_ = t
	_ = cmd
	return Response{ message: 'XTODO: needs Screen.kitty_images' }
}

// Delete a previously transmitted image.
//
// XTODO: Requires Screen.kitty_images (ImageStorage) field.
// Delegates to ImageStorage.delete() which handles all delete modes
// (by ID, by number, all, intersecting cursor, by z-index, etc.).
fn exec_delete(mut t terminal.Terminal, cmd &Command) Response {
	_ = t
	_ = cmd
	return Response{ message: 'XTODO: needs Screen.kitty_images' }
}

// Internal result from loading and adding an image.
struct LoadResult {
	image   Image
	more    bool
	display ?Display
}

// Load and add an image to the terminal's image storage.
//
// XTODO: Requires Screen.kitty_images (ImageStorage) field.
// The algorithm is:
// 1. Extract transmission data from command.
// 2. If there's a loading image in progress (chunked), add data to it.
//    If more chunks expected, return early with more=true.
//    Otherwise, complete the loading image.
// 3. If no loading in progress, create new LoadingImage from command.
// 4. Assign auto image ID if needed (mark implicit if no number either).
// 5. If more chunks expected (start of chunked), store loading state.
// 6. Complete the image and add to storage.
// 7. Return LoadResult with image, display settings, and more flag.
fn load_and_add_image(mut t terminal.Terminal, cmd &Command) !LoadResult {
	_ = t
	_ = cmd
	return error('XTODO: needs Screen.kitty_images')
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
