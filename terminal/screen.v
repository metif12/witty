module terminal

import unicode

// --- Original Ghostty Comments Start: src/terminal/Screen.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/Screen.zig
//
// The general purpose allocator to use for all memory allocations.
// Unfortunately some screen operations do require allocation.
// The list of pages in the screen.
// Special-case where we want no scrollback whatsoever. We have to flag
// this because max_size 0 in PageList gets rounded up to two pages so
// we can always have an active screen.
// The current cursor position
// The saved cursor
// The selection for this screen (if any). This MUST be a tracked selection
// otherwise the selection will become invalid. Instead of accessing this
// directly to set it, use the `select` function which will assert and
// automatically setup tracking.
// The charset state
// The current or most recent protected mode. Once a protection mode is
// set, this will never become "off" again until the screen is reset.
// The current state of whether protection attributes should be set is
// set on the Cell pen; this is only used to determine the most recent
// protection mode since some sequences such as ECH depend on this.
// The kitty keyboard settings.
// Kitty graphics protocol state.
// Semantic prompt (OSC133) state.
// Dirty flags for the renderer.
// See Terminal.Dirty. This behaves the same way.
// Set when the selection is set or unset, regardless of if the
// selection is changed or not.
// When an OSC8 hyperlink is hovered, we set the full screen as dirty
// because links can span multiple lines.
// This is flipped to true when any sort of semantic content is
// seen. In particular, this is set to true only when a `prompt` type
// is ever set on our cursor.
//
// This is used to optimize away semantic content operations if we know
// we've never seen them.
// This is set on any `cl` or `click_events` option set on the
// most recent OSC 133 commands to specify how click handling in a
// prompt is handling.
// The cursor position and style.
// The x/y position within the active area.
// The visual style of the cursor. This defaults to block because
// it has to default to something, but users of this struct are
// encouraged to set their own default.
// The "last column flag (LCF)" as its called. If this is set then the
// next character print will force a soft-wrap.
// The protected mode state of the cursor. If this is true then
// all new characters printed will have the protected state set.
// The currently active style. This is the concrete style value
// that should be kept up to date. The style ID to use for cell writing
// is below.
// The currently active style ID. The style is page-specific so when
// we change pages we need to ensure that we update that page with
// our style when used.
// The hyperlink ID that is currently active for the cursor. A value
// of zero means no hyperlink is active. (Implements OSC8, saying that
// so code search can find it.).
// This is the implicit ID to use for hyperlinks that don't specify
// an ID. We do an overflowing add to this so repeats can technically
// happen with carefully crafted inputs but for real workloads its
// highly unlikely -- and the fix is for the TUI program to use explicit
// IDs.
// Heap-allocated hyperlink state so that we can recreate it when
// the cursor page pin changes. We can't get it from the old screen
// state because the page may be cleared. This is heap allocated
// because its most likely null.
// The current semantic content type for the cursor that will be
// applied to any newly written cells.
// The pointers into the page list where the cursor is currently
// located. This makes it faster to move the cursor.
// Saved cursor state.
// State required for all charset operations.
// The list of graphical charsets by slot
// GL is the slot to use when using a 7-bit printable char (up to 127)
// GR used for 8-bit printable chars.
// Single shift where a slot is used for exactly one char.
// An array to map a charset slot to a lookup table.
//
// We use this bespoke struct instead of `std.EnumArray` because
// accessing these slots is very performance critical since it's
// done for every single print. This benchmarks faster.
// The maximum size of scrollback in bytes. Zero means unlimited. Any
// other value will be clamped to support a minimum of the active area.
// The total storage limit for Kitty images in bytes for this
// screen. Kitty image storage is per-screen.
// A simple, default terminal. If you rely on specific dimensions or
// scrollback (or lack of) then do not use this directly. This is just
// for callers that need some defaults.
// Initialize a new screen.
//
// max_scrollback is the amount of scrollback to keep in bytes. This
// will be rounded UP to the nearest page size because our minimum allocation
// size is that anyways.
//
// If max scrollback is 0, then no scrollback is kept at all.
// Initialize our backing pages.
// Create our tracked pin for the cursor.
// This can't fail because the storage is always empty at this point
// and the only fail-able case is that we have to evict images.
// Assert that the screen is in a consistent state. This doesn't check
// all pages in the page list because that is SO SLOW even just for
// tests. This only asserts the screen specific data so callers should
// ensure they're also calling page integrity checks if necessary.
// We don't run integrity checks on Valgrind because its soooooo slow,
// Valgrind is our integrity checker, and we run these during unit
// tests (non-Valgrind) anyways so we're verifying anyways.
// Our cursor x/y should always match the pin. If this doesn't
// match then it indicates that the tracked pin moved and we didn't
// account for it by either calling cursorReload or manually
// adjusting.
// Reset the screen according to the logic of a DEC RIS sequence.
//
// - Clears the screen and attempts to reclaim memory.
// - Moves the cursor to the top-left.
// - Clears any cursor state: style, hyperlink, etc.
// - Resets the charset
// - Clears the selection
// - Deletes all Kitty graphics
// - Resets Kitty Keyboard settings
// - Disables protection mode
//
// Reset our pages
// The above reset preserves tracked pins so we can still use
// our cursor pin, which should be at the top-left already.
// Reset kitty graphics storage
// Reset our basic state
// Clone the screen.
//
// This will copy:
//
//   - Screen dimensions
//   - Screen data (cell state, etc.) for the region
//
// Anything not mentioned above is NOT copied. Some of this is for
// very good reason:
//
//   - Kitty images have a LOT of data. This is not efficient to copy.
//     Use a lock and access the image data. The dirty bit is there for
//     a reason.
//   - Cursor location can be expensive to calculate with respect to the
//     specified region. It is faster to grab the cursor from the old
//     screen and then move it to the new screen.
//   - Current hyperlink cursor state has heap allocations. Since clone
//     is only for read-only operations, it is better to not have any
//     hyperlink state. Note that already-written hyperlinks are cloned.
//
// If not mentioned above, then there isn't a specific reason right now
// to not copy some data other than we probably didn't need it and it
// isn't necessary for screen coherency.
//
// Other notes:
//
//   - The viewport will always be set to the active area of the new
//     screen. This is the bottom "rows" rows.
//   - If the clone region is smaller than a viewport area, blanks will
//     be filled in at the bottom.
//
// Create a tracked pin remapper for our selection and cursor. Note
// that we may want to expose this generally in the future but at the
// time of doing this we don't need to.
// Find our cursor. If the cursor isn't in the cloned area, we move it
// to the top-left arbitrarily because a screen must have SOME cursor.
// Preserve our selection if we have one.
// No start means it is outside the cloned area.
// If we have no end pin then either
// (1) our whole selection is outside the cloned area or
// (2) our cloned area is within the selection
// We check if the selection bottom right pin is above
// the cloned area or if the top left pin is below the
// cloned area, in either of these cases it means that
// the selection is fully out of bounds, so we have no
// selection in the cloned area and break out now.
// We move the top pin back in bounds to the top row.
// If we got to this point it means that the selection is not
// fully out of bounds, so we move the bottom right pin back
// in bounds if it isn't already.
// If the page being modified isn't our cursor page then
// this is a quick operation because we have no additional
// accounting. We have to do this check here BEFORE calling
// increaseCapacity because increaseCapacity will update all
// our tracked pins (including our cursor).
// We're modifying the cursor page. When we increase the
// capacity below it will be short the ref count on our
// current style and hyperlink, so we need to init those.
// Re-add the style, if the page somehow doesn't have enough
// memory to add it, we emit a warning and gracefully degrade
// to the default style for the cursor.
// TODO: Should we increase the capacity further in this case?
// Reset the cursor style.
// Re-add the hyperlink, if the page somehow doesn't have enough
// memory to add it, we emit a warning and gracefully degrade to
// no hyperlink.
// So we don't attempt to free any memory in the replaced page.
// Re-add
// TODO: Should we increase the capacity further in this case?
// Remove our old link
// Reload the cursor information because the pin changed.
// So our page row/cell and so on are all off.
// Move the cursor right. This is a specialized function that is very fast
// if the caller can guarantee we have space to move right (no wrapping).
// Move the cursor left.
// Move the cursor up.
//
// Precondition: The cursor is not at the top of the screen.
// Move the cursor down.
//
// Precondition: The cursor is not at the bottom of the screen.
// We move the offset into our page list to the next row and then
// get the pointers to the row/cell and set all the cursor state up.
// Move the cursor to some absolute horizontal position.
// Move the cursor to some absolute position.
// Reloads the cursor pointer information into the screen. This is expensive
// so it should only be done in cases where the pointers are invalidated
// in such a way that its difficult to recover otherwise.
// Our tracked pin is ALWAYS accurate, so we derive the active
// point from the pin. If this returns null it means our pin
// points outside the active area. In that case, we update the
// pin to be the top-left.
// If we have a style, we need to ensure it is in the page because this
// method may also be called after a page change.
// This failure should not happen because manualStyleUpdate
// handles page splitting, overflow, and more. This should only
// happen if we're out of RAM. In this case, we'll just degrade
// gracefully back to the default style.
// Scroll the active area and keep the cursor at the bottom of the screen.
// This is a very specialized function but it keeps it fast.
// Scrolling dirties the images because it updates their placements pins.
// If we have no scrollback, then we shift all our rows instead.
// If we have a single-row screen, we have no rows to shift
// so our cursor is in the correct place we just have to clear
// the cells.
// The call to `eraseRow` will move the tracked cursor pin up by one
// row, but we don't actually want that, so we keep the old pin and
// put it back after calling `eraseRow`.
// eraseRow will shift everything below it up.
// Note we don't need to mark anything dirty in this branch
// because eraseRow will mark all the rotated rows as dirty
// in the entire page.
// We don't use `cursorChangePin` here because we aren't
// actually changing the pin, we're keeping it the same.
// We do, however, need to refresh the cached page row
// and cell, because `eraseRow` will have moved the row.
// Grow our pages by one row. The PageList will handle if we need to
// allocate, prune scrollback, whatever.
// We do this all in a block here because referencing this pin
// after cursorChangePin is unsafe, and we want to keep it out
// of scope.
// If our pin page change it means that the page that the pin
// was on was pruned. In this case, grow() moves the pin to
// the top-left of the new page. This effectively moves it by
// one already, we just need to fix up the x value.
// These assertions help catch some pagelist math errors. Our
// x/y should be unchanged after the grow.
// Our new row is always dirty
// Clear the new row so it gets our bg color. We only do this
// if we have a bg color at all.
// The newly created line needs to be styled according to
// the bg color if it is set.
// This scrolls the active area at and above the cursor.
// The lines below the cursor are not scrolled.
// We unconditionally mark the cursor row as dirty here because
// the cursor always changes page rows inside this function, and
// when that happens it can mean the text in the old row needs to
// be re-shaped because the cursor splits runs to break ligatures.
// If the cursor is on the bottom of the screen, its faster to use
// our specialized function for that case.
// Logic below assumes we always have at least one row that isn't moving
// Explanation:
//  We don't actually move everything that's at or above the cursor row,
//  since this would require us to shift up our ENTIRE scrollback, which
//  would be ridiculously expensive. Instead, we insert a new row at the
//  end of the pagelist (`grow()`), and move everything BELOW the cursor
//  DOWN by one row. This has the same practical result but it's a whole
//  lot cheaper in 99% of cases.
// In this case, it means grow() didn't allocate a new page.
// If we're on the last page we can do a very fast path because
// all the rows we need to move around are within a single page.
// Note: we don't need to call cursorChangePin here because
// the pin page is the same so there is no accounting to do
// for styles or any of that.
// Rotate the rows so that the newly created empty row is at the
// beginning. e.g. [ 0 1 2 3 ] in to [ 3 0 1 2 ].
// Mark the whole page as dirty.
//
// Technically we only need to mark from the cursor row to the
// end but this is a hot function, so we want to minimize work.
// Setup our cursor caches after the rotation so it points to the
// correct data
// We didn't grow pages but our cursor isn't on the last page.
// In this case we need to do more work because we need to copy
// elements between pages.
//
// An example scenario of this is shown below:
//
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4302 |1A00000000| | 0
// 4303 |2B00000000| | 1
//      :^         : : = PIN 0
// 4304 |3C00000000| | 2
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |4D00000000| | 3
//    1 |5E00000000| | 4
//      +----------+ :
//     +-------------+
// The newly created line needs to be styled according to
// the bg color if it is set.
// Go through each of the pages following our pin, shift all rows
// down by one, and copy the last row of the previous page.
// Rotate the pages down: [ 0 1 2 3 ] => [ 3 0 1 2 ]
// Copy the last row of the previous page to the top of current.
// Mark dirty on the page, since we are dirtying all rows with this.
// Our current is our cursor page, we need to rotate down from
// our cursor and clear our row.
// Mark the whole page as dirty.
//
// Technically we only need to mark from the cursor row to the
// end but this is a hot function, so we want to minimize work.
// Setup cursor cache data after all the rotations so our
// row is valid.
// Move the cursor down if we're not at the bottom of the screen. Otherwise
// scroll. Currently only used for testing.
// Copy another cursor. The cursor can be on any screen but the x/y
// must be within our screen bounds.
// Copy the hyperlink from the other cursor. If not set, this will
// clear our current hyperlink.
// End any currently active hyperlink on our cursor.
// Keep our old style ID so it can be properly cleaned up below.
// Hyperlinks will be managed separately below.
// Keep our old page pin and X/Y because:
// 1. The old style will need to be cleaned up from the page it's from.
// 2. The new position navigated to by `cursorAbsolute` needs to be in our
//    own screen.
// Call manual style update in order to clean up our old style, if we have
// one, and also to load the style from the other cursor, if it had one.
// Move to the correct location to match the other cursor.
// If the other cursor had a hyperlink, add it to ours.
// Get the hyperlink from the other cursor's page.
// And it to our cursor.
// This shouldn't happen because startHyperlink should handle
// resizing. This only happens if we're truly out of RAM. Degrade
// to forgetting the hyperlink.
// Always use this to write to cursor.page_pin.*.
//
// This specifically handles the case when the new pin is on a different
// page than the old AND we have a style or hyperlink set. In that case,
// we must release our old one and insert the new one, since styles are
// stored per-page.
//
// Note that this can change the cursor pin AGAIN if the process of
// setting up our cursor forces a capacity adjustment of the underlying
// cursor page, so any references to the page pin should be re-read
// from `self.cursor.page_pin` after calling this.
// Moving the cursor affects text run splitting (ligatures) so
// we must mark the old and new page dirty. We do this as long
// as the pins are not equal
// If our pin is on the same page, then we can just update the pin.
// We don't need to migrate any state.
// If we have an old style then we need to release it from the old page.
// Release the style directly from the old page instead of going through
// manualStyleUpdate, because the cursor position may have already been
// updated but the pin has not, which would fail integrity checks.
// If we have a hyperlink then we need to release it from the old page.
// Update our pin to the new page
// On the new page, we need to migrate our style
// This failure should not happen because manualStyleUpdate
// handles page splitting, overflow, and more. This should only
// happen if we're out of RAM. In this case, we'll just degrade
// gracefully back to the default style.
// On the new page, we need to migrate our hyperlink
// So we don't attempt to free any memory in the replaced page.
// Re-add
// This shouldn't happen because startHyperlink should handle
// resizing. This only happens if we're truly out of RAM. Degrade
// to forgetting the hyperlink.
// Remove our old link
// Mark the cursor position as dirty.
// TODO: test
// Reset the cursor row's soft-wrap state and the cursor's pending wrap.
// Also handles clearing the spacer head on the cursor row and resetting
// the wrap_continuation flag on the next row if necessary.
//
// NOTE(qwerasd): This method is not scrolling region aware, and cannot be
// since it's on Screen not Terminal. This needs to be addressed down the
// line. Not an extremely urgent issue since it's an edge case of an edge
// case, but not ideal.
// Reset the cursor's pending wrap state
// This row does not wrap and the next row is not wrapped to
// If the last cell in the row is a spacer head we need to clear it.
// Options for scrolling the viewport of the terminal grid. The reason
// we have this in addition to PageList.Scroll is because we have additional
// scroll behaviors that are not part of the PageList.Scroll enum.
// For all of these, see PageList.Scroll.
// Scroll the viewport of the terminal grid.
// No matter what, scrolling marks our image state as dirty since
// it could move placements. If there are no placements or no images
// this is still a very cheap operation.
// See PageList.scrollClear. In addition to that, we reset the cursor
// to be on top.
// No matter what, scrolling marks our image state as dirty since
// it could move placements. If there are no placements or no images
// this is still a very cheap operation.
// Returns true if the viewport is scrolled to the bottom of the screen.
// Erase the region specified by tl and br, inclusive. This will physically
// erase the rows meaning the memory will be reclaimed (if the underlying
// page is empty) and other rows will be shifted up.
// Erase the rows
// Just to be safe, reset our cursor since it is possible depending
// on the points that our active area shifted so our pointers are
// invalid.
// Clear the region specified by tl and bl, inclusive. Cleared cells are
// colored with the current style background color. This will clear all
// cells in the rows.
//
// If protected is true, the protected flag will be respected and only
// unprotected cells will be cleared. Otherwise, all cells will be cleared.
// Clear all cells
// We need to preserve other row attributes since we only
// cleared unprotected cells.
// Clear the cells with the blank cell.
//
// This takes care to handle cleaning up graphemes and styles.
// This whole operation does unsafe things, so we just want to assert
// the end state.
// Our row and cells should be within the page.
// If we have managed memory (styles, graphemes, or hyperlinks)
// in this row then we go cell by cell and clear them if present.
// If we have no left/right scroll region we can be sure
// that we've cleared all the graphemes, so we clear the
// flag, otherwise we ask the page to update the flag.
// If we have no left/right scroll region we can be sure
// that we've cleared all the hyperlinks, so we clear the
// flag, otherwise we ask the page to update the flag.
// If we have no left/right scroll region we can be sure
// that we've cleared all the styles, so we clear the
// flag, otherwise we ask the page to update the flag.
// Clear cells but only if they are not protected.
// Clean up boundary conditions where a cell will become discontiguous with
// a neighboring cell because either one of them will be moved and/or cleared.
//
// For performance reasons this is specialized to operate on the cursor row.
//
// Handles the boundary between the cell at `x` and the cell at `x - 1`.
//
// So, for example, when moving a region of cells [a, b] (inclusive), call this
// function with `x = a` and `x = b + 1`. It is okay if `x` is out of bounds by
// 1, this will be interpreted correctly.
//
// DOES NOT MODIFY ROW WRAP STATE! See `cursorResetWrap` for that.
//
// The following boundary conditions are handled:
//
// - `x - 1` is a wide character and `x` is a spacer tail:
//   o Both cells will be cleared.
//   o If `x - 1` is the start of the row and was wrapped from a previous row
//     then the previous row is checked for a spacer head, which is cleared if
//     present.
//
// - `x == 0` and is a wide character:
//   o If the row is a wrap continuation then the previous row will be checked
//     for a spacer head, which is cleared if present.
//
// - `x == cols` and `x - 1` is a spacer head:
//   o `x - 1` will be cleared.
//
// NOTE(qwerasd): This method is not scrolling region aware, and cannot be
// since it's on Screen not Terminal. This needs to be addressed down the
// line. Not an extremely urgent issue since it's an edge case of an edge
// case, but not ideal.
// `x` may be up to an INCLUDING `cols`, since that signifies splitting
// the boundary to the right of the final cell in the row.
// [ A B C D E F|]
//              ^ Boundary between final cell and row end.
// Spacer head at end of wrapped row.
// [|A B C D E F ]
//  ^ Boundary between first cell and row start.
//
//  OR
//
// [ A|B C D E F ]
//    ^ Boundary between first cell and second cell.
//
// First cell may be a wrapped wide cell with a spacer
// head on the previous row that needs to be cleared.
// If the first cell in a row is wide the previous row
// may have a spacer head which needs to be cleared.
// If x is 0 then we're done.
// [ ... X|Y ... ]
//        ^ Boundary between two cells in the middle of the row.
// There should not be spacer heads in the middle of the row.
// We don't need to do anything for narrow cells or spacer tails.
// A wide char would be split, so must be cleared.
// Returns the blank cell to use when doing terminal operations that
// require preserving the bg color.
// The new size to resize to
// Whether to reflow soft-wrapped text.
//
// This will reflow soft-wrapped text. If the screen size is getting
// smaller and the maximum scrollback size is exceeded, data will be
// lost from the top of the scrollback.
// Set this to enable prompt redraw on resize. This signals
// that the running program can redraw the prompt if the cursor is
// currently at a prompt. This detects OSC133 prompts lines and clears
// them. If set to `.last`, only the most recent prompt line is cleared.
// Resize the screen. The rows or cols can be bigger or smaller.
//
// If this returns an error, the screen is left in a likely garbage state.
// It is very hard to undo this operation without blowing up our memory
// usage. The only way to recover is to reset the screen. The only way
// this really fails is if page allocation is required and fails, which
// probably means the system is in trouble anyways. I'd like to improve this
// in the future but it is not a priority particularly because this scenario
// (resize) is difficult.
// No matter what we mark our image state as dirty
// Release the cursor style while resizing just
// in case the cursor ends up on a different page.
// Restore the cursor style.
// This failure should not happen because manualStyleUpdate
// handles page splitting, overflow, and more. This should only
// happen if we're out of RAM. In this case, we'll just degrade
// gracefully back to the default style.
// If we have a hyperlink, release it from the old page
// and then we need to re-add it to the new page. This needs
// to happen because resize below typically reallocates a
// new page so the old hyperlink is invalid.
// Note we do NOT use endHyperlink because we want to keep
// our allocated self.cursor.hyperlink valid.
// We need to insert a tracked pin for our saved cursor so we can
// modify its X/Y for reflow.
// If our cursor is on a prompt or input line, clear it so the shell can
// redraw it. This works with OSC 133 semantic prompts.
//
// We check cursor.semantic_content rather than page_row.semantic_prompt
// because some shells (e.g., Nu) mark input areas with OSC 133 B but don't
// mark continuation lines with k=s. If the input spans multiple lines and
// continuation lines are unmarked, checking only page_row.semantic_prompt
// would miss them. By checking semantic_content, we assume that if the
// cursor is on anything other than command output, we're at a prompt/input
// line and should clear from there.
// For `.last`, only clear the current line where the cursor is.
// For `.true`, clear all prompt lines starting from the beginning.
// This should never happen because promptIterator should always
// find a prompt if we already verified our row is some kind of
// prompt.
// Clear cells from our start down. We replace it with spaces,
// and do not physically erase the rows (eraseRows) because the
// shell is going to expect this space to be available.
// Perform the resize operation.
// If we have no scrollback and we shrunk our rows, we must explicitly
// erase our history. This is because PageList always keeps at least
// a page size of history.
// If our cursor was updated, we do a full reload so all our cursor
// state is correct.
// If we reflowed a saved cursor, update it.
// This should never fail because a non-null saved_cursor_pin
// implies a non-null saved_cursor.
// If we had pending wrap set and we're no longer at the end of
// the line, we unset the pending wrap and move the cursor to
// reflect the correct next position.
// I think this can happen if the screen is resized to be
// less rows or less cols and our saved cursor moves outside
// the active area. In this case, there isn't anything really
// reasonable we can do so we just move the cursor to the
// top-left. It may be reasonable to also move the cursor to
// match the primary cursor. Any behavior is fine since this is
// totally unspecified.
// Fix up our hyperlink if we had one.
// This shouldn't happen because startHyperlink should handle
// resizing. This only happens if we're truly out of RAM. Degrade
// to forgetting the hyperlink.
// Remove our old link
// Set a style attribute for the current cursor.
//
// If the style can't be set due to any internal errors (memory-related),
// then this will revert back to the existing style and return an error.
// If we fail to set our style for any reason, we should revert
// back to the old style. If we fail to do that, we revert back to
// the default style.
// Bold and faint share the same SGR code for this
// Call this whenever you manually change the cursor style.
//
// This function can NOT fail if the cursor style is changing to the
// default style.
//
// If this returns an error, the style change did not take effect and
// the cursor style is reverted back to the default. The only scenario
// this returns an error is if there is a physical memory allocation failure
// or if there is no possible way to increase style capacity to store
// the style.
//
// This function WILL split pages as necessary to accommodate the new style.
// So if OutOfSpace is returned, it means that even after splitting the page
// there was still no room for the new style.
// std.log.warn("active styles={}", .{page.styles.count()});
// Release our previous style if it was not default.
// If our new style is the default, just reset to that
// Clear the cursor style ID to prevent weird things from happening
// if the page capacity has to be adjusted which would end up calling
// manualStyleUpdate again.
//
// This also ensures that if anything fails below, we fall back to
// clearing our style.
// After setting the style, we need to update our style map.
// Note that we COULD lazily do this in print. We should look into
// if that makes a meaningful difference. Our priority is to keep print
// fast because setting a ton of styles that do nothing is uncommon
// and weird.
// Our style map is full or needs to be rehashed, so we need to
// increase style capacity (or rehash).
// Out of space, we need to split the page. Split wherever
// is using less capacity and hope that works. If it doesn't
// work, we tried.
// This shouldn't happen because increaseCapacity is
// guaranteed to increase our capacity by at least one and
// we only need one space, but again, I don't want to crash
// here so let's log loudly and reset.
// This should be impossible because we rehash above
// and rehashing should never result in a duplicate. But
// we don't want to simply hard crash so log it and
// clear our style.
// Split at the given pin so that the pinned row moves to the page
// with less used capacity after the split.
//
// The primary use case for this is to handle IncreaseCapacityError
// OutOfSpace conditions where we need to split the page in order
// to make room for more managed memory.
//
// If the caller cares about where the pin moves to, they should
// setup a tracked pin before calling this and then check that.
// In many calling cases, the input pin is tracked (e.g. the cursor
// pin).
//
// If this returns OOM then its a system OOM. If this returns OutOfSpace
// then it means the page can't be split further.
// Get our capacities. We include our target row because its
// capacity will be preserved.
// We need to track the old cursor pin because if our split
// moves the cursor pin we need to update our accounting.
// If our bytes above are less than bytes below, we move the pin
// to split down one since splitting includes the pinned row in
// the new node.
// Cursor didn't change nodes, we're done.
// Cursor changed, we need to restore the old pin then use
// cursorChangePin to move to the new pin. The old node is guaranteed
// to still exist, just not the row.
//
// Note that page_row and all that will be invalid, it points to the
// new node, but at the time of writing this we don't need any of that
// to be right in cursorChangePin.
// Append a grapheme to the given cell within the current cursor row.
// We need to determine the actual cell index of the cell so
// that after we adjust the capacity we can reload the cell.
// Adjust our capacity. This will update our cursor page pin and
// force us to reload.
// The cell pointer is now invalid, so we need to get it from
// the reloaded cursor pointers.
// This should never happen because we just increased capacity.
// Log loudly but still return an error so we don't just
// crash.
// Start the hyperlink state. Future cells will be marked as hyperlinks with
// this state. Note that various terminal operations may clear the hyperlink
// state, such as switching screens (alt screen).
// Create our pending entry.
// Loop until we have enough page memory to add the hyperlink
// An actual self.alloc OOM is a fatal error.
// strings table is out of memory, adjust it up
// hyperlink set is out of memory, adjust it up
// hyperlink set is too full, rehash it
// This is like startHyperlink but if we have to adjust page capacities
// this returns error.PageAdjusted. This is useful so that we unwind
// all the previous state and try again.
// End any prior hyperlink
// Allocate our new Hyperlink entry in non-page memory. This
// lets us quickly get access to URI, ID.
// Insert the hyperlink into page memory
// Save it all
// End the hyperlink state so that future cells aren't part of the
// current hyperlink (if any). This is safe to call multiple times.
// If we have no hyperlink state then do nothing
// Release the old hyperlink state. If there are cells using the
// hyperlink this will work because the creation creates a reference
// and all additional cells create a new reference. This release will
// just release our initial reference.
//
// If the ref count reaches zero the set will not delete the item
// immediately; it is kept around in case it is used again (this is
// how RefCountedSet works). This causes some memory fragmentation but
// is fine because if it is ever pruned the context deleted callback
// will be called.
// Set the current hyperlink state on the current cell.
// Success, increase the refcount for the hyperlink.
// hyperlink_map is out of space, realloc the page to be larger
// Attempt to allocate the space that would be required to
// insert a new copy of the cursor hyperlink uri in to the
// string alloc, since right now increaseCapacity always just
// adds an extra copy even if one already exists in the page.
// If this alloc fails then we know we also need to grow our
// string bytes.
//
// FIXME: increaseCapacity should not do this.
// We don't bother freeing because we're
// about to free the entire page anyway.
// We didn't have enough room, let's increase string bytes
// Retry
//
// We check that the cursor hyperlink hasn't been destroyed
// by the capacity adjustment first though- since despite the
// terrible code above, that can still apparently happen ._.
// Modify the semantic content type of the cursor. This should
// be preferred over setting it manually since it handles all the
// proper accounting.
// Set the selection to the given selection. If this is a tracked selection
// then the screen will take ownership of the selection. If this is untracked
// then the screen will convert it to tracked internally. This will automatically
// untrack the prior selection (if any).
//
// Set the selection to null to clear any previous selection.
//
// This is always recommended over setting `selection` directly. Beyond
// managing memory for you, it also performs safety checks that the selection
// is always tracked.
// If this selection is untracked then we track it.
// Untrack prior selection
// Same as select(null) but can't fail.
// The selection to convert to a string.
// If true, trim whitespace around the selection.
// If non-null, a stringmap will be written here. This will use
// the same allocator as the call to selectionString. The string will
// be duplicated here and in the return value so both must be freed.
// Returns the raw text associated with a selection. This will unwrap
// soft-wrapped edges. The returned slice is owned by the caller and allocated
// using alloc, not the allocator associated with the screen (unless they match).
//
// For more flexibility, use a ScreenFormatter directly.
// We'll use this as our buffer to build our string.
// Create a formatter and use that to emit our text.
// If we have a string map, we need to set that up.
// Emit. Since this is an allocating writer, a failed write
// just becomes an OOM.
// Build our final text and if we have a string map set that up.
// The pin of some part of the line to select.
// These are the codepoints to consider whitespace to trim
// from the ends of the selection.
// If true, line selection will consider semantic prompt
// state changing a boundary. State changing is ANY state
// change.
// Select the line under the given point. This will select across soft-wrapped
// lines and will omit the leading and trailing whitespace. If the point is
// over whitespace but the line has non-whitespace characters elsewhere, the
// line will be selected.
// Get the current point semantic prompt state since that determines
// boundary conditions too. This makes it so that line selection can
// only happen within the same prompt state. For example, if you triple
// click output, but the shell uses spaces to soft-wrap to the prompt
// then the selection will stop prior to the prompt. See issue #1329.
// The real start of the row is the first row in the soft-wrap.
// First, check the current row for semantic boundaries before the clicked position.
// Scan backwards from clicked position to find where our content starts
// No boundary found before clicked position on current row.
// If row doesn't wrap from above, start is at column 0.
// Otherwise, continue checking previous rows.
// We need to check every cell in this row in reverse
// order since we're going up and back.
// The real end of the row is the final row in the soft-wrap.
// We need to check every cell in this row
// If this is our pin row we can start from our x because
// the start_pin logic already found the real start.
// Handle the zero case specially because if the first
// col doesn't match then we end at the end of the prior
// row. But if this is the first row, we can't go back,
// so we scan forward to find where our content ends.
// For every other case, we end at the prior cell.
// Go forward from the start to find the first non-whitespace character.
// Non-empty means we found it.
// Go backward from the end to find the first non-whitespace character.
// Non-empty means we found it.
// Return the selection for all contents on the screen. Surrounding
// whitespace is omitted. If there is no selection, this returns null.
// Non-empty means we found it.
// Non-empty means we found it.
// Select the nearest word to start point that is between start_pt and
// end_pt (inclusive). Because it selects "nearest" to start point, start
// point can be before or after end point.
//
// The boundary_codepoints parameter should be a slice of u21 codepoints that
// mark word boundaries, passed through to selectWord.
//
// TODO: test this
// Boundary conditions
// If we found a word, then return it
// Select the word under the given point. A word is any consecutive series
// of characters that are exclusively whitespace or exclusively non-whitespace.
// A selection can span multiple physical lines if they are soft-wrapped.
//
// This will return null if a selection is impossible. The only scenario
// this happens is if the point pt is outside of the written screen space.
//
// The boundary_codepoints parameter should be a slice of u21 codepoints that
// mark word boundaries. This is expected to be pre-parsed from the config.
// If our cell is empty we can't select a word, because we can't select
// areas where the screen is not yet written.
// Determine if we are a boundary or not to determine what our boundary is.
// Go forwards to find our end boundary
// If we reached an empty cell its always a boundary
// If we do not match our expected set, we hit a boundary
// If we are going to the next row and it isn't wrapped, we
// return the previous.
// Go backwards to find our start boundary
// If we are going to the next row and it isn't wrapped, we
// return the previous.
// If we reached an empty cell its always a boundary
// If we do not match our expected set, we hit a boundary
// Select the command output under the given point. The limits of the output
// are determined by semantic prompt information provided by shell integration.
// A selection can span multiple physical lines if they are soft-wrapped.
//
// This will return null if a selection is impossible:
//  - the point pt is outside of the written screen space.
//  - the point pt is on a prompt / input line.
// If our pin right now is not on output, then we return nothing.
// Get the post prior prompt from this pin. This is the prompt whose
// output we'll be capturing.
// If we have a prompt above this point (including this point),
// then thats the prompt we want to capture output from.
// If we don't have a prompt, then we assume that we're
// capturing all the output up to the next prompt.
// We'll capture from the start of the screen to just above
// the prompt and will trim the trailing whitespace.
// Grab our content
// Trim our trailing whitespace
// Returns an iterator to move through the soft-wrapped lines starting
// from pin.
// Determine the inputs necessary to move the cursor to the given
// click location within a prompt input area.
//
// If the cursor isn't currently at a prompt input location, this
// returns no movement.
//
// This feature depends on well-behaved OSC133 shell integration. Specifically,
// this only moves over designated input areas (OSC 133 B). It is assumed
// that the shell will only move the cursor to input cells, so prompt cells
// and other blank cells are ignored as part of the movement calculation.
// If we're not at an input cell with our cursor, no movement will
// ever be possible.
// None doesn't support movement and click_events must use a
// different mechanism (SGR mouse events) that callers must handle.
// All of these currently use dumb line-based navigation.
// But eventually we'll support more.
// Determine the inputs required to move from the cursor to the given
// click location. If the cursor isn't currently at a prompt input
// location, this will return zero.
//
// This currently only supports moving a single line.
// If our click pin is our cursor pin, no movement is needed.
// Do this early so we can assume later that they are different.
// If our cursor is before our click, we're only emitting right inputs.
// We go row-by-row because soft-wrapped rows are still a single
// line to a shell, so we can't just look at our page row.
// Determine if this row is our cursor.
// If this is not the cursor row, verify it's still part of the
// continuation of our starting prompt.
// Determine where our input starts.
// If this is our cursor row then we start after the cursor.
// Otherwise, we start at the first input cell, because
// we expect the shell to properly translate arrows across
// lines to the start of the input. Some shells indent
// where input starts on subsequent lines so we must do
// this.
// We never found an input cell, so we need to move to the
// next row.
// Iterate over the input cells and assume arrow keys only
// jump to input cells.
// Ignore non-input cells, but allow breaks. We assume
// the shell will translate arrow keys to only input
// areas.
// Increment our input count
// If this is our target, we're done.
// If this row isn't soft-wrapped, we need to break out
// because line based moving only handles single lines.
// We're done!
// If we never found our pin, that means we clicked further
// right/beyond it. If we're already on a non-empty input cell
// then we add one so we can move to the newest, empty cell
// at the end, matching typical editor behavior.
// Otherwise, cursor is after click, so we're emitting left inputs.
// We go row-by-row because soft-wrapped rows are still a single
// line to a shell, so we can't just look at our page row.
// Determine the length of the cells we look at in this row.
// If this is our cursor row then we end before the cursor.
// Otherwise, we end at the last cell in the row.
// Iterate backwards over the input cells.
// Ignore non-input cells.
// Increment our input count
// If this is our target, we're done.
// If this row is not a wrap continuation, then break out
// Dump the screen to a string. The writer given should be buffered;
// this function does not attempt to efficiently write and generally writes
// one byte at a time.
// The start and end points of the dump, both inclusive. The x will
// be ignored and the full row will always be dumped.
// If true, this will unwrap soft-wrapped lines. If false, this will
// dump the screen as it is visually seen in a rendered window.
// Create a formatter and use that to emit our text.
// Set up the selection based on the pins
// Emit
// You should use dumpString, this is a restricted version mostly for
// legacy and convenience reasons for unit tests.
// You should use dumpString, this is a restricted version mostly for
// legacy and convenience reasons for unit tests.
// This is basically a really jank version of Terminal.printString. We
// have to reimplement it here because we want a way to print to the screen
// to test it but don't want all the features of Terminal.
// Explicit newline forces a new row
// If we have a ref-counted style, increase.
// If we have a hyperlink, add it to the cell.
// Need a wide spacer head
// If we have a hyperlink, add it to the cell.
// Write our wide char
// If we have a hyperlink, add it to the cell.
// Write our tail
// If we have a hyperlink, add it to the cell.
// If we have a ref-counted style, increase twice.
// Bold should create our style
// Copy default style, should release our style
// We need to get the cursor on a new page.
// Fill the scrollback with blank lines until
// there are only 5 rows left on the first page.
// s2.pages.diagram(...):
//
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4300 |1         | | 0
// 4301 |2         | | 1
// 4302 |3         | | 2
// 4303 |4         | | 3
// 4304 |5         | | 4
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |6         | | 5
//    1 |7         | | 6
//    2 |8         | | 7
//    3 |9         | | 8
//    4 |10        | | 9
//      :  ^       : : = PIN 0
//      +----------+ :
//     +-------------+
// This should be PAGE 1
// It should be the last page in the list.
// It should have a previous page.
// The cursor should be at 2, 9
// Bold should create our style in page 1.
// Copy the cursor for the first screen. This should release
// the style from page 1 and move the cursor back to page 0.
// The page after the page the cursor is now in should be page 1.
// The cursor should be at 0, 0
// Create a hyperlink for the cursor.
// Copy a cursor with no hyperlink, should release our hyperlink.
// We need to get the cursor on a new page.
// Fill the scrollback with blank lines until
// there are only 5 rows left on the first page.
// s2.pages.diagram(...):
//
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4300 |1         | | 0
// 4301 |2         | | 1
// 4302 |3         | | 2
// 4303 |4         | | 3
// 4304 |5         | | 4
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |6         | | 5
//    1 |7         | | 6
//    2 |8         | | 7
//    3 |9         | | 8
//    4 |10        | | 9
//      :  ^       : : = PIN 0
//      +----------+ :
//     +-------------+
// This should be PAGE 1
// It should be the last page in the list.
// It should have a previous page.
// The cursor should be at 2, 9
// Create a hyperlink for the cursor, should be in page 1.
// Copy the cursor for the first screen. This should release
// the hyperlink from page 1 and move the cursor back to page 0.
// The page after the page the cursor is now in should be page 1.
// The cursor should be at 0, 0
// Create a hyperlink for the cursor.
// Copy the cursor with the hyperlink.
// Create a hyperlink for the cursor.
// Copy the cursor with the hyperlink.
// Set a new style
// Set another style, we should still only have one since it was unused
// Set a new style
// Reset to default
// Set a new style
// Reset to default
// We should have one style
// We should have none because active cleared it
// Scroll down enough to go to another page
// We need our page to change for this test o make sense. If this
// assertion fails then the bug is in the test: we should be scrolling
// above enough for a new page to show up.
// Scroll back to the previous page
// Go back up, set a style
// Go back down into the next page and we should have that style
// Scroll down enough to go to another page
// We need our page to change for this test o make sense. If this
// assertion fails then the bug is in the test: we should be scrolling
// above enough for a new page to show up.
// Go back up, set a style
// Go back down into the prev page and we should have that style
// Scroll down enough to go to another page
// We need our page to change for this test o make sense. If this
// assertion fails then the bug is in the test: we should be scrolling
// above enough for a new page to show up.
// Go back up, set a style
// Go back down into the prev page and we should have that style
// This test checks for a very specific edge case
// which previously resulted in memory corruption.
//
// The conditions for this edge case are as such:
// - The cursor has an associated style or other managed memory.
// - The cursor moves to a different page.
// - The new page is at capacity and must have its capacity adjusted.
// Scroll down enough to go to another page
// We need our page to change for this test to make sense. If this
// assertion fails then the bug is in the test: we should be scrolling
// above enough for a new page to show up.
// Add styles to the start page until it reaches capacity.
// Pause integrity checks because they're slow and
// we're not testing this, this is just setup.
// Set a style on the cursor.
// Go back up into the start page and we should still have that style.
// The page we're on now should NOT equal start_page, since its
// capacity should have been adjusted, which invalidates our ptr.
// To make sure we DID change pages we check we're not on new_page.
// Scroll down, should still be bottom
// Everything is dirty because we have no scrollback
// Scrolling to the bottom does nothing
// Scroll down, should still be bottom
// Screen should be dirty
// Scroll down, should still be bottom
// Active should be dirty
// Scrollback also dirty because cursor moved from there
// Scroll down enough to go to another page
// We need our page to change for this test o make sense. If this
// assertion fails then the bug is in the test: we should be scrolling
// above enough for a new page to show up.
// Scrolling up does nothing, but allows it
// Scrolling to the bottom
// Scrolling back should make it visible again
// Scrolling back again should do nothing
// Scrolling to the bottom
// Scrolling forward with no grow should do nothing
// Scrolling to the top should work
// Should be able to easily clear active area only
// Scrolling to the bottom
// Scroll to top
// Scroll down multiple
// First test: we scroll up by 1, so we're not at the bottom anymore.
// Next, we scroll back down by 1, this grows the scrollback but we
// shouldn't move.
// Scroll again, this clears scrollback so we should move viewports
// but still see the same thing since our original view fits.
// Select a single line
// Scroll down, should still be bottom
// Our selection should've moved up
// Test our contents rotated
// Scrolling to the bottom does nothing
// Our selection should've stayed the same
// Test our contents rotated
// Scroll up again
// Test our contents rotated
// Our selection should be null because it left the screen.
// Test our contents rotated
// Write some to create scrollback and move back into our scrollback.
// Our viewport is now somewhere pinned. Create so much scrollback
// that we prune it.
// Move back to top-left
// Write and clear
// Move back to top-left
// At this point:
//  +-------------+ ACTIVE
//   +----------+ : = PAGE 0
// 0 |1ABCD00000| | 0
// 1 |2EFGH00000| | 1
//   :^         : : = PIN 0
// 2 |3IJKL00000| | 2
//   +----------+ :
//  +-------------+
//   +----------+ = PAGE 0
// 0 |1ABCD00000|
//  +-------------+ ACTIVE
// 1 |2EFGH00000| | 0
// 2 |          | | 1
//   :^         : : = PIN 0
// 3 |3IJKL00000| | 2
//   +----------+ :
//  +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0 row 1 (active row 0) is dirty because the cursor moved off of it.
// Page 0 row 2 (active row 1) is dirty because it was cleared.
// Page 0 row 3 (active row 2) is dirty because it's new.
// We need to get the cursor to a new page
// Ensure we're still on the first page and have a second
// At this point:
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4305 |1A00000000| | 0
// 4306 |2B00000000| | 1
//      :^         : : = PIN 0
// 4307 |3C00000000| | 2
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |4D00000000| | 3
//    1 |5E00000000| | 4
//      +----------+ :
//     +-------------+
//      +----------+ = PAGE 0
//  ... :          :
// 4305 |1A00000000|
//     +-------------+ ACTIVE
// 4306 |2B00000000| | 0
// 4307 |          | | 1
//      :^         : : = PIN 0
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |3C00000000| | 2
//    1 |4D00000000| | 3
//    2 |5E00000000| | 4
//      +----------+ :
//     +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0's penultimate row is dirty because the cursor moved off of it.
// The rest of the rows are dirty because they've been modified or are new.
// We need to get the cursor to a new page
// Ensure we're still on the first page and have a second
// At this point:
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4306 |1A00000000| | 0
// 4307 |2B00000000| | 1
//      :^         : : = PIN 0
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |3C00000000| | 2
//    1 |4D00000000| | 3
//    2 |5E00000000| | 4
//      +----------+ :
//     +-------------+
//      +----------+ = PAGE 0
//  ... :          :
// 4306 |1A00000000|
//     +-------------+ ACTIVE
// 4307 |2B00000000| | 0
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |          | | 1
//      :^         : : = PIN 0
//    1 |3C00000000| | 2
//    2 |4D00000000| | 3
//    3 |5E00000000| | 4
//      +----------+ :
//     +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0's final row is dirty because the cursor moved off of it.
// Page 1's rows are all dirty because every row was moved.
// Attempt to clear the style from the cursor and
// then assert the integrity of both of our pages.
//
// This catches a case of memory corruption where the cursor
// is moved between pages without accounting for style refs.
// We need to get the cursor to a new page
// Ensure we're still on the first page
// At this point:
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4305 |1ABCD00000| | 0
// 4306 |2EFGH00000| | 1
//      :^         : : = PIN 0
// 4307 |3IJKL00000| | 2
//      +----------+ :
//     +-------------+
//      +----------+ = PAGE 0
//  ... :          :
// 4305 |1ABCD00000|
//     +-------------+ ACTIVE
// 4306 |2EFGH00000| | 0
// 4307 |          | | 1
//      :^         : : = PIN 0
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |3IJKL00000| | 2
//      +----------+ :
//     +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0's penultimate row is dirty because the cursor moved off of it.
// Page 0's final row is dirty because it was cleared.
// Page 1's row is dirty because it's new.
// Get the cursor to be 2 rows above a new page
// Write 3 lines of text, forcing the last line into the first
// row of a new page. Move our cursor onto the previous page.
// Ensure we're still on the first page. So our cursor is on the first
// page but we have two pages of data.
//      +----------+ = PAGE 0
//  ... :          :
//     +-------------+ ACTIVE
// 4305 |1AB0000000| | 0
// 4306 |2BC0000000| | 1
//      :^         : : = PIN 0
// 4307 |3DE0000000| | 2
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |4FG0000000| | 3
//      +----------+ :
//     +-------------+
//     +----------+ = PAGE 0
//  ... :          :
// 4305 |1AB0000000|
//     +-------------+ ACTIVE
// 4306 |2BC0000000| | 0
// 4307 |          | | 1
//      :^         : : = PIN 0
//      +----------+ :
//      +----------+ : = PAGE 1
//    0 |3DE0000000| | 2
//    1 |4FG0000000| | 3
//      +----------+ :
//     +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0's penultimate row is dirty because the cursor moved off of it.
// Page 0's final row is dirty because it was cleared.
// Page 1's row is dirty because it's new.
// At this point:
//  +-------------+ ACTIVE
//   +----------+ : = PAGE 0
// 0 |1ABCD00000| | 0
// 1 |2EFGH00000| | 1
//   :^         : : = PIN 0
// 2 |3IJKL00000| | 2
//   +----------+ :
//  +-------------+
//   +----------+ = PAGE 0
// 0 |1ABCD00000|
//  +-------------+ ACTIVE
// 1 |2EFGH00000| | 0
// 2 |          | | 1
//   :^         : : = PIN 0
// 3 |3IJKL00000| | 2
//   +----------+ :
//  +-------------+
// try s.pages.diagram(std.io.getStdErr().writer());
// Page 0 row 1 (active row 0) is dirty because the cursor moved off of it.
// Page 0 row 2 (active row 1) is dirty because it was cleared.
// Page 0 row 3 (active row 2) is dirty because it is new.
// Clone
// Write to s1, should not be in s2
// Clone
// Cursor is shifted since we cloned partial
// Clone
// Cursor is shifted since we cloned partial
// Select a single line
// Clone
// Our selection should remain valid
// Select a single line
// Clone
// Our selection should be null
// Select a single line
// Clone
// Our selection should remain valid
// Select a single line
// Clone
// Our selection should remain valid
// Select a single line
// Clone
// Our selection should remain valid
// Select the full screen
// Clone
// Our selection should remain valid
// Select the full screen from x=1 to x=3
// Clone
// Our selection should remain valid and be properly clipped
// preserving the columns of the start and end points of the
// selection.
// Test our contents rotated
// Test our contents rotated
// Test our contents rotated
// Test our contents
// Test our contents rotated
// Test our contents rotated
// Test our contents rotated
// Test our contents rotated
// Scroll to top
// Test our contents rotated
// Test our contents rotated
// Test our contents rotated
// Resize
// Since we shrunk, we should adjust our cursor
// Write only a background color into the remaining rows
// Cursor should not move
// Write only a background color into the remaining rows
// Cursor should not move
// https://github.com/mitchellh/ghostty/issues/1030
// Every second row should be wrapped
// Resize
// Every second row should be wrapped
// Cursor should not move
// Cursor should not move
// Set our cursor to be on the "4"
// Resize
// Cursor should still be on the "4"
// Cursor should not move
// https://github.com/mitchellh/ghostty/issues/272#issuecomment-1676038963
// https://github.com/mitchellh/ghostty/issues/1159
// Cursor at bottom
// Cursor remains at bottom
// https://github.com/mitchellh/ghostty/issues/1159
// Cursor at bottom
// Cursor remains at bottom
// Old implementation doesn't do this but it makes sense to me:
// {
//     const contents = try s.dumpStringAlloc(alloc, .{ .viewport = .{} });
//     defer alloc.free(contents);
//     try testing.expectEqualStrings("2\n3\n4", contents);
// }
// Set one of the rows to be a prompt
// Our one row should still be a semantic prompt, the others should not.
// Verify we soft wrapped
// Let's put our cursor on row 2, where the soft wrap is
// Resize and verify we undid the soft wrap because we have space now
// Our cursor should've moved
// Verify we soft wrapped
// Let's put our cursor on the last row
// Resize and verify we undid the soft wrap because we have space now
// Our cursor should still be on the 3
// Let's put our cursor on row 2, where the soft wrap is
// Verify we soft wrapped
// Resize and verify we undid the soft wrap because we have space now
// Our cursor should've moved
// Let's put our cursor on row 2, where the soft wrap is
// Verify we soft wrapped
// Resize and verify we undid the soft wrap because we have space now
// Our cursor should've moved
// // Set our cursor to be on the "5"
// Resize
// Cursor should still be on the "5"
// Let's put our cursor on row 2, where the soft wrap is
// Verify we soft wrapped
// Resize and verify we undid the soft wrap because we have space now
// Our cursor should've moved
// Cursor should move due to wrapping
// Cursor should not move
// Put our cursor on the last line
// Resize
// Cursor should be on the last line
// Resize
// Resize
// Cursor should stay in the same relative place (bottom of the
// screen, same character).
// Cursor should not move
// Put our cursor on the end
// Cursor should be on the last line
// Check
// {
//     const contents = try s.testString(alloc, .viewport);
//     defer alloc.free(contents);
//     const expected = "CD\n5EF\nGH";
//     try testing.expectEqualStrings(expected, contents);
// }
// Put our cursor on the end
// Cursor should be on the last line
// Check
// Put our cursor on the end
// Cursor should be on the last line
// Lets do a scroll and clear operation
// Move our cursor to the beginning
// Cursor should be on the last line
// This seems like it should work fine but for some reason in practice
// in the initial implementation I found this bug! This is a regression
// test for that.
// Grow
// Shrink
// Grow again
// Resize to 1 column can't fit a wide char. So it should be deleted.
// So this is the key point: we end up with a wide spacer head at
// the end of row 1, then the emoji, then a wide spacer tail on row 2.
// We should expect that if we resize to more cols, the wide spacer
// head is replaced with the emoji.
// Similar to the "wide spacer head" test, but this time we'er going
// to increase our columns such that multiple rows are unwrapped.
// This resizes to 3 columns, which isn't enough space for our wide
// char to enter row 1. But we need to mark the wide spacer head on the
// end of the first row since we're wrapping to the next row.
// zig fmt: off
// zig fmt: on
// Cursor should not move
// zig fmt: off
// zig fmt: on
// Cursor should not move
// zig fmt: off
// zig fmt: on
// Cursor is at end of "world" line with semantic_content = .input
// With .last, only the current line where cursor is should be cleared
// Create a 3-line prompt: 1 initial + 2 continuation lines
// zig fmt: off
// zig fmt: on
// Cursor is at end of line3 (the last continuation line)
// With .last, only line3 (where cursor is) should be cleared
// Outside of active area
// try testing.expect(s.selectLine(.{ .x = 13, .y = 0 }) == null);
// try testing.expect(s.selectLine(.{ .x = 0, .y = 5 }) == null);
// Going forward
// Going backward
// Going forward and backward
// Outside active area
// Going forward
// Going forward
// Going backward
// Going forward and backward
// Going forward
// Non-wrapped
// Selecting first line
// Selecting last line
// https://github.com/mitchellh/ghostty/issues/1329
// Selecting output stops at the prompt even if soft-wrapped
// Write prompt followed by user input on same row: "$>command"
// Using non-whitespace to avoid whitespace trimming affecting the test
// Selecting from prompt should only select prompt
// Selecting from input should only select input
// Row 0: user input
// Row 1: command output
// Selecting from input should only select input
// Selecting from output should only select output
// Single row with output then prompt then input: "out$>cmd"
// Using non-whitespace to avoid whitespace trimming affecting the test
// Selecting from output should stop at prompt
// Selecting from prompt should only select prompt
// Selecting from input should only select input
// Row 0: prompt "$ " + input "cmd" (soft-wraps)
// Row 1: input continues "12" + output "out"
// Verify layout
// Selecting from input on row 0 should get all input across soft-wrap
// Selecting from input on row 1 should get all input across soft-wrap
// Selecting from output should only get output
// Write prompt followed by input
// With semantic_prompt_boundary = false, should select entire line
// Row 0: input that soft-wraps
// Row 1: output starts at first cell
// Verify soft-wrap happened
// Selecting from input should stop before output on row 1
// Selecting from output should only get output
// All prompt content that soft-wraps
// Verify soft-wrap
// Should select all prompt content across soft-wraps
// Default boundary codepoints for word selection
// Outside of active area
// try testing.expect(s.selectWord(.{ .x = 9, .y = 0 }) == null);
// try testing.expect(s.selectWord(.{ .x = 0, .y = 5 }) == null);
// Going forward
// Going backward
// Going forward and backward
// Whitespace
// Whitespace single char
// End of screen
// Default boundary codepoints for word selection
// Going forward
// Going backward
// Going forward and backward
// Default boundary codepoints for word selection
// Going forward
// Going backward
// Going forward and backward
// Default boundary codepoints for word selection
// Inside character forward
// Inside character backward
// Inside character bidirectional
// On quote
// NOTE: this behavior is not ideal, so we can change this one day,
// but I think its also not that important compared to the above.
// Build content with cell-level semantic content:
// Row 0-1: output1 (output)
// Row 2: prompt2 (prompt)
// Row 3: input2 (input)
// Row 4-7: output2 (output, with overflow causing wrap)
// Row 8: "$ " (prompt) + "input3" (input)
// Row 9-11: output3 (output)
// First output block (rows 0-1), should select those rows
// Second output block (rows 4-7)
// Third output block (rows 9-11)
// Click on prompt should return null
// Click on input should return null
// No trim
// No trim
// https://github.com/mitchellh/ghostty/issues/289
// Let me describe the situation that caused this because this
// test is not obvious. By writing an emoji below, we introduce
// one cell with the emoji and one cell as a "wide char spacer".
// We then soft wrap the line by writing spaces.
//
// By selecting only the tail, we'd select nothing and we had
// a logic error that would cause a crash.
// Integrity check
// The real test
// Lazy way to seek to the first page boundary.
// Test the line iterator
// Test the line iterator
// try testing.expect(iter.next() == null);
// Use it for the first time
// Reuse the same hyperlink, expect we have the same ID
// This test depends on underlying PageList implementation so
// it may be invalid one day. It's here to document/verify the
// current behavior.
// Start a hyperlink
// Resize. Any column growth will trigger a page to be reallocated.
// Start a hyperlink with a URI that just barely fits in the string alloc.
// This will ensure that additional string alloc space is needed for the
// redundant copy of the URI when the page is re-alloced.
// Figure out how many cells should can have hyperlinks in this page,
// and write twice that number, to guarantee the capacity needs to be
// increased at some point.
// Make sure the capacity really did increase.
// And that our string_bytes increased as well.
// We should have one page and it should be our cursor page
// 5 chars + cursor = 6 refs
// This forces the page to change via increaseCapacity.
// Cursor's page_pin should now point to the new node
// Verify cursor's page_cell and page_row are correctly reloaded from the pin
// Style should be preserved
// After increaseCapacity, the 5 chars are cloned (5 refs) and
// the cursor's style is re-added (1 ref) = 6 total.
// We should have one page and it should be our cursor page
// Cursor has the hyperlink active = 1 count in hyperlink_set
// This forces the page to change via increaseCapacity.
// Hyperlink should be preserved with correct URI
// After increaseCapacity, the hyperlink is re-added to the new page.
// Set both a non-default style AND an active hyperlink.
// Write one character first with bold to mark the row as styled,
// then start the hyperlink and write more characters.
// We should have one page and it should be our cursor page
// 5 chars + cursor = 6 refs for bold style
// Cursor has the hyperlink active = 1 count in hyperlink_set
// This forces the page to change via increaseCapacity.
// Style should be preserved
// Hyperlink should be preserved with correct URI
// After increaseCapacity, both style and hyperlink are re-added to the new page.
// Test that calling increaseCapacity on a page that is NOT the cursor's
// page properly delegates to pages.increaseCapacity without doing the
// extra cursor accounting (style/hyperlink re-adding).
// Set up a custom style and hyperlink on the cursor
// Store cursor state before growing pages
// The cursor is on the first (and only) page
// Grow pages until we have multiple pages. The cursor's pin stays on
// the first page since we're just adding rows.
// Now we have two pages
// Cursor should still be on the first page (where it was created)
// Call increaseCapacity on the second page (NOT the cursor's page)
// The second page should have increased capacity
// The cursor's page (first page) should be unchanged
// Cursor state should be completely unchanged since we didn't touch its page
// Verify hyperlink is still valid
// Regression test for https://github.com/ghostty-org/ghostty/issues/10282
//
// This test exposes a use-after-realloc bug in cursorDown (and similar
// cursor movement functions). The bug pattern:
//
// 1. cursorDown creates a by-value copy of the pin via page_pin.down(n)
// 2. cursorChangePin is called, which may trigger adjustCapacity
//    if the target page's style map is full
// 3. adjustCapacity frees the old page and creates a new one
// 4. The local pin copy still points to the freed page
// 5. rowAndCell() on the stale pin accesses freed memory
// Small screen to make page boundary crossing easy to set up
// Scroll down enough to create a second page
// Cursor should now be on a new page
// Fill new_page's style map to capacity. When we move INTO this page
// with a style set, adjustCapacity will be triggered.
// Move cursor to start of active area and set a style
// Find the row just before the page boundary
// Cursor is at 'row', moving down crosses to new_page
// This cursorDown triggers the bug: the local page_pin copy
// becomes stale after adjustCapacity, causing rowAndCell()
// to access freed memory.
// If the fix is applied, verify correct state
// Didn't find boundary
// Tests that setAttribute succeeds when the style map is full by
// increasing page capacity. When capacity is at max and increaseCapacity
// returns OutOfSpace, manualStyleUpdate will split the page instead.
// Use a small screen with multiple rows
// Write content to multiple rows
// Get the page and fill its style map to capacity
// Fill the style map to capacity using the StyleSet's layout capacity
// which accounts for the load factor
// Now try to set a new unique attribute that would require a new style slot
// This should succeed by increasing capacity (or splitting if at max capacity)
// The style should have been applied (bold flag set)
// The cursor should have a valid non-default style_id
// Either the capacity increased or the page was split/changed
// Write content to multiple rows so we have something to split
// Remember the original node
// Increase the page's style capacity to max by repeatedly calling increaseCapacity
// Use Screen.increaseCapacity to properly maintain cursor state
// Get the page reference after increaseCapacity - cursor may have moved
// Fill the style map to capacity using the StyleSet's layout capacity
// which accounts for the load factor
// Track the node before setAttribute
// Now try to set a new unique attribute that would require a new style slot
// At max capacity, increaseCapacity will return OutOfSpace, triggering page split
// The style should have been applied (bold flag set)
// The cursor should have a valid non-default style_id
// The page should have been split
// This test verifies that if toOwnedSlice fails when building
// the StringMap, we don't leak the already-allocated map.string.
// Get a selection
// Trigger allocation failure on toOwnedSlice
// If this test passes without memory leaks (when run with testing.allocator),
// it means the errdefer properly cleaned up map.string when toOwnedSlice failed.
// Enable line click mode
// Write a prompt and input
// Move cursor back to start of input (column 2, the 'h')
// Click on first 'l' (column 4), should require 2 right movements (h->e->l)
// Enable line click mode
// Write a prompt and input
// Move cursor back to prompt area (column 0, the '>')
// Cursor is on prompt, not input - should return zero
// Enable line click mode
// Write a prompt and input
// Move cursor to column 4
// Click on same position - no movement needed
// Enable line click mode
// Write: "> h" then output "X" then input "llo"
// Move cursor to column 2 (the 'h')
// Click on 'l' at column 5 - should skip the 'X' output cell
// Movement: h (start) -> l (col 4) -> l (col 5) = 2 right movements
// Enable line click mode
// Write a prompt and input that wraps
// Write 8 chars of input, first row has 2 for prompt + 8 input = 10 cols
// Continue on next row (soft-wrapped)
// Verify soft wrap occurred
// Move cursor to column 2 (the 'a')
// Click on 'j' at column 1, row 1 - should count all input cells
// Movement: a->b->c->d->e->f->g->h->i->j = 9 right movements
// Click mode is .none by default (disabled)
// Write a prompt and input
// Move cursor to start of input
// Click should return zero since click mode is disabled
// Enable line click mode
// Write prompt and input on first line
// Hard wrap (newline)
// Move cursor to column 2 (the 'h')
// Click on 'w' at column 0, row 1 - but line mode stops at hard wrap
// Should only move to end of first line: h->e->l->l->o = 4 movements
// Should stop at end of first line, not cross hard wrap
// Enable line click mode
// Row 0: PROMPT "> hello"
// Row 1: CONTINUATION "world"
// Row 2: NEW PROMPT "> again"
// Verify content
// Move cursor to 'w' at column 0, row 1
// Click on 'a' at column 2, row 2 - but row 2 is a new prompt
// Should stop at end of "world": w->o->r->l->d = 4 movements
// Should stop at 'd' (end of world), not cross to new prompt
// Enable line click mode
// Write a prompt and input
// Cursor is at column 7 (after 'o'), move it to column 6 (the 'o')
// Click on 'h' (column 2), should require 4 left movements (o->l->l->e->h)
// Enable line click mode
// Write: "> h" then output "X" then input "llo"
// Move cursor to column 6 (the 'o')
// Click on 'h' at column 2 - should skip the 'X' output cell
// Movement: o->l->l->h = 3 left movements (skipping X)
// Enable line click mode
// Write a prompt and input that wraps
// Write 8 chars of input, first row has 2 for prompt + 8 input = 10 cols
// Continue on next row (soft-wrapped)
// Verify soft wrap occurred
// Cursor is at column 2, row 1 (after 'j'). Move to 'j' at column 1.
// Click on 'a' at column 2, row 0 - should count all input cells backwards
// Movement: j->i->h->g->f->e->d->c->b->a = 9 left movements
// Enable line click mode
// Write prompt and input on first line, then hard wrap
// Hard wrap (newline)
// Move cursor to 'd' at column 4, row 1 (an actual input cell)
// Click on 'h' at column 2, row 0 - but line mode stops at hard wrap
// Should only move to start of second line, not cross to row 0
// Should stop at start of second line: d->l->r->o->w = 4 movements
// Set up: "> hello" where "> " is prompt and "hello" is input
// Clicking to the right of the 'o' should move cursor past the input
// Enable line click mode
// Write a prompt and input
// Move cursor to start of input (column 2, the 'h')
// Click beyond the input (column 15) - should move to one past the 'o'
// Enable line click mode
// Write a prompt and input
// Cursor is already at column 7 (one past 'o') after writing
// Click beyond the input (column 15) - no movement needed since
// cursor is already at the end position
// Enable line click mode
// Write a prompt and input
// Move cursor to start of input (column 2, the 'h')
// Click on a lower line (row 1) - should move to end of input
// This is outside the prompt area so should clamp to end
// From 'h', we need to pass e, l, l, o (4 cells) + 1 past end = 5
// Enable line click mode
// Write a prompt and input
// Cursor is at column 7 after writing (one past 'o')
// Click on a lower line (row 1) - cursor already at end, no movement needed
// Enable line click mode
// Write a prompt and input
// Move cursor to last input char (column 6, the 'o')
// Click beyond the input (column 15)
//
// --- Original Ghostty Comments End: src/terminal/Screen.zig

