module renderer

// --- Original Ghostty Comments Start: src/renderer/generic.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/renderer/generic.zig
//
// Create a renderer type with the provided graphics API wrapper.
//
// The graphics API wrapper must provide the interface outlined below.
// Specific details for the interfaces are documented on the existing
// implementations (`Metal` and `OpenGL`).
//
// Hierarchy of graphics abstractions:
//
// [ GraphicsAPI ] - Responsible for configuring the runtime surface
//    |     |        and providing render `Target`s that draw to it,
//    |     |        as well as `Frame`s and `Pipeline`s.
//    |     V
//    | [ Target ] - Represents an abstract target for rendering, which
//    |              could be a surface directly but is also used as an
//    |              abstraction for off-screen frame buffers.
//    V
// [ Frame ] - Represents the context for drawing a given frame,
//    |        provides `RenderPass`es for issuing draw commands
//    |        to, and reports the frame health when complete.
//    V
// [ RenderPass ] - Represents a render pass in a frame, consisting of
//   :              one or more `Step`s applied to the same target(s),
// [ Step ] - - - - each describing the input buffers and textures and
//   :              the vertex/fragment functions and geometry to use.
//   :_ _ _ _ _ _ _ _ _ _/
//   v
// [ Pipeline ] - Describes a vertex and fragment function to be used
//                for a `Step`; the `GraphicsAPI` is responsible for
//                these and they should be constructed and cached
//                ahead of time.
//
// [ Buffer ] - An abstraction over a GPU buffer.
//
// [ Texture ] - An abstraction over a GPU texture.
//
// Allocator that can be used
// This mutex must be held whenever any state used in `drawFrame` is
// being modified, and also when it's being accessed in `drawFrame`.
// The configuration we need derived from the main config.
// The mailbox for communicating with the window.
// Current font metrics defining our grid.
// The size of everything.
// True if the window is focused
// Flag to indicate that our focus state changed for custom
// shaders to update their state.
// The most recent scrollbar state. We use this as a cache to
// determine if we need to notify the apprt that there was a
// scrollbar change.
// The most recent viewport matches so that we can render search
// matches in the visible frame. This is provided asynchronously
// from the search thread so we have the dirty flag to also note
// if we need to rebuild our cells to include search highlights.
//
// Note that the selections MAY BE INVALID (point to PageList nodes
// that do not exist anymore). These must be validated prior to use.
// The current set of cells to render. This is rebuilt on every frame
// but we keep this around so that we don't reallocate. Each set of
// cells goes into a separate shader.
// Set to true after rebuildCells is called. This can be used
// to determine if any possible changes have been made to the
// cells for the draw call.
// The current GPU uniform values.
// Custom shader uniform values.
// Timestamp we rendered out first frame.
//
// This is used when updating custom shader uniforms.
// Timestamp when we rendered out more recent frame.
//
// This is used when updating custom shader uniforms.
// The font structures.
// The images that we may render.
// Background image, if we have one.
// Set whenever the background image changes, signalling
// that the new background image needs to be uploaded to
// the GPU.
//
// This is initialized as true so that we load the image
// on renderer initialization, not just on config change.
// Background image vertex buffer.
// This value is used to force-update the swap chain copy
// of the background image buffer whenever we change it.
// Graphics API state.
// The CVDisplayLink used to drive the rendering loop in
// sync with the display. This is void on platforms that
// don't support a display link.
// Health of the most recently completed frame.
// Our swap chain (multiple buffering)
// This value is used to force-update swap chain targets in the
// event of a config change that requires it (such as blending mode).
// If something happened that requires us to reinitialize our shaders,
// this is set to true so that we can do that whenever possible.
// Whether or not we have custom shaders.
// Our shader pipelines.
// The render state we update per loop.
// The number of frames since the last terminal state reset.
// We reset the terminal state after ~100,000 frames (about 10 to
// 15 minutes at 120Hz) to prevent wasted memory buildup from
// a large screen.
// Our overlay state, if any.
// Swap chain which maintains multiple copies of the state needed to
// render a frame, so that we can start building the next frame while
// the previous frame is still being processed on the GPU.
// The count of buffers we use for double/triple buffering.
// If this is one then we don't do any double+ buffering at all.
// This is comptime because there isn't a good reason to change
// this at runtime and there is a lot of complexity to support it.
// `buf_count` structs that can hold the
// data needed by the GPU to draw a frame.
// Index of the most recently used frame state struct.
// Semaphore that we wait on to make sure we have an available
// frame state struct so we can start working on a new frame.
// Set to true when deinited, if you try to deinit a defunct
// swap chain it will just be ignored, to prevent double-free.
//
// This is required because of `displayUnrealized`, since it
// `deinits` the swapchain, which leads to a double-free if
// the renderer is deinited after that.
// Initialize all of our frame state.
// Wait for all of our inflight draws to complete
// so that we can cleanly deinit our GPU state.
// Get the next frame state to draw to. This will wait on the
// semaphore to ensure that the frame is available. This must
// always be paired with a call to releaseFrame.
// This should be called when the frame has completed drawing.
// State we need duplicated for every frame. Any state that could be
// in a data race between the GPU and CPU while a frame is being drawn
// should be in this struct.
//
// While a draw is in-process, we "lock" the state (via a semaphore)
// and prevent the CPU from updating the state until our graphics API
// reports that the frame is complete.
//
// This is used to implement double/triple buffering.
// See property of same name on Renderer for explanation.
// Buffer with the vertex data for our background image.
//
// TODO: Make this an optional and only create it
//       if we actually have a background image.
// See property of same name on Renderer for explanation.
// Custom shader state, this is null if we have no custom shaders.
// Uniform buffer contains exactly 1 uniform struct. The
// uniform data will be undefined so this must be set before
// a frame is drawn.
// Create GPU buffers for our cells.
//
// We start them off with a size of 1, which will of course be
// too small, but they will be resized as needed. This is a bit
// wasteful but since it's a one-time thing it's not really a
// huge concern.
// Create a GPU buffer for our background image info.
// Initialize our textures for our font atlas.
//
// As with the buffers above, we start these off as small
// as possible since they'll inevitably be resized anyway.
// Initialize the target. Just as with the other resources,
// start it off as small as we can since it'll be resized.
// State relevant to our custom shaders if we have any.
// When we have a custom shader state, we maintain a front
// and back texture which we use as a swap chain to render
// between when multiple custom shaders are defined.
// Shadertoy uses a sampler for accessing the various channel
// textures. In Metal, we need to explicitly create these since
// the glslang-to-msl compiler doesn't do it for us (as we
// normally would in hand-written MSL). To keep it clean and
// consistent, we just force all rendering APIs to provide an
// explicit sampler.
//
// Samplers are immutable and describe sampling properties so
// we can share the sampler across front/back textures (although
// we only need it for the source texture at a time, we don't
// need to "swap" it).
// Swap the front and back textures.
// Create a GPU buffer to hold our uniforms.
// Initialize the front and back textures at 1x1 px, this
// is slightly wasteful but it's only done once so whatever.
// The configuration for this renderer that is derived from the main
// configuration. This must be exported so that we don't need to
// pass around Config pointers which makes memory management a pain.
// Copy our shaders
// Copy our background image
// Copy our font features
// Get our font styles
// Our link configs
// Initialize our graphics API wrapper, this will prepare the
// surface provided by the apprt and set up any API-specific
// GPU resources.
// Prepare our swap chain
// Create the font shaper.
// Initialize all the data that requires a critical font section.
// Render state
// Note that if we're on macOS with glass effects
// we'll disable background opacity but we handle
// that in updateFrame.
// Fonts
// Shaders (initialized below)
// Graphics API stuff
// Ensure our undefined values above are correctly initialized.
// Load our custom shaders
// This is called early right after surface creation.
// If our API has to do things here, let it.
// This is called just prior to spinning up the renderer thread for
// final main thread setup requirements.
// If our API has to do things to finalize surface init, let it.
// Callback called by renderer.Thread when it begins.
// If our API has to do things on thread enter, let it.
// Callback called by renderer.Thread when it exits.
// If our API has to do things on thread exit, let it.
// Called by renderer.Thread when it starts the main loop.
// If our API has to do things on loop enter, let it.
// If we don't support a display link we have no work to do.
// This is when we know our "self" pointer is stable so we can
// setup the display link. To setup the display link we set our
// callback and we can start it immediately.
// Called by renderer.Thread when it exits the main loop.
// If our API has to do things on loop exit, let it.
// If we don't support a display link we have no work to do.
// Stop our display link. If this fails its okay it just means
// that we either never started it or the view its attached to
// is gone which is fine.
// This is called by the GTK apprt after the surface is
// reinitialized due to any of the events mentioned in
// the doc comment for `displayUnrealized`.
// If our API has to do things on realize, let it.
// Lock the draw mutex so that we can
// safely reinitialize our GPU resources.
// We assume that the swap chain was deinited in
// `displayUnrealized`, in which case it should be
// marked defunct. If not, we have a problem.
// We reinitialize our shaders and our swap chain.
// This is called by the GTK apprt when the surface is being destroyed.
// This can happen because the surface is being closed but also when
// moving the window between displays or splitting.
// If our API has to do things on unrealize, let it.
// Lock the draw mutex so that we can
// safely deinitialize our GPU resources.
// We deinit our swap chain and shaders.
//
// This will mark them as defunct so that they
// can't be double-freed or used in draw calls.
// Mark the full screen as dirty so that we redraw everything.
// Called when we get an updated display ID for our display link.
// True if our renderer has animations so that a higher frequency
// timer is used.
// True if our renderer is using vsync. If true, the renderer or apprt
// is responsible for triggering draw_now calls to the render thread.
// That is the only way to trigger a drawFrame.
// Callback when the focus changes for the terminal this is rendering.
//
// Must be called on the render thread.
// Flag that we need to update our custom shaders
// If we're not focused, then we want to stop the display link
// because it is a waste of resources and we can move to pure
// change-driven updates.
// Callback when the window is visible or occluded.
//
// Must be called on the render thread.
// If we're not visible, then we want to stop the display link
// because it is a waste of resources and we can move to pure
// change-driven updates.
// Set the new font grid.
//
// Must be called on the render thread.
// Update our grid
// Update all our textures so that they sync on the next frame.
// We can modify this without a lock because the GPU does not
// touch this data.
// Get our metrics from the grid. This doesn't require a lock because
// the metrics are never recalculated.
// Reset our shaper cache. If our font changed (not just the size) then
// the data in the shaper cache may be invalid and cannot be used, so we
// always clear the cache just in case.
// Update cell size.
// Update relevant uniforms
// Force a full rebuild, because cached rows may still reference
// an outdated atlas from the old grid and this can cause garbage
// to be rendered.
// Update uniforms that are based on the font grid.
//
// Caller must hold the draw mutex.
// Update the frame data.
// const start = std.time.Instant.now() catch unreachable;
// const start_micro = std.time.microTimestamp();
// defer {
//     const end = std.time.Instant.now() catch unreachable;
//     log.warn(
//         "[updateFrame time] start_micro={} duration={}ns",
//         .{ start_micro, end.since(start) / std.time.ns_per_us },
//     );
// }
// We fully deinit and reset the terminal state every so often
// so that a particularly large terminal state doesn't cause
// the renderer to hold on to retained memory.
//
// Frame count is ~12 minutes at 120Hz.
// Create an arena for all our temporary allocations while rebuilding
// Data we extract out of the critical area.
// Update all our data as tightly as possible within the mutex.
// const start = try std.time.Instant.now();
// const start_micro = std.time.microTimestamp();
// defer {
//     const end = std.time.Instant.now() catch unreachable;
//     std.log.err("[updateFrame critical time] start={}\tduration={} us", .{ start_micro, end.since(start) / std.time.ns_per_us });
// }
// If we're in a synchronized output state, we pause all rendering.
// Update our terminal state
// If our terminal state is dirty at all we need to redo
// the viewport search.
// Get our scrollbar out of the terminal. We synchronize
// the scrollbar read with frame data updates because this
// naturally limits the number of calls to this method (it
// can be expensive) and also makes it so we don't need another
// cross-thread mailbox message within the IO path.
// Get our preedit state
// If we have Kitty graphics data, we enter a SLOW SLOW SLOW path.
// We only do this if the Kitty image state is dirty meaning only if
// it changes.
//
// If we have any virtual references, we must also rebuild our
// kitty state on every frame because any cell change can move
// an image.
// Get our OSC8 links we're hovering if we have a mouse.
// This requires terminal state because of URLs.
// If our mouse isn't hovering, we have no links.
// If the right mods aren't pressed, then we can't match.
// Outside the critical area we can update our links to contain
// our regex results.
// Clear our highlight state and update.
// Clear the prior highlights
// NOTE: The order below matters. Highlights added earlier
// will take priority.
// Not a critical error, we just won't show highlights.
// Not a critical error, we just won't show highlights.
// From this point forward no more errors.
// Reset our dirty state after updating.
// Rebuild the overlay image if we have one. We can do this
// outside of any critical areas.
// Acquire the draw mutex for all remaining state updates.
// Build our GPU cells
// This means we weren't able to allocate our buffer
// to update the cells. In this case, we continue with
// our old buffer (frozen contents) and log it.
// The scrollbar is only emitted during draws so we also
// check the scrollbar cache here and update if needed.
// This is pretty fast.
// Update our background color
// If we're on macOS and have glass styles, we remove
// the background opacity because the glass effect handles
// it.
// Prepare our overlay image for upload (or unload). This
// has to use our general allocator since it modifies
// state that survives frames.
// Update custom shader uniforms that depend on terminal state.
// Notify our shaper we're done for the frame. For some shapers,
// such as CoreText, this triggers off-thread cleanup logic.
// Draw the frame to the screen.
//
// If `sync` is true, this will synchronously block until
// the frame is finished drawing and has been presented.
// const start = std.time.Instant.now() catch unreachable;
// const start_micro = std.time.microTimestamp();
// defer {
//     const end = std.time.Instant.now() catch unreachable;
//     log.warn(
//         "[drawFrame time] start_micro={} duration={}ns",
//         .{ start_micro, end.since(start) / std.time.ns_per_us },
//     );
// }
// We hold a the draw mutex to prevent changes to any
// data we access while we're in the middle of drawing.
// After the graphics API is complete (so we defer) we want to
// update our scrollbar state.
// Fail instantly if the surface mailbox if full, we'll just
// get it on the next frame.
// Let our graphics API do any bookkeeping, etc.
// that it needs to do before / after `drawFrame`.
// Retrieve the most up-to-date surface size from the Graphics API
// If either of our surface dimensions is zero
// then drawing is absurd, so we just return.
// Conditions under which we need to draw the frame, otherwise we
// don't need to since the previous frame should be identical.
// We still need to present the last target again, because the
// apprt may be swapping buffers and display an outdated frame
// if we don't draw something new.
// Wait for a frame to be available.
// log.debug("drawing frame index={}", .{self.swap_chain.frame_index});
// If we need to reinitialize our shaders, do so.
// Our shaders should not be defunct at this point.
// If we have custom shaders, make sure we have the
// custom shader state in our frame state, otherwise
// if we have a state but don't need it we remove it.
// If our stored size doesn't match the
// surface size we need to update it.
// If this frame's target isn't the correct size, or the target
// config has changed (such as when the blending mode changes),
// remove it and replace it with a new one with the right values.
// Upload images to the GPU as necessary.
// Upload the background image to the GPU as necessary.
// Update per-frame custom shader uniforms.
// Setup our frame data
// If our background image buffer has changed, sync it.
// If our font atlas changed, sync the texture data
// Get a frame context from the graphics API.
// First we draw our background image, if we have one.
// The bg image shader also draws the main bg color.
//
// Otherwise, if we don't have a background image, we
// draw the background color by itself in its own step.
//
// NOTE: We don't use the clear_color for this because that
//       would require us to do color space conversion on the
//       CPU-side. In the future when we have utilities for
//       that we should remove this step and use clear_color.
// Then we draw any kitty images that need
// to be behind text AND cell backgrounds.
// Then we draw any opaque cell backgrounds.
// Kitty images between cell backgrounds and text.
// Text.
// Kitty images in front of text.
// Debug overlay. We do this before any custom shader state
// because our debug overlay is aligned with the grid.
// If we have custom shaders, then we render them.
// Sync our uniforms.
// Callback from the graphics API when a frame is completed.
// If our health value hasn't changed, then we do nothing. We don't
// do a cmpxchg here because strict atomicity isn't important.
// Our health value changed, so we notify the surface so that it
// can do something about it.
// Always release our semaphore
// Call this any time the background image path changes.
//
// Caller must hold the draw mutex.
// Then we try to load the background image if we have a path.
// Open the file
// Read it
// Figure out what type it probably is.
// Decode it if we know how.
// If we have an existing background image, replace it.
// Otherwise, set this as our background image directly.
// If we don't have a background image path, mark our
// background image for unload if we currently have one.
// Make sure our bg image is uploaded if it needs to be.
// Update the configuration.
// We always redo the font shaper in case font features changed. We
// could check to see if there was an actual config change but this is
// easier and rare enough to not cause performance issues.
// We also need to reset the shaper cache so shaper info
// from the previous font isn't reused for the new font.
// Set our new minimum contrast
// Set our new color space and blending
// If our background image path changed, prepare the new bg image.
// If our background image config changed, update the vertex buffer.
// Reset our viewport to force a rebuild, in case of a font change.
// We update our API's blending mode.
// And indicate that we need to reinitialize our shaders.
// And indicate that our swap chain targets need to
// be re-created to account for the new blending mode.
// Resize the screen.
// We only actually need the padding from this,
// everything else is derived elsewhere.
// Update uniforms that are based on the screen size.
//
// Caller must hold the draw mutex.
// Blank space around the grid.
// Setup our uniforms
// Update the background image vertex buffer (CPU-side).
//
// This should be called if and when configs change that
// could affect the background image.
//
// Caller must hold the draw mutex.
// Signal that the buffer was modified.
// Update custom shader uniforms that depend on terminal state.
//
// This should be called in `updateFrame` when terminal state changes.
// We only need to do this if we have custom shaders.
// Only update when terminal state is dirty.
// 256-color palette
// Background color
// Foreground color
// Cursor color
// NOTE: the following could be optimized to follow a change in
// config for a slight optimization however this is only 12 bytes
// each being updated and likely isn't a cause for concern
// Cursor text color
// Selection background color
// Selection foreground color
// Update per-frame custom shader uniforms.
//
// This should be called exactly once per frame, inside `drawFrame`.
// We only need to do this if we have custom shaders.
// Update custom cursor uniforms, if we have a cursor.
// Left edge of the cell the cursor is in.
// Top edge, relative to the top of the
// screen, of the cell the cursor is in.
// If +Y is up in our shaders, we need to flip the coordinate
// so that it's instead the top edge of the cell relative to
// the *bottom* of the screen.
// Add the X bearing to get the -X (left) edge of the cursor.
// How we deal with the Y bearing depends on which direction
// is "up", since we want our final `pixel_y` value to be the
// +Y edge of the cursor.
// As a reminder, the Y bearing is the distance from the
// bottom of the cell to the top of the glyph, so to get
// the +Y edge we need to add the cell height, subtract
// the Y bearing, and add the glyph height to get the +Y
// (bottom) edge of the cursor.
// If the Y direction is reversed though, we instead want
// the *top* edge of the cursor, which means we just need
// to subtract the cell height and add the Y bearing.
// Update focus uniforms
// If we need to update the time our focus state changed
// then update it to our current frame time. This may not be
// exactly correct since it is frame time, not exact focus
// time, but focus time on its own isn't exactly correct anyways
// since it comes async from a message.
// Build the overlay as configured. Returns null if there is no
// overlay currently configured.
// const start = std.time.Instant.now() catch unreachable;
// const start_micro = std.time.microTimestamp();
// defer {
//     const end = std.time.Instant.now() catch unreachable;
//     log.warn(
//         "[rebuildOverlay time] start_micro={} duration={}ns",
//         .{ start_micro, end.since(start) / std.time.ns_per_us },
//     );
// }
// If we have no features enabled, don't build an overlay.
// If we had a previous overlay, deallocate it.
// If we had a previous overlay, clear it. Otherwise, init.
// Verify that our overlay size matches our screen
// size as we know it now. If not, deinit and reinit.
// Note: these intCasts are always safe because z2d
// stores as i32 but we always init with a u32.
// We also depend on cell size.
// Everything matches, so we can just reset the surface
// and redraw.
// If we reached this point we want to reset our overlay.
// Convert the terminal state to GPU cells stored in CPU memory. These
// are then synced to the GPU in the next frame. This only updates CPU
// memory and doesn't touch the GPU.
//
// This requires the draw mutex.
//
// Dirty state on terminal state won't be reset by this.
// const start = try std.time.Instant.now();
// const start_micro = std.time.microTimestamp();
// defer {
//     const end = std.time.Instant.now() catch unreachable;
//     // "[rebuildCells time] <START us>\t<TIME_TAKEN us>"
//     std.log.warn("[rebuildCells time] {}\t{}", .{start_micro, end.since(start) / std.time.ns_per_us});
// }
// Determine our x/y range for preedit. We don't want to render anything
// here because we will render the preedit separately.
// We base the preedit on the position of the cursor in the
// viewport. If the cursor isn't visible in the viewport we
// don't show it.
// Update our uniforms accordingly, otherwise
// our background cells will be out of place.
// If we are doing a full rebuild, then we clear the entire cell buffer.
// We also reset our padding extension depending on the screen type
// For extension, assume we are extending in all directions.
// For "extend" this may be disabled due to heuristics below.
// From this point on we never fail. We produce some kind of
// working terminal state, even if incorrect.
// Get our row data from our state
// If our cell contents buffer is shorter than the screen viewport,
// we render the rows that fit, starting from the bottom. If instead
// the viewport is shorter than the cell contents buffer, we align
// the top of the viewport with the top of the contents buffer.
// Only rebuild if we are doing a full rebuild or this row is dirty.
// Clear the cells if the row is dirty
// Unmark the dirty state in our render state.
// This should never happen except under exceptional
// scenarios. In this case, we don't want to corrupt
// our render state so just clear this row and keep
// trying to finish it out.
// Setup our cursor rendering information.
// Clear our cursor by default.
// If the cursor isn't visible on the viewport, don't show
// a cursor. Otherwise, get our cursor cell, because we may
// need it for styling.
// If we have preedit text, we don't setup a cursor
// If there isn't a cursor visual style requested then
// we don't render a cursor.
// Determine the cursor color.
// If an explicit cursor color was set by OSC 12, use that.
// Use our configured color if specified
// If the cursor is visible then we set our uniforms.
// If we are a spacer tail of a wide cell, our cursor needs
// to move back one cell. The saturate is to ensure we don't
// overflow but this shouldn't happen with well-formed input.
// If cursor-text is set, then compute the correct color.
// Otherwise, use the background color.
// Use the color set by cursor-text, if any.
// If the cell is reversed, use the opposite cell color instead.
// Setup our preedit text.
// Update that our cells rebuilt
// Log some things
// log.debug("rebuildCells complete cached_runs={}", .{
//     self.font_shaper_cache.count(),
// });
// If our viewport is wider than our cell contents buffer,
// we still only process cells up to the width of the buffer.
// On primary screen, we still apply vertical padding
// extension under certain conditions we feel are safe.
//
// This helps make some scenarios look better while
// avoiding scenarios we know do NOT look good.
// These already have the correct values set above.
// Apply heuristics for padding extension.
// Iterator of runs for shaping.
// We want to do font shaping as long as the cursor is
// visible on this viewport.
// If this cell falls within our preedit range then we
// skip this because preedits are setup separately.
// We're not on the preedit line, no actions necessary.
// We're before the preedit range, no actions necessary.
// We're in the preedit range, skip this cell.
// After exiting the preedit range we need to catch
// the run position up because of the missed cells.
// In all other cases, no action is necessary.
// Step the run iterator until we find a run that ends
// after the current cell, which will be the soonest run
// that might contain glyphs for our cell.
// If we haven't shaped this run, do so now.
// Try to read the cells from the shaping cache if we can.
// Otherwise we have to shape them.
// Try to cache them. If caching fails for any reason we
// continue because it is just a performance optimization,
// not a correctness issue.
// The cells we get from direct shaping are always owned
// by the shaper and valid until the next shaping call so
// we can safely use them.
// Advance our index until we reach or pass
// our current x position in the shaper cells.
// True if this cell is selected
// Order below matters for precedence.
// Selection should take the highest precedence.
// If we're highlighted, then we're selected. In the
// future we want to use a different style for this
// but this to get started.
// The `_style` suffixed values are the colors based on
// the cell style (SGR), before applying any additional
// configuration, inversions, selections, etc.
// The final background color for the cell.
// If we have an explicit selection background color
// specified in the config, use that.
//
// If no configuration, then our selection background
// is our foreground color.
// Not selected
// Two cases cause us to invert (use the fg color as the bg)
// - The "inverse" style flag.
// - A "covering" glyph; we use fg for bg in that
//   case to help make sure that padding extension
//   works correctly.
//
// If one of these is true (but not the other)
// then we use the fg style color for the bg.
// Otherwise they cancel out.
// Our happy-path non-selection background color
// is our style or our configured defaults.
// Whether we need to use the bg color as our fg color:
// - Cell is selected, inverted, and set to cell-foreground
// - Cell is selected, not inverted, and set to cell-background
// - Cell is inverted and not selected
// Foreground alpha for this cell.
// Set the cell's background color.
// Determine our background alpha. If we have transparency configured
// then this is dynamic depending on some situations. This is all
// in an attempt to make transparency look the best for various
// situations. See inline comments.
// Cells that are selected should be fully opaque.
// Cells that are reversed should be fully opaque.
// If the user requested to have opacity on all cells, apply it.
// Cells that have an explicit bg color should be fully opaque.
// Otherwise, we won't draw the bg for this cell,
// we'll let the already-drawn background color
// show through.
// If the invisible flag is set on this cell then we
// don't need to render any foreground elements, so
// we just skip all glyphs with this x coordinate.
//
// NOTE: This behavior matches xterm. Some other terminal
// emulators, e.g. Alacritty, still render text decorations
// and only make the text itself invisible. The decision
// has been made here to match xterm's behavior for this.
// Give links a single underline, unless they already have
// an underline, in which case use a double underline to
// distinguish them.
// We draw underlines first so that they layer underneath text.
// This improves readability when a colored underline is used
// which intersects parts of the text (descenders).
// If we're at or past the end of our shaper run then
// we need to get the next run from the run iterator.
// If we haven't shaped this run yet, do so.
// Try to read the cells from the shaping cache if we can.
// Otherwise we have to shape them.
// Try to cache them. If caching fails for any reason we
// continue because it is just a performance optimization,
// not a correctness issue.
// The cells we get from direct shaping are always owned
// by the shaper and valid until the next shaping call so
// we can safely use them.
// If there are no shaper cells for this run, ignore it.
// This can occur for runs of empty cells, and is fine.
// If we encounter a shaper cell to the left of the current
// cell then we have some problems. This logic relies on x
// position monotonically increasing.
// NOTE: An assumption is made here that a single cell will never
// be present in more than one shaper run. If that assumption is
// violated, this logic breaks.
// Finally, draw a strikethrough if necessary.
// Add an underline decoration to the specified cell
// Add a overline decoration to the specified cell
// Add a strikethrough decoration to the specified cell
// Add a glyph to the specified cell.
// Render
// If there's no Nerd Font constraint for this codepoint
// then, if it's a symbol, we constrain it to fit inside
// its cell(s), we don't modify the alignment at all.
// If the glyph is 0 width or height, it will be invisible
// when drawn, so don't bother adding it to the buffer.
// Add the cursor. We render the cursor over the wide character if
// we're on the wide character tail.
// The cursor goes over the screen cursor position.
// If we're part of a wide character, we move the cursor back
// to the actual character.
// This should never happen because we embed nerd
// fonts so we just log and return instead of fallback.
// Render the glyph for our preedit text
// Add our opaque background cell
// Add our text
// Add underline
// Sync the atlas data to the given texture. This copies the bytes
// associated with the atlas to the given texture. If the atlas no
// longer fits into the texture, the texture will be resized.
// Free our old texture
// Reallocate
//
// --- Original Ghostty Comments End: src/renderer/generic.zig

