module terminal

import datastruct

// --- Original Ghostty Comments Start: src/terminal/page.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/page.zig
//
// The allocator to use for multi-codepoint grapheme data. We use
// a chunk size of 4 codepoints. It'd be best to set this empirically
// but it is currently set based on vibes. My thinking around 4 codepoints
// is that most skin-tone emoji are <= 4 codepoints, letter combiners
// are usually <= 4 codepoints, and 4 codepoints is a nice power of two
// for alignment.
// The allocator used for shared utf8-encoded strings within a page.
// Note the chunk size below is the minimum size of a single allocation
// and requires a single bit of metadata in our bitmap allocator. Therefore
// it should be tuned carefully (too small and we waste metadata, too large
// and we have fragmentation). We can probably use a better allocation
// strategy in the future.
//
// At the time of writing this, the strings table is only used for OSC8
// IDs and URIs. IDs are usually short and URIs are usually longer. I chose
// 32 bytes as a compromise between these two since it represents single
// domain links quite well and is not too wasteful for short IDs. We can
// continue to tune this as we see how it's used.
// Default number of hyperlinks we support.
//
// The cell multiplier is the number of cells per hyperlink entry that
// we support. A hyperlink can be longer than this multiplier; the multiplier
// just sets the total capacity to simplify adjustable size metrics.
// A page represents a specific section of terminal screen. The primary
// idea of a page is that it is a fully self-contained unit that can be
// serialized, copied, etc. as a convenient way to represent a section
// of the screen.
//
// This property is useful for renderers which want to copy just the pages
// for the visible portion of the screen, or for infinite scrollback where
// we may want to serialize and store pages that are sufficiently far
// away from the current viewport.
//
// Pages are always backed by a single contiguous block of memory that is
// aligned on a page boundary. This makes it easy and fast to copy pages
// around. Within the contiguous block of memory, the contents of a page are
// thoughtfully laid out to optimize primarily for terminal IO (VT streams)
// and to minimize memory usage.
// The alignment of our members. We want to ensure that the page
// alignment is always divisible by this.
// The backing memory for the page. A page is always made up of a
// a single contiguous block of memory that is aligned on a page
// boundary and is a multiple of the system page size.
// The array of rows in the page. The rows are always in row order
// (i.e. index 0 is the top row, index 1 is the row below that, etc.)
// The array of cells in the page. The cells are NOT in row order,
// but they are in column order. To determine the mapping of cells
// to row, you must use the `rows` field. From the pointer to the
// first column, all cells in that row are laid out in column order.
// Set to true when an operation is performed that dirties all rows in
// the page. See `Row.dirty` for more information on dirty tracking.
//
// NOTE: A value of false does NOT indicate that
//       the page has no dirty rows in it, only
//       that no full-page-dirtying operations
//       have occurred since it was last cleared.
// The string allocator for this page used for shared utf-8 encoded
// strings. Liveness of strings and memory management is deferred to
// the individual use case.
// The multi-codepoint grapheme data for this page. This is where
// any cell that has more than one codepoint will be stored. This is
// relatively rare (typically only emoji) so this defaults to a very small
// size and we force page realloc when it grows.
// The mapping of cell to grapheme data. The exact mapping is the
// cell offset to the grapheme data offset. Therefore, whenever a
// cell is moved (i.e. `erase`) then the grapheme data must be updated.
// Grapheme data is relatively rare so this is considered a slow
// path.
// The available set of styles in use on this page.
// The structures used for tracking hyperlinks within the page.
// The map maps cell offsets to hyperlink IDs and the IDs are in
// the ref counted set. The strings within the hyperlink structures
// are allocated in the string allocator.
// The current dimensions of the page. The capacity may be larger
// than this. This allows us to allocate a larger page than necessary
// and also to resize a page smaller without reallocating.
// The capacity of this page. This is the full size of the backing
// memory and is fixed at page creation time.
// If this is true then verifyIntegrity will do nothing. This is
// only present with runtime safety enabled.
// Initialize a new page, allocating the required backing memory.
// The size of the initialized page defaults to the full capacity.
//
// The backing memory is always allocated using mmap directly.
// You cannot use custom allocators with this structure because
// it is critical to performance that we use mmap.
// We use mmap directly to avoid Zig allocator overhead
// (small but meaningful for this path) and because a private
// anonymous mmap is guaranteed on Linux and macOS to be zeroed,
// which is a critical property for us.
// Initialize a new page using the given backing memory.
// It is up to the caller to not call deinit on these pages.
// We need to go through and initialize all the rows so that
// they point to a valid offset into the cells, since the rows
// zero-initialized aren't valid.
// Deinitialize the page, freeing any backing memory. Do NOT call
// this if you allocated the backing memory yourself (i.e. you used
// initBuf).
// Reinitialize the page with the same capacity.
// We zero the page memory as u64 instead of u8 because
// we can and it's empirically quite a bit faster.
// Temporarily pause integrity checks. This is useful when you are
// doing a lot of operations that would trigger integrity check
// violations but you know the page will end up in a consistent state.
// A helper that can be used to assert the integrity of the page
// when runtime safety is enabled. This is a no-op when runtime
// safety is disabled. This uses the libc allocator.
// Verifies the integrity of the page data. This is not fast,
// but it is useful for assertions, deserialization, etc. The
// allocator is only used for temporary allocations -- all memory
// is freed before this function returns.
//
// Integrity errors are also logged as warnings.
// Some things that seem like we should check but do not:
//
// - We do not check that the style ref count is exact, only that
//   it is at least what we see. We do this because some fast paths
//   trim rows without clearing data.
// - We do not check that styles seen is exactly the same as the
//   styles count in the page for the same reason as above.
// - We only check that we saw less graphemes than the total memory
//   used for the same reason as styles above.
//
// We don't run integrity checks on Valgrind because its soooooo slow,
// Valgrind is our integrity checker, and we run these during unit
// tests (non-Valgrind) anyways so we're verifying anyways.
// If a cell has grapheme data, it must be present in
// the grapheme map.
// It should not have grapheme data if it isn't marked.
// The grapheme_count check above is just an optimization
// to speed up integrity checks.
// If a cell has a style, it must be present in the styles
// set. Accessing it with `get` asserts that.
// Hyperlink ID should be valid. This just straight crashes
// if this fails due to assertions.
// It should not have hyperlink data if it isn't marked
// Spacer tails can't be at the start because they follow
// a wide char.
// Spacer tails must follow a wide char
// Spacer heads must be at the end
// The row must be wrapped
// Check row grapheme data
// If a cell in a row has grapheme data, the row must
// be marked as having grapheme data.
// Our graphemes seen should exactly match the grapheme count
// Verify all our styles have the correct ref count.
// Verify all our hyperlinks have the correct ref count.
// Verify there are no zombie styles, that is, styles in the
// set with ref counts > 0, which are not present in the page.
// NOTE: This is currently disabled because @qwerasd says that
// certain fast paths can cause this but its okay.
// Just 1 zombie style might be the cursor style, so ignore it.
// if (zombies > 1) {
//     log.warn(
//         "page integrity violation zombie styles count={}",
//         .{zombies},
//     );
//     return IntegrityError.ZombieStyles;
// }
// Clone the contents of this page. This will allocate new memory
// using the page allocator. If you want to manage memory manually,
// use cloneBuf.
// Clone the entire contents of this page.
//
// The buffer must be at least the size of self.memory.
// The entire concept behind a page is that everything is stored
// as offsets so we can do a simple linear copy of the backing
// memory and copy all the offsets and everything will work.
// This is a memcpy. We may want to investigate if there are
// faster ways to do this (i.e. copy-on-write tricks) but I suspect
// they'll be slower. I haven't experimented though.
// std.log.warn("copy bytes={}", .{self.memory.len});
// Compute the exact capacity required to store a range of rows from
// this page.
//
// The returned capacity will have the same number of columns as this
// page and the number of rows equal to the range given. The returned
// capacity is by definition strictly less than or equal to this
// page's capacity, so the layout is guaranteed to succeed.
//
// Preconditions:
// - Range must be at least 1 row
// - Start and end must be valid for this page
// Track unique IDs using a bitset. Both style IDs and hyperlink IDs
// are CellCountInt (u16), so we reuse this set for both to save
// stack memory (~8KB instead of ~16KB).
// Accumulators
// First pass: count styles and grapheme bytes
// Second pass: count hyperlinks and string bytes
// We count both unique hyperlinks (for hyperlink_set) and total
// hyperlink cells (for hyperlink_map capacity).
// Only count each unique hyperlink once for set sizing
// Get the hyperlink entry to compute string bytes
// The hyperlink_map capacity in layout() is computed as:
//   hyperlink_count * hyperlink_cell_multiplier (rounded to power of 2)
// We need enough hyperlink_bytes so that when layout() computes
// the map capacity, it can accommodate all hyperlink cells. This
// is unit tested.
// All the intCasts below are safe because we should have a
// capacity strictly less than or equal to this page's capacity.
// Clone the contents of another page into this page. The capacities
// can be different, but the size of the other page must fit into
// this page.
//
// The y_start and y_end parameters allow you to clone only a portion
// of the other page. This is useful for splitting a page into two
// or more pages.
//
// The column count of this page will always be the same as this page.
// If the other page has more columns, the extra columns will be
// truncated. If the other page has fewer columns, the extra columns
// will be zeroed.
// We should remain consistent
// Clone a single row from another page into this page.
// Clone a single row from another page into this page, supporting
// partial copy. cloneRowFrom calls this.
// This whole operation breaks integrity until the end.
// If our destination has styles or graphemes then we need to
// clear some state. This will free up the managed memory as well.
// Copy all the row metadata but keep our cells offset
// If we're not copying the full row then we want to preserve
// some original state from our dst row.
// Our cell offset remains the same
// If we have no managed memory in the source, then we can just
// copy it directly.
// This is an integrity check: if the row claims it doesn't
// have managed memory then all cells must also not have
// managed memory.
// We have managed memory, so we have to do a slower copy to
// get all of that right.
// Reset any managed memory markers on the cell so that we don't
// hit an integrity check if we have to return an error because
// the page can't fit the new memory.
// Copy the grapheme codepoints
// Safe to use setGraphemes because we cleared all
// managed memory for our destination cell range.
// Fast-path: same page we can add with the same id.
// Slow-path: get the hyperlink from the other page,
// add it, and migrate.
// If our page can't support an additional cell with
// a hyperlink then we have to return an error.
// The hyperlink map capacity needs to be increased.
// First check if the link already exists in our page,
// and increment its refcount if so, since we're about
// to use it.
// If we don't have this link in our page yet then
// we need to clone it over and add it to our set.
// Clone the link.
// The string alloc capacity needs to be increased.
// Add it, preferring to use the same ID as the other
// page, since this *probably* speeds up full-page
// clones.
//
// TODO(qwerasd): verify the assumption that `addWithId`
// is ever actually useful, I think it may not be.
// The hyperlink set capacity needs to be increased.
// The hyperlink set needs to be rehashed.
// If it's the same page we don't have to worry about
// copying the style, we can use the style ID directly.
// Slow path: Get the style from the other
// page and add it to this page's style set.
// The style set capacity needs to be increased.
// The style set needs to be rehashed.
// If we are growing columns, then we need to ensure spacer heads
// are cleared.
// Get a single row. y must be valid.
// Get the cells for a row.
// Get the row and cell for the given X/Y within this page.
// Move a cell from one location to another. This will replace the
// previous contents with a blank cell. Because this is a move, this
// doesn't allocate and can't fail.
// Clear our destination now matter what
// If src has no managed memory, this is very fast.
// Source has graphemes or hyperlinks...
// Required for moveGrapheme assertions
// The destination row has styles if any of the cells are styled
// Clear our source row now that the copy is complete. We can NOT
// use clearCells here because clearCells will garbage collect our
// styles and graphames but we moved them above.
//
// Zero the cells as u64s since empirically this seems
// to be a bit faster than using @memset(src_cells, .{})
// Swap two cells within the same row as quickly as possible.
// Graphemes are keyed by cell offset so we do have to move them.
// We do this first so that all our grapheme state is correct.
// Both had graphemes, so we have to manually swap
// Hyperlinks are keyed by cell offset.
// Both had hyperlinks, so we have to manually swap
// Copy the metadata. Note that we do NOT have to worry about
// styles because styles are keyed by ID and we're preserving the
// exact ref count and row state here.
// Clear the cells in the given row. This will reclaim memory used
// by graphemes and styles. Note that if the style cleared is still
// active, Page cannot know this and it will still be ref counted down.
// The best solution for this is to artificially increment the ref count
// prior to calling this function.
// If we have managed memory (styles, graphemes, or hyperlinks)
// in this row then we go cell by cell and clear them if present.
// If we have no left/right scroll region we can be sure
// that we've cleared all the graphemes, so we clear the
// flag, otherwise we use the update function to update.
// If we have no left/right scroll region we can be sure
// that we've cleared all the hyperlinks, so we clear the
// flag, otherwise we use the update function to update.
// If we have no left/right scroll region we can be sure
// that we've cleared all the styles, so we clear the
// flag, otherwise we use the update function to update.
// Zero the cells as u64s since empirically this seems
// to be a bit faster than using @memset(cells, .{})
// Returns the hyperlink ID for the given cell.
// Clear the hyperlink from the given cell.
//
// In order to update the hyperlink flag on the row, call
// `updateRowHyperlinkFlag` after you finish clearing any
// hyperlinks in the row.
// Get our ID
// Release our usage of this, free memory, unset flag
// Checks if the row contains any hyperlinks and sets
// the hyperlink flag to false if none are found.
//
// Call after removing hyperlinks in a row.
// string_alloc errors
// hyperlink_set errors
// Convert a hyperlink into a page entry, returning the ID.
//
// This does not de-dupe any strings, so if the URI, explicit ID,
// etc. is already in the strings table this will duplicate it.
//
// To release the memory associated with the given hyperlink,
// release the ID from the `hyperlink_set`. If the refcount reaches
// zero and the slot is needed then the context will reap the
// memory.
// Insert our URI into the page strings table.
// Allocate an ID for our page memory if we have to.
// Build our entry
// Put our hyperlink into the hyperlink set to get an ID
// Set the hyperlink for the given cell. If the cell already has a
// hyperlink, then this will handle memory management and refcount
// update for the prior hyperlink.
//
// DOES NOT increment the reference count for the new hyperlink!
//
// Caller is responsible for updating the refcount in the hyperlink
// set as necessary by calling `use` if the id was not acquired with
// `add`.
// The hyperlink map capacity needs to be increased.
// Always release the old hyperlink, because even if it's actually
// the same as the one we're setting, we'd end up double-counting
// if we left the reference count be, because the caller does not
// know whether it's the same and will have increased the count
// outside of this function.
// If the hyperlink matches then we don't need to do anything.
// It is possible for cell hyperlink to be false but row
// must never be false. The cell hyperlink can be false because
// in Terminal.print we clear the hyperlink for the cursor cell
// before writing the cell again, so if someone prints over
// a cell with a matching hyperlink this state can happen.
// This is tested in Terminal.zig.
// Set the hyperlink on the cell and in the map.
// Move the hyperlink from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
// Destination must NOT have a hyperlink.
// NOTE: We must not set src/dst.hyperlink here because this
// function is used in various cases where we swap cell contents
// and its unsafe. The flip side: the caller must be careful
// to set the proper cell state to represent the move.
// Returns the number of hyperlinks in the page. This isn't the byte
// size but the total number of unique cells that have hyperlink data.
// Returns the hyperlink capacity for the page. This isn't the byte
// size but the number of unique cells that can have hyperlink data.
// Set the graphemes for the given cell. This asserts that the cell
// has no graphemes set, and only contains a single codepoint.
// The grapheme alloc capacity needs to be increased.
// The grapheme map capacity needs to be increased.
// Append a codepoint to the given cell as a grapheme.
// If this cell has no graphemes, we can go faster by knowing we
// need to allocate a new grapheme slice and update the map.
// The cell already has graphemes. We need to append to the existing
// grapheme slice and update the map.
// If our slice len doesn't divide evenly by the grapheme chunk
// length then we can utilize the additional chunk space.
// We are out of chunk space. There is no fast path here. We need
// to allocate a larger chunk. This is a very slow path. We expect
// most graphemes to fit within our chunk size.
// Free our old chunk
// Returns the codepoints for the given cell. These are the codepoints
// in addition to the first codepoint. The first codepoint is NOT
// included since it is on the cell itself.
// Move the graphemes from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
//
// WARNING: This will NOT change the content_tag on the cells because
// there are scenarios where we want to move graphemes without changing
// the content tag. Callers beware but assertIntegrity should catch this.
// Clear the graphemes for a given cell.
//
// In order to update the grapheme flag on the row, call
// `updateRowGraphemeFlag` after you finish clearing any
// graphemes in the row.
// Get our entry in the map, which must exist
// Free our grapheme data
// Remove the entry
// Mark that we no longer have graphemes by changing the content tag.
// Checks if the row contains any graphemes and sets
// the grapheme flag to false if none are found.
//
// Call after removing graphemes in a row.
// Returns the number of graphemes in the page. This isn't the byte
// size but the total number of unique cells that have grapheme data.
// Returns the grapheme capacity for the page. This isn't the byte
// size but the number of unique cells that can have grapheme data.
// Checks if the row contains any styles and sets
// the styled flag to false if none are found.
//
// Call after removing styles in a row.
// Returns true if this page is dirty at all.
// The memory layout for a page given a desired minimum cols
// and rows size.
// Use divCeil to match GraphemeAlloc.layout() which uses alignForward,
// ensuring grapheme_map has capacity when grapheme_alloc has chunks.
// The standard capacity for a page that doesn't have special
// requirements. This is enough to support a very large number of cells.
// The standard capacity is chosen as the fast-path for allocation since
// pages of standard capacity use a pooled allocator instead of single-use
// mmaps.
// The size of this page.
// Capacity of this page.
//
// This capacity can be maxed out (every field max) and still fit
// within a 64-bit memory space. If you need more than this, you will
// need to split data across separate pages.
//
// For 32-bit systems, it is possible to overflow the addressable
// space and this is something we still need to address in the future
// likely by limiting the maximum capacity on 32-bit systems further.
// Number of columns and rows we can know about.
// Number of unique styles that can be used on this page.
// Number of bytes to allocate for hyperlink data. Note that the
// amount of data used for hyperlinks in total is more than this because
// hyperlinks use string data as well as a small amount of lookup metadata.
// This number is a rough approximation.
// Number of bytes to allocate for grapheme data.
// Number of bytes to allocate for strings.
// Returns the maximum number of columns that can be used with this
// capacity while still fitting at least one row. Returns null if even
// a single column cannot fit (which would indicate an unusable capacity).
//
// Note that this is the maximum number of columns that never increases
// the amount of memory the original capacity will take. If you modify
// the original capacity to add rows, then you can fit more columns.
// If we can't even fit the row metadata, return null
// We do the math of how many columns we can fit in the remaining
// bits ignoring the metadata of a row.
// Clamp to CellCountInt max
// Adjust the capacity parameters while retaining the same total size.
//
// Adjustments always happen by limiting the rows in the page. Everything
// else can grow. If it is impossible to achieve the desired adjustment,
// OutOfMemory is returned.
// The size per row is:
//   - The row metadata itself
//   - The cells per row (n=cols)
// If our rows go to zero then we can't fit any row metadata
// for the desired number of columns.
// Computes the number of bits available for rows and cells in the page.
//
// This is done by laying out the "meta" members (styles, graphemes,
// hyperlinks, strings) from the end of the page and finding where they
// start, which gives us the space available for rows and cells.
// The math below only works if there is no alignment gap between
// the end of the rows array and the start of the cells array.
//
// To guarantee this, we assert that Row's size is a multiple of
// Cell's alignment, so that any length array of Rows will end on
// a valid alignment for the start of the Cell array.
// Layout meta members from the end to find styles_start
// Multiply by 8 to convert bytes to bits
// The cells in the row offset from the page.
// True if this row is soft-wrapped. The first cell of the next
// row is a continuation of this row.
// True if the previous row to this one is soft-wrapped and
// this row is a continuation of that row.
// True if any of the cells in this row have multi-codepoint
// grapheme clusters. If this is true, some fast paths are not
// possible because erasing for example may need to clear existing
// grapheme data.
// True if any of the cells in this row have a ref-counted style.
// This can have false positives but never a false negative. Meaning:
// this will be set to true the first time a style is used, but it
// will not be set to false if the style is no longer used, because
// checking for that condition is too expensive.
//
// Why have this weird false positive flag at all? This makes VT operations
// that erase cells (such as insert lines, delete lines, erase chars,
// etc.) MUCH MUCH faster in the case that the row was never styled.
// At the time of writing this, the speed difference is around 4x.
// True if any of the cells in this row are part of a hyperlink.
// This is similar to styled: it can have false positives but never
// false negatives. This is used to optimize hyperlink operations.
// The semantic prompt state for this row.
//
// This is ONLY meant to note if there are ANY cells in this
// row that are part of a prompt. This is an optimization for more
// efficiently implementing jump-to-prompt operations.
//
// This may contain false positives but never false negatives. If
// this is set, you should still check individual cells to see if they
// have prompt semantics.
// True if this row contains a virtual placeholder for the Kitty
// graphics protocol. (U+10EEEE)
// Note: We keep this as memory-using even if the kitty graphics
// feature is disabled because we want to keep our padding and
// everything throughout the same.
// True if this row is dirty and requires a redraw. This is set to true
// by any operation that modifies the row's contents or position, and
// consumers of the page are expected to clear it when they redraw.
//
// Dirty status is only ever meant to convey that one or more cells in
// the row have changed visually. A cell which changes in a way that
// doesn't affect the visual representation may not be marked as dirty.
//
// Dirty tracking may have false positives but should never have false
// negatives. A false negative would result in a visual artifact on the
// screen.
// The semantic prompt state of the row. See `semantic_prompt`.
// No prompt cells in this row.
// Prompt cells exist in this row and this is a primary prompt
// line. A primary prompt line is one that is not a continuation
// and is the beginning of a prompt.
// Prompt cells exist in this row that had k=c set (continuation)
// line. This is used as a way to detect when a line should
// be considered part of some prior prompt. If no prior prompt
// is found, the last (most historical) prompt continuation line is
// considered the prompt.
// Returns true if this row has any managed memory outside of the
// row structure (graphemes, styles, etc.)
// Ordered on purpose for likelihood.
// A cell represents a single terminal grid cell.
//
// The zero value of this struct must be a valid cell representing empty,
// since we zero initialize the backing memory for a page.
// The content tag dictates the active tag in content and possibly
// some other behaviors.
// The content of the cell. This is a union based on content_tag.
// The codepoint that this cell contains. If `grapheme` is false,
// then this is the only codepoint in the cell. If `grapheme` is
// true, then this is the first codepoint in the grapheme cluster.
// The content is an empty cell with a background color.
// The style ID to use for this cell within the style map. Zero
// is always the default style so no lookup is required.
// The wide property of this cell, for wide characters. Characters in
// a terminal grid can only be 1 or 2 cells wide. A wide character
// is always next to a spacer. This is used to determine both the width
// and spacer properties of a cell.
// Whether this was written with the protection flag set.
// Whether this cell is a hyperlink. If this is true then you must
// look up the hyperlink ID in the page hyperlink_map and the ID in
// the hyperlink_set to get the actual hyperlink data.
// The semantic type of the content of this cell. This is used
// by the semantic prompt (OSC 133) set of sequences to understand
// boundary points for content.
// A single codepoint, could be zero to be empty cell.
// A codepoint that is part of a multi-codepoint grapheme cluster.
// The codepoint tag is active in content, but also expect more
// codepoints in the grapheme data.
// The cell has no text but only a background color. This is an
// optimization so that cells with only backgrounds don't take up
// style map space and also don't require a style map lookup.
// Not a wide character, cell width 1.
// Wide character, cell width 2.
// Spacer after wide character. Do not render.
// Spacer at the end of a soft-wrapped line to indicate that a wide
// character is continued on the next line.
// Regular output content, such as command output.
// Content that is part of user input, such as the command
// to execute at a prompt.
// Content that is part of prompt emitted by the interactive
// application, such as "user@host >"
// Helper to make a cell that just has a codepoint.
// We have to use this bitCast here to ensure that our memory is
// zeroed. Otherwise, the content below will leave some uninitialized
// memory in the packed union. Valgrind verifies this.
// Returns true if this cell represents a cell with text to render.
//
// Cases this returns false:
//   - Cell text is blank
//   - Cell is styled but only with a background color and no text
//   - Cell has a unicode placeholder for Kitty graphics protocol
// The width in grid cells that this cell takes up.
// Returns true if the cell has no text or styling.
// Textual cells are empty if they have no text and are narrow.
// The "narrow" requirement is because wide spacers are meaningful.
// Returns true if the set of cells has text in it.
// Uncomment this when you want to do some math.
// test "Page size calculator" {
//     const total_size = alignForward(
//         usize,
//         Page.layout(.{
//             .cols = 250,
//             .rows = 250,
//             .styles = 128,
//             .grapheme_bytes = 1024,
//         }).total_size,
//         std.heap.page_size_min,
//     );
//
//     std.log.warn("total_size={} pages={}", .{
//         total_size,
//         total_size / std.heap.page_size_min,
//     });
// }
//
// test "Page std size" {
//     // We want to ensure that the standard capacity is what we
//     // expect it to be. Changing this is fine but should be done with care
//     // so we fail a test if it changes.
//     const total_size = Page.layout(std_capacity).total_size;
//     try testing.expectEqual(@as(usize, 524_288), total_size); // 512 KiB
//     //const pages = total_size / std.heap.page_size_min;
// }
// Our intention is for a maxed-out capacity to always fit
// within a page layout without triggering runtime safety on any
// overflow. This simplifies some of our handling downstream of the
// call (relevant to: https://github.com/ghostty-org/ghostty/issues/10258)
// Note that a max capacity will exceed our max_page_size so we
// can't init a page with it, but it should layout.
// The zero value should be output type for semantic content.
// This is very important for our assumptions elsewhere.
// If we layout a page with 1 more row and it's still the same size
// then adjust is not producing enough rows.
// If we layout a page with 1 more row and it's still the same size
// then adjust is not producing enough rows.
// If we layout a page with 1 more row and it's still the same size
// then adjust is not producing enough rows.
// If we layout a page with 1 more row and it's still the same size
// then adjust is not producing enough rows.
// maxCols should be >= current cols (since current capacity is valid)
// Adjusting to maxCols should succeed with at least 1 row
// Adjusting to maxCols + 1 should fail
// Read it again
// One
// Two
// Clear it
// Clear it
// Write
// Clone
// Read it again
// Write again
// Read it again, should be unchanged
// Read the original
// Append some graphemes
// Clone it
// Write with some styles
// Clone it
// Write
// Clone
// Read it again
// Write again
// Read it again, should be unchanged
// Read the original
// Write
// Clone
// Read it again
// Write
// Clone
// Read it again
// Ensure our page can accommodate the capacity.
// Create a hyperlink.
// Fill the exact cap with cells.
// Clone the full page
// We should have the same number of hyperlinks
// Write
// Clone
// Read it again
// Write again
// Read it again, should be unchanged
// Read the original
// Clone
// Clone from page which has no graphemes.
// Read it again
// Write
// Clone
// Read it again
// Write
// Clone
// Read it again
// Write
// Clone
// Read it again
// We need to create a hyperlink.
// Write
// Hyperlink in a single cell
// Clone into the same page
// Read it again
// We need to create a hyperlink.
// Write
// Hyperlink in a single cell
// Clone into the same page
// Read it again
// Write
// New rows should have text
// Old row should be blank
// Write
// New rows should have text
// Old row should be blank
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Write
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Write
// Make invalid by unmarking the row
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Upsert a style we'll use
// Write
// The original style add would have incremented the
// ref count too, so release it to balance that out.
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Upsert a style we'll use
// Write
// The original style add would have incremented the
// ref count too, so release it to balance that out.
// Miss a ref
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Too slow, and not really necessary because the integrity tests are
// only run in debug builds and unit tests verify they work well enough.
// Empty page: all capacity fields should be 0 (except cols/rows)
// No styles: capacity should be 0
// Add one style to a cell
// One unique style - capacity accounts for load factor
// Add same style to another cell (duplicate) - capacity unchanged
// Add a different style
// Two unique styles - capacity accounts for load factor
// Style outside the row range should not be counted
// Full range includes the new style
// Verify clone works with exact capacity and produces same result
// Regression test: verify a single style can be cloned with exact capacity.
// This tests that capacityForCount properly accounts for ID 0 being reserved.
// Add exactly one style to row 0
// exactRowCapacity for just row 0 should give capacity for 1 style
// Create a new page with exact capacity and clone
// This must not fail with StyleSetOutOfMemory
// Verify the style was cloned correctly
// Style our first row
// Fill cells with styles until we get OOM, but limit to a reasonable count
// to avoid overflow when computing capacityForCount near maxInt
// Verify we added a meaningful number of styles
// Capacity should be at least count (adjusted for load factor)
// No graphemes: capacity should be 0
// Add one grapheme (1 codepoint) to a cell - rounds up to grapheme_chunk
// 1 codepoint = 4 bytes, rounds up to grapheme_chunk (16)
// Add another grapheme to a different cell - should sum
// 2 graphemes, each 1 codepoint = 2 * grapheme_chunk
// Add a larger grapheme (multiple codepoints) that fits in one chunk
// First two cells: 2 * grapheme_chunk
// Third cell: 3 codepoints = 12 bytes, rounds up to grapheme_chunk
// Grapheme outside the row range should not be counted
// Full range includes the new grapheme
// Verify clone works with exact capacity and produces same result
// Add a grapheme larger than one chunk (grapheme_chunk_len = 4 codepoints)
// Add 6 codepoints - requires 2 chunks (6 * 4 = 24 bytes, rounds up to 32)
// 6 codepoints = 24 bytes, alignForward(24, 16) = 32
// Verify clone works with exact capacity and produces same result
// No hyperlinks: capacity should be 0
// Add one hyperlink with implicit ID
// Create and add hyperlink entry
// 1 hyperlink - capacity accounts for load factor
// URI "https://example.com" = 19 bytes, rounds up to string_chunk (32)
// Add same hyperlink to another cell (duplicate ID) - capacity unchanged
// Use the same hyperlink ID for another cell
// Add a different hyperlink with explicit ID
// 2 hyperlinks - capacity accounts for load factor
// First URI: 19 bytes -> 32, Second URI: 30 bytes -> 32, Explicit ID: 10 bytes -> 32
// Hyperlink outside the row range should not be counted
// Full range includes the new hyperlink
// Third URI: 27 bytes -> 32
// Verify clone works with exact capacity and produces same result
// Regression test: verify a single hyperlink can be cloned with exact capacity.
// This tests that capacityForCount properly accounts for ID 0 being reserved.
// Add exactly one hyperlink to row 0
// exactRowCapacity for just row 0 should give capacity for 1 hyperlink
// Create a new page with exact capacity and clone
// This must not fail with HyperlinkSetOutOfMemory
// Verify the hyperlink was cloned correctly
// A single hyperlink spanning many cells requires hyperlink_map capacity
// based on cell count, not unique hyperlink count.
// Add one hyperlink spanning all 50 columns in row 0
// Apply same hyperlink to remaining cells in row 0
// exactRowCapacity must account for 50 hyperlink cells, not just 1 unique hyperlink
// The hyperlink_bytes must be large enough that layout() computes sufficient
// hyperlink_map capacity. With hyperlink_cell_multiplier=16, we need at least
// ceil(50/16) = 4 hyperlink entries worth of bytes for the map.
// Create a new page with exact capacity and clone - must not fail
// This must not fail with HyperlinkMapOutOfMemory
// Verify all hyperlinks were cloned correctly
//
// --- Original Ghostty Comments End: src/terminal/page.zig