// Screen represents a single terminal screen with cursor, selection,
// and cell data. Translated from ghostty's Screen.zig.

// ScreenDirty tracks what parts of the screen need redrawing.
pub struct ScreenDirty {
pub mut:
	selection       bool
	hyperlink_hover bool
}

// SemanticPrompt tracks OSC 133 semantic prompt state.
pub struct SemanticPrompt {
pub mut:
	seen  bool
	click SemanticClick
}

pub const semantic_prompt_disabled = SemanticPrompt{
	seen: false
	click: .none
}

pub enum SemanticClick {
	none
	click_events
	cl_line
	cl_multiple
	cl_conservative_vertical
	cl_smart_vertical
}

// Cursor holds the cursor position and associated state.
pub struct Cursor {
pub mut:
	x                          u32
	y                          u32
	cursor_style               CursorStyle = .block
	pending_wrap               bool
	is_protected               bool
	style                      CellStyle
	style_id                   u32
	hyperlink_id               u32
	hyperlink_implicit_id      u32
	hyperlink_state            ?Hyperlink
	semantic_content           SemanticContent = .output
	semantic_content_clear_eol bool
}

// CursorCopyOptions controls which cursor-owned state is migrated when a
// cursor is copied between screens.
pub struct CursorCopyOptions {
pub:
	// Copy the hyperlink from the other cursor. When false, any current
	// hyperlink is cleared and the source hyperlink is not activated.
	hyperlink bool = true
}