import input
import sync
import terminal
import font
import time
import configpkg
import highlight

// Create a renderer type with the provided graphics API wrapper.
//
// The graphics API wrapper must provide the interface outlined below.
// Specific details for the interfaces are documented on the existing
// implementations (Metal and OpenGL).
//
// In this V translation, we use Metal as our graphics backend
// on macOS, with stubs for OpenGL and WebGL.
//
// Hierarchy of graphics abstractions:
//
// [ GraphicsAPI ] - Responsible for configuring the runtime surface
//    |     |        and providing render Targets that draw to it,
//    |     |        as well as Frames and Pipelines.
//    |     V
//    | [ Target ] - Represents an abstract target for rendering, which
//    |              could be a surface directly but is also used as an
//    |              abstraction for off-screen frame buffers.
//    V
// [ Frame ] - Represents the context for drawing a given frame,
//    |        provides RenderPasses for issuing draw commands
//    |        to, and reports the frame health when complete.
//    V
// [ RenderPass ] - Represents a render pass in a frame, consisting of
//   :              one or more Steps applied to the same target(s),
// [ Step ] - - - - each describing the input buffers and textures and
//   :              the vertex/fragment functions and geometry to use.
//   :_ _ _ _ _ _ _ _ _ _/
//   v
// [ Pipeline ] - Describes a vertex and fragment function to be used
//                for a Step; the GraphicsAPI is responsible for
//                these and they should be constructed and cached
//                ahead of time.
//
// [ Buffer ] - An abstraction over a GPU buffer.
//
// [ Texture ] - An abstraction over a GPU texture.