// Page represents a specific section of terminal screen. The primary
// idea of a page is that it is a fully self-contained unit that can be
// serialized, copied, etc. as a convenient way to represent a section
// of the screen.
//
// This property is useful for renderers which want to copy just the pages
// for the visible portion of the screen, or for infinite scrollback where
// we may want to serialize and store pages that are sufficiently far
// away from the current viewport.
//
// Translated from Ghostty's terminal/page.zig to V.
// In Zig, pages use a single contiguous mmap'd block with offset-based
// addressing. In V, we use V arrays and maps with GC-managed memory.

// ============================================================
// Constants
// ============================================================

// The allocator to use for multi-codepoint grapheme data. We use
// a chunk size of 4 codepoints. It'd be best to set this empirically
// but it is currently set based on vibes. My thinking around 4 codepoints
// is that most skin-tone emoji are <= 4 codepoints, letter combiners
// are usually <= 4 codepoints, and 4 codepoints is a nice power of two
// for alignment.
const grapheme_chunk_len = 4

// Chunk size in bytes for grapheme data.
const grapheme_chunk = grapheme_chunk_len * 4 // sizeof(u32)

// Default grapheme bytes capacity. The standard production page overrides
// this to 8192 below; an ordinary Capacity literal uses Ghostty's 64 chunks.
const grapheme_bytes_default = u32(1024)