// SavedCursor holds saved cursor state for save/restore operations.
pub struct SavedCursor {
pub mut:
	x            u32
	y            u32
	style        CellStyle
	is_protected bool
	pending_wrap bool
	origin       bool
	charset      CharsetState
}

// CharsetState holds the charset mapping state.
pub struct CharsetState {
pub mut:
	charsets     CharsetArray
	gl           CharsetSlot = .g0
	gr           CharsetSlot = .g2
	single_shift ?CharsetSlot
}

// CharsetArray maps charset slots to charset tables.
pub struct CharsetArray {
pub mut:
	g0 Charset = .utf8
	g1 Charset = .utf8
	g2 Charset = .utf8
	g3 Charset = .utf8
}

pub fn (self CharsetArray) get(slot CharsetSlot) Charset {
	return match slot {
		.g0 { self.g0 }
		.g1 { self.g1 }
		.g2 { self.g2 }
		.g3 { self.g3 }
	}
}

pub fn (mut self CharsetArray) set(slot CharsetSlot, charset Charset) {
	match slot {
		.g0 {
			self.g0 = charset
		}
		.g1 {
			self.g1 = charset
		}
		.g2 {
			self.g2 = charset
		}
		.g3 {
			self.g3 = charset
		}
	}
}

// Options for creating a new Screen.
pub struct ScreenOptions {
pub:
	cols           u32 = 80
	rows           u32 = 24
	max_scrollback u32
}