// Renderer handles drawing the terminal surface using Metal.
pub struct Renderer {
pub mut:
	// The Metal graphics API for rendering.
	metal &MetalAPI = unsafe { nil }

	// The configuration we need derived from the main config.
	config DerivedConfig

	// Current font metrics defining our grid.
	grid_metrics font.Metrics

	// The size of everything.
	size Size

	// True if the window is focused.
	focused bool = true

	// Flag to indicate that our focus state changed for custom
	// shaders to update their state.
	custom_shader_focused_changed bool

	// The most recent scrollbar state. We use this as a cache to
	// determine if we need to notify the apprt that there was a
	// scrollbar change.
	scrollbar terminal.Scrollbar
	// Whether the scrollbar state has changed since last frame.
	scrollbar_dirty bool

	// The most recent viewport matches so that we can render search
	// matches in the visible frame. This is provided asynchronously
	// from the search thread so we have the dirty flag to also note
	// if we need to rebuild our cells to include search highlights.
	//
	// Note that the selections MAY BE INVALID (point to PageList nodes
	// that do not exist anymore). These must be validated prior to use.
	search_matches        []highlight.FlattenedHighlight
	search_selected_match ?highlight.FlattenedHighlight
	search_matches_dirty  bool

	// The current set of cells to render. This is rebuilt on every frame
	// but we keep this around so that we don't reallocate. Each set of
	// cells goes into a separate shader.
	cells CellContents

	// Set to true after rebuild_cells is called. This can be used
	// to determine if any possible changes have been made to the
	// cells for the draw call.
	cells_rebuilt bool

	// The current GPU uniform values.
	uniforms Uniforms

	// Custom shader uniform values.
	custom_shader_uniforms CustomShaderUniforms

	// Timestamp we rendered our first frame (nanoseconds since monotonic epoch).
	//
	// This is used when updating custom shader uniforms.
	first_frame_time i64 = -1

	// Timestamp when we rendered our most recent frame (nanoseconds since monotonic epoch).
	//
	// This is used when updating custom shader uniforms.
	last_frame_time i64 = -1

	// The font structures.
	font_grid         &font.SharedGrid = unsafe { nil }
	font_shaper       font.Shaper
	font_shaper_cache font.ShaperCache