// The allocator used for shared utf8-encoded strings within a page.
// Note the chunk size below is the minimum size of a single allocation.
// At the time of writing this, the strings table is only used for OSC8
// IDs and URIs. IDs are usually short and URIs are usually longer. I chose
// 32 bytes as a compromise between these two since it represents single
// domain links quite well and is not too wasteful for short IDs.
const string_chunk_len = 32
const string_chunk = string_chunk_len
const string_bytes_default = u32(2048)

// Default number of hyperlinks we support.
//
// The cell multiplier is the number of cells per hyperlink entry that
// we support. A hyperlink can be longer than this multiplier; the multiplier
// just sets the total capacity to simplify adjustable size metrics.
const hyperlink_count_default = 4
const hyperlink_cell_multiplier = 16
const hyperlink_set_item_size = usize(48)
const hyperlink_bytes_default = u16(hyperlink_count_default * hyperlink_set_item_size)

// Kitty graphics protocol Unicode placeholder / virtual placement codepoint.
const kitty_unicode_placeholder = u32(0x10EEEE)

// Standard capacity for a new page.
const std_capacity = PageCapacity{
	cols: 215
	rows: 215
	styles: 128
	hyperlink_bytes: 192
	grapheme_bytes: 8192
	string_bytes: 2048
}