// Scroll controls viewport scrolling behavior.
pub enum Scroll {
	active
	top
	pin_scroll
	row
	delta_row
	delta_prompt
}

// Resize options for resizing the screen.
pub struct ScreenResize {
pub:
	cols          u32
	rows          u32
	reflow        bool = true
	prompt_redraw PromptRedraw = .false_
}

// SelectionString options for converting selection to string.
pub struct SelectionString {
pub:
	sel  Selection
	trim bool = true
	// When non-nil, receives one screen pin for every byte in the returned
	// UTF-8 string. This is used to map regex match offsets back to cells.
	map &StringMap = unsafe { nil }
}

// SelectLine options for selecting a line.
pub struct SelectLine {
pub:
	pin                      Pin
	whitespace               ?[]u32 = [u32(0), u32(` `), u32(`\t`)]
	semantic_prompt_boundary bool = true
}

// LineIterator iterates over soft-wrapped lines.
pub struct LineIterator {
pub mut:
	screen  &Screen = unsafe { nil }
	current ?Pin
}

pub fn (mut self LineIterator) next() ?Selection {
	cur := self.current or { return none }
	result := self.screen.select_line(SelectLine{
		pin: cur
		whitespace: none
		semantic_prompt_boundary: false
	}) or { return none }
	self.current = result.end().down(1)
	return result
}