	// Whether or not we have custom shaders.
	has_custom_shaders bool

	// If something happened that requires us to reinitialize our shaders,
	// this is set to true so that we can do that whenever possible.
	reinitialize_shaders bool

	// The render state we update per loop.
	terminal_state terminal.RenderState

	// The number of frames since the last terminal state reset.
	// We reset the terminal state after ~100,000 frames (about 10 to
	// 15 minutes at 120Hz) to prevent wasted memory buildup from
	// a large screen.
	terminal_state_frame_count u64

	// Background image data, if we have one.
	bg_image ?MetalTexture

	// Set whenever the background image changes, signalling
	// that the new background image needs to be uploaded to
	// the GPU.
	//
	// This is initialized as true so that we load the image
	// on renderer initialization, not just on config change.
	bg_image_changed bool = true

	// Background image vertex buffer.
	bg_image_buffer BgImageBuffer

	// Health of the most recently completed frame.
	health Health = .healthy
}

// Initialize the renderer.
pub fn Renderer.init(opts RendererOpts) !Renderer {
	// Create the font shaper
	mut font_shaper := font.Shaper.init(font.ShaperOptions{})!

	// Get font metrics from the grid
	grid := opts.font_grid
	metrics := grid.metrics

	has_custom_shaders := false

	mut result := Renderer{
		config: opts.config
		grid_metrics: metrics
		size: opts.size
		focused: true
		scrollbar: terminal.Scrollbar{}
		scrollbar_dirty: false
		search_matches_dirty: false
		search_matches: []highlight.FlattenedHighlight{}
		search_selected_match: none
		// Render state
		cells: CellContents{}
		uniforms: Uniforms{
			min_contrast: opts.config.min_contrast
			cursor_pos: [u16(0xFFFF), u16(0xFFFF)]!
			bg_color: [
				opts.config.background.r,
				opts.config.background.g,
				opts.config.background.b,
				u8(opts.config.background_opacity * 255.0),
			]!
			bools: UniformBools{
				cursor_wide: false
				use_display_p3: opts.config.colorspace == .display_p3
				use_linear_blending: opts.config.blending.is_linear()
				use_linear_correction: opts.config.blending == .linear_corrected
			}
		}
		custom_shader_uniforms: CustomShaderUniforms{
			focus: 1
		}
		// Fonts
		font_grid: opts.font_grid
		font_shaper: font_shaper
		font_shaper_cache: font.ShaperCache.init()
		has_custom_shaders: has_custom_shaders
	}

	// Ensure our undefined values above are correctly initialized
	result.update_font_grid_uniforms()
	result.update_screen_size_uniforms()
	result.update_bg_image_buffer()

	return result
}

// Deinitialize the renderer and free all resources.
pub fn (mut self Renderer) deinit() {
	for mut match_ in self.search_matches {
		match_.deinit()
	}
	self.search_matches = []
	if mut match_ := self.search_selected_match {
		match_.deinit()
	}
	self.search_selected_match = none
	self.terminal_state.deinit()
	self.font_shaper.deinit()
	self.font_shaper_cache.deinit()
	self.config.deinit()
}

// Mark the full screen as dirty so that we redraw everything.
pub fn (mut self Renderer) mark_dirty() {
	self.terminal_state.dirty = .full
}

// True if our renderer has animations so that a higher frequency
// timer is used.
pub fn (self &Renderer) has_animations() bool {
	return self.has_custom_shaders
}

// True if our renderer is using vsync. If true, the renderer or apprt
// is responsible for triggering draw_now calls to the render thread.
// That is the only way to trigger a draw_frame.
pub fn (self &Renderer) has_vsync() bool {
	return false
}

// Callback when the focus changes for the terminal this is rendering.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_focus(focus bool) ! {
	self.focused = focus

	// Flag that we need to update our custom shaders
	self.custom_shader_focused_changed = true
}

// Callback when the window is visible or occluded.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_visible(visible bool) {
	// On platforms with display links, we would start/stop
	// the display link here based on visibility. With gg,
	// visibility is managed by the framework.
	_ = visible
}

// Set the new font grid.
//
// Must be called on the render thread.
pub fn (mut self Renderer) set_font_grid(grid &font.SharedGrid) {
	// Update our grid
	self.font_grid = unsafe { grid }

	// Get our metrics from the grid. This doesn't require a lock because
	// the metrics are never recalculated.
	metrics := grid.metrics
	self.grid_metrics = metrics

	// Reset our shaper cache. If our font changed (not just the size) then
	// the data in the shaper cache may be invalid and cannot be used, so we
	// always clear the cache just in case.
	font_shaper_cache := font.ShaperCache.init()
	self.font_shaper_cache.deinit()
	self.font_shaper_cache = font_shaper_cache

	// Update cell size
	self.size.cell = CellSize{
		width: metrics.cell_width
		height: metrics.cell_height
	}

	// Update relevant uniforms
	self.update_font_grid_uniforms()

	// Force a full rebuild, because cached rows may still reference
	// an outdated atlas from the old grid and this can cause garbage
	// to be rendered.
	self.mark_dirty()
}

// Update uniforms that are based on the font grid.
fn (mut self Renderer) update_font_grid_uniforms() {
	self.uniforms.cell_size = [
		f32(self.grid_metrics.cell_width),
		f32(self.grid_metrics.cell_height),
	]!
}

// Update the frame data. This translates the CPU-side of Ghostty's
// updateFrame: the critical-section extraction (terminal state update,
// sync-output pause, scrollbar read, OSC8 links, search highlights) plus
// the cell rebuild and per-frame uniform updates.
//
// BOUNDARY: In Ghostty this takes a `*renderer.State` (holding a mutex,
// mouse, preedit and inspector) and locks it around the critical section.
// The V thread passes the terminal directly, so the mouse/preedit/inspector
// (which live on the renderer RenderState, not passed here) and the OSC8
// link cell matching that depends on the mouse point are boundaries; we
// translate everything that is reachable from the terminal state.
pub fn (mut self Renderer) update_frame(state &terminal.Terminal, cursor_blink_visible bool) ! {
	// We fully deinit and reset the terminal state every so often
	// so that a particularly large terminal state doesn't cause
	// the renderer to hold on to retained memory.
	//
	// Frame count is ~12 minutes at 120Hz.
	max_terminal_state_frame_count := u64(100_000)
	if self.terminal_state_frame_count >= max_terminal_state_frame_count {
		self.terminal_state.deinit()
		self.terminal_state = terminal.RenderState{}
	}
	self.terminal_state_frame_count += 1

	// Data we extract out of the critical area. In Ghostty this is done
	// under the state mutex; here we alias the terminal mutably because
	// the caller owns a mutable terminal and terminal_state.update mutates
	// dirty flags.
	mut t := unsafe { &terminal.Terminal(state) }

	// If we're in a synchronized output state, we pause all rendering.
	if t.modes.get(.synchronized_output) {
		return
	}

	// Update our terminal state.
	self.terminal_state.update(mut t)

	// Get our scrollbar out of the terminal. We synchronize the scrollbar
	// read with frame data updates.
	//
	// BOUNDARY: In Ghostty the scrollbar comes from
	// `screens.active.pages.scrollbar()` (a PageList method). The V
	// simplified terminal `Pages` type does not implement `scrollbar()`,
	// so we use a default (empty) scrollbar here.
	scrollbar := terminal.Scrollbar{}

	// Get our OSC8 links we're hovering if we have a mouse.
	//
	// BOUNDARY: The mouse point/mods live on the renderer RenderState which
	// isn't passed to this method, so we can't match hovered OSC8 links
	// here. We use an empty link set.
	links := terminal.CellSet(map[u64]bool{})

	// Clear our highlight state and update. The order matters: selected
	// highlights are appended first and therefore take visual priority.
	if self.search_matches_dirty || self.terminal_state.dirty != .false_ {
		self.search_matches_dirty = false

		mut any_dirty := false
		for mut r in self.terminal_state.row_data {
			if r.highlights.len > 0 {
				r.highlights = []
				r.dirty = true
				any_dirty = true
			}
		}
		if any_dirty && self.terminal_state.dirty == .false_ {
			self.terminal_state.dirty = .partial
		}

		if selected := self.search_selected_match {
			converted := render_flattened_highlight(selected)
			self.terminal_state.update_highlights_flattened(u8(HighlightTag.search_match_selected), [
				converted,
			])
		}
		if self.search_matches.len > 0 {
			mut converted := []terminal.RenderFlattenedHighlight{cap: self.search_matches.len}
			for match_ in self.search_matches {
				converted << render_flattened_highlight(match_)
			}
			self.terminal_state.update_highlights_flattened(u8(HighlightTag.search_match), converted)
		}
	}

	// Build our GPU cells.
	cs := cursor_style(&self.terminal_state, StyleOptions{
		preedit: false
		focused: self.focused
		blink_visible: cursor_blink_visible
	})
	self.rebuild_cells(none, cs, &links) or {
		// This means we weren't able to allocate our buffer to update the
		// cells. In this case, we continue with our old buffer.
	}

	// The scrollbar is only emitted during draws so we also check the
	// scrollbar cache here and update if needed.
	if !self.scrollbar.eql(scrollbar) {
		self.scrollbar = scrollbar
		self.scrollbar_dirty = true
	}

	// Update our background color.
	self.uniforms.bg_color = [
		self.terminal_state.colors.background.r,
		self.terminal_state.colors.background.g,
		self.terminal_state.colors.background.b,
		u8(self.config.background_opacity * 255.0),
	]!

	// Update custom shader uniforms that depend on terminal state.
	self.update_custom_shader_uniforms_from_state()

	// Reset our dirty state after updating.
	self.terminal_state.dirty = .false_

	// Signal shaper we're done for the frame.
	self.font_shaper.end_frame()
}

fn render_flattened_highlight(src highlight.FlattenedHighlight) terminal.RenderFlattenedHighlight {
	mut chunks := []terminal.RenderHighlightChunk{cap: src.chunks.len}
	for chunk in src.chunks {
		chunks << terminal.RenderHighlightChunk{
			node: chunk.node
			serial: chunk.serial
			start: chunk.start
			end: chunk.end
		}
	}
	return terminal.RenderFlattenedHighlight{
		chunks: chunks
		top_x: src.top_x
		bot_x: src.bot_x
	}
}

// Draw the frame to the screen.
//
// If `sync` is true, this will synchronously block until
// the frame is finished drawing and has been presented.
pub fn (mut self Renderer) draw_frame(sync_ bool) ! {
	// If either of our surface dimensions is zero
	// then drawing is absurd, so we just return.
	if self.size.screen.width == 0 || self.size.screen.height == 0 {
		return
	}

	// Conditions under which we need to draw the frame, otherwise we
	// don't need to since the previous frame should be identical.
	needs_redraw := self.cells_rebuilt || self.has_animations() || sync_

	if !needs_redraw {
		return
	}
	self.cells_rebuilt = false

	// XTODO: Metal rendering pipeline:
	// 1. metal.begin_frame() -> command buffer
	// 2. Render pass 1: background color (full-screen quad)
	// 3. Render pass 2: cell backgrounds (instanced, bg_cells buffer)
	// 4. Render pass 3: text glyphs (instanced, fg_rows buffer + font atlas texture)
	// 5. metal.complete_frame() -> present drawable, commit

	_ = sync_
}