// Number of pages to preheat the pool with.
const page_preheat = 4

// StyleSet is the page-facing specialization of Ghostty's bounded,
// reference-counted style set. The adapter keeps Page's u32 style-ID API
// while the underlying implementation uses the canonical u16 StyleId.
pub struct StyleSet {
pub mut:
	set RefCountedSet
}

// Initialize a new empty StyleSet for the requested page capacity.
pub fn StyleSet.init(capacity u16) StyleSet {
	return StyleSet{
		set: RefCountedSet.init(RefCountedSetLayout.init(int(capacity)))
	}
}

// Add a style to the set. If the style already exists, returns the
// existing ID and increments the ref count. Otherwise adds it and
// returns the new ID with ref_count = 1.
pub fn (mut self StyleSet) add(style CellStyle) !u32 {
	return u32(self.set.add(style)!)
}

// Add a style, preferring to use the given ID.
pub fn (mut self StyleSet) add_with_id(style CellStyle, preferred_id u32) !u32 {
	if preferred_id == 0 || preferred_id > max_u16 {
		return self.add(style)
	}
	return u32(self.set.add_with_id(style, u16(preferred_id))!.id)
}

// Increment the ref count for a style.
pub fn (mut self StyleSet) use_style(id u32) {
	self.set.use_item(u16(id))
}

// Decrement the ref count for a style. If ref count hits 0, the
// slot is freed.
pub fn (mut self StyleSet) release(id u32) {
	self.set.release(u16(id))
}

// Get a style by ID.
pub fn (self &StyleSet) get(id u32) CellStyle {
	return *self.set.get(u16(id))
}

// Get the ref count for a style.
pub fn (self &StyleSet) ref_count(id u32) int {
	return int(self.set.ref_count(u16(id)))
}

// Returns the number of styles with capacity for the given count,
// accounting for the canonical load factor and reserved ID zero.
pub fn StyleSet.capacity_for_count(count int) u16 {
	return u16(rcs_capacity_for_count(count))
}

// clone returns an independent copy preserving IDs, refs, and probe metadata.
fn (self &StyleSet) clone() StyleSet {
	return StyleSet{
		set: RefCountedSet{
			hash_table: self.set.hash_table.clone()
			items: self.set.items.clone()
			max_psl: self.set.max_psl
			psl_stats: self.set.psl_stats
			living: self.set.living
			next_id: self.set.next_id
			layout: self.set.layout
		}
	}
}

// ============================================================
// IntegrityError
// ============================================================

pub enum IntegrityError {
	zero_row_count
	zero_col_count
	unmarked_grapheme_row
	missing_grapheme_data
	invalid_grapheme_count
	unmarked_grapheme_cell
	missing_style
	unmarked_style_row
	mismatched_style_ref
	invalid_style_count
	missing_hyperlink_data
	mismatched_hyperlink_ref
	unmarked_hyperlink_cell
	unmarked_hyperlink_row
	invalid_spacer_tail_location
	invalid_spacer_head_location
	unwrapped_spacer_head
}

enum PageCloneError {
	style_set_out_of_memory
	hyperlink_map_out_of_memory
}

// ============================================================
// PageCapacity - describes how many cols/rows a page can hold
// ============================================================

// Capacity of a page.
//
// This capacity can be maxed out (every field max) and still fit
// within a page layout. V's GC owns the actual arrays, but these fields
// retain Ghostty's exact logical contiguous-page layout and accounting.
pub struct PageCapacity {
pub mut:
	// Number of columns and rows we can know about.
	cols u16 = 80
	rows u16 = 128
	// Number of unique styles that can be used on this page.
	styles u16 = 16
	// Number of bytes to allocate for hyperlink set entries.
	hyperlink_bytes u16 = hyperlink_bytes_default
	// Number of bytes to allocate for grapheme data.
	grapheme_bytes u32 = grapheme_bytes_default
	// Number of bytes to allocate for shared strings.
	string_bytes u32 = string_bytes_default
}

// Bit sizes of the packed Row and Cell structs in Ghostty's page.zig.
// Both are `packed struct(u64)`, so they are exactly 64 bits each. We
// model our grid "budget" using these to faithfully reproduce the
// row-limiting behavior of Capacity.adjust even though V uses GC-managed
// memory rather than a single contiguous mmap'd block.
const row_bit_size = usize(64)
const cell_bit_size = usize(64)

const page_row_size = usize(8)
const page_cell_size = usize(8)
const page_style_item_size = usize(36)

// PageSetLayout is the layout shared by Ghostty's specialized
// RefCountedSet instances. Item sizes differ for styles and hyperlinks.
pub struct PageSetLayout {
pub:
	cap         usize
	table_cap   usize
	table_mask  u16
	table_start usize
	items_start usize
	total_size  usize
}

// PageLayout mirrors Page.Layout in the pinned Ghostty source. Offsets and
// sizes describe the Zig backing allocation rather than V object storage.
pub struct PageLayout {
pub:
	total_size            usize
	rows_start            usize
	rows_size             usize
	cells_start           usize
	cells_size            usize
	styles_start          usize
	styles_layout         PageSetLayout
	grapheme_alloc_start  usize
	grapheme_alloc_layout BitmapAllocatorLayout
	grapheme_map_start    usize
	grapheme_map_layout   HashMapLayout
	string_alloc_start    usize
	string_alloc_layout   BitmapAllocatorLayout
	hyperlink_map_start   usize
	hyperlink_map_layout  HashMapLayout
	hyperlink_set_start   usize
	hyperlink_set_layout  PageSetLayout
	capacity              PageCapacity
}

fn page_align_forward(value usize, alignment usize) usize {
	return (value + alignment - 1) & ~(alignment - 1)
}

fn page_align_backward(value usize, alignment usize) usize {
	return value & ~(alignment - 1)
}

fn page_memory_alignment() usize {
	$if macos {
		return 16384
	} $else {
		return 4096
	}
}

fn page_ceil_power_of_two(value usize) usize {
	if value <= 1 {
		return 1
	}
	mut result := usize(1)
	for result < value {
		result <<= 1
	}
	return result
}

fn page_set_layout(cap usize, item_size usize, item_alignment usize) PageSetLayout {
	if cap == 0 {
		return PageSetLayout{}
	}

	table_cap := page_ceil_power_of_two(cap)
	items_cap := table_cap * 13 / 16
	table_start := usize(0)
	table_end := table_start + table_cap * 2
	items_start := page_align_forward(table_end, item_alignment)
	return PageSetLayout{
		cap: items_cap
		table_cap: table_cap
		table_mask: u16(table_cap - 1)
		table_start: table_start
		items_start: items_start
		total_size: items_start + items_cap * item_size
	}
}