// PromptClickMove describes cursor movement needed for a click in a prompt.
pub struct PromptClickMove {
pub:
	left  int
	right int
}

pub const prompt_click_move_zero = PromptClickMove{
	left: 0
	right: 0
}

// KittyImagesEvent is sent through Screen's opaque Kitty storage hook. The
// terminal package owns screen lifecycle while the kitty package owns the
// concrete storage type, so this keeps both responsibilities intact without
// introducing an import cycle.
pub enum KittyImagesEvent {
	reset
	deinit
	dirty
	clear
}

pub type KittyImagesLifecycleFn = fn (voidptr, &Screen, KittyImagesEvent)

// ============================================================
// Screen struct
// ============================================================

@[heap]
pub struct Screen {
pub mut:
	pages          Pages
	no_scrollback  bool
	cursor         Cursor
	saved_cursor   ?SavedCursor
	selection      ?Selection
	charset        CharsetState
	protected_mode ProtectedMode = .off
	kitty_keyboard KeyFlagStack
	// Opaque pointer to kitty.ImageStorage. Keeping the storage behind an
	// opaque module boundary avoids a terminal -> kitty -> terminal import
	// cycle while still giving every screen independent persistent state.
	kitty_images           voidptr
	kitty_images_lifecycle KittyImagesLifecycleFn = unsafe { nil }
	semantic_prompt        SemanticPrompt
	dirty                  ScreenDirty
	// Scratch cell/row used only as a safe fallback when a cursor
	// pointer accessor is called with invalid (out-of-bounds) state,
	// which should not happen given the callers' preconditions.
	scratch_cell CellData
	scratch_row  RowData
}

// Initialize a new screen with the given dimensions and scrollback.
pub fn Screen.init(cols u32, rows u32, max_scrollback u32) Screen {
	return Screen{
		pages: Pages.init(cols, rows, max_scrollback)
		no_scrollback: max_scrollback == 0
		cursor: Cursor{
			x: 0
			y: 0
		}
		semantic_prompt: terminal.semantic_prompt_disabled
	}
}

// Clean up screen resources.
pub fn (mut self Screen) deinit() {
	if self.kitty_images != unsafe { nil }
		&& self.kitty_images_lifecycle != unsafe { nil } {
		lifecycle := self.kitty_images_lifecycle
		lifecycle(self.kitty_images, self, KittyImagesEvent.deinit)
	}
	self.pages.deinit()
	self.kitty_images = unsafe { nil }
	self.kitty_images_lifecycle = unsafe { nil }
	self.selection = none
	self.saved_cursor = none
}

// Assert screen state integrity (simplified for V).
pub fn (self &Screen) assert_integrity() {
	assert self.cursor.x < self.pages.cols, 'cursor x ${self.cursor.x} >= cols ${self.pages.cols}'
	assert self.cursor.y < self.pages.rows, 'cursor y ${self.cursor.y} >= rows ${self.pages.rows}'
}

// ============================================================
// Reset
// ============================================================

// Reset the screen: clear content, move cursor to top-left, reset state.
pub fn (mut self Screen) reset() {
	self.pages.reset()
	if self.kitty_images != unsafe { nil }
		&& self.kitty_images_lifecycle != unsafe { nil } {
		lifecycle := self.kitty_images_lifecycle
		lifecycle(self.kitty_images, self, KittyImagesEvent.reset)
	}
	self.cursor = Cursor{
		x: 0
		y: 0
	}
	self.saved_cursor = none
	self.charset = CharsetState{}
	self.kitty_keyboard = KeyFlagStack{}
	self.protected_mode = .off
	self.semantic_prompt = terminal.semantic_prompt_disabled
	self.clear_selection()
}

// Mark Kitty placements dirty after operations such as switching screens.
pub fn (self &Screen) mark_kitty_images_dirty() {
	if self.kitty_images != unsafe { nil }
		&& self.kitty_images_lifecycle != unsafe { nil } {
		lifecycle := self.kitty_images_lifecycle
		lifecycle(self.kitty_images, self, KittyImagesEvent.dirty)
	}
}

// Clear all non-virtual placements and their now-unused images.
pub fn (self &Screen) clear_kitty_images() {
	if self.kitty_images != unsafe { nil }
		&& self.kitty_images_lifecycle != unsafe { nil } {
		lifecycle := self.kitty_images_lifecycle
		lifecycle(self.kitty_images, self, KittyImagesEvent.clear)
	}
}

// ============================================================
// Clone
// ============================================================

// Clone the screen.
//
// This copies the screen dimensions and the cell data for the region
// specified by [top, bot] (inclusive, by row). It does NOT copy Kitty
// images, live hyperlink cursor state, or other data that isn't needed
// for read-only operations.
//
// Ghostty uses PageList.clone with a tracked pin remapper so that the
// cursor and selection pins are relocated into the cloned page list. In
// this port, rows are a flat array so "remapping" is arithmetic: we clone
// the requested absolute row range and shift the cursor/selection y values
// by the top of that range.
pub fn (self &Screen) clone(top PointTag, bot ?PointTag) !Screen {
	// Resolve the absolute row range [top_y, bot_y] we are cloning.
	tl := self.pages.get_top_left(top)
	bot_tag := bot or { top }
	br := self.pages.get_bottom_right(bot_tag) or {
		// Nothing to clone; fall back to top-left row only.
		Pin{ x: self.pages.cols - 1, y: tl.y }
	}
	top_y := int(tl.y)
	bot_y := int(br.y)
	row_count := if bot_y >= top_y { bot_y - top_y + 1 } else { 0 }

	mut new_screen := Screen.init(self.pages.cols, self.pages.rows, self.pages.max_scrollback)
	new_screen.no_scrollback = self.no_scrollback
	new_screen.dirty = self.dirty

	// Build the cloned row array. The viewport is always set to the active
	// area of the new screen (the bottom "rows" rows). If the clone region
	// is smaller than a viewport area, blanks are filled in at the bottom.
	mut cloned := []RowData{cap: row_count}
	for i in 0 .. row_count {
		src_idx := top_y + i
		if src_idx < 0 || src_idx >= self.pages.screen_rows.len {
			cloned << RowData.init(self.pages.cols)
			continue
		}
		src := self.pages.screen_rows[src_idx]
		mut dst := RowData.init(self.pages.cols)
		limit := if src.cells.len < dst.cells.len { src.cells.len } else { dst.cells.len }
		for x in 0 .. limit {
			mut cell := src.cells[x]
			cell.graphemes = src.cells[x].graphemes.clone()
			if src.cells[x].has_hyperlink {
				cell.hyperlink = src.cells[x].hyperlink.dupe()
			}
			dst.cells[x] = cell
		}
		dst.wrap = src.wrap
		dst.wrap_continuation = src.wrap_continuation
		dst.styled = src.styled
		dst.grapheme = src.grapheme
		dst.hyperlink = src.hyperlink
		dst.dirty = src.dirty
		dst.semantic_prompt = src.semantic_prompt
		dst.kitty_virtual_placeholder = src.kitty_virtual_placeholder
		cloned << dst
	}

	// Ensure we have at least a full active area; pad blanks at the bottom.
	for cloned.len < int(self.pages.rows) {
		cloned << RowData.init(self.pages.cols)
	}

	new_screen.pages.screen_rows = cloned
	// The active area is the bottom "rows" rows of the cloned region.
	new_screen.pages.active_start = cloned.len - int(self.pages.rows)
	if new_screen.pages.active_start < 0 {
		new_screen.pages.active_start = 0
	}

	// Remap our cursor. If the cursor isn't in the cloned area, move it to
	// the top-left arbitrarily because a screen must have SOME cursor.
	cursor_abs := self.pages.active_start + int(self.cursor.y)
	new_screen.cursor = Cursor{
		x: self.cursor.x
		y: 0
	}
	if cursor_abs >= top_y && cursor_abs <= bot_y {
		new_active := cursor_abs - new_screen_top(top_y, cloned.len, int(self.pages.rows))
		if new_active >= 0 && new_active < int(new_screen.pages.rows) {
			new_screen.cursor.y = u32(new_active)
		} else {
			new_screen.cursor.x = 0
			new_screen.cursor.y = 0
		}
	} else {
		new_screen.cursor.x = 0
		new_screen.cursor.y = 0
	}
	if new_screen.cursor.x >= new_screen.pages.cols {
		new_screen.cursor.x = 0
	}

	// Preserve our selection if we have one and it intersects the clone.
	if sel := self.selection {
		// Ghostty orders the tracked selection vertically before remapping it.
		// Mirrored rectangle selections keep their horizontal orientation.
		ordered := match sel.order(self) {
			.forward, .mirrored_forward { sel }
			.reverse, .mirrored_reverse {
				Selection.init(sel.end_pin, sel.start_pin, sel.rectangle)
			}
		}
		start_y := int(ordered.start_pin.y)
		end_y := int(ordered.end_pin.y)
		if end_y < top_y || start_y > bot_y {
			new_screen.selection = none
		} else {
			start_pin := if start_y < top_y {
				Pin{
					x: if ordered.rectangle { ordered.start_pin.x } else { 0 }
					y: 0
				}
			} else {
				Pin{
					x: ordered.start_pin.x
					y: u32(start_y - top_y)
				}
			}
			end_pin := if end_y > bot_y {
				Pin{
					x: if ordered.rectangle {
						ordered.end_pin.x
					} else {
						self.pages.cols - 1
					}
					y: u32(bot_y - top_y)
				}
			} else {
				Pin{
					x: ordered.end_pin.x
					y: u32(end_y - top_y)
				}
			}
			new_screen.selection = Selection.init(start_pin, end_pin, ordered.rectangle)
		}
	}

	return new_screen
}

// Helper: the absolute row index that becomes row 0 of the cloned screen's
// active area, used to remap the cursor. The cloned region starts at
// clone_top and has clone_len rows; the active area is the last `rows` rows.
fn new_screen_top(clone_top int, clone_len int, rows int) int {
	active_offset := if clone_len > rows { clone_len - rows } else { 0 }
	return clone_top + active_offset
}

// ============================================================
// Cursor movement
// ============================================================

// Returns the cell n positions to the right of the cursor.
pub fn (mut self Screen) cursor_cell_right(n u32) &CellData {
	assert self.cursor.x + n < self.pages.cols
	row_idx := self.pages.active_start + int(self.cursor.y)
	return unsafe { &self.pages.screen_rows[row_idx].cells[int(self.cursor.x + n)] }
}

// Returns the cell n positions to the left of the cursor.
pub fn (mut self Screen) cursor_cell_left(n u32) &CellData {
	assert self.cursor.x >= n
	row_idx := self.pages.active_start + int(self.cursor.y)
	return unsafe { &self.pages.screen_rows[row_idx].cells[int(self.cursor.x - n)] }
}

// Move the cursor right by n positions.
pub fn (mut self Screen) cursor_right(n u32) {
	assert self.cursor.x + n < self.pages.cols
	self.cursor.x += n
}

// Move the cursor left by n positions.
pub fn (mut self Screen) cursor_left(n u32) {
	assert self.cursor.x >= n
	self.cursor.x -= n
}

// Move the cursor up by n rows.
pub fn (mut self Screen) cursor_up(n u32) {
	assert self.cursor.y >= n
	self.cursor.y -= n
	self.cursor_mark_dirty()
}

// Move the cursor down by n rows.
pub fn (mut self Screen) cursor_down(n u32) {
	assert self.cursor.y + n < self.pages.rows
	self.cursor.y += n
	self.cursor_mark_dirty()
}

// Move the cursor to the given absolute column.
pub fn (mut self Screen) cursor_horizontal_absolute(x u32) {
	assert x < self.pages.cols
	self.cursor.x = x
}

// Move the cursor to the given absolute position.
pub fn (mut self Screen) cursor_absolute(x u32, y u32) {
	assert x < self.pages.cols
	assert y < self.pages.rows
	if self.cursor.x != x || self.cursor.y != y {
		self.cursor_mark_dirty()
	}
	self.cursor.x = x
	self.cursor.y = y
	self.cursor_mark_dirty()
}

// Reloads the cursor pointer information into the screen. This is expensive
// so it should only be done in cases where the pointers are invalidated in
// such a way that its difficult to recover otherwise.
//
// In Ghostty, the tracked pin is always accurate, so the active point is
// derived from the pin (falling back to the top-left if the pin is outside
// the active area) and the page row/cell pointers are refreshed. In this
// port the cursor x/y ARE the source of truth (there are no separate cached
// pointers), so we clamp them to the active area (top-left on overflow) and
// then re-ensure our style is consistent, mirroring the tail of cursorReload.
pub fn (mut self Screen) cursor_reload() {
	// Our x/y should always be within the active area. If they are not,
	// reset the cursor to the top-left (this mirrors the pin fallback).
	if self.cursor.x >= self.pages.cols || self.cursor.y >= self.pages.rows {
		self.cursor.x = 0
		self.cursor.y = 0
	}

	// If we have a style, we need to ensure it is consistent because this
	// method may also be called after a page change. This should never
	// fail because manual_style_update handles everything; if it does, we
	// degrade gracefully back to the default style.
	self.manual_style_update() or {
		self.cursor.style = CellStyle{}
		self.cursor.style_id = default_style_id
	}
}

// Mark the cursor row as dirty for rendering.
pub fn (mut self Screen) cursor_mark_dirty() {
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			row.dirty = true
		}
	}
}

// Returns the last cell of the row directly above the cursor row.
//
// Precondition: The cursor is not at the top of the screen.
pub fn (mut self Screen) cursor_cell_end_of_prev() &CellData {
	assert self.cursor.y > 0
	prev_idx := self.pages.active_start + int(self.cursor.y) - 1
	last := int(self.pages.cols) - 1
	if prev_idx >= 0 && prev_idx < self.pages.screen_rows.len
		&& last >= 0 && last < self.pages.screen_rows[prev_idx].cells.len {
		return unsafe { &self.pages.screen_rows[prev_idx].cells[last] }
	}
	// Fall back to a scratch cell to avoid a null deref. Callers only
	// reach here on malformed state.
	self.scratch_cell = CellData{}
	return unsafe { &self.scratch_cell }
}

// Returns the row n rows above the cursor row.
//
// Precondition: cursor.y >= n
pub fn (mut self Screen) cursor_row_up(n u32) &RowData {
	assert self.cursor.y >= n
	idx := self.pages.active_start + int(self.cursor.y) - int(n)
	if idx >= 0 && idx < self.pages.screen_rows.len {
		return unsafe { &self.pages.screen_rows[idx] }
	}
	self.scratch_row = RowData.init(self.pages.cols)
	return unsafe { &self.scratch_row }
}

// Copy another cursor's state into this screen. The cursor can be on any
// screen but the x/y must be within our screen bounds.
pub fn (mut self Screen) cursor_copy(other Cursor, opts CursorCopyOptions) ! {
	assert other.x < self.pages.cols
	assert other.y < self.pages.rows

	// End any currently active hyperlink on our cursor.
	self.end_hyperlink()

	old := self.cursor
	self.cursor = other

	// Keep our old style ID so it can be properly cleaned up below.
	self.cursor.style_id = old.style_id

	// Hyperlinks are managed separately (and cleared here).
	self.cursor.hyperlink_id = 0
	self.cursor.hyperlink_state = none

	// Keep our old X/Y because the new position navigated to by
	// cursor_absolute needs to be in our own screen.
	self.cursor.x = old.x
	self.cursor.y = old.y

	// Call manual style update in order to clean up our old style, if we
	// have one, and also to load the style from the other cursor.
	self.manual_style_update()!

	// Move to the correct location to match the other cursor.
	self.cursor_absolute(other.x, other.y)

	// If the other cursor had a hyperlink, add it to ours. Ghostty resolves
	// the source page-table entry here; the flat Pages model already keeps the
	// resolved hyperlink on the cursor. Explicit IDs are preserved, while an
	// implicit link intentionally receives a fresh destination-screen ID.
	if opts.hyperlink && other.hyperlink_id != 0 {
		if link := other.hyperlink_state {
			id_ := match link.id {
				HyperlinkExplicitId { ?string(link.id.value) }
				HyperlinkImplicitId { ?string(none) }
			}
			self.start_hyperlink(link.uri, id_)!
		}
	}
}

// Reset the wrap state of the cursor row.
pub fn (mut self Screen) cursor_reset_wrap() {
	self.cursor.pending_wrap = false
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			row.wrap = false
		}
		// Also reset next row's wrap_continuation
		next_idx := idx + 1
		if next_idx < self.pages.screen_rows.len {
			unsafe {
				mut next_row := &self.pages.screen_rows[next_idx]
				next_row.wrap_continuation = false
			}
		}
	}
}

// ============================================================
// Scrolling
// ============================================================

// Scroll the viewport.
pub fn (mut self Screen) scroll(behavior Scroll) {
	self.mark_kitty_images_dirty()
	match behavior {
		.active { self.pages.scroll(.active) }
		.top { self.pages.scroll(.top) }
		.pin_scroll, .row, .delta_row, .delta_prompt {}
	}
}

pub fn (mut self Screen) scroll_delta_rows(delta int) {
	self.mark_kitty_images_dirty()
	self.pages.scroll_delta(delta)
}