// Draw the background image via Metal.
fn (self &Renderer) draw_background_image(img MetalTexture) {
	// XTODO: Background image rendering via Metal render pass.
	// Requires bg_image pipeline, texture binding, and instanced quad draw.
	_ = img
}

// Draw all cell background colors via Metal.
fn (self &Renderer) draw_cell_backgrounds() {
	// XTODO: Cell background rendering via Metal instanced draw.
	// Sync bg_cells buffer to GPU, bind cell_bg pipeline, draw instanced quads.
}

// Draw all foreground cells (text glyphs, underlines, etc) via Metal.
fn (self &Renderer) draw_cell_foregrounds() {
	// XTODO: Glyph rendering via Metal instanced draw.
	// Sync fg cell buffer + font atlas texture, bind cell_text pipeline, draw.
}

// Draw the cursor via Metal.
fn (self &Renderer) draw_cursor() {
	// XTODO: Cursor rendering via Metal.
	// Uses cursor sprite from font atlas, drawn as instanced quad.
	_ = self.cells.cursor or { return }
	_ = self.cells.cursor_style or { return }
}

// Callback from the graphics API when a frame is completed.
pub fn (mut self Renderer) frame_completed(health Health) {
	// If our health value hasn't changed, then we do nothing.
	if self.health != health {
		self.health = health
	}
}

// Call this any time the background image path changes.
fn (mut self Renderer) prep_background_image() ! {
	// XTODO: Background image loading requires file I/O and image
	// decoding (PNG/JPEG), then creating a MetalTexture.
	if self.config.bg_image != none {
		// Would load and decode the image here
		self.bg_image_changed = true
	} else {
		self.bg_image = none
	}
}

// Update the configuration.
pub fn (mut self Renderer) change_config(config &DerivedConfig) ! {
	// We always redo the font shaper in case font features changed. We
	// could check to see if there was an actual config change but this is
	// easier and rare enough to not cause performance issues.
	mut font_shaper := font.Shaper.init(font.ShaperOptions{
		features: config.font_features
	})!
	self.font_shaper.deinit()
	self.font_shaper = font_shaper

	// We also need to reset the shaper cache so shaper info
	// from the previous font isn't reused for the new font.
	font_shaper_cache := font.ShaperCache.init()
	self.font_shaper_cache.deinit()
	self.font_shaper_cache = font_shaper_cache

	// Set our new minimum contrast
	self.uniforms.min_contrast = config.min_contrast

	// Set our new color space and blending
	self.uniforms.bools.use_display_p3 = config.colorspace == .display_p3
	self.uniforms.bools.use_linear_blending = config.blending.is_linear()
	self.uniforms.bools.use_linear_correction = config.blending == .linear_corrected

	bg_image_config_changed := self.config.bg_image_fit != config.bg_image_fit
		|| self.config.bg_image_position != config.bg_image_position
		|| self.config.bg_image_repeat != config.bg_image_repeat
		|| self.config.bg_image_opacity != config.bg_image_opacity

	self.config.deinit()
	self.config = *config

	// If our background image config changed, update the vertex buffer
	if bg_image_config_changed {
		self.update_bg_image_buffer()
	}

	// Reset our viewport to force a rebuild, in case of a font change
	self.mark_dirty()
}

// Resize the screen.
pub fn (mut self Renderer) set_screen_size(size Size) {
	// We only actually need the padding from this,
	// everything else is derived elsewhere.
	self.size.padding = size.padding

	self.update_screen_size_uniforms()
}

// Update uniforms that are based on the screen size.
fn (mut self Renderer) update_screen_size_uniforms() {
	terminal_size := self.size.terminal_size()

	// Blank space around the grid
	blank := self.size.blank_padding(self.cells.size)

	// Setup our uniforms
	self.uniforms.projection_matrix = ortho2d(
		-1 * f32(self.size.padding.left),
		f32(terminal_size.width + self.size.padding.right),
		f32(terminal_size.height + self.size.padding.bottom),
		-1 * f32(self.size.padding.top),
	)
	self.uniforms.grid_padding = [
		f32(blank.top),
		f32(blank.right),
		f32(blank.bottom),
		f32(blank.left),
	]!
	self.uniforms.screen_size = [
		f32(self.size.screen.width),
		f32(self.size.screen.height),
	]!
}

// Update the background image vertex buffer (CPU-side).
//
// This should be called if and when configs change that
// could affect the background image.
fn (mut self Renderer) update_bg_image_buffer() {
	self.bg_image_buffer = BgImageBuffer{
		opacity: self.config.bg_image_opacity
		info: BgImageInfo{
			position: match self.config.bg_image_position {
				.top_left { .tl }
				.top_center { .tc }
				.top_right { .tr }
				.center_left { .ml }
				.center { .mc }
				.center_right { .mr }
				.bottom_left { .bl }
				.bottom_center { .bc }
				.bottom_right { .br }
			}
			fit: match self.config.bg_image_fit {
				.contain { .contain }
				.cover { .cover }
				.stretch { .stretch }
				.none_ { .none_ }
			}
			repeat: self.config.bg_image_repeat
		}
	}
}

// Update custom shader uniforms that depend on terminal state.
//
// This should be called in update_frame when terminal state changes.
fn (mut self Renderer) update_custom_shader_uniforms_from_state() {
	// We only need to do this if we have custom shaders
	if !self.has_custom_shaders {
		return
	}

	// Only update when terminal state is dirty
	if self.terminal_state.dirty == .false_ {
		return
	}

	colors := &self.terminal_state.colors

	// 256-color palette
	for i in 0 .. 256 {
		c := colors.palette[i]
		self.custom_shader_uniforms.palette[i] = [
			f32(c.r) / 255.0,
			f32(c.g) / 255.0,
			f32(c.b) / 255.0,
			f32(1.0),
		]!
	}

	// Background color
	self.custom_shader_uniforms.background_color = [
		f32(colors.background.r) / 255.0,
		f32(colors.background.g) / 255.0,
		f32(colors.background.b) / 255.0,
		f32(1.0),
	]!

	// Foreground color
	self.custom_shader_uniforms.foreground_color = [
		f32(colors.foreground.r) / 255.0,
		f32(colors.foreground.g) / 255.0,
		f32(colors.foreground.b) / 255.0,
		f32(1.0),
	]!

	// Cursor color
	if cursor_color := colors.cursor {
		self.custom_shader_uniforms.cursor_color = [
			f32(cursor_color.r) / 255.0,
			f32(cursor_color.g) / 255.0,
			f32(cursor_color.b) / 255.0,
			f32(1.0),
		]!
	}
}

// Update per-frame custom shader uniforms.
//
// This should be called exactly once per frame, inside draw_frame.
fn (mut self Renderer) update_custom_shader_uniforms_for_frame() ! {
	// We only need to do this if we have custom shaders
	if !self.has_custom_shaders {
		return
	}

	mut uniforms := &self.custom_shader_uniforms

	now := time.sys_mono_now()

	if self.first_frame_time >= 0 {
		since_ns := now - self.first_frame_time
		uniforms.time = f32(since_ns) / 1_000_000_000.0
	} else {
		self.first_frame_time = now
		uniforms.time = 0
	}

	if self.last_frame_time >= 0 {
		delta_ns := now - self.last_frame_time
		uniforms.time_delta = f32(delta_ns) / 1_000_000_000.0
	} else {
		uniforms.time_delta = 0
	}

	self.last_frame_time = now

	uniforms.frame += 1

	screen := self.size.screen

	uniforms.resolution = [
		f32(screen.width),
		f32(screen.height),
		f32(1),
	]!
	uniforms.channel_resolution[0] = [
		f32(screen.width),
		f32(screen.height),
		f32(1),
		f32(0),
	]!

	// Update custom cursor uniforms, if we have a cursor
	if cursor := self.cells.get_cursor_glyph() {
		cursor_width := f32(cursor.glyph_size[0])
		cursor_height := f32(cursor.glyph_size[1])

		cell := self.size.cell
		padding := self.size.padding

		// Left edge of the cell the cursor is in
		mut pixel_x := f32(u32(cursor.grid_pos[0]) * cell.width + padding.left)
		// Top edge of the cell the cursor is in
		pixel_y := f32(u32(cursor.grid_pos[1]) * cell.height + padding.top)

		// Add the X bearing to get the left edge of the cursor
		pixel_x += f32(cursor.bearings[0])

		new_cursor := [pixel_x, pixel_y, cursor_width, cursor_height]!
		new_cursor_color := [
			f32(cursor.color[0]) / 255.0,
			f32(cursor.color[1]) / 255.0,
			f32(cursor.color[2]) / 255.0,
			f32(cursor.color[3]) / 255.0,
		]!

		cursor_changed := new_cursor[0] != uniforms.current_cursor[0]
			|| new_cursor[1] != uniforms.current_cursor[1]
			|| new_cursor[2] != uniforms.current_cursor[2]
			|| new_cursor[3] != uniforms.current_cursor[3]
			|| new_cursor_color[0] != uniforms.current_cursor_color[0]
			|| new_cursor_color[1] != uniforms.current_cursor_color[1]
			|| new_cursor_color[2] != uniforms.current_cursor_color[2]
			|| new_cursor_color[3] != uniforms.current_cursor_color[3]

		if cursor_changed {
			uniforms.previous_cursor = uniforms.current_cursor
			uniforms.previous_cursor_color = uniforms.current_cursor_color
			uniforms.current_cursor = new_cursor
			uniforms.current_cursor_color = new_cursor_color
			uniforms.cursor_change_time = uniforms.time
		}
	}

	// Update focus uniforms
	uniforms.focus = if self.focused { u32(1) } else { u32(0) }

	// If we need to update the time our focus state changed
	// then update it to our current frame time.
	if self.custom_shader_focused_changed && self.focused {
		uniforms.time_focus = uniforms.time
		self.custom_shader_focused_changed = false
	}
}

// Determines the x/y range for preedit text within a row. We don't
// render anything within this range in rebuild_row because the preedit
// is rendered separately.
struct PreeditRange {
	y         u16
	x         [2]u16
	cp_offset int
}

// Compute the CellSet key matching terminal.cell_set_key: (y << 32) | x.
fn cell_set_key(x u32, y u32) u64 {
	return u64(y) << 32 | u64(x)
}