// layout computes the exact byte layout used by the pinned Zig Page.
pub fn Page.layout(cap PageCapacity) PageLayout {
	rows_start := usize(0)
	rows_size := usize(cap.rows) * page_row_size
	rows_end := rows_start + rows_size

	cells_start := page_align_forward(rows_end, page_cell_size)
	cells_size := usize(cap.cols) * usize(cap.rows) * page_cell_size
	cells_end := cells_start + cells_size

	styles_layout := page_set_layout(usize(cap.styles), page_style_item_size, 4)
	styles_start := page_align_forward(cells_end, 8)
	styles_end := styles_start + styles_layout.total_size

	grapheme_alloc_layout := bitmap_allocator_layout(int(cap.grapheme_bytes), grapheme_chunk)
	grapheme_alloc_start := page_align_forward(styles_end, 8)
	grapheme_alloc_end := grapheme_alloc_start + usize(grapheme_alloc_layout.total_size)

	grapheme_count := if cap.grapheme_bytes == 0 {
		usize(0)
	} else {
		page_ceil_power_of_two((usize(cap.grapheme_bytes) + usize(grapheme_chunk) - 1) / usize(grapheme_chunk))
	}
	grapheme_map_layout := layout_for_capacity(u32(grapheme_count), 4, 16, 4, 8)
	grapheme_map_start := page_align_forward(grapheme_alloc_end, 8)
	grapheme_map_end := grapheme_map_start + usize(grapheme_map_layout.total_size)

	string_alloc_layout := bitmap_allocator_layout(int(cap.string_bytes), string_chunk)
	string_alloc_start := page_align_forward(grapheme_map_end, 8)
	string_alloc_end := string_alloc_start + usize(string_alloc_layout.total_size)

	hyperlink_count := usize(cap.hyperlink_bytes) / hyperlink_set_item_size
	hyperlink_set_layout := page_set_layout(hyperlink_count, hyperlink_set_item_size, 8)
	hyperlink_set_start := page_align_forward(string_alloc_end, 8)
	hyperlink_set_end := hyperlink_set_start + hyperlink_set_layout.total_size

	hyperlink_map_count := if hyperlink_count == 0 {
		usize(0)
	} else {
		page_ceil_power_of_two(hyperlink_count * hyperlink_cell_multiplier)
	}
	hyperlink_map_layout := layout_for_capacity(u32(hyperlink_map_count), 4, 2, 4, 2)
	hyperlink_map_start := page_align_forward(hyperlink_set_end, 4)
	hyperlink_map_end := hyperlink_map_start + usize(hyperlink_map_layout.total_size)

	return PageLayout{
		total_size: page_align_forward(hyperlink_map_end, page_memory_alignment())
		rows_start: rows_start
		rows_size: rows_size
		cells_start: cells_start
		cells_size: cells_size
		styles_start: styles_start
		styles_layout: styles_layout
		grapheme_alloc_start: grapheme_alloc_start
		grapheme_alloc_layout: grapheme_alloc_layout
		grapheme_map_start: grapheme_map_start
		grapheme_map_layout: grapheme_map_layout
		string_alloc_start: string_alloc_start
		string_alloc_layout: string_alloc_layout
		hyperlink_map_start: hyperlink_map_start
		hyperlink_map_layout: hyperlink_map_layout
		hyperlink_set_start: hyperlink_set_start
		hyperlink_set_layout: hyperlink_set_layout
		capacity: cap
	}
}

// Computes the number of bits available for rows and cells in the page.
//
// This lays out metadata members backward from the aligned page end exactly
// as Ghostty does, exposing all alignment slack to the row/cell grid.
fn (self PageCapacity) available_bits_for_grid() usize {
	l := Page.layout(self)
	hyperlink_map_start := page_align_backward(l.total_size - usize(l.hyperlink_map_layout.total_size), 4)
	hyperlink_set_start := page_align_backward(hyperlink_map_start - l.hyperlink_set_layout.total_size, 8)
	string_alloc_start := page_align_backward(hyperlink_set_start - usize(l.string_alloc_layout.total_size), 8)
	grapheme_map_start := page_align_backward(string_alloc_start - usize(l.grapheme_map_layout.total_size), 8)
	grapheme_alloc_start := page_align_backward(grapheme_map_start - usize(l.grapheme_alloc_layout.total_size), 8)
	styles_start := page_align_backward(grapheme_alloc_start - l.styles_layout.total_size, 8)
	return styles_start * 8
}

// Returns the maximum number of columns that can be used with this
// capacity while still fitting at least one row. Returns none if even
// a single column cannot fit (which would indicate an unusable capacity).
//
// Note that this is the maximum number of columns that never increases
// the amount of memory the original capacity will take.
pub fn (self PageCapacity) max_cols() ?u16 {
	available_bits := self.available_bits_for_grid()

	// If we can't even fit the row metadata, return none.
	if available_bits <= row_bit_size {
		return none
	}

	// We do the math of how many columns we can fit in the remaining
	// bits ignoring the metadata of a row.
	remaining_bits := available_bits - row_bit_size
	max_cols := remaining_bits / cell_bit_size

	// Clamp to CellCountInt (u16) max.
	if max_cols > usize(max_u16) {
		return max_u16
	}
	return u16(max_cols)
}

// Adjust the capacity parameters while retaining the same total size.
//
// Adjustments always happen by limiting the rows in the page. Everything
// else can grow. If it is impossible to achieve the desired adjustment
// (rows would go to zero), an error is returned.
pub fn (self PageCapacity) adjust_checked(cols u16) !PageCapacity {
	mut adjusted := self
	if cols > 0 {
		available_bits := self.available_bits_for_grid()

		// Each packed row consists of its metadata and n packed cells.
		bits_per_row := row_bit_size + cell_bit_size * usize(cols)
		new_rows := available_bits / bits_per_row

		// If our rows go to zero then we can't fit any row metadata
		// for the desired number of columns.
		if new_rows == 0 {
			return error('OutOfMemory')
		}

		adjusted.cols = cols
		adjusted.rows = if new_rows > usize(max_u16) { max_u16 } else { u16(new_rows) }
	}
	return adjusted
}

const max_u16 = u16(65535)

// ============================================================
// PageSize - actual used size within a page
// ============================================================

pub struct PageSize {
pub mut:
	cols u16
	rows u16
}

// ============================================================
// Page - a page of terminal rows
// ============================================================

@[heap]
pub struct Page {
pub mut:
	// The array of rows in the page. The rows are always in row order
	// (i.e. index 0 is the top row, index 1 is the row below that, etc.)
	rows []RowData

	// Set to true when an operation is performed that dirties all rows
	// in the page. See RowData.dirty for more information on dirty tracking.
	//
	// NOTE: A value of false does NOT indicate that
	//       the page has no dirty rows in it, only
	//       that no full-page-dirtying operations
	//       have occurred since it was last cleared.
	dirty bool

	// The current dimensions of the page. The capacity may be larger
	// than this. This allows us to allocate a larger page than necessary
	// and also to resize a page smaller without reallocating.
	size PageSize

	// The capacity of this page. This is the full size of the backing
	// memory and is fixed at page creation time.
	capacity PageCapacity

	// The available set of styles in use on this page.
	styles StyleSet

	// The structures used for tracking hyperlinks within the page.
	// The map maps cell positions to hyperlink IDs and the IDs are in
	// the ref counted set.
	hyperlink_set HyperlinkSet
	hyperlink_map map[u64]u32 // cell_key -> hyperlink_id

	// A nesting counter used by multi-step mutations that temporarily leave
	// the page inconsistent.
	pause_integrity_checks usize
}

// Initialize a new page, allocating the required backing memory.
// The size of the initialized page defaults to the full capacity.
pub fn Page.init(cap PageCapacity) Page {
	mut rows := []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		rows << RowData.init(u32(cap.cols))
	}
	return Page{
		rows: rows
		capacity: cap
		size: PageSize{
			cols: cap.cols
			rows: 0
		}
		dirty: false
		styles: StyleSet.init(cap.styles)
		hyperlink_set: HyperlinkSet.init()
	}
}

// Deinitialize the page, freeing any backing memory.
// In V, the GC handles memory, but we clear the data.
pub fn (mut self Page) deinit() {
	self.rows = []
	self.hyperlink_map = map[u64]u32{}
	self.styles = StyleSet.init(self.capacity.styles)
	self.hyperlink_set = HyperlinkSet.init()
}

// Reinitialize the page with the same capacity.
pub fn (mut self Page) reinit(cap PageCapacity) {
	self.capacity = cap
	self.size = PageSize{
		cols: cap.cols
		rows: 0
	}
	self.rows = []RowData{cap: int(cap.rows)}
	for _ in 0 .. int(cap.rows) {
		self.rows << RowData.init(u32(cap.cols))
	}
	self.dirty = false
	self.styles = StyleSet.init(cap.styles)
	self.hyperlink_set = HyperlinkSet.init()
	self.hyperlink_map = map[u64]u32{}
}