pub fn (mut self Screen) scroll_to_row(row usize) {
	self.mark_kitty_images_dirty()
	self.pages.viewport_start = clamp_int(int(row), 0, self.pages.active_start)
	self.pages.viewport = if self.pages.viewport_start == 0 {
		.top
	} else if self.pages.viewport_start == self.pages.active_start {
		.active
	} else {
		.pinned
	}
}

pub fn (mut self Screen) scroll_delta_prompts(delta int) {
	if delta == 0 {
		return
	}
	self.mark_kitty_images_dirty()
	mut remaining := if delta < 0 { -delta } else { delta }
	current := match self.pages.viewport {
		.active { self.pages.active_start }
		.top { 0 }
		.pinned { self.pages.viewport_start }
	}
	mut y := current + if delta > 0 { 1 } else { -1 }
	for y >= 0 && y < self.pages.screen_rows.len {
		if self.pages.screen_rows[y].semantic_prompt == .prompt {
			remaining -= 1
			if remaining == 0 {
				self.scroll_to_row(usize(y))
				return
			}
		}
		y += if delta > 0 { 1 } else { -1 }
	}
}

// Scroll and clear the screen, moving content to scrollback.
pub fn (mut self Screen) scroll_clear() ! {
	self.mark_kitty_images_dirty()
	self.pages.scroll_clear()!
	self.cursor_reload()
}

// Scroll down when cursor is at the bottom of the screen.
pub fn (mut self Screen) cursor_down_scroll() ! {
	assert self.cursor.y == self.pages.rows - 1
	self.mark_kitty_images_dirty()

	if self.no_scrollback {
		if self.pages.rows == 1 {
			// Single-row: just clear the row
			self.clear_active_row(0)
			self.cursor_mark_dirty()
		} else {
			// Shift everything up: remove first active row, add blank at bottom
			self.pages.erase_row(PinOpts{ tag: .active, x: 0, y: 0 })!
			// The newly-vacated bottom row must preserve the current bg SGR,
			// matching Ghostty's cursorDownScroll which memsets the new row
			// with blankCell() when a background color is active.
			self.fill_active_row_blank(self.pages.rows - 1)
		}
	} else {
		// With scrollback: grow by one row, moving old top row to scrollback
		self.pages.grow() or {}
		self.pages.active_start += 1
		if self.pages.viewport == .active {
			self.pages.viewport_start = self.pages.active_start
		}
		// Ensure we have a row at the new bottom
		active_end := self.pages.active_start + int(self.pages.rows)
		for self.pages.screen_rows.len < active_end {
			self.pages.screen_rows << RowData.init(self.pages.cols)
		}
		// Clear the new bottom row
		self.clear_active_row(self.pages.rows - 1)
		self.cursor_mark_dirty()
	}
}

// Scroll the active area at and above the cursor. The lines below the cursor
// are not scrolled. This is a translation of Ghostty's Screen.cursorScrollAbove.
//
// The net effect: everything at and above the cursor row scrolls up (the
// top-most active row moves into scrollback), a blank line appears at the
// cursor row, and the rows below the cursor shift down by one.
pub fn (mut self Screen) cursor_scroll_above() ! {
	self.mark_kitty_images_dirty()
	// We unconditionally mark the cursor row as dirty here because the cursor
	// always changes rows inside this function.
	self.cursor_mark_dirty()

	// If the cursor is on the bottom of the screen, it's faster to use our
	// specialized function for that case.
	if self.cursor.y == self.pages.rows - 1 {
		return self.cursor_down_scroll()
	}

	if self.no_scrollback {
		// Without scrollback we can't push a row into history, so we drop the
		// top-most active row and rotate a fresh blank row in at the cursor.
		// This shifts everything above the cursor up by one and everything
		// at/below the cursor down by one relative to the moved window.
		if self.pages.active_start < self.pages.screen_rows.len {
			self.pages.screen_rows.delete(self.pages.active_start)
		}
		// A new active window starts one row earlier now; append a blank row
		// at the bottom so the window keeps its size.
		self.pages.screen_rows << RowData.init(self.pages.cols)
	} else {
		// With scrollback: grow by one row (moving the old top active row into
		// scrollback) and slide the active window down by one.
		self.pages.grow() or {}
		self.pages.active_start += 1
		if self.pages.viewport == .active {
			self.pages.viewport_start = self.pages.active_start
		}
		active_end := self.pages.active_start + int(self.pages.rows)
		for self.pages.screen_rows.len < active_end {
			self.pages.screen_rows << RowData.init(self.pages.cols)
		}
	}

	self.cursor_scroll_above_rotate()
}

// Rotate all rows below the cursor down by one and clear the cursor row.
// This is the flat-storage translation of Ghostty's
// Screen.cursorScrollAboveRotate; page-boundary copies collapse into one
// contiguous rotation because Pages stores the same logical rows in one slice.
fn (mut self Screen) cursor_scroll_above_rotate() {
	new_cursor_abs := self.pages.active_start + int(self.cursor.y)
	new_active_end := self.pages.active_start + int(self.pages.rows)
	if new_cursor_abs < new_active_end && new_active_end <= self.pages.screen_rows.len {
		last := self.pages.screen_rows[new_active_end - 1]
		for i := new_active_end - 1; i > new_cursor_abs; i-- {
			self.pages.screen_rows[i] = self.pages.screen_rows[i - 1]
		}
		self.pages.screen_rows[new_cursor_abs] = last
	}

	// The newly created line at the cursor must be blank and preserve the
	// current bg SGR, matching Ghostty's memset of the new row with blankCell().
	if new_cursor_abs < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[new_cursor_abs]
			blank := self.blank_cell()
			for i in 0 .. row.cells.len {
				row.cells[i] = blank
			}
			row.wrap = false
			row.wrap_continuation = false
			row.styled = self.cursor.style_id != default_style_id
			row.grapheme = false
			row.hyperlink = false
		}
	}

	// Mark the affected rows dirty.
	for i in new_cursor_abs .. new_active_end {
		if i < self.pages.screen_rows.len {
			unsafe {
				mut row := &self.pages.screen_rows[i]
				row.dirty = true
			}
		}
	}
}

// Fill an active-area row entirely with the current cursor's blank cell.
// This preserves the active background SGR when new rows are exposed by
// scrolling, mirroring Ghostty's @memset(cells, blankCell()).
fn (mut self Screen) fill_active_row_blank(y u32) {
	if self.cursor.style_id == default_style_id {
		return
	}
	idx := self.pages.active_start + int(y)
	if idx >= self.pages.screen_rows.len {
		return
	}
	blank := self.blank_cell()
	unsafe {
		mut row := &self.pages.screen_rows[idx]
		for i in 0 .. row.cells.len {
			row.cells[i] = blank
		}
		row.dirty = true
	}
}

// Move cursor down or scroll if at the bottom.
fn (mut self Screen) cursor_down_or_scroll() ! {
	if self.cursor.y + 1 < self.pages.rows {
		self.cursor_down(1)
	} else {
		self.cursor_down_scroll()!
	}
}

// Returns true if the viewport is at the bottom.
pub fn (self &Screen) viewport_is_bottom() bool {
	return self.pages.viewport == .active
}

// ============================================================
// Row/Cell management
// ============================================================

// Clear a row in the active area, filling with blank cells. The blank cell
// carries the current cursor background SGR so newly-vacated rows preserve
// the active background color, matching Ghostty's use of clearCells/blankCell.
fn (mut self Screen) clear_active_row(y u32) {
	idx := self.pages.active_start + int(y)
	if idx < self.pages.screen_rows.len {
		blank := self.blank_cell()
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			for i in 0 .. int(self.pages.cols) {
				if i < row.cells.len {
					row.cells[i] = blank
				}
			}
			row.dirty = true
			row.styled = false
			row.grapheme = false
			row.hyperlink = false
		}
	}
}

// Erase rows physically (reclaim memory).
pub fn (mut self Screen) erase_rows(tl Point, bl ?Point) {
	self.pages.erase_rows(tl, bl)
	self.cursor_reload()
}

// Clear rows (set to blank, preserving the row slots).
pub fn (mut self Screen) clear_rows(tl Point, bl ?Point, protected bool) {
	tl_pin := self.pages.pin_point(tl) or { return }
	bl_pin := if point := bl {
		self.pages.pin_point(point) or { return }
	} else {
		self.pages.get_bottom_right(tl.tag) or { return }
	}
	if tl_pin.y > bl_pin.y {
		return
	}

	blank := self.blank_cell()
	for y in int(tl_pin.y) .. int(bl_pin.y) + 1 {
		if y < self.pages.screen_rows.len {
			unsafe {
				mut row := &self.pages.screen_rows[y]
				if protected {
					// Only clear unprotected cells
					for mut cell in row.cells {
						if !cell.is_protected {
							cell = blank
						}
					}
				} else {
					for i in 0 .. row.cells.len {
						row.cells[i] = blank
					}
					row.wrap = false
					row.wrap_continuation = false
					row.styled = false
					row.grapheme = false
					row.hyperlink = false
					row.semantic_prompt = .unknown
					row.kitty_virtual_placeholder = false
				}
				row.dirty = true
			}
		}
	}
}

// Clear specific cells in a row.
pub fn (mut self Screen) clear_cells(row_idx int, start int, end int) {
	if row_idx >= self.pages.screen_rows.len {
		return
	}
	// Cleared cells are filled with the current cursor's blank cell so that
	// erasing while a background SGR is active preserves that background,
	// matching Ghostty's Screen.clearCells which @memsets with blankCell().
	blank := self.blank_cell()
	unsafe {
		mut row := &self.pages.screen_rows[row_idx]
		for i in start .. end {
			if i < row.cells.len {
				row.cells[i] = blank
			}
		}
		row.dirty = true
	}
}

// Clear cells in a row but only if they are not protected. This works by
// finding contiguous runs of unprotected cells within [start, end) and
// clearing each run, matching Ghostty's clearUnprotectedCells.
pub fn (mut self Screen) clear_unprotected_cells(row_idx int, start int, end int) {
	if row_idx < 0 || row_idx >= self.pages.screen_rows.len {
		return
	}
	cells_len := self.pages.screen_rows[row_idx].cells.len
	hi := if end < cells_len { end } else { cells_len }
	mut x0 := if start < 0 { 0 } else { start }
	for x0 < hi {
		// Skip protected cells.
		for x0 < hi && self.pages.screen_rows[row_idx].cells[x0].is_protected {
			x0++
		}
		if x0 >= hi {
			break
		}
		// Find the end of this unprotected run.
		mut x1 := x0 + 1
		for x1 < hi && !self.pages.screen_rows[row_idx].cells[x1].is_protected {
			x1++
		}
		self.clear_cells(row_idx, x0, x1)
		x0 = x1
	}
}

// Returns a blank cell with the current cursor background color.
pub fn (self &Screen) blank_cell() CellData {
	if self.cursor.style_id == default_style_id {
		return CellData{}
	}
	return self.cursor.style.bg_cell() or { CellData{} }
}

// ============================================================
// Resize
// ============================================================

// Resize the screen. The rows or cols can be bigger or smaller.
//
// The soft-wrap reflow of cell content itself is delegated to Pages.resize.
// The surrounding logic translated here from Ghostty's Screen.resize:
//   - release/restore the cursor style around the resize (in case the cursor
//     ends up "on a different page")
//   - track the saved cursor position so we can remap it after resize
//   - clear prompt/input lines when prompt_redraw is requested
//   - reload the cursor and fix up the saved cursor's pending wrap
pub fn (mut self Screen) resize(opts ScreenResize) ! {
	self.mark_kitty_images_dirty()
	mut cursor_pin := Pin{
		x: self.cursor.x
		y: u32(self.pages.active_start) + self.cursor.y
	}
	mut tracked_pins := []&Pin{cap: 4}
	tracked_pins << &cursor_pin
	// Release the cursor style while resizing just in case the cursor ends
	// up on a different page. We restore it at the end.
	cursor_style := self.cursor.style
	self.cursor.style = CellStyle{}
	self.manual_style_update() or {}

	// The saved cursor and selection are permanently tracked PageList pins in
	// Ghostty. Build their flat absolute-pin equivalents so every resize
	// operation can update them together.
	mut has_saved_pin := false
	mut saved_pin := Pin{}
	if sc := self.saved_cursor {
		if sc.x < self.pages.cols && sc.y < self.pages.rows {
			has_saved_pin = true
			saved_pin = Pin{
				x: sc.x
				y: u32(self.pages.active_start) + sc.y
			}
			tracked_pins << &saved_pin
		}
	}
	mut has_selection_pins := false
	mut selection_start_pin := Pin{}
	mut selection_end_pin := Pin{}
	if sel := self.selection {
		has_selection_pins = true
		selection_start_pin = sel.start_pin
		selection_end_pin = sel.end_pin
		tracked_pins << &selection_start_pin
		tracked_pins << &selection_end_pin
	}

	// If our cursor is on a prompt or input line, clear it so the shell can
	// redraw it. This works with OSC 133 semantic prompts. We check
	// cursor.semantic_content rather than the row's semantic_prompt because
	// some shells mark input areas but don't mark continuation lines.
	if opts.prompt_redraw != .false_ && self.cursor.semantic_content != .output {
		cur_idx := self.pages.active_start + int(self.cursor.y)
		match opts.prompt_redraw {
			.false_ {}
			.last {
				// Only clear the current line where the cursor is.
				self.clear_cells(cur_idx, 0, int(self.pages.cols))
			}
			.true_ {
				mut prompt_it := self.pages.prompt_iterator(Pin{
					x: self.cursor.x
					y: u32(cur_idx)
				}, .left_up, none)
				if start := prompt_it.next() {
					for y := int(start.y); y <= cur_idx; y++ {
						if y >= 0 && y < self.pages.screen_rows.len {
							self.clear_cells(y, 0, int(self.pages.cols))
						}
					}
				}
			}
		}
	}

	// Perform the resize operation (handles reflow in Pages.resize).
	self.pages.resize(ResizeOpts{
		cols: opts.cols
		rows: opts.rows
		reflow: opts.reflow
		cursor: struct {
			x: self.cursor.x
			y: self.cursor.y
		}
		tracked_pins: tracked_pins
	})!

	// If we have no scrollback and we shrunk our rows, we must explicitly
	// erase our history. PageList always keeps at least a page of history.
	if self.no_scrollback {
		erased := self.pages.active_start
		self.pages.erase_rows(Point.new(.history, Coordinate{}), ?Point(none))
		// eraseRows updates all PageList tracked pins. Mirror its behavior:
		// surviving pins shift up, while pins in erased history move to the
		// first remaining cell.
		if erased > 0 {
			for mut pin in tracked_pins {
				if int(pin.y) >= erased {
					pin.y -= u32(erased)
				} else {
					pin.x = 0
					pin.y = 0
				}
			}
		}
	}

	// Reload the live cursor from its tracked pin. If it moved outside the
	// active area, PageList's pointFromPin fallback places it at top-left.
	cursor_y := int(cursor_pin.y) - self.pages.active_start
	if cursor_y >= 0 && cursor_y < int(self.pages.rows) {
		self.cursor.x = cursor_pin.x
		self.cursor.y = u32(cursor_y)
	} else {
		self.cursor.x = 0
		self.cursor.y = 0
	}
	if self.pages.reflow_did_reflow {
		self.cursor.pending_wrap = false
	}

	// If our cursor was updated, we do a full reload so all our cursor
	// state is correct.
	self.cursor_reload()

	// Update the saved cursor from its tracked pin.
	if has_saved_pin {
		if mut sc := self.saved_cursor {
			new_active := int(saved_pin.y) - self.pages.active_start
			if new_active >= 0 && new_active < int(self.pages.rows) {
				sc.x = saved_pin.x
				sc.y = u32(new_active)
				// If we had pending wrap set and we're no longer at the end
				// of the line, we unset the pending wrap and move the cursor
				// to reflect the correct next position.
				if sc.pending_wrap && sc.x != opts.cols - 1 {
					sc.pending_wrap = false
					sc.x += 1
				}
			} else {
				// The saved cursor moved outside the active area. There's no
				// reasonable thing to do so we move it to the top-left.
				sc.x = 0
				sc.y = 0
				sc.pending_wrap = false
			}
			self.saved_cursor = sc
		}
	}

	// Selection endpoints are tracked screen pins, so retain their original
	// orientation while replacing both endpoints with their remapped values.
	if has_selection_pins {
		if mut sel := self.selection {
			sel.start_pin = selection_start_pin
			sel.end_pin = selection_end_pin
			self.selection = sel
		}
	}

	// Restore the cursor style. This should not fail; degrade gracefully.
	self.cursor.style = cursor_style
	self.manual_style_update() or {
		self.cursor.style = CellStyle{}
		self.cursor.style_id = default_style_id
	}
}

// ============================================================
// Style management (SGR attributes)
// ============================================================