// Resolve a config TerminalColor to an RGB, given the cell's style-derived
// fg/bg colors and a fallback for the explicit `.color` variant.
//
// BOUNDARY: In Ghostty, TerminalColor's `.color` variant carries an
// explicit RGB (via toTerminalRGB()). The V configpkg.TerminalColor enum
// does not carry an attached color yet, so for `.color` we use the
// provided fallback (the Ghostty default when no explicit color is set).
fn resolve_terminal_color(tc configpkg.TerminalColor, inverse bool, fg_style terminal.RGB, bg_style terminal.RGB, fallback terminal.RGB) terminal.RGB {
	return match tc {
		.color { fallback }
		.cell_foreground {
			if inverse { bg_style } else { fg_style }
		}
		.cell_background {
			if inverse { fg_style } else { bg_style }
		}
	}
}

// Convert the terminal state to GPU cells stored in CPU memory. These
// are then synced to the GPU in the next frame. This only updates CPU
// memory and doesn't touch the GPU.
//
// This translates the CPU-side of Ghostty's rebuildCells: preedit range
// setup, grid resize, full-rebuild reset with padding extension, per-row
// iteration with dirty tracking, cursor rendering info, and preedit text.
//
// Dirty state on terminal state won't be reset by this.
fn (mut self Renderer) rebuild_cells(preedit ?RenderPreedit, cursor_style_ ?CursorStyle, links &terminal.CellSet) ! {
	state := &self.terminal_state

	// Determine our x/y range for preedit. We don't want to render anything
	// here because we will render the preedit separately.
	mut preedit_range := ?PreeditRange(none)
	if p := preedit {
		// We base the preedit on the position of the cursor in the
		// viewport. If the cursor isn't visible in the viewport we
		// don't show it.
		if cursor_vp := state.cursor.viewport {
			r_start, r_end, cp_offset := p.range(u32(cursor_vp.x), u32(state.cols) - 1)
			preedit_range = PreeditRange{
				y: cursor_vp.y
				x: [u16(r_start), u16(r_end)]!
				cp_offset: cp_offset
			}
		}
	}

	grid_size_diff := self.cells.size.rows != u32(state.rows)
		|| self.cells.size.columns != u32(state.cols)

	if grid_size_diff {
		mut new_size := self.cells.size
		new_size.rows = u32(state.rows)
		new_size.columns = u32(state.cols)
		self.cells.resize(new_size)!

		// Update our uniforms accordingly, otherwise
		// our background cells will be out of place
		self.uniforms.grid_size = [u16(new_size.columns), u16(new_size.rows)]!
	}

	rebuild := state.dirty == .full || grid_size_diff
	if rebuild {
		// If we are doing a full rebuild, then we clear the entire cell buffer
		self.cells.reset()

		// We also reset our padding extension depending on the screen type
		match self.config.padding_color {
			.background {}
			// For extension, assume we are extending in all directions.
			// For "extend" this may be disabled due to heuristics below.
			.extend, .extend_always {
				self.uniforms.padding_extend = PaddingExtend{
					up: true
					down: true
					left: true
					right: true
				}
			}
		}
	}

	// If our cell contents buffer is shorter than the screen viewport,
	// we render the rows that fit. Iterate up to the min of state rows
	// and our cell buffer rows.
	row_len := if int(state.rows) < int(self.cells.size.rows) {
		int(state.rows)
	} else {
		int(self.cells.size.rows)
	}

	for y in 0 .. row_len {
		mut row := &state.row_data[y]

		if !rebuild {
			// Only rebuild if we are doing a full rebuild or this row is dirty.
			if !row.dirty {
				continue
			}

			// Clear the cells if the row is dirty
			self.cells.clear(u16(y))
		}

		// Unmark the dirty state in our render state.
		row.dirty = false

		self.rebuild_row(u16(y), row, preedit_range, links) or {
			// This should never happen except under exceptional
			// scenarios. In this case, we don't want to corrupt
			// our render state so just clear this row and keep
			// trying to finish it out.
			self.cells.clear(u16(y))
		}
	}

	// Setup our cursor rendering information.
	self.rebuild_cursor(preedit, cursor_style_)

	// Setup our preedit text.
	if p := preedit {
		if range := preedit_range {
			mut x := range.x[0]
			for i := range.cp_offset; i < p.codepoints.len; i++ {
				cp := p.codepoints[i]
				self.add_preedit_cell(PreeditCodepoint{
					codepoint: cp.codepoint
					wide: cp.wide
				}, terminal.ViewportPoint{
					x: x
					y: range.y
				}, state.colors.background, state.colors.foreground) or {}
				x += if cp.wide { u16(2) } else { u16(1) }
			}
		}
	}

	// Update that our cells rebuilt
	self.cells_rebuilt = true
}

// Setup cursor rendering info: clear cursor by default, then if visible
// determine cursor color and set uniforms. Faithful translation of the
// `cursor:` block in rebuildCells.
fn (mut self Renderer) rebuild_cursor(preedit ?RenderPreedit, cursor_style_ ?CursorStyle) {
	state := &self.terminal_state

	// Clear our cursor by default.
	self.cells.set_cursor(none, none)
	self.uniforms.cursor_pos = [u16(0xFFFF), u16(0xFFFF)]!

	// If the cursor isn't visible on the viewport, don't show a cursor.
	cursor_vp := state.cursor.viewport or { return }

	// Get the style of the cell the cursor is on, because we may need
	// it for styling.
	cursor_cell_style := if int(cursor_vp.y) < state.row_data.len
		&& int(cursor_vp.x) < state.row_data[int(cursor_vp.y)].cells.len
		&& state.row_data[int(cursor_vp.y)].cells[int(cursor_vp.x)].raw.has_styling() {
		state.row_data[int(cursor_vp.y)].cells[int(cursor_vp.x)].raw.style
	} else {
		terminal.CellStyle{}
	}

	// If we have preedit text, we don't setup a cursor.
	if preedit != none {
		return
	}

	// If there isn't a cursor visual style requested then we don't render.
	style := cursor_style_ or { return }

	// Determine the cursor color.
	cursor_color := self.compute_cursor_color(cursor_cell_style)

	self.add_cursor(&state.cursor, style, cursor_color)

	// If the cursor is visible then we set our uniforms.
	if style == .block {
		wide := state.cursor.cell.wide

		// If we are a spacer tail of a wide cell, our cursor needs
		// to move back one cell. Saturating subtraction avoids overflow.
		cur_x := match wide {
			.narrow, .spacer_head, .wide { cursor_vp.x }
			.spacer_tail {
				if cursor_vp.x > 0 { cursor_vp.x - 1 } else { u16(0) }
			}
		}
		self.uniforms.cursor_pos = [cur_x, cursor_vp.y]!

		self.uniforms.bools.cursor_wide = match wide {
			.narrow, .spacer_head { false }
			.wide, .spacer_tail { true }
		}

		// Determine the cursor text color.
		uniform_color := self.compute_cursor_text_color(cursor_cell_style)
		self.uniforms.cursor_color = [
			uniform_color.r,
			uniform_color.g,
			uniform_color.b,
			u8(255),
		]!
	}
}

// Compute the cursor glyph color per rebuildCells. Uses OSC 12 color if
// set, else configured cursor color, else the terminal foreground.
fn (self &Renderer) compute_cursor_color(cursor_style terminal.CellStyle) terminal.RGB {
	state := &self.terminal_state

	// If an explicit cursor color was set by OSC 12, use that.
	if v := state.colors.cursor {
		return v
	}

	// Use our configured color if specified.
	if v := self.config.cursor_color {
		fg_style := cursor_style.fg_rgb(terminal.FgOpts{
			default_color: state.colors.foreground
			palette: state.colors.palette
		})
		bg_style := cursor_style.bg_rgb(&state.cursor.cell, state.colors.palette) or {
			state.colors.background
		}
		// For the explicit `.color` variant we fall back to foreground
		// (see resolve_terminal_color boundary note).
		return resolve_terminal_color(v, cursor_style.flags.inverse, fg_style, bg_style, state.colors.foreground)
	}

	return state.colors.foreground
}

// Compute the cursor text (glyph-over-cursor) color per rebuildCells.
fn (self &Renderer) compute_cursor_text_color(cursor_style terminal.CellStyle) terminal.RGB {
	state := &self.terminal_state

	// If cursor-text is set, compute the correct color; else use bg color.
	if txt := self.config.cursor_text {
		fg_style := cursor_style.fg_rgb(terminal.FgOpts{
			default_color: state.colors.foreground
			palette: state.colors.palette
		})
		bg_style := cursor_style.bg_rgb(&state.cursor.cell, state.colors.palette) or {
			state.colors.background
		}
		// `.color` falls back to background (Ghostty uses cursor-text color).
		return resolve_terminal_color(txt, cursor_style.flags.inverse, fg_style, bg_style, state.colors.background)
	}

	return state.colors.background
}

// Selection classification for a cell, matching the Zig `selected` enum.
enum CellSelected {
	false_
	selection
	search
	search_selected
}

struct RowShapedGlyph {
	cell       font.ShapeCell
	font_index u32
}