// Verifies the integrity of the page data. This is not fast,
// but it is useful for assertions, deserialization, etc.
//
// Integrity errors are also logged as warnings.
pub fn (self &Page) verify_integrity() ?IntegrityError {
	if self.pause_integrity_checks > 0 {
		return none
	}
	// Some things that seem like we should check but do not:
	//
	// - We do not check that the style ref count is exact, only that
	//   it is at least what we see. We do this because some fast paths
	//   trim rows without clearing data.
	// - We do not check that styles seen is exactly the same as the
	//   styles count in the page for the same reason as above.
	// - We only check that we saw less graphemes than the total memory
	//   used for the same reason as styles above.
	//
	if self.size.cols == 0 {
		return IntegrityError.zero_col_count
	}
	if self.size.rows == 0 {
		return IntegrityError.zero_row_count
	}

	mut graphemes_seen := 0
	mut styles_seen := map[u32]int{}
	mut hyperlinks_seen := map[u32]int{}
	total_graphemes := self.grapheme_count()

	for y in 0 .. int(self.size.rows) {
		if y >= self.rows.len {
			break
		}
		row := self.rows[y]
		graphemes_start := graphemes_seen

		for x in 0 .. int(self.size.cols) {
			if x >= row.cells.len {
				break
			}
			cell := row.cells[x]

			if cell.has_grapheme {
				// If a cell has grapheme data, it must actually have graphemes.
				if cell.graphemes.len == 0 {
					return IntegrityError.missing_grapheme_data
				}
				graphemes_seen++
			} else if total_graphemes > 0 {
				// It should not have grapheme data if it isn't marked.
				if cell.graphemes.len > 0 {
					return IntegrityError.unmarked_grapheme_cell
				}
			}

			if cell.style_id != default_style_id {
				if !row.styled {
					return IntegrityError.unmarked_style_row
				}
				styles_seen[cell.style_id] = styles_seen[cell.style_id] + 1
			}

			if cell.has_hyperlink {
				key := cell_key(y, x, int(self.capacity.cols))
				if key !in self.hyperlink_map {
					return IntegrityError.missing_hyperlink_data
				}
				if !row.hyperlink {
					return IntegrityError.unmarked_hyperlink_row
				}
				hl_id := self.hyperlink_map[key]
				hyperlinks_seen[hl_id] = hyperlinks_seen[hl_id] + 1
			} else {
				// It should not have hyperlink data if it isn't marked.
				key := cell_key(y, x, int(self.capacity.cols))
				if key in self.hyperlink_map {
					return IntegrityError.unmarked_hyperlink_cell
				}
			}

			// Check spacer validity.
			match cell.wide {
				.narrow, .wide {}
				.spacer_tail {
					// Spacer tails can't be at the start because they follow
					// a wide char.
					if x == 0 {
						return IntegrityError.invalid_spacer_tail_location
					}
					// Spacer tails must follow a wide char.
					prev := row.cells[x - 1]
					if prev.wide != .wide {
						return IntegrityError.invalid_spacer_tail_location
					}
				}
				.spacer_head {
					// Spacer heads must be at the end.
					if x != int(self.size.cols) - 1 {
						return IntegrityError.invalid_spacer_head_location
					}
					// The row must be wrapped.
					if !row.wrap {
						return IntegrityError.unwrapped_spacer_head
					}
				}
			}
		}

		// Check row grapheme data.
		if graphemes_seen > graphemes_start {
			// If a cell in a row has grapheme data, the row must
			// be marked as having grapheme data.
			if !row.grapheme {
				return IntegrityError.unmarked_grapheme_row
			}
		}
	}

	// Our graphemes seen should not exceed the grapheme count.
	if graphemes_seen > total_graphemes {
		return IntegrityError.invalid_grapheme_count
	}

	// Verify all our styles have the correct ref count.
	for style_id, count in styles_seen {
		rc := self.styles.ref_count(style_id)
		if rc < count {
			return IntegrityError.mismatched_style_ref
		}
	}

	// Verify all our hyperlinks have the correct ref count.
	for hl_id, count in hyperlinks_seen {
		rc := self.hyperlink_set.ref_count(hl_id)
		if rc < count {
			return IntegrityError.mismatched_hyperlink_ref
		}
	}

	return none
}

// A helper that verifies integrity and panics on violation.
pub fn (self &Page) assert_integrity() {
	if violation := self.verify_integrity() {
		panic('page integrity violation: ${violation}')
	}
}

// Temporarily pause or resume integrity checks around multi-step mutations.
pub fn (mut self Page) pause_integrity_checks_set(pause bool) {
	if pause {
		self.pause_integrity_checks += 1
	} else {
		assert self.pause_integrity_checks > 0
		self.pause_integrity_checks -= 1
	}
}

// Clone the contents of this page. This creates a deep copy.
pub fn (self &Page) clone() Page {
	mut new_rows := []RowData{cap: self.rows.len}
	for row in self.rows {
		mut new_cells := []CellData{cap: row.cells.len}
		for cell in row.cells {
			mut new_cell := CellData{
				codepoint: cell.codepoint
				content_tag: cell.content_tag
				style_id: cell.style_id
				wide: cell.wide
				is_protected: cell.is_protected
				has_grapheme: cell.has_grapheme
				has_hyperlink: cell.has_hyperlink
				semantic_content: cell.semantic_content
				color_palette: cell.color_palette
				color_rgb_r: cell.color_rgb_r
				color_rgb_g: cell.color_rgb_g
				color_rgb_b: cell.color_rgb_b
				style: cell.style
			}
			if cell.graphemes.len > 0 {
				new_cell.graphemes = cell.graphemes.clone()
			}
			if cell.has_hyperlink {
				new_cell.hyperlink = cell.hyperlink.dupe()
			}
			new_cells << new_cell
		}
		new_rows << RowData{
			cells: new_cells
			wrap: row.wrap
			wrap_continuation: row.wrap_continuation
			grapheme: row.grapheme
			styled: row.styled
			hyperlink: row.hyperlink
			semantic_prompt: row.semantic_prompt
			kitty_virtual_placeholder: row.kitty_virtual_placeholder
			dirty: row.dirty
		}
	}

	// Deep copy the styles.
	new_styles := self.styles.clone()

	// Deep copy hyperlink set.
	mut new_hl_set := HyperlinkSet{
		entries: self.hyperlink_set.entries.clone()
	}

	// Clone hyperlink map.
	mut new_hl_map := map[u64]u32{}
	for k, v in self.hyperlink_map {
		new_hl_map[k] = v
	}

	return Page{
		rows: new_rows
		dirty: self.dirty
		size: self.size
		capacity: self.capacity
		styles: new_styles
		hyperlink_set: new_hl_set
		hyperlink_map: new_hl_map
	}
}

// Compute the exact capacity required to store a range of rows from
// this page.
//
// The returned capacity will have the same number of columns as this
// page and the number of rows equal to the range given.
//
// Preconditions:
// - Range must be at least 1 row
// - Start and end must be valid for this page
pub fn (self &Page) exact_row_capacity(y_start int, y_end int) PageCapacity {
	assert y_start < y_end
	assert y_end <= int(self.size.rows)

	// Track unique style IDs.
	mut style_ids := map[u32]bool{}
	mut grapheme_bytes := u32(0)

	// First pass: count styles and grapheme bytes.
	for y in y_start .. y_end {
		if y >= self.rows.len {
			break
		}
		row := self.rows[y]
		for x in 0 .. int(self.size.cols) {
			if x >= row.cells.len {
				break
			}
			cell := row.cells[x]
			if cell.style_id != default_style_id {
				style_ids[cell.style_id] = true
			}
			if cell.has_grapheme && cell.graphemes.len > 0 {
				// Each grapheme allocation rounds up to grapheme_chunk.
				bytes := u32(cell.graphemes.len) * 4 // sizeof(u32)
				// Round up to grapheme_chunk.
				chunks := (bytes + u32(grapheme_chunk) - 1) / u32(grapheme_chunk)
				grapheme_bytes += chunks * u32(grapheme_chunk)
			}
		}
	}

	styles_cap := StyleSet.capacity_for_count(style_ids.len)

	// Second pass: size both the hyperlink set and its cell-to-ID map, and
	// count the page-owned URI/explicit-ID string allocations once per link.
	mut hyperlink_ids := map[u32]bool{}
	mut hyperlink_cells := 0
	mut string_bytes := u32(0)
	for y in y_start .. y_end {
		if y >= self.rows.len {
			break
		}
		row := self.rows[y]
		for x in 0 .. int(self.size.cols) {
			if x >= row.cells.len {
				break
			}
			if !row.cells[x].has_hyperlink {
				continue
			}

			hyperlink_cells++
			id := self.lookup_hyperlink(y, x) or { continue }
			if id in hyperlink_ids {
				continue
			}
			hyperlink_ids[id] = true

			entry := self.hyperlink_set.get(id)
			string_bytes += u32(page_align_forward(usize(entry.uri.len), string_chunk))
			match entry.id {
				HyperlinkExplicitId {
					string_bytes += u32(page_align_forward(usize(entry.id.value.len), string_chunk))
				}
				else {}
			}
		}
	}

	hyperlink_set_cap := HyperlinkSet.capacity_for_count(hyperlink_ids.len)
	hyperlink_map_min := (hyperlink_cells + hyperlink_cell_multiplier - 1) / hyperlink_cell_multiplier
	hyperlink_cap := if hyperlink_set_cap > hyperlink_map_min {
		hyperlink_set_cap
	} else {
		hyperlink_map_min
	}

	return PageCapacity{
		cols: self.size.cols
		rows: u16(y_end - y_start)
		styles: styles_cap
		hyperlink_bytes: u16(hyperlink_cap * int(hyperlink_set_item_size))
		grapheme_bytes: grapheme_bytes
		string_bytes: string_bytes
	}
}

// Clone the contents of another page into this page. The capacities
// can be different, but the size of the other page must fit into
// this page.
//
// The y_start and y_end parameters allow you to clone only a portion
// of the other page. This is useful for splitting a page into two
// or more pages.
//
// The column count of this page will always be the same as this page.
// If the other page has more columns, the extra columns will be
// truncated. If the other page has fewer columns, the extra columns
// will be zeroed.
pub fn (mut self Page) clone_from(other &Page, y_start u16, y_end u16) {
	assert y_start <= y_end
	assert y_end <= other.size.rows

	count := int(y_end) - int(y_start)
	for i in 0 .. count {
		src_idx := int(y_start) + i
		if src_idx >= other.rows.len || i >= self.rows.len {
			break
		}
		self.clone_row_from(other, u16(i), u16(src_idx))
	}
}

// Clone a single row from another page into this page.
pub fn (mut self Page) clone_row_from(other &Page, dst_row_idx u16, src_row_idx u16) {
	if clone_error := self.try_clone_row_from(other, dst_row_idx, src_row_idx) {
		panic('page row clone failed: ${clone_error}')
	}
}

// Clone a single row from another page into this page, supporting
// partial copy. clone_row_from calls this.
pub fn (mut self Page) clone_partial_row_from(other &Page, dst_row_idx u16, src_row_idx u16, x_start u16, x_end_req u16) {
	if clone_error := self.try_clone_partial_row_from(other, dst_row_idx, src_row_idx, x_start, x_end_req) {
		panic('partial page row clone failed: ${clone_error}')
	}
}

fn (mut self Page) try_clone_row_from(other &Page, dst_row_idx u16, src_row_idx u16) ?PageCloneError {
	return self.try_clone_partial_row_from(other, dst_row_idx, src_row_idx, 0, self.size.cols)
}