// Set a style attribute on the current cursor.
pub fn (mut self Screen) set_attribute(attr SgrAttribute) ! {
	match attr.kind {
		.unset {
			self.cursor.style = CellStyle{}
		}
		.bold {
			self.cursor.style.flags.bold = true
		}
		.reset_bold {
			self.cursor.style.flags.bold = false
			self.cursor.style.flags.faint = false
		}
		.italic {
			self.cursor.style.flags.italic = true
		}
		.reset_italic {
			self.cursor.style.flags.italic = false
		}
		.faint {
			self.cursor.style.flags.faint = true
		}
		.underline_set {
			self.cursor.style.flags.underline = attr.underline
		}
		.overline {
			self.cursor.style.flags.overline = true
		}
		.reset_overline {
			self.cursor.style.flags.overline = false
		}
		.blink {
			self.cursor.style.flags.blink = true
		}
		.reset_blink {
			self.cursor.style.flags.blink = false
		}
		.inverse {
			self.cursor.style.flags.inverse = true
		}
		.reset_inverse {
			self.cursor.style.flags.inverse = false
		}
		.invisible {
			self.cursor.style.flags.invisible = true
		}
		.reset_invisible {
			self.cursor.style.flags.invisible = false
		}
		.strikethrough {
			self.cursor.style.flags.strikethrough = true
		}
		.reset_strikethrough {
			self.cursor.style.flags.strikethrough = false
		}
		.direct_color_fg {
			self.cursor.style.fg_color = .rgb
			self.cursor.style.fg_r = attr.r
			self.cursor.style.fg_g = attr.g
			self.cursor.style.fg_b = attr.b
		}
		.direct_color_bg {
			self.cursor.style.bg_color = .rgb
			self.cursor.style.bg_r = attr.r
			self.cursor.style.bg_g = attr.g
			self.cursor.style.bg_b = attr.b
		}
		.fg_8, .fg_256 {
			self.cursor.style.fg_color = .palette
			self.cursor.style.fg_palette = attr.index
		}
		.bright_fg_8 {
			self.cursor.style.fg_color = .palette
			self.cursor.style.fg_palette = attr.index + 8
		}
		.bg_8, .bg_256 {
			self.cursor.style.bg_color = .palette
			self.cursor.style.bg_palette = attr.index
		}
		.bright_bg_8 {
			self.cursor.style.bg_color = .palette
			self.cursor.style.bg_palette = attr.index + 8
		}
		.reset_fg {
			self.cursor.style.fg_color = .none
		}
		.reset_bg {
			self.cursor.style.bg_color = .none
		}
		.underline_color {
			self.cursor.style.underline_color = .rgb
			self.cursor.style.underline_r = attr.r
			self.cursor.style.underline_g = attr.g
			self.cursor.style.underline_b = attr.b
		}
		.underline_color_256 {
			self.cursor.style.underline_color = .palette
			self.cursor.style.underline_palette = attr.index
		}
		.reset_underline_color {
			self.cursor.style.underline_color = .none
		}
		.unknown {
			return
		}
	}
	self.manual_style_update()!
}

// Call this whenever you manually change the cursor style.
//
// This function can NOT fail if the cursor style is changing to the default
// style.
//
// In Ghostty this maps the cursor's concrete style value to a page-local
// ref-counted style ID (Page.styles.add), splitting/growing the page as
// needed. In this port, the concrete style is stored inline on each cell
// (CellData.style), so style_id is only used as a "has non-default style"
// discriminator: default_style_id for the default style, and a non-default
// (non-zero) ID otherwise. We still clear the ID first so that print writes
// the correct discriminator regardless of intermediate state.
pub fn (mut self Screen) manual_style_update() ! {
	// Clear the cursor style ID to prevent weird things from happening.
	// This also ensures that if the style is default we fall back to
	// clearing our style.
	self.cursor.style_id = default_style_id

	// If our new style is the default, just reset to that.
	if self.cursor.style.default() {
		return
	}

	// After setting the style, we update our style discriminator.
	self.cursor.style_id = 1
}

// ============================================================
// Hyperlink management
// ============================================================

fn (mut self Screen) start_hyperlink_once(source Hyperlink) ! {
	// End any prior hyperlink before installing the duplicated pending state.
	self.end_hyperlink()
	link := source.dupe()
	self.cursor.hyperlink_state = link
	// Flat Pages does not yet expose Page's ref-counted ID. Preserve the same
	// nonzero active-state invariant while retaining the exact hyperlink value.
	self.cursor.hyperlink_id = match link.id {
		HyperlinkImplicitId { link.id.offset + 1 }
		HyperlinkExplicitId { self.cursor.hyperlink_implicit_id + 1 }
	}
}

// Start a hyperlink on the cursor.
pub fn (mut self Screen) start_hyperlink(uri string, id_ ?string) ! {
	link_id := if explicit := id_ {
		HyperlinkIdKind(HyperlinkExplicitId{
			value: explicit.clone()
		})
	} else {
		offset := self.cursor.hyperlink_implicit_id
		self.cursor.hyperlink_implicit_id += 1
		HyperlinkIdKind(HyperlinkImplicitId{
			offset: offset
		})
	}
	self.start_hyperlink_once(Hyperlink{
		id: link_id
		uri: uri.clone()
	}) or {
		if id_ == none {
			self.cursor.hyperlink_implicit_id -= 1
		}
		return err
	}
}

// End the current hyperlink.
pub fn (mut self Screen) end_hyperlink() {
	if self.cursor.hyperlink_id == 0 {
		assert self.cursor.hyperlink_state == none
		return
	}
	self.cursor.hyperlink_id = 0
	self.cursor.hyperlink_state = none
}

// Set the hyperlink on the current cell.
pub fn (mut self Screen) cursor_set_hyperlink() ! {
	assert self.cursor.hyperlink_id != 0
	link := self.cursor.hyperlink_state or { return error('active hyperlink has no value') }
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if int(self.cursor.x) < row.cells.len {
				row.cells[int(self.cursor.x)].has_hyperlink = true
				row.cells[int(self.cursor.x)].hyperlink = link.dupe()
			}
			row.hyperlink = true
		}
	}
}

// ============================================================
// Semantic content
// ============================================================

pub enum SemanticInputClear {
	clear_explicit
	clear_eol
}

pub struct CursorSemanticPrompt {
pub:
	kind PromptKind
}

pub struct CursorSemanticOutput {}

pub struct CursorSemanticInput {
pub:
	clear SemanticInputClear
}

pub type CursorSemanticContent = CursorSemanticInput | CursorSemanticOutput | CursorSemanticPrompt

// Set the semantic content type of the cursor.
pub fn (mut self Screen) cursor_set_semantic_content(value CursorSemanticContent) {
	match value {
		CursorSemanticOutput {
			self.cursor.semantic_content = .output
			self.cursor.semantic_content_clear_eol = false
		}
		CursorSemanticInput {
			self.cursor.semantic_content = .input
			self.cursor.semantic_content_clear_eol = value.clear == .clear_eol
		}
		CursorSemanticPrompt {
			self.semantic_prompt.seen = true
			self.cursor.semantic_content = .prompt
			self.cursor.semantic_content_clear_eol = false
			idx := self.pages.active_start + int(self.cursor.y)
			if idx < self.pages.screen_rows.len {
				unsafe {
					mut row := &self.pages.screen_rows[idx]
					row.semantic_prompt = match value.kind {
						.initial, .right { SemanticPromptType.prompt }
						.continuation, .secondary { SemanticPromptType.prompt_continuation }
					}
				}
			}
		}
	}
}

pub fn (mut self Screen) cursor_set_semantic_content_prompt(kind PromptKind) {
	self.cursor_set_semantic_content(CursorSemanticPrompt{ kind: kind })
}

pub fn (mut self Screen) cursor_set_semantic_content_output() {
	self.cursor_set_semantic_content(CursorSemanticOutput{})
}

pub fn (mut self Screen) cursor_set_semantic_content_input(clear_eol bool) {
	self.cursor_set_semantic_content(CursorSemanticInput{
		clear: if clear_eol { .clear_eol } else { .clear_explicit }
	})
}

// ============================================================
// Selection
// ============================================================

// Set the selection, replacing any previous selection.
pub fn (mut self Screen) select(sel ?Selection) ! {
	self.selection = sel
	self.dirty.selection = true
}

// Clear the current selection.
pub fn (mut self Screen) clear_selection() {
	if self.selection != none {
		self.dirty.selection = true
	}
	self.selection = none
}

// Get the string for a selection.
pub fn (mut self Screen) selection_string(opts SelectionString) !string {
	mut formatter := ScreenFormatter.init(&self, FormatOptions{
		emit: .plain
		unwrap: true
		trim: opts.trim
	})
	formatter.content = ScreenContent(ScreenContentSelection{
		sel: opts.sel
	})
	mut pin_map := PinMap{}
	if !isnil(opts.map) {
		formatter.pin_map = &pin_map
	}

	result := formatter.format()
	if !isnil(opts.map) {
		unsafe {
			mut output_map := opts.map
			output_map.str = result
			output_map.map_pin = pin_map.pins.clone()
		}
	}
	return result
}

// Select a line around the given pin.
pub fn (self &Screen) select_line(opts SelectLine) ?Selection {
	if int(opts.pin.y) >= self.pages.screen_rows.len || opts.pin.x >= self.pages.cols {
		return none
	}

	semantic_state := self.pages.screen_rows[int(opts.pin.y)].cells[int(opts.pin.x)].semantic_content

	mut start_pin := Pin{ x: 0, y: opts.pin.y }
	mut found_start_boundary := false
	if opts.semantic_prompt_boundary {
		cells := self.pages.screen_rows[int(opts.pin.y)].cells
		for offset in u32(0) .. opts.pin.x + 1 {
			x := opts.pin.x - offset
			if cells[int(x)].semantic_content != semantic_state {
				start_pin = Pin{ x: x + 1, y: opts.pin.y }
				found_start_boundary = true
				break
			}
		}
	}

	if !found_start_boundary {
		mut prior_y := int(opts.pin.y) - 1
		mut previous := Pin{ x: 0, y: opts.pin.y }
		for prior_y >= 0 {
			row := self.pages.screen_rows[prior_y]
			if !row.wrap {
				previous.x = 0
				start_pin = previous
				found_start_boundary = true
				break
			}

			if opts.semantic_prompt_boundary {
				mut semantic_boundary := false
				for reverse_x := int(self.pages.cols) - 1; reverse_x >= 0; reverse_x-- {
					if row.cells[reverse_x].semantic_content != semantic_state {
						semantic_boundary = true
						break
					}
					previous = Pin{ x: u32(reverse_x), y: u32(prior_y) }
				}
				if semantic_boundary {
					start_pin = previous
					found_start_boundary = true
					break
				}
			} else {
				previous = Pin{ x: 0, y: u32(prior_y) }
			}
			prior_y--
		}
		if !found_start_boundary {
			previous.x = 0
			start_pin = previous
		}
	}

	mut end_pin := Pin{}
	mut found_end_boundary := false
	mut y := int(opts.pin.y)
	for y < self.pages.screen_rows.len {
		row := self.pages.screen_rows[y]
		if opts.semantic_prompt_boundary {
			start_x := if y == int(opts.pin.y) { int(opts.pin.x) } else { 0 }
			if start_x == 0 && row.cells[0].semantic_content != semantic_state {
				if y == 0 {
					return none
				}
				end_pin = Pin{ x: self.pages.cols - 1, y: u32(y - 1) }
				found_end_boundary = true
				break
			}
			for x in start_x .. int(self.pages.cols) {
				if row.cells[x].semantic_content != semantic_state {
					end_pin = Pin{ x: u32(x - 1), y: u32(y) }
					found_end_boundary = true
					break
				}
			}
			if found_end_boundary {
				break
			}
		}
		if !row.wrap {
			end_pin = Pin{ x: self.pages.cols - 1, y: u32(y) }
			found_end_boundary = true
			break
		}
		y++
	}
	if !found_end_boundary {
		return none
	}

	// Trim whitespace if requested
	if ws := opts.whitespace {
		mut start_it := self.pages.cell_iterator(start_pin, .right_down, end_pin)
		mut trimmed_start := ?Pin(none)
		for {
			pin := start_it.next() or { break }
			cell := self.pages.screen_rows[int(pin.y)].cells[int(pin.x)]
			if cell.has_text() && !is_codepoint_in(cell.codepoint_val(), ws) {
				trimmed_start = pin
				break
			}
		}

		mut end_it := self.pages.cell_iterator(end_pin, .left_up, start_pin)
		mut trimmed_end := ?Pin(none)
		for {
			pin := end_it.next() or { break }
			cell := self.pages.screen_rows[int(pin.y)].cells[int(pin.x)]
			if cell.has_text() && !is_codepoint_in(cell.codepoint_val(), ws) {
				trimmed_end = pin
				break
			}
		}

		return Selection.init(trimmed_start or { return none }, trimmed_end or { return none }, false)
	}

	return Selection.init(start_pin, end_pin, false)
}

fn is_codepoint_in(cp u32, list []u32) bool {
	for v in list {
		if cp == v {
			return true
		}
	}
	return false
}

// Select all content on the screen, trimming surrounding whitespace.
pub fn (mut self Screen) select_all() ?Selection {
	whitespace := [u32(0), u32(` `), u32(`\t`)]

	// Find start (first non-whitespace)
	mut start := ?Pin(none)
	for y in 0 .. self.pages.screen_rows.len {
		row := self.pages.screen_rows[y]
		for x in 0 .. int(self.pages.cols) {
			if x < row.cells.len {
				cp := row.cells[x].codepoint
				if cp != 0 && !is_codepoint_in(cp, whitespace) {
					start = Pin{ x: u32(x), y: u32(y) }
					break
				}
			}
		}
		if start != none {
			break
		}
	}

	s := start or { return none }

	// Find end (last non-whitespace)
	mut end := ?Pin(none)
	for rev_y := self.pages.screen_rows.len - 1; rev_y >= 0; rev_y-- {
		row := self.pages.screen_rows[rev_y]
		for rev_x := int(self.pages.cols) - 1; rev_x >= 0; rev_x-- {
			if rev_x < row.cells.len {
				cp := row.cells[rev_x].codepoint
				if cp != 0 && !is_codepoint_in(cp, whitespace) {
					end = Pin{ x: u32(rev_x), y: u32(rev_y) }
					break
				}
			}
		}
		if end != none {
			break
		}
	}

	e := end or { return none }
	return Selection.init(s, e, false)
}

// Select a word near start that is between start and end.
pub fn (self &Screen) select_word_between(start Pin, end_p Pin, boundary_codepoints []u32) ?Selection {
	if start.before(end_p) {
		// Iterate right_down from start to end
		mut pin := start
		for pin.y <= end_p.y {
			if pin.y == end_p.y && pin.x > end_p.x {
				break
			}
			if sel := self.select_word(pin, boundary_codepoints) {
				return sel
			}
			// Move to next cell
			pin.x += 1
			if pin.x >= self.pages.cols {
				pin.x = 0
				pin.y += 1
			}
		}
	} else {
		// Iterate left_up from start to end
		mut pin := start
		for {
			if sel := self.select_word(pin, boundary_codepoints) {
				return sel
			}
			if pin.eql(end_p) || pin.before(end_p) {
				break
			}
			if pin.x > 0 {
				pin.x -= 1
			} else if pin.y > 0 {
				pin.y -= 1
				pin.x = self.pages.cols - 1
			} else {
				break
			}
		}
	}
	return none
}

// Select the word under the given pin.
pub fn (self &Screen) select_word(pin Pin, boundary_codepoints []u32) ?Selection {
	if int(pin.y) >= self.pages.screen_rows.len {
		return none
	}

	row := self.pages.screen_rows[int(pin.y)]
	if int(pin.x) >= row.cells.len {
		return none
	}
	start_cell := row.cells[int(pin.x)]
	if !start_cell.has_text() {
		return none
	}

	expect_boundary := is_codepoint_in(start_cell.codepoint, boundary_codepoints)

	// Go forwards to find end
	mut end := pin
	mut fx := int(pin.x) + 1
	mut fy := int(pin.y)
	for {
		if fy >= self.pages.screen_rows.len {
			break
		}
		cur_row := self.pages.screen_rows[fy]
		if fx >= int(self.pages.cols) {
			if !cur_row.wrap {
				break
			}
			fx = 0
			fy += 1
			continue
		}
		if fx >= cur_row.cells.len {
			break
		}
		cell := cur_row.cells[fx]
		if !cell.has_text() {
			break
		}
		this_boundary := is_codepoint_in(cell.codepoint, boundary_codepoints)
		if this_boundary != expect_boundary {
			break
		}
		end = Pin{ x: u32(fx), y: u32(fy) }
		fx += 1
	}

	// Go backwards to find start
	mut start := pin
	mut bx := int(pin.x) - 1
	mut by := int(pin.y)
	for {
		if by < 0 {
			break
		}
		if bx < 0 {
			if by == 0 {
				break
			}
			prev_row := self.pages.screen_rows[by - 1]
			if !prev_row.wrap {
				break
			}
			by -= 1
			bx = int(self.pages.cols) - 1
			continue
		}
		if by >= self.pages.screen_rows.len {
			break
		}
		cur_row := self.pages.screen_rows[by]
		if bx >= cur_row.cells.len {
			break
		}
		cell := cur_row.cells[bx]
		if !cell.has_text() {
			break
		}
		this_boundary := is_codepoint_in(cell.codepoint, boundary_codepoints)
		if this_boundary != expect_boundary {
			break
		}
		start = Pin{ x: u32(bx), y: u32(by) }
		bx -= 1
	}

	return Selection.init(start, end, false)
}