// Rebuild a single row's cells: shaping, selection/highlight classification,
// color computation, glyph emission, and text decorations.
fn (mut self Renderer) rebuild_row(y u16, row &terminal.RenderRow, preedit_range ?PreeditRange, links &terminal.CellSet) ! {
	state := &self.terminal_state

	// If our viewport is wider than our cell contents buffer, we still
	// only process cells up to the width of the buffer.
	cells_len := if row.cells.len < int(self.cells.size.columns) {
		row.cells.len
	} else {
		int(self.cells.size.columns)
	}

	// Build a raw/style view for padding heuristics.
	mut cells_raw := []terminal.CellData{cap: row.cells.len}
	mut cells_style := []terminal.CellStyle{cap: row.cells.len}
	for c in row.cells {
		cells_raw << c.raw
		cells_style << c.raw.style
	}

	// Shape the row into glyphs before emitting individual cell layers. Runs
	// split on style, selection, cursor, and font boundaries; multiple glyphs
	// may share one cell for ligatures and combining marks.
	mut shaped := [][]RowShapedGlyph{len: cells_len}
	cursor_x := if viewport := state.cursor.viewport {
		if self.config.font_shaping_break.cursor && viewport.y == y {
			?u16(viewport.x)
		} else {
			?u16(none)
		}
	} else {
		?u16(none)
	}
	mut run_iter := self.font_shaper.run_iterator(font.RunOptions{
		grid: self.font_grid
		render_cells: row.cells[..cells_len]
		selection: row.selection
		cursor_x: cursor_x
	})
	for {
		run := run_iter.next() or { break }
		shaped_cells := self.font_shaper_cache.get(run) or {
			new_cells := self.font_shaper.shape(run)!
			self.font_shaper_cache.put(run, new_cells) or {}
			new_cells
		}
		for shaped_cell in shaped_cells {
			x := int(run.offset + shaped_cell.x)
			if x >= 0 && x < shaped.len {
				shaped[x] << RowShapedGlyph{ cell: shaped_cell, font_index: run.font_index }
			}
		}
	}

	// On primary screen, we still apply vertical padding extension under
	// certain conditions we feel are safe.
	match self.config.padding_color {
		// These already have the correct values set above.
		.background, .extend_always {}
		// Apply heuristics for padding extension.
		.extend {
			if y == 0 {
				self.uniforms.padding_extend.up = !never_extend_bg(row.raw, cells_raw, cells_style, state.colors.palette, state.colors.background)
			} else if u32(y) == self.cells.size.rows - 1 {
				self.uniforms.padding_extend.down = !never_extend_bg(row.raw, cells_raw, cells_style, state.colors.palette, state.colors.background)
			}
		}
	}

	for x in 0 .. cells_len {
		cell := &row.cells[x].raw

		// If this cell falls within our preedit range then we skip it
		// because preedits are setup separately.
		if range := preedit_range {
			if range.y == y {
				// We're in or around the preedit range.
				if u16(x) >= range.x[0] && u16(x) <= range.x[1] {
					// We're in the preedit range, skip this cell.
					continue
				}
			}
		}

		wide := cell.wide
		style := if cell.has_styling() { cell.style } else { terminal.CellStyle{} }

		// True if this cell is selected. Order below matters for precedence.
		// x_compare handles spacer tails by comparing against the base cell.
		x_compare := if wide == .spacer_tail && x > 0 { u16(x) - 1 } else { u16(x) }
		mut selected := CellSelected.false_

		// Selection should take the highest precedence.
		if sel := row.selection {
			if x_compare >= sel[0] && x_compare <= sel[1] {
				selected = .selection
			}
		}

		// If we're highlighted, then we're selected.
		if selected == .false_ {
			for hl in row.highlights {
				if x_compare >= hl.range[0] && x_compare <= hl.range[1] {
					selected = match unsafe { HighlightTag(hl.tag) } {
						.search_match { CellSelected.search }
						.search_match_selected { CellSelected.search_selected }
					}
					break
				}
			}
		}

		// The `_style` suffixed values are the colors based on the cell
		// style (SGR), before applying any additional configuration,
		// inversions, selections, etc.
		bg_style_opt := style.bg_rgb(cell, state.colors.palette)
		fg_style := style.fg_rgb(terminal.FgOpts{
			default_color: state.colors.foreground
			palette: state.colors.palette
		})

		// The final background color for the cell.
		bg := self.compute_cell_bg(selected, style, cell, bg_style_opt, fg_style)

		// The final foreground color for the cell.
		fg := self.compute_cell_fg(selected, style, bg_style_opt, fg_style)

		// Foreground alpha for this cell.
		alpha := if style.flags.faint { self.config.faint_opacity } else { u8(255) }

		// Set the cell's background color.
		{
			rgb := bg or { state.colors.background }

			// Determine our background alpha. If we have transparency
			// configured then this is dynamic depending on some situations.
			bg_alpha := self.compute_bg_alpha(selected, style, bg_style_opt)

			self.cells.set_bg(y, u16(x), CellBg{
				r: rgb.r
				g: rgb.g
				b: rgb.b
				a: bg_alpha
			})
		}

		// If the invisible flag is set on this cell then we don't need to
		// render any foreground elements, so we skip all glyphs with this
		// x coordinate. NOTE: matches xterm's behavior.
		if style.flags.invisible {
			continue
		}

		// Give links a single underline, unless they already have an
		// underline, in which case use a double underline to distinguish.
		mut underline := style.flags.underline
		if u64(cell_set_key(u32(x), u32(y))) in links {
			underline = if style.flags.underline == .single {
				terminal.UnderlineStyle.double
			} else {
				terminal.UnderlineStyle.single
			}
		}

		// We draw underlines first so that they layer underneath text.
		if underline != .none {
			ul_color := style.underline_color_rgb(state.colors.palette) or { fg }
			self.add_underline(u16(x), y, underline, ul_color, alpha) or {}
		}

		if style.flags.overline {
			self.add_overline(u16(x), y, fg, alpha) or {}
		}

		for shaped_glyph in shaped[x] {
			self.add_glyph(u16(x), y, fg, alpha, shaped_glyph.cell.glyph_index, shaped_glyph.font_index, shaped_glyph.cell.x_offset, shaped_glyph.cell.y_offset, u32(cell.grid_width()), cells_raw, x, cells_len)!
		}

		// Finally, draw a strikethrough if necessary.
		if style.flags.strikethrough {
			self.add_strikethrough(u16(x), y, fg, alpha) or {}
		}
	}
}

// Compute the final background color for a cell given its selection state
// and style. Returns none if the cell should use the terminal background.
fn (self &Renderer) compute_cell_bg(selected CellSelected, style terminal.CellStyle, cell &terminal.CellData, bg_style_opt ?terminal.RGB, fg_style terminal.RGB) ?terminal.RGB {
	state := &self.terminal_state
	bg_style := bg_style_opt or { state.colors.background }
	inverse := style.flags.inverse

	return match selected {
		.selection {
			// If we have an explicit selection background color specified
			// in the config, use that. If no configuration, then our
			// selection background is our foreground color.
			if v := self.config.selection_background {
				resolve_terminal_color(v, inverse, fg_style, bg_style, state.colors.foreground)
			} else {
				state.colors.foreground
			}
		}
		.search {
			resolve_terminal_color(self.config.search_background, inverse, fg_style, bg_style, state.colors.foreground)
		}
		.search_selected {
			resolve_terminal_color(self.config.search_selected_background, inverse, fg_style, bg_style, state.colors.foreground)
		}
		.false_ {
			// Two cases cause us to invert (use the fg color as the bg):
			// - The "inverse" style flag.
			// - A "covering" glyph.
			// If exactly one is true then we use fg for bg; else bg_style.
			if inverse != is_covering(cell.codepoint_val()) {
				?terminal.RGB(fg_style)
			} else {
				bg_style_opt
			}
		}
	}
}

// Compute the final foreground color for a cell given its selection state
// and style. Faithful translation of the `fg:` block in rebuildRow.
fn (self &Renderer) compute_cell_fg(selected CellSelected, style terminal.CellStyle, bg_style_opt ?terminal.RGB, fg_style terminal.RGB) terminal.RGB {
	state := &self.terminal_state

	// Our happy-path non-selection background color is our style or
	// our configured defaults.
	final_bg := bg_style_opt or { state.colors.background }
	inverse := style.flags.inverse

	return match selected {
		.selection {
			if v := self.config.selection_foreground {
				resolve_terminal_color(v, inverse, fg_style, final_bg, state.colors.background)
			} else {
				state.colors.background
			}
		}
		.search {
			resolve_terminal_color(self.config.search_foreground, inverse, fg_style, final_bg, state.colors.background)
		}
		.search_selected {
			resolve_terminal_color(self.config.search_selected_foreground, inverse, fg_style, final_bg, state.colors.background)
		}
		.false_ {
			if inverse { final_bg } else { fg_style }
		}
	}
}

// Determine the background alpha for a cell. Faithful translation of the
// `bg_alpha:` block in rebuildRow.
fn (self &Renderer) compute_bg_alpha(selected CellSelected, style terminal.CellStyle, bg_style_opt ?terminal.RGB) u8 {
	default := u8(255)

	// Cells that are selected should be fully opaque.
	if selected != .false_ {
		return default
	}

	// Cells that are reversed should be fully opaque.
	if style.flags.inverse {
		return default
	}

	// If the user requested to have opacity on all cells, apply it.
	if self.config.background_opacity_cells && bg_style_opt != none {
		mut opacity := f64(default)
		opacity *= self.config.background_opacity
		return u8(opacity)
	}

	// Cells that have an explicit bg color should be fully opaque.
	if bg_style_opt != none {
		return default
	}

	// Otherwise, we won't draw the bg for this cell, we'll let the
	// already-drawn background color show through.
	return 0
}