// Failable core of clone_partial_row_from. PageList consumes this result to
// grow a bounded style set and retry, matching Ghostty's cloneRowFrom callers.
fn (mut self Page) try_clone_partial_row_from(other &Page, dst_row_idx u16, src_row_idx u16, x_start u16, x_end_req u16) ?PageCloneError {
	if int(src_row_idx) >= other.rows.len || int(dst_row_idx) >= self.rows.len {
		return none
	}

	cell_len := if self.size.cols < other.size.cols { self.size.cols } else { other.size.cols }
	x_end := if x_end_req < cell_len { x_end_req } else { cell_len }

	src_row := other.rows[int(src_row_idx)]
	mut dst_row := &self.rows[int(dst_row_idx)]

	// If our destination has styles or graphemes then we need to
	// clear some state.
	if dst_row.managed_memory() {
		self.clear_cells(dst_row_idx, x_start, x_end)
	}

	// Copy row metadata but adjust if partial copy.
	is_full_row := (int(x_end) - int(x_start)) >= int(self.size.cols)
	if is_full_row {
		dst_row.wrap = src_row.wrap
		dst_row.wrap_continuation = src_row.wrap_continuation
		dst_row.grapheme = src_row.grapheme
		dst_row.hyperlink = src_row.hyperlink
		dst_row.styled = src_row.styled
		dst_row.semantic_prompt = src_row.semantic_prompt
		dst_row.kitty_virtual_placeholder = src_row.kitty_virtual_placeholder
		dst_row.dirty = src_row.dirty
	} else {
		// For partial copy, keep original flags for non-copied regions.
		dst_row.dirty = dst_row.dirty || src_row.dirty
	}

	// Copy cells.
	same_page := unsafe { voidptr(other) == voidptr(&self) }
	for xi in int(x_start) .. int(x_end) {
		if xi >= src_row.cells.len || xi >= dst_row.cells.len {
			break
		}
		src_cell := src_row.cells[xi]
		mut dst_cell := CellData{
			codepoint: src_cell.codepoint
			content_tag: if src_cell.content_tag == .codepoint_grapheme {
				ContentTag.codepoint
			} else {
				src_cell.content_tag
			}
			wide: src_cell.wide
			is_protected: src_cell.is_protected
			semantic_content: src_cell.semantic_content
			color_palette: src_cell.color_palette
			color_rgb_r: src_cell.color_rgb_r
			color_rgb_g: src_cell.color_rgb_g
			color_rgb_b: src_cell.color_rgb_b
			style: src_cell.style
		}

		// Copy graphemes.
		if src_cell.has_grapheme && src_cell.graphemes.len > 0 {
			dst_cell.graphemes = src_cell.graphemes.clone()
			dst_cell.has_grapheme = true
			dst_cell.content_tag = .codepoint_grapheme
			dst_row.grapheme = true
		}

		// Copy hyperlinks.
		if src_cell.has_hyperlink {
			dst_cell.hyperlink = src_cell.hyperlink.dupe()
			src_key := cell_key(int(src_row_idx), xi, int(other.capacity.cols))
			if src_key in other.hyperlink_map {
				dst_key := cell_key(int(dst_row_idx), xi, int(self.capacity.cols))
				if dst_key !in self.hyperlink_map && self.hyperlink_count() >= self.hyperlink_capacity() {
					return .hyperlink_map_out_of_memory
				}
				src_hl_id := other.hyperlink_map[src_key]
				hl_id := if same_page {
					// Same page: reuse the hyperlink ID.
					self.hyperlink_set.use_link(src_hl_id)
					src_hl_id
				} else {
					// Different page: clone the hyperlink, preferring the
					// source ID just like Ghostty's addWithIdContext path.
					src_link := other.hyperlink_set.get(src_hl_id)
					self.hyperlink_set.add_with_id(src_link, src_hl_id)
				}
				self.hyperlink_map[dst_key] = hl_id
				dst_cell.has_hyperlink = true
				dst_row.hyperlink = true
			}
		}

		// Copy styles.
		if src_cell.style_id != default_style_id {
			if same_page {
				// Same page: use the same style ID.
				dst_cell.style_id = src_cell.style_id
				self.styles.use_style(src_cell.style_id)
			} else {
				// Different page: add the style to our set.
				src_style := other.styles.get(src_cell.style_id)
				dst_cell.style_id = self.styles.add_with_id(src_style, src_cell.style_id) or {
					return .style_set_out_of_memory
				}
			}
			dst_row.styled = true
		}

		// Copy Kitty virtual placeholder status.
		if src_cell.codepoint_val() == kitty_unicode_placeholder {
			dst_row.kitty_virtual_placeholder = true
		}

		dst_row.cells[xi] = dst_cell
	}

	// If we are growing columns, then we need to ensure spacer heads
	// are cleared.
	if self.size.cols > other.size.cols {
		last_idx := int(other.size.cols) - 1
		if last_idx >= 0 && last_idx < dst_row.cells.len {
			if dst_row.cells[last_idx].wide == .spacer_head {
				dst_row.cells[last_idx].wide = .narrow
			}
		}
	}
	return none
}

// Get a single row. y must be valid.
pub fn (self &Page) get_row(y int) &RowData {
	assert y < int(self.size.rows)
	return &self.rows[y]
}

// Get the cells for a row.
pub fn (self &Page) get_cells(row &RowData) []CellData {
	return row.cells[..int(self.size.cols)]
}

// Get the row and cell for the given X/Y within this page.
pub struct RowAndCell {
pub mut:
	row  &RowData = unsafe { nil }
	cell &CellData = unsafe { nil }
}

pub fn (mut self Page) get_row_and_cell(x int, y int) RowAndCell {
	assert y < int(self.size.rows)
	assert x < int(self.size.cols)
	return RowAndCell{
		row: unsafe { &self.rows[y] }
		cell: unsafe { &self.rows[y].cells[x] }
	}
}

// Move cells from one location to another. This will replace the
// previous contents with a blank cell. Because this is a move, this
// doesn't allocate and can't fail.
pub fn (mut self Page) move_cells(src_row_idx int, src_left int, dst_row_idx int, dst_left int, len int) {
	// Clear our destination no matter what.
	self.clear_cells(u16(dst_row_idx), u16(dst_left), u16(dst_left + len))

	mut src_row := &self.rows[src_row_idx]
	mut dst_row := &self.rows[dst_row_idx]

	// If src has no managed memory, this is very fast.
	if !src_row.managed_memory() {
		for i in 0 .. len {
			dst_row.cells[dst_left + i] = src_row.cells[src_left + i]
		}
	} else {
		// Source has graphemes or hyperlinks...
		for i in 0 .. len {
			si := src_left + i
			di := dst_left + i
			src_cell := src_row.cells[si]
			dst_row.cells[di] = src_cell

			if src_cell.has_grapheme {
				// Move grapheme data.
				dst_row.cells[di].graphemes = src_cell.graphemes.clone()
				dst_row.cells[di].has_grapheme = true
				dst_row.cells[di].content_tag = .codepoint_grapheme
				dst_row.grapheme = true
			}
			if src_cell.has_hyperlink {
				src_key := cell_key(src_row_idx, si, int(self.capacity.cols))
				if src_key in self.hyperlink_map {
					hl_id := self.hyperlink_map[src_key]
					self.hyperlink_map.delete(src_key)
					dst_key := cell_key(dst_row_idx, di, int(self.capacity.cols))
					self.hyperlink_map[dst_key] = hl_id
					dst_row.cells[di].has_hyperlink = true
					dst_row.hyperlink = true
				}
			}
			if src_cell.codepoint_val() == kitty_unicode_placeholder {
				dst_row.kitty_virtual_placeholder = true
			}
		}
	}

	// The destination row has styles if any of the cells are styled.
	if !dst_row.styled {
		for i in 0 .. len {
			if dst_row.cells[dst_left + i].style_id != default_style_id {
				dst_row.styled = true
				break
			}
		}
	}

	// Clear source row cells. We can NOT use clear_cells here because
	// clear_cells will garbage collect our styles and graphemes but we
	// moved them above.
	for i in 0 .. len {
		src_row.cells[src_left + i] = CellData{}
	}
	if len == int(self.size.cols) {
		src_row.grapheme = false
		src_row.hyperlink = false
		src_row.styled = false
		src_row.kitty_virtual_placeholder = false
	}
}

// Swap two cells within the same row as quickly as possible.
pub fn (mut self Page) swap_cells(row_idx int, src_x int, dst_x int) {
	mut row := &self.rows[row_idx]

	// Graphemes are keyed by cell, so we do have to move them.
	src_has_grapheme := row.cells[src_x].has_grapheme
	dst_has_grapheme := row.cells[dst_x].has_grapheme
	if src_has_grapheme || dst_has_grapheme {
		// Just swap the grapheme data in place since it's on the cells.
	}

	// Hyperlinks are keyed by cell position, so swap map entries.
	src_has_hl := row.cells[src_x].has_hyperlink
	dst_has_hl := row.cells[dst_x].has_hyperlink
	if src_has_hl || dst_has_hl {
		src_key := cell_key(row_idx, src_x, int(self.capacity.cols))
		dst_key := cell_key(row_idx, dst_x, int(self.capacity.cols))
		src_hl := self.hyperlink_map[src_key] or { 0 }
		dst_hl := self.hyperlink_map[dst_key] or { 0 }
		if src_has_hl && dst_has_hl {
			self.hyperlink_map[src_key] = dst_hl
			self.hyperlink_map[dst_key] = src_hl
		} else if src_has_hl {
			self.hyperlink_map.delete(src_key)
			self.hyperlink_map[dst_key] = src_hl
		} else {
			self.hyperlink_map.delete(dst_key)
			self.hyperlink_map[src_key] = dst_hl
		}
	}

	// Swap the cells themselves.
	old_dst := row.cells[dst_x]
	row.cells[dst_x] = row.cells[src_x]
	row.cells[src_x] = old_dst
}

// Clear the cells in the given row. This will reclaim memory used
// by graphemes and styles. Note that if the style cleared is still
// active, Page cannot know this and it will still be ref counted down.
// The best solution for this is to artificially increment the ref count
// prior to calling this function.
pub fn (mut self Page) clear_cells(row_idx u16, left u16, end u16) {
	if int(row_idx) >= self.rows.len {
		return
	}
	mut row := &self.rows[int(row_idx)]
	cols := int(self.size.cols)

	// If we have managed memory (styles, graphemes, or hyperlinks)
	// in this row then we go cell by cell and clear them if present.
	if row.grapheme {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_grapheme {
				row.cells[x].graphemes = []
				row.cells[x].has_grapheme = false
				row.cells[x].content_tag = .codepoint
			}
		}
		// If we cleared the full row width, clear the flag.
		if int(end) - int(left) >= cols {
			row.grapheme = false
		} else {
			self.update_row_grapheme_flag(row)
		}
	}

	if row.hyperlink {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_hyperlink {
				key := cell_key(int(row_idx), x, int(self.capacity.cols))
				if key in self.hyperlink_map {
					hl_id := self.hyperlink_map[key]
					self.hyperlink_set.release(hl_id)
					self.hyperlink_map.delete(key)
				}
				row.cells[x].has_hyperlink = false
			}
		}
		if int(end) - int(left) >= cols {
			row.hyperlink = false
		} else {
			self.update_row_hyperlink_flag(row)
		}
	}

	if row.styled {
		for x in int(left) .. int(end) {
			if x < row.cells.len && row.cells[x].has_styling() {
				self.styles.release(row.cells[x].style_id)
			}
		}
		if int(end) - int(left) >= cols {
			row.styled = false
		} else {
			self.update_row_styled_flag(row)
		}
	}

	// Zero the cells.
	for x in int(left) .. int(end) {
		if x < row.cells.len {
			row.cells[x] = CellData{}
		}
	}
	row.dirty = true
}