// Select command output around the given pin.
pub fn (mut self Screen) select_output(pin Pin) ?Selection {
	if int(pin.y) >= self.pages.screen_rows.len {
		return none
	}
	row := self.pages.screen_rows[int(pin.y)]
	if int(pin.x) >= row.cells.len {
		return none
	}
	cell := row.cells[int(pin.x)]
	if cell.semantic_content != .output {
		return none
	}

	mut prior_it := self.pages.prompt_iterator(pin, .left_up, none)
	prompt_pin := prior_it.next() or {
		mut next_it := self.pages.prompt_iterator(pin, .right_down, none)
		next := next_it.next() or { return none }
		mut end_pin := next.up(1) or { return none }
		end_pin.x = self.pages.cols - 1
		start_pin := self.pages.get_top_left(.screen)
		mut cell_it := self.pages.cell_iterator(end_pin, .left_up, start_pin)
		for {
			p := cell_it.next() or { break }
			end_pin = p
			if self.pages.screen_rows[int(p.y)].cells[int(p.x)].has_text() {
				break
			}
		}
		return Selection.init(start_pin, end_pin, false)
	}

	mut semantic := self.pages.highlight_semantic_content(prompt_pin, .output) or {
		return none
	}
	mut cell_it := self.pages.cell_iterator(semantic.end, .left_up, semantic.start)
	for {
		p := cell_it.next() or { break }
		semantic.end = p
		if self.pages.screen_rows[int(p.y)].cells[int(p.x)].has_text() {
			break
		}
	}
	return Selection.init(semantic.start, semantic.end, false)
}

// Returns a line iterator starting from the given pin.
pub fn (self &Screen) line_iterator(start Pin) LineIterator {
	return LineIterator{
		screen: self
		current: start
	}
}

// ============================================================
// Prompt click movement
// ============================================================

// Determine cursor movement needed to move to a click location in a prompt.
pub fn (self &Screen) prompt_click_move(click_pin Pin) PromptClickMove {
	if self.cursor.semantic_content != .input {
		return prompt_click_move_zero
	}
	match self.semantic_prompt.click {
		.none, .click_events {
			return prompt_click_move_zero
		}
		.cl_line, .cl_multiple, .cl_conservative_vertical, .cl_smart_vertical {
			return self.prompt_click_line(click_pin)
		}
	}
}

fn (self &Screen) prompt_click_line(click_pin Pin) PromptClickMove {
	cursor_pin := Pin{ x: self.cursor.x, y: u32(self.pages.active_start) + self.cursor.y }
	if cursor_pin.eql(click_pin) {
		return prompt_click_move_zero
	}

	// The cursor cell's semantic content, used to decide whether to add a
	// trailing empty input cell to move to at the end (editor behavior).
	cursor_cell_input := if int(cursor_pin.y) < self.pages.screen_rows.len
		&& int(cursor_pin.x) < self.pages.screen_rows[int(cursor_pin.y)].cells.len {
		self.pages.screen_rows[int(cursor_pin.y)].cells[int(cursor_pin.x)].semantic_content == .input
	} else {
		false
	}

	if cursor_pin.before(click_pin) {
		// Moving right
		mut count := 0
		mut y := int(cursor_pin.y)
		for y <= int(click_pin.y) && y < self.pages.screen_rows.len {
			row := self.pages.screen_rows[y]
			is_cursor_row := u32(y) == cursor_pin.y
			// If this is not the cursor row, verify it's still part of the
			// continuation of our starting prompt.
			if !is_cursor_row && row.semantic_prompt != .prompt_continuation {
				break
			}
			// Determine where our input starts. On the cursor row we start
			// after the cursor. Otherwise we start at the first input cell.
			mut start_x := 0
			if is_cursor_row {
				start_x = int(cursor_pin.x) + 1
			} else {
				start_x = int(self.pages.cols)
				for x in 0 .. int(self.pages.cols) {
					if x < row.cells.len && row.cells[x].semantic_content == .input {
						start_x = x
						break
					}
				}
			}
			for x in start_x .. int(self.pages.cols) {
				if x < row.cells.len && row.cells[x].semantic_content == .input {
					count += 1
					if u32(y) == click_pin.y && u32(x) == click_pin.x {
						return PromptClickMove{ left: 0, right: count }
					}
				}
			}
			if !row.wrap {
				// If we never found our pin, we clicked further right/beyond
				// it. If we're already on a non-empty input cell then we add
				// one so we can move to the newest, empty cell at the end,
				// matching typical editor behavior.
				if cursor_cell_input {
					count += 1
				}
				break
			}
			y += 1
		}
		return PromptClickMove{ left: 0, right: count }
	} else {
		// Moving left
		mut count := 0
		mut y := int(cursor_pin.y)
		for y >= int(click_pin.y) && y >= 0 {
			if y >= self.pages.screen_rows.len {
				y -= 1
				continue
			}
			row := self.pages.screen_rows[y]
			is_cursor_row := u32(y) == cursor_pin.y
			end_x := if is_cursor_row { int(cursor_pin.x) } else { int(self.pages.cols) }
			for rev_x := end_x - 1; rev_x >= 0; rev_x-- {
				if rev_x < row.cells.len && row.cells[rev_x].semantic_content == .input {
					count += 1
					if u32(y) == click_pin.y && u32(rev_x) == click_pin.x {
						return PromptClickMove{ left: count, right: 0 }
					}
				}
			}
			if !row.wrap_continuation {
				break
			}
			y -= 1
		}
		return PromptClickMove{ left: count, right: 0 }
	}
}

// ============================================================
// Dump / Format
// ============================================================

// Options for dumping an inclusive screen region.
pub struct DumpStringOptions {
pub:
	tl     Pin
	br     ?Pin
	unwrap bool = true
}

// Dump the screen through the shared formatter. The supplied pins are
// absolute flat-storage pins; when br is omitted the screen's final written
// cell is used. This is the writer-independent V equivalent of Ghostty's
// Screen.dumpString.
pub fn (self &Screen) dump_string(opts DumpStringOptions) !string {
	if int(opts.tl.y) >= self.pages.screen_rows.len || opts.tl.x >= self.pages.cols {
		return error('UnknownPoint')
	}
	br := opts.br or { self.pages.get_bottom_right(.screen) or { return error('UnknownPoint') } }
	if int(br.y) >= self.pages.screen_rows.len || br.x >= self.pages.cols {
		return error('UnknownPoint')
	}
	mut formatter := PageFormatter.init(&self.pages, FormatOptions{
		emit: .plain
		unwrap: opts.unwrap
		trim: false
	})
	formatter.start_x = opts.tl.x
	formatter.start_y = opts.tl.y
	formatter.end_x = br.x
	formatter.end_y = br.y
	return formatter.format()
}

// Dump screen contents to an allocated string without joining soft wraps.
pub fn (self &Screen) dump_string_alloc(tag PointTag) !string {
	tl := self.pages.get_top_left(tag)
	br := self.pages.get_bottom_right(tag) or { return error('UnknownPoint') }
	return self.dump_string(DumpStringOptions{
		tl: tl
		br: br
		unwrap: false
	})
}

// Dump unwrapped (soft-wraps joined) contents to a string.
pub fn (self &Screen) dump_string_alloc_unwrapped(tag PointTag) !string {
	tl := self.pages.get_top_left(tag)
	br := self.pages.get_bottom_right(tag) or { return error('UnknownPoint') }
	return self.dump_string(DumpStringOptions{
		tl: tl
		br: br
		unwrap: true
	})
}

// ============================================================
// Grapheme support
// ============================================================

// Append a grapheme codepoint to a cell.
// Append a grapheme codepoint to the given cell within the current cursor
// row. The first codepoint stays on the cell; additional codepoints are
// stored in the cell's graphemes slice and the content tag is switched to
// codepoint_grapheme.
pub fn (mut self Screen) append_grapheme(cell_x u32, cp u32) ! {
	idx := self.pages.active_start + int(self.cursor.y)
	if idx < self.pages.screen_rows.len {
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if int(cell_x) < row.cells.len {
				mut cell := &row.cells[int(cell_x)]
				cell.graphemes << cp
				cell.has_grapheme = true
				cell.content_tag = .codepoint_grapheme
				row.grapheme = true
			}
		}
	}
}

// ============================================================
// Increase capacity (page management)
// ============================================================

// Increase capacity of the page containing the given node.
pub fn (mut self Screen) increase_capacity() ! {
	// Pages uses growable V arrays rather than fixed packed allocations, so
	// capacity increases happen automatically at the point of insertion.
}

// Split a page for capacity reasons.
fn (mut self Screen) split_for_capacity() ! {
	// The flat Pages storage has no fixed-capacity page boundary to split.
}

// Clean up boundary conditions where a cell will become discontiguous with
// a neighboring cell because either one of them will be moved and/or cleared.
//
// For performance reasons this is specialized to operate on the cursor row.
//
// Handles the boundary between the cell at `x` and the cell at `x - 1`.
//
// So, for example, when moving a region of cells [a, b] (inclusive), call this
// function with `x = a` and `x = b + 1`. It is okay if `x` is out of bounds by
// 1, this will be interpreted correctly.
//
// DOES NOT MODIFY ROW WRAP STATE! See cursor_reset_wrap for that.
//
// The following boundary conditions are handled:
//
// - `x - 1` is a wide character and `x` is a spacer tail:
//   o Both cells will be cleared.
//   o If `x - 1` is the start of the row and was wrapped from a previous row
//     then the previous row is checked for a spacer head, which is cleared if
//     present.
//
// - `x == 0` and is a wide character:
//   o If the row is a wrap continuation then the previous row will be checked
//     for a spacer head, which is cleared if present.
//
// - `x == cols` and `x - 1` is a spacer head:
//   o `x - 1` will be cleared.
pub fn (mut self Screen) split_cell_boundary(x u32) {
	cols := self.pages.cols
	// `x` may be up to and INCLUDING `cols`, since that signifies splitting
	// the boundary to the right of the final cell in the row.
	if x > cols {
		return
	}

	row_idx := self.pages.active_start + int(self.cursor.y)
	if row_idx < 0 || row_idx >= self.pages.screen_rows.len {
		return
	}

	// [ A B C D E F|]
	//              ^ Boundary between final cell and row end.
	if x == cols {
		is_wrap := self.pages.screen_rows[row_idx].wrap
		if !is_wrap {
			return
		}
		// Spacer head at end of wrapped row.
		last := int(cols) - 1
		if last >= 0 && last < self.pages.screen_rows[row_idx].cells.len {
			if self.pages.screen_rows[row_idx].cells[last].wide == .spacer_head {
				self.clear_cells(row_idx, last, last + 1)
			}
		}
		return
	}

	// [|A B C D E F ]
	//  ^ Boundary between first cell and row start.
	//
	//  OR
	//
	// [ A|B C D E F ]
	//    ^ Boundary between first cell and second cell.
	//
	// First cell may be a wrapped wide cell with a spacer head on the
	// previous row that needs to be cleared.
	if (x == 0 || x == 1) && self.pages.screen_rows[row_idx].wrap_continuation {
		first_wide := self.pages.screen_rows[row_idx].cells.len > 0
			&& self.pages.screen_rows[row_idx].cells[0].wide == .wide
		if first_wide {
			prev_idx := row_idx - 1
			if prev_idx >= 0 {
				last := int(cols) - 1
				if last >= 0 && last < self.pages.screen_rows[prev_idx].cells.len {
					if self.pages.screen_rows[prev_idx].cells[last].wide == .spacer_head {
						self.clear_cells(prev_idx, last, last + 1)
					}
				}
			}
		}
	}

	// If x is 0 then we're done.
	if x == 0 {
		return
	}

	// [ ... X|Y ... ]
	//        ^ Boundary between two cells in the middle of the row.
	xi := int(x)
	if xi - 1 < self.pages.screen_rows[row_idx].cells.len {
		left := self.pages.screen_rows[row_idx].cells[xi - 1]
		match left.wide {
			// There should not be spacer heads in the middle of the row.
			.spacer_head {}
			// We don't need to do anything for narrow cells or spacer tails.
			.narrow, .spacer_tail {}
			// A wide char would be split, so must be cleared.
			.wide {
				self.clear_cells(row_idx, xi - 1, xi + 1)
			}
		}
	}
}

// ============================================================
// Test helper: write string to screen
// ============================================================

// Write a string to the screen at the cursor position.
// This mirrors Ghostty's Screen.testWriteString test helper, including
// Unicode cell widths, grapheme attachment, wide-cell spacers, styling,
// hyperlinks, wrapping, and semantic prompt continuation state.
pub fn (mut self Screen) test_write_string(text string) ! {
	runes := text.runes()
	for c in runes {
		// Explicit newline
		if c == `\n` {
			self.cursor_down_or_scroll()!
			self.cursor_horizontal_absolute(0)
			self.cursor.pending_wrap = false
			if self.cursor.semantic_content_clear_eol {
				self.cursor_set_semantic_content_output()
			} else {
				match self.cursor.semantic_content {
					.output {}
					.prompt, .input {
						idx := self.pages.active_start + int(self.cursor.y)
						if idx < self.pages.screen_rows.len {
							unsafe {
								mut row := &self.pages.screen_rows[idx]
								row.semantic_prompt = .prompt_continuation
							}
						}
					}
				}
			}
			continue
		}

		width := if c <= 0xff { u32(1) } else { u32(unicode.get(u32(c)).width) }
		if width == 0 {
			assert self.cursor.x > 0
			mut cell_x := self.cursor.x - 1
			idx := self.pages.active_start + int(self.cursor.y)
			if idx < self.pages.screen_rows.len
				&& int(cell_x) < self.pages.screen_rows[idx].cells.len
				&& self.pages.screen_rows[idx].cells[int(cell_x)].wide == .spacer_tail {
				assert cell_x > 0
				cell_x--
			}
			self.append_grapheme(cell_x, u32(c))!
			continue
		}

		if self.cursor.pending_wrap {
			assert self.cursor.x == self.pages.cols - 1
			self.cursor.pending_wrap = false
			// Mark current row as wrapped
			cur_idx := self.pages.active_start + int(self.cursor.y)
			if cur_idx < self.pages.screen_rows.len {
				unsafe {
					mut row := &self.pages.screen_rows[cur_idx]
					row.wrap = true
				}
			}
			self.cursor_down_or_scroll()!
			self.cursor_horizontal_absolute(0)
			// Mark new row as continuation
			new_idx := self.pages.active_start + int(self.cursor.y)
			if new_idx < self.pages.screen_rows.len {
				unsafe {
					mut row := &self.pages.screen_rows[new_idx]
					row.wrap_continuation = true
				}
			}
			match self.cursor.semantic_content {
				.output {}
				.input, .prompt {
					idx2 := self.pages.active_start + int(self.cursor.y)
					if idx2 < self.pages.screen_rows.len {
						unsafe {
							mut row := &self.pages.screen_rows[idx2]
							row.semantic_prompt = .prompt_continuation
						}
					}
				}
			}
		}

		assert width == 1 || width == 2
		match width {
			1 {
				row_idx := self.pages.active_start + int(self.cursor.y)
				if row_idx < self.pages.screen_rows.len {
					unsafe {
						mut row := &self.pages.screen_rows[row_idx]
						if int(self.cursor.x) < row.cells.len {
							row.cells[int(self.cursor.x)] = CellData{
								codepoint: u32(c)
								content_tag: .codepoint
								style_id: self.cursor.style_id
								is_protected: self.cursor.is_protected
								semantic_content: self.cursor.semantic_content
								style: self.cursor.style
							}
							if self.cursor.style_id != default_style_id {
								row.styled = true
							}
						}
					}
				}
				if self.cursor.hyperlink_id > 0 {
					self.cursor_set_hyperlink()!
				}
			}
			2 {
				// A wide character at the last column first writes the spacer
				// head and wraps. The character and its tail are then written on
				// the following row.
				if self.cursor.x == self.pages.cols - 1 {
					row_idx := self.pages.active_start + int(self.cursor.y)
					unsafe {
						mut row := &self.pages.screen_rows[row_idx]
						row.cells[int(self.cursor.x)] = CellData{
							content_tag: .codepoint
							wide: .spacer_head
							is_protected: self.cursor.is_protected
							semantic_content: self.cursor.semantic_content
						}
						row.wrap = true
					}
					if self.cursor.hyperlink_id > 0 {
						self.cursor_set_hyperlink()!
					}
					self.cursor_down_or_scroll()!
					self.cursor_horizontal_absolute(0)
					new_idx := self.pages.active_start + int(self.cursor.y)
					unsafe {
						mut row := &self.pages.screen_rows[new_idx]
						row.wrap_continuation = true
					}
				}

				row_idx := self.pages.active_start + int(self.cursor.y)
				unsafe {
					mut row := &self.pages.screen_rows[row_idx]
					row.cells[int(self.cursor.x)] = CellData{
						codepoint: u32(c)
						content_tag: .codepoint
						style_id: self.cursor.style_id
						wide: .wide
						is_protected: self.cursor.is_protected
						semantic_content: self.cursor.semantic_content
						style: self.cursor.style
					}
					if self.cursor.style_id != default_style_id {
						row.styled = true
					}
				}
				if self.cursor.hyperlink_id > 0 {
					self.cursor_set_hyperlink()!
				}

				self.cursor_right(1)
				unsafe {
					mut row := &self.pages.screen_rows[row_idx]
					row.cells[int(self.cursor.x)] = CellData{
						content_tag: .codepoint
						wide: .spacer_tail
						is_protected: self.cursor.is_protected
						semantic_content: self.cursor.semantic_content
					}
				}
				if self.cursor.hyperlink_id > 0 {
					self.cursor_set_hyperlink()!
				}
			}
			else { panic('invalid Unicode cell width') }
		}

		if self.cursor.x + 1 < self.pages.cols {
			self.cursor.x += 1
		} else {
			self.cursor.pending_wrap = true
		}
	}
}