// Add an underline decoration to the specified cell.
fn (mut self Renderer) add_underline(x u16, y u16, style terminal.UnderlineStyle, color terminal.RGB, alpha u8) ! {
	// Map the underline style to a sprite
	if style == .none {
		return
	}
	sprite := match style {
		.none { font.Sprite.underline } // unreachable
		.single { font.Sprite.underline }
		.double { font.Sprite.underline_double }
		.dotted { font.Sprite.underline_dotted }
		.dashed { font.Sprite.underline_dashed }
		.curly { font.Sprite.underline_curly }
	}

	render := self.font_grid.render_glyph(font.Index.init_special(.sprite), u32(sprite), font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.underline, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add an overline decoration to the specified cell.
fn (mut self Renderer) add_overline(x u16, y u16, color terminal.RGB, alpha u8) ! {
	render := self.font_grid.render_glyph(font.Index.init_special(.sprite), u32(font.Sprite.overline), font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.overline, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add a strikethrough decoration to the specified cell.
fn (mut self Renderer) add_strikethrough(x u16, y u16, color terminal.RGB, alpha u8) ! {
	render := self.font_grid.render_glyph(font.Index.init_special(.sprite), u32(font.Sprite.strikethrough), font.RenderOptions{
		cell_width: 1
		grid_metrics: self.grid_metrics
	})!

	self.cells.add(.strikethrough, CellText{
		atlas: .grayscale
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!
}

// Add a glyph to the specified cell.
fn (mut self Renderer) add_glyph(x u16, y u16, color terminal.RGB, alpha u8, glyph_index u32, font_index u32, x_offset i32, y_offset i32, cell_width u32, raw_cells []terminal.CellData, raw_x int, cols int) ! {
	fidx := font.Index.from_int(font_index)
	cp := raw_cells[raw_x].codepoint_val()
	constraint := font.get_constraint(cp) or {
		if is_symbol(cp) { font.Constraint{ size: .fit } } else { font.Constraint{} }
	}
	render := self.font_grid.render_glyph(fidx, glyph_index, font.RenderOptions{
		grid_metrics: self.grid_metrics
		thicken: self.config.font_thicken
		thicken_strength: self.config.font_thicken_strength
		cell_width: cell_width
		constraint: constraint
		constraint_width: u32(constraint_width(raw_cells, raw_x, cols))
	})!

	// If the glyph is 0 width or height, it will be invisible
	// when drawn, so don't bother adding it to the buffer.
	if render.glyph.width == 0 || render.glyph.height == 0 {
		return
	}

	self.cells.add(.text, CellText{
		atlas: match render.presentation {
			.emoji { .color }
			.text { .grayscale }
		}
		grid_pos: [x, y]!
		color: [color.r, color.g, color.b, alpha]!
		bools: CellTextBools{ no_min_contrast: no_min_contrast(cp) }
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [
			i32(render.glyph.offset_x + x_offset),
			i32(render.glyph.offset_y + y_offset),
		]!
	})!
}

// Add a cursor to the cell rendering.
fn (mut self Renderer) add_cursor(cursor_state &terminal.RenderCursor, cursor_style CursorStyle, cursor_color terminal.RGB) {
	cursor_vp := cursor_state.viewport or { return }

	// Add the cursor. We render the cursor over the wide character if
	// we're on the wide character tail.
	wide, x := if !cursor_vp.wide_tail {
		cursor_state.cell.wide == .wide, cursor_vp.x
	} else {
		// If we're part of a wide character, we move the cursor back
		// to the actual character.
		true, cursor_vp.x - 1
	}

	alpha := if !self.focused {
		u8(255)
	} else {
		u8(255 * self.config.cursor_opacity)
	}

	// Map cursor style to sprite
	sprite := match cursor_style {
		.block { font.Sprite.cursor_rect }
		.block_hollow { font.Sprite.cursor_hollow_rect }
		.bar { font.Sprite.cursor_bar }
		.underline { font.Sprite.cursor_underline }
		.lock { font.Sprite.cursor_rect }
	}

	// fallback for lock

	render := self.font_grid.render_glyph(
		font.Index.init_special(.sprite),
		u32(sprite),
		font.RenderOptions{
			cell_width: if wide { u32(2) } else { u32(1) }
			grid_metrics: self.grid_metrics
		},
	) or {
		return
	}

	self.cells.set_cursor(CellText{
		atlas: .grayscale
		bools: CellTextBools{
			is_cursor_glyph: true
		}
		grid_pos: [x, cursor_vp.y]!
		color: [cursor_color.r, cursor_color.g, cursor_color.b, alpha]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	}, cursor_style)
}

// Add a preedit (IME composition) cell.
fn (mut self Renderer) add_preedit_cell(cp PreeditCodepoint, coord terminal.ViewportPoint, screen_bg terminal.RGB, screen_fg terminal.RGB) ! {
	render := self.font_grid.render_codepoint(cp.codepoint, .regular, .text, font.RenderOptions{
		grid_metrics: self.grid_metrics
	}) or {
		return
	}

	// Add our opaque background cell
	self.cells.set_bg(coord.y, coord.x, CellBg{
		r: screen_bg.r
		g: screen_bg.g
		b: screen_bg.b
		a: 255
	})
	if cp.wide && coord.x < u16(self.cells.size.columns) - 1 {
		self.cells.set_bg(coord.y, coord.x + 1, CellBg{
			r: screen_bg.r
			g: screen_bg.g
			b: screen_bg.b
			a: 255
		})
	}

	self.cells.add(.text, CellText{
		atlas: .grayscale
		grid_pos: [coord.x, coord.y]!
		color: [screen_fg.r, screen_fg.g, screen_fg.b, u8(255)]!
		glyph_pos: [render.glyph.atlas_x, render.glyph.atlas_y]!
		glyph_size: [render.glyph.width, render.glyph.height]!
		bearings: [render.glyph.offset_x, render.glyph.offset_y]!
	})!

	// Add underline for preedit text
	self.add_underline(coord.x, coord.y, .single, screen_fg, 255)!
	if cp.wide && coord.x < u16(self.cells.size.columns) - 1 {
		self.add_underline(coord.x + 1, coord.y, .single, screen_fg, 255)!
	}
}

// ============================================================
// Existing types (kept for backward compatibility)
// ============================================================

// RendererOpts holds initialization options for the Renderer.
pub struct RendererOpts {
pub:
	// Font grid to use.
	font_grid &font.SharedGrid = unsafe { nil }
	// Initial configuration.
	config DerivedConfig
	// Initial size.
	size Size
}

// State holds shared renderer state protected by a mutex.
pub struct State {
pub mut:
	terminal  voidptr
	preedit   ?Preedit
	mouse     MouseState
	inspector ?voidptr
	mutex     sync.Mutex
}

pub struct MouseState {
pub mut:
	point ?Coordinate
	mods  input.Mods
}

pub struct Coordinate {
pub mut:
	x u32
	y u32
}

pub struct Preedit {
pub mut:
	codepoints []PreeditCodepoint
}

pub struct PreeditCodepoint {
pub:
	codepoint u32
	wide      bool
}

pub fn (p Preedit) width() int {
	mut w := 0
	for cp in p.codepoints {
		w += if cp.wide { 2 } else { 1 }
	}
	return w
}

// Thread manages the renderer thread and its mailbox.
pub struct Thread {
pub mut:
	wakeup  Wakeup
	mailbox Mailbox
}

pub fn Thread.init() !Thread {
	return Thread{}
}

pub fn (mut t Thread) deinit() {}

pub struct Wakeup {}

pub fn (w Wakeup) notify() ! {
	// stub: wakes up the renderer thread
}

pub struct Mailbox {}

// push attempts to push a message. Returns number of items pushed (0 or 1).
pub fn (m Mailbox) push(msg Message) int {
	_ = msg
	return 1
}

pub struct Message {
pub:
	kind MessageKind
}

pub enum MessageKind {
	visible
	focus
	reset_cursor_blink
	font_grid
	resize
	inspector
	change_config
	search_viewport_matches
	search_selected_match
}

pub fn Message.init_change_config(config voidptr) !Message {
	return Message{ kind: .change_config }
}

pub fn (m Message) deinit() {}

// Health status of the renderer.
pub enum Health {
	healthy
	unhealthy
}

// CursorStyle describes how the cursor should be rendered.
pub enum CursorStyle {
	block
	block_hollow
	bar
	underline
	lock
}

// Size holds all sizing information.
pub struct Size {
pub mut:
	screen  ScreenSize
	cell    CellSize
	padding Padding
}

pub struct ScreenSize {
pub mut:
	width  u32
	height u32
}

pub fn (a ScreenSize) equals(b ScreenSize) bool {
	return a.width == b.width && a.height == b.height
}

pub struct CellSize {
pub mut:
	width  u32
	height u32
}

pub struct Padding {
pub mut:
	top    u32
	bottom u32
	left   u32
	right  u32
}

// Add two paddings together.
pub fn (a Padding) add(b Padding) Padding {
	return Padding{
		top: a.top + b.top
		bottom: a.bottom + b.bottom
		left: a.left + b.left
		right: a.right + b.right
	}
}

pub fn (s Size) grid() GridSize {
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	cols := if s.cell.width > 0 { usable_w / s.cell.width } else { u32(0) }
	rows := if s.cell.height > 0 { usable_h / s.cell.height } else { u32(0) }
	return GridSize{ columns: cols, rows: rows }
}

pub struct GridSize {
pub mut:
	columns u32
	rows    u32
}

// Get the terminal rendering area size (grid area only).
pub fn (s &Size) terminal_size() ScreenSize {
	g := GridSize{
		columns: if s.cell.width > 0 {
			usable_w := if s.screen.width > s.padding.left + s.padding.right {
				s.screen.width - s.padding.left - s.padding.right
			} else {
				u32(0)
			}
			usable_w / s.cell.width
		} else {
			u32(0)
		}
		rows: if s.cell.height > 0 {
			usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
				s.screen.height - s.padding.top - s.padding.bottom
			} else {
				u32(0)
			}
			usable_h / s.cell.height
		} else {
			u32(0)
		}
	}
	return ScreenSize{
		width: g.columns * s.cell.width
		height: g.rows * s.cell.height
	}
}

pub fn (s Size) terminal_width() u32 {
	g := GridSize{
		columns: if s.cell.width > 0 {
			usable_w := if s.screen.width > s.padding.left + s.padding.right {
				s.screen.width - s.padding.left - s.padding.right
			} else {
				u32(0)
			}
			usable_w / s.cell.width
		} else {
			u32(0)
		}
		rows: u32(0)
	}
	return g.columns * s.cell.width
}

// Compute the blank padding (space between the grid and the edge of the screen).
pub fn (s &Size) blank_padding(grid GridSize) Padding {
	term := s.terminal_size()
	usable_w := if s.screen.width > s.padding.left + s.padding.right {
		s.screen.width - s.padding.left - s.padding.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > s.padding.top + s.padding.bottom {
		s.screen.height - s.padding.top - s.padding.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > term.width { usable_w - term.width } else { u32(0) }
	extra_h := if usable_h > term.height { usable_h - term.height } else { u32(0) }
	return Padding{
		left: s.padding.left + extra_w / 2
		right: s.padding.right + (extra_w - extra_w / 2)
		top: s.padding.top + extra_h / 2
		bottom: s.padding.bottom + (extra_h - extra_h / 2)
	}
}

pub fn (mut s Size) balance_padding(explicit Padding) {
	g := s.grid()
	total_w := g.columns * s.cell.width
	total_h := g.rows * s.cell.height
	usable_w := if s.screen.width > explicit.left + explicit.right {
		s.screen.width - explicit.left - explicit.right
	} else {
		u32(0)
	}
	usable_h := if s.screen.height > explicit.top + explicit.bottom {
		s.screen.height - explicit.top - explicit.bottom
	} else {
		u32(0)
	}
	extra_w := if usable_w > total_w { usable_w - total_w } else { u32(0) }
	extra_h := if usable_h > total_h { usable_h - total_h } else { u32(0) }
	s.padding = Padding{
		left: explicit.left + extra_w / 2
		right: explicit.right + (extra_w - extra_w / 2)
		top: explicit.top + extra_h / 2
		bottom: explicit.bottom + (extra_h - extra_h / 2)
	}
}

// This is called early right after surface creation.
pub fn surface_init() ! {
	// stub: initialize surface for rendering
}

// This is called just prior to spinning up the renderer thread for
// final main thread setup requirements.
pub fn (r &Renderer) finalize_surface_init() ! {
	// stub: finalize surface init on main thread
}

// Callback called by renderer.Thread when it begins.
pub fn (r &Renderer) thread_enter() ! {
	// stub: enter rendering thread
}

// Callback called by renderer.Thread when it exits.
pub fn (r &Renderer) thread_exit() {
	// stub: exit rendering thread
}

// Called by renderer.Thread when it starts the main loop.
pub fn (mut r Renderer) loop_enter() ! {
	// stub: enter main loop
}

// Called by renderer.Thread when it exits the main loop.
pub fn (mut r Renderer) loop_exit() {
	// stub: exit main loop
}

// This is called by the GTK apprt after the surface is
// reinitialized due to any of the events mentioned in
// the doc comment for display_unrealized.
pub fn (mut r Renderer) display_realized() ! {
	// stub: reinitialize GPU resources after display realize
	r.mark_dirty()
}

// This is called by the GTK apprt when the surface is being destroyed.
// This can happen because the surface is being closed but also when
// moving the window between displays or splitting.
pub fn (mut r Renderer) display_unrealized() {
	// stub: deinitialize GPU resources on display unrealize
}