// Clear an entire row.
pub fn (mut self Page) clear_row(row_idx u16) {
	self.clear_cells(row_idx, 0, self.size.cols)
	if int(row_idx) < self.rows.len {
		mut row := &self.rows[int(row_idx)]
		row.wrap = false
		row.wrap_continuation = false
		row.styled = false
		row.grapheme = false
		row.hyperlink = false
		row.semantic_prompt = .unknown
		row.kitty_virtual_placeholder = false
	}
}

// Returns the hyperlink ID for the given cell.
pub fn (self &Page) lookup_hyperlink(row_idx int, col_idx int) ?u32 {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))
	if key in self.hyperlink_map {
		return self.hyperlink_map[key]
	}
	return none
}

// Clear the hyperlink from the given cell.
//
// In order to update the hyperlink flag on the row, call
// update_row_hyperlink_flag after you finish clearing any
// hyperlinks in the row.
pub fn (mut self Page) clear_hyperlink(row_idx int, col_idx int) {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))
	if key in self.hyperlink_map {
		hl_id := self.hyperlink_map[key]
		self.hyperlink_set.release(hl_id)
		self.hyperlink_map.delete(key)
	}
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].has_hyperlink = false
	}
}

// Convert a hyperlink into a page entry, returning the ID.
//
// To release the memory associated with the given hyperlink,
// release the ID from the hyperlink_set. If the refcount reaches
// zero the slot is freed.
pub fn (mut self Page) insert_hyperlink(link Hyperlink) u32 {
	return self.hyperlink_set.add(link)
}

// Set the hyperlink for the given cell. If the cell already has a
// hyperlink, then this will handle memory management and refcount
// update for the prior hyperlink.
//
// DOES NOT increment the reference count for the new hyperlink!
//
// Caller is responsible for updating the refcount in the hyperlink
// set as necessary by calling use_link if the id was not acquired with
// add.
pub fn (mut self Page) set_hyperlink(row_idx int, col_idx int, id u32) ! {
	key := cell_key(row_idx, col_idx, int(self.capacity.cols))

	if key in self.hyperlink_map {
		old_id := self.hyperlink_map[key]
		// Always release the old hyperlink.
		self.hyperlink_set.release(old_id)
		self.hyperlink_map[key] = id
	} else {
		if self.hyperlink_count() >= self.hyperlink_capacity() {
			return error('HyperlinkMapOutOfMemory')
		}
		self.hyperlink_map[key] = id
	}
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].has_hyperlink = true
	}
	if row_idx < self.rows.len {
		self.rows[row_idx].hyperlink = true
	}
}

// Move the hyperlink from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
// Destination must NOT have a hyperlink.
fn (mut self Page) move_hyperlink(src_row int, src_col int, dst_row int, dst_col int) {
	src_key := cell_key(src_row, src_col, int(self.capacity.cols))
	dst_key := cell_key(dst_row, dst_col, int(self.capacity.cols))
	if src_key in self.hyperlink_map {
		hl_id := self.hyperlink_map[src_key]
		self.hyperlink_map.delete(src_key)
		self.hyperlink_map[dst_key] = hl_id
	}
	// NOTE: We must not set has_hyperlink here because this
	// function is used in various cases where we swap cell contents
	// and its unsafe. The flip side: the caller must be careful
	// to set the proper cell state to represent the move.
}

// Returns the number of hyperlinks in the page. This isn't the byte
// size but the total number of unique cells that have hyperlink data.
pub fn (self &Page) hyperlink_count() int {
	return self.hyperlink_map.len
}

// Returns the hyperlink capacity for the page.
pub fn (self &Page) hyperlink_capacity() int {
	return int(Page.layout(self.capacity).hyperlink_map_layout.capacity)
}

// Set the graphemes for the given cell. This asserts that the cell
// has no graphemes set, and only contains a single codepoint.
pub fn (mut self Page) set_graphemes(row_idx int, col_idx int, cps []u32) {
	mut row := &self.rows[row_idx]
	mut cell := &row.cells[col_idx]
	assert cell.codepoint > 0
	assert cell.content_tag == .codepoint

	cell.graphemes = cps.clone()
	cell.content_tag = .codepoint_grapheme
	cell.has_grapheme = true
	row.grapheme = true
}

// Append a codepoint to the given cell as a grapheme.
pub fn (mut self Page) append_grapheme(row_idx int, col_idx int, cp u32) {
	mut row := &self.rows[row_idx]
	mut cell := &row.cells[col_idx]

	cell.graphemes << cp
	if cell.content_tag != .codepoint_grapheme {
		cell.content_tag = .codepoint_grapheme
		cell.has_grapheme = true
		row.grapheme = true
	}
}

// Returns the codepoints for the given cell. These are the codepoints
// in addition to the first codepoint. The first codepoint is NOT
// included since it is on the cell itself.
pub fn (self &Page) lookup_grapheme(row_idx int, col_idx int) ?[]u32 {
	if row_idx >= self.rows.len {
		return none
	}
	row := self.rows[row_idx]
	if col_idx >= row.cells.len {
		return none
	}
	cell := row.cells[col_idx]
	if cell.has_grapheme && cell.graphemes.len > 0 {
		return cell.graphemes
	}
	return none
}

// Move the graphemes from one cell to another. This can't fail
// because we avoid any allocations since we're just moving data.
//
// WARNING: This will NOT change the content_tag on the cells because
// there are scenarios where we want to move graphemes without changing
// the content tag. Callers beware but assert_integrity should catch this.
fn (mut self Page) move_grapheme(src_row int, src_col int, dst_row int, dst_col int) {
	if src_row < self.rows.len && src_col < self.rows[src_row].cells.len {
		graphemes := self.rows[src_row].cells[src_col].graphemes.clone()
		self.rows[src_row].cells[src_col].graphemes = []
		self.rows[src_row].cells[src_col].has_grapheme = false
		self.rows[src_row].cells[src_col].content_tag = .codepoint
		if dst_row < self.rows.len && dst_col < self.rows[dst_row].cells.len {
			self.rows[dst_row].cells[dst_col].graphemes = graphemes
			self.rows[dst_row].cells[dst_col].has_grapheme = true
			self.rows[dst_row].cells[dst_col].content_tag = .codepoint_grapheme
		}
	}
}

// Clear the graphemes for a given cell.
//
// In order to update the grapheme flag on the row, call
// update_row_grapheme_flag after you finish clearing any
// graphemes in the row.
pub fn (mut self Page) clear_grapheme(row_idx int, col_idx int) {
	if row_idx < self.rows.len && col_idx < self.rows[row_idx].cells.len {
		self.rows[row_idx].cells[col_idx].graphemes = []
		self.rows[row_idx].cells[col_idx].has_grapheme = false
		// Mark that we no longer have graphemes by changing the content tag.
		self.rows[row_idx].cells[col_idx].content_tag = .codepoint
	}
}

// Checks if the row contains any graphemes and sets
// the grapheme flag to false if none are found.
//
// Call after removing graphemes in a row.
pub fn (mut self Page) update_row_grapheme_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_grapheme {
			return
		}
	}
	unsafe {
		mut r := row
		r.grapheme = false
	}
}

// Returns the number of graphemes in the page. This isn't the byte
// size but the total number of unique cells that have grapheme data.
pub fn (self &Page) grapheme_count() int {
	mut count := 0
	for row in self.rows {
		if !row.grapheme {
			continue
		}
		for cell in row.cells {
			if cell.has_grapheme {
				count++
			}
		}
	}
	return count
}

// Returns the number of unique cells that the pinned page's grapheme map can
// address without increasing capacity.
pub fn (self &Page) grapheme_capacity() int {
	return int(Page.layout(self.capacity).grapheme_map_layout.capacity)
}

// Checks if the row contains any hyperlinks and sets
// the hyperlink flag to false if none are found.
//
// Call after removing hyperlinks in a row.
pub fn (mut self Page) update_row_hyperlink_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_hyperlink {
			return
		}
	}
	unsafe {
		mut r := row
		r.hyperlink = false
	}
}

// Checks if the row contains any styles and sets
// the styled flag to false if none are found.
//
// Call after removing styles in a row.
pub fn (mut self Page) update_row_styled_flag(row &RowData) {
	for cell in row.cells {
		if cell.has_styling() {
			return
		}
	}
	unsafe {
		mut r := row
		r.styled = false
	}
}

// Returns true if this page is dirty at all.
pub fn (self &Page) is_dirty() bool {
	if self.dirty {
		return true
	}
	for y in 0 .. int(self.size.rows) {
		if y < self.rows.len && self.rows[y].dirty {
			return true
		}
	}
	return false
}

// Returns true if a row is entirely blank (no codepoints).
pub fn (self &Page) row_is_blank(row_idx u16) bool {
	if int(row_idx) >= self.rows.len {
		return true
	}
	row := self.rows[int(row_idx)]
	for cell in row.cells {
		if cell.has_text() {
			return false
		}
	}
	return true
}

// ============================================================
// Helper: cell key for hyperlink map
// ============================================================

// Compute a unique key for a cell position in the hyperlink map.
fn cell_key(row_idx int, col_idx int, max_cols int) u64 {
	return u64(row_idx) * u64(max_cols) + u64(col_idx)
}

// ============================================================
// PageNode - a node in the doubly-linked list of pages
// ============================================================

@[heap]
pub struct PageNode {
pub mut:
	prev   ?&PageNode
	next   ?&PageNode
	data   Page
	serial u64
}

// ============================================================
// PageNodeList - doubly-linked list of PageNode
// ============================================================

pub type PageNodeList = datastruct.IntrusiveDoublyLinkedList[PageNode]

// Pop and return the last node.
pub fn (mut self PageNodeList) pop_last() ?&PageNode {
	return self.pop()
}
