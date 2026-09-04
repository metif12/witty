module terminal

// --- Original Ghostty Comments Start: src/terminal/Terminal.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/Terminal.zig
//
// The primary terminal emulation structure. This represents a single
// "terminal" containing a grid of characters and exposes various operations
// on that grid. This also maintains the scrollback buffer.
// Default tabstop interval
// The set of screens behind this terminal (e.g. primary vs alternate).
// Whether we're currently writing to the status line (DECSASD and DECSSDT).
// We don't support a status line currently so we just black hole this
// data so that it doesn't mess up our main display.
// Where the tabstops are.
// The size of the terminal.
// The size of the screen in pixels. This is used for pty events and images
// The current scrolling region.
// The last reported pwd, if any.
// The color state for this terminal.
// The previous printed character. This is used for the repeat previous
// char CSI (ESC [ <n> b).
// The modes that this terminal currently has active.
// The most recently set mouse shape for the terminal.
// These are just a packed set of flags we may set on the terminal.
// This supports a Kitty extension where programs using semantic
// prompts (OSC133) can annotate their new prompts with `redraw=0` to
// disable clearing the prompt on resize.
// This is set via ESC[4;2m. Any other modify key mode just sets
// this to false and we act in mode 1 by default.
// The mouse event mode and format. These are set to the last
// set mode in modes. You can't get the right event/format to use
// based on modes alone because modes don't show you what order
// this was called so we have to track it separately.
// Set via the XTSHIFTESCAPE sequence. If true (XTSHIFTESCAPE = 1)
// then we want to capture the shift key for the mouse protocol
// if the configuration allows it.
// True if the window is focused.
// True if the terminal is in a password entry mode. This is set
// to true based on termios state. This is set
// to true based on termios state.
// True if the terminal should perform selection scrolling.
// Dirty flag used only by the search thread. The renderer is expected
// to set this to true if the viewport was dirty as it was rendering.
// This is used by the search thread to more efficiently re-search the
// viewport and active area.
//
// Since the renderer is going to inspect the viewport/active area ANYWAYS,
// this lets our search thread do less work and hold the lock less time,
// resulting in more throughput for everything.
// Dirty flags for the renderer.
// The various color configurations a terminal maintains and that can
// be set dynamically via OSC, with defaults usually coming from a
// configuration.
// This is a set of dirty flags the renderer can use to determine
// what parts of the screen need to be redrawn. It is up to the renderer
// to clear these flags.
//
// This only contains dirty flags for terminal state, not for the screen
// state. The screen state has its own dirty flags.
// Set when the color palette is modified in any way.
// Set when the reverse colors mode is modified.
// Screen clear of some kind. This can be due to a screen change,
// erase display, etc.
// Set when the pre-edit is modified.
// The event types that can be reported for mouse-related activities.
// These are all mutually exclusive (hence in a single enum).
// Returns true if this event sends motion events.
// The format of mouse events when enabled.
// These are all mutually exclusive (hence in a single enum).
// Scrolling region is the area of the screen designated where scrolling
// occurs. When scrolling the screen, only this viewport is scrolled.
// Top and bottom of the scroll region (0-indexed)
// Precondition: top < bottom
// Left/right scroll regions.
// Precondition: right > left
// Precondition: right <= cols - 1
// The default mode state. When the terminal gets a reset, it
// will revert back to this state.
// Initialize a new terminal.
// Return a terminal.Stream that can process VT streams and update this
// terminal state. The streams will only process read-only data that
// modifies terminal state. Sequences that query or otherwise require
// output will be ignored.
// This is the handler-side only for vtStream.
// The general allocator we should use for this terminal.
// Print UTF-8 encoded string to the terminal.
// Print the previous printed character a repeated amount of times.
// log.debug("print={x} y={} x={}", .{ c, self.screens.active.cursor.y, self.screens.active.cursor.x });
// If we're not on the main display, do nothing for now
// After doing any printing, wrapping, scrolling, etc. we want to ensure
// that our screen remains in a consistent state.
// Our right margin depends where our cursor is now.
// Perform grapheme clustering if grapheme support is enabled (mode 2027).
// This is MUCH slower than the normal path so the conditional below is
// purposely ordered in least-likely to most-likely so we can drop out
// as quickly as possible.
// We need the previous cell to determine if we're at a grapheme
// break or not. If we are NOT, then we are still combining the
// same grapheme. Otherwise, we can stay in this cell.
// If we have wraparound, then we always use the prev col
// If we do not have wraparound, the logic is trickier. If
// we're not on the last column, then we just use the previous
// column. Otherwise, we need to check if there is text to
// figure out if we're attaching to the prev or current.
// If the previous cell is a wide spacer tail, then we actually
// want to use the cell before that because that has the actual
// content.
// If our cell has no content, then this is a new cell and
// necessarily a grapheme break.
// log.debug("cp1={x} cp2={x}", .{ cp1, cp2 });
// log.debug("cp1={x} cp2={x} end", .{ cp1, c });
// If we can NOT break, this means that "c" is part of a grapheme
// with the previous char.
// If this is an emoji variation selector then we need to modify
// the cell width accordingly. VS16 makes the character wide and
// VS15 makes it narrow.
// Check if it is a valid variation sequence in
// emoji-variation-sequences.txt, and if not, ignore the char.
// Move our cursor back to the previous. We'll move
// the cursor within this block to the proper location.
// If we don't have space for the wide char, we need
// to insert spacers and wrap. Then we just print the wide
// char as normal.
// Write our spacer
// Move the cursor again so we're beyond our spacer
// Prev cell is no longer wide
// Remove the wide spacer tail
// Back track the cursor so that we don't end up with
// an extra space after the character. Since xterm is
// not VS aware, it cannot be used as a reference for
// this behavior; but it does follow the principle of
// least surprise, and also matches the behavior that
// can be observed in Kitty, which is one of the only
// other VS aware terminals.
// If we're already at the right edge, we stay
// here and set the pending wrap to false since
// when we pend a wrap, we only move our cursor once
// even for wide chars (tests verify).
// Otherwise, move back.
// Determine the width of this character so we can handle
// non-single-width characters properly. We have a fast-path for
// byte-sized characters since they're so common. We can ignore
// control characters because they're always filtered prior.
// Note: it is possible to have a width of "3" and a width of "-1" from
// uucode.x's wcwidth. We should look into those cases and handle them
// appropriately.
// log.debug("c={x} width={}", .{ c, width });
// Attach zero-width characters to our cell as grapheme data.
// If we have grapheme clustering enabled, we don't blindly attach
// any zero width character to our cells and we instead just ignore
// it.
// If we're at cell zero, then this is malformed data and we don't
// print anything or even store this. Zero-width characters are ALWAYS
// attached to some other non-zero-width character at the time of
// writing.
// Find our previous cell
// If our previous cell has no text, just ignore the zero-width character
// If this is a emoji variation selector, prev must be an emoji
// We have a printable character, save it
// If we're soft-wrapping, then handle that first.
// If we have insert mode enabled then we need to handle that. We
// only do insert mode if we're not at the end of the line.
// Single cell is very easy: just write in the cell
// Wide character requires a spacer. We print this by
// using two cells: the first is flagged "wide" and has the
// wide char. The second is guaranteed to be a spacer if
// we're not at the end of the line.
// If we don't have space for the wide char, we need
// to insert spacers and wrap. Then we just print the wide
// char as normal.
// If we don't have wraparound enabled then we don't print
// this character at all and don't move the cursor. This is
// how xterm behaves.
// We only create a spacer head if we're at the real edge
// of the screen. Otherwise, we clear the space with a narrow.
// This allows soft wrapping to work correctly.
// This is pretty broken, terminals should never be only 1-wide.
// We should prevent this downstream.
// If we're at the column limit, then we need to wrap the next time.
// In this case, we don't move the cursor.
// Move the cursor
// TODO: spacers should use a bgcolor only cell
// TODO: non-utf8 handling, gr
// If we're single shifting, then we use the key exactly once.
// UTF-8 or ASCII is used as-is
// If we're outside of ASCII range this is an invalid value in
// this table so we just return space.
// Get our lookup table and map it
// If the wide property of this cell is the same, then we don't
// need to do the special handling here because the structure will
// be the same. If it is NOT the same, then we may need to clear some
// cells.
// Previous cell was narrow. Do nothing.
// Previous cell was wide. We need to clear the tail and head.
// So integrity checks pass. We fix this up later so we don't
// need to do this without safety checks.
// TODO: this case was not handled in the old terminal implementation
// but it feels like we should do something. investigate other
// terminals (xterm mainly) and see what's up.
// If the prior value had graphemes, clear those
// We don't need to update the style refs unless the
// cell's new style will be different after writing.
// Release the old style.
// Keep track if we had a hyperlink so we can unset it.
// Write
// Use the new style.
// If this is a Kitty unicode placeholder then we need to mark the
// row so that the renderer can lookup rows with these much faster.
// We check for an active hyperlink first because setHyperlink
// handles clearing the old hyperlink and an optimization if we're
// overwriting the same hyperlink.
// If the previous cell had a hyperlink then we need to clear it.
// We only mark that we soft-wrapped if we're at the edge of our
// full screen. We don't mark the row as wrapped if we're in the
// middle due to a right margin.
// Get the old semantic prompt so we can extend it to the next
// line. We need to do this before we index() because we may
// modify memory.
// Move to the next line
// Our pointer should never move
// We always reset our semantic prompt state
// Always mark the row as a continuation
// Assure that our screen is consistent
// Set the charset into the given slot.
// Invoke the charset in slot into the active slot. If single is true,
// then this will only be invoked for a single character.
// Carriage return moves the cursor to the first column.
// Always reset pending wrap state
// In origin mode we always move to the left margin
// Linefeed moves the cursor to the next line.
// Backspace moves the cursor back a column (but not less than 0).
// Move the cursor up amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. If amount is
// 0, adjust it to 1.
// Always resets pending wrap
// The maximum amount the cursor can move up depends on scrolling regions
// We can safely intCast below because of the min/max clamping we did above.
// Move the cursor down amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. This sequence
// will not scroll the screen or scroll region. If amount is 0, adjust it to 1.
// Always resets pending wrap
// The max the cursor can move to depends where the cursor currently is
// Move the cursor right amount columns. If amount is greater than the
// maximum move distance then it is internally adjusted to the maximum.
// This sequence will not scroll the screen or scroll region. If amount is
// 0, adjust it to 1.
// Always resets pending wrap
// The max the cursor can move to depends where the cursor currently is
// Move the cursor to the left amount cells. If amount is 0, adjust it to 1.
// Wrapping behavior depends on various terminal modes
// If we are in no wrap mode, then we move the cursor left and exit
// since this is the fastest and most typical path.
// If we have a pending wrap state and we are in either reverse wrap
// modes then we decrement the amount we move by one to match xterm.
// The margins we can move to.
// Handle some edge cases when our cursor is already on the left margin.
// In reverse mode, if we're already before the top margin
// then we just set our cursor to the top-left and we're done.
// Handled in while loop
// Handled above
// We can move at most to the left margin.
// We want to move at most the number of columns we have left
// or our remaining count. Do the move.
// If we have no more to move, then we're done.
// If we are at the top, then we are done.
// UNDEFINED TERMINAL BEHAVIOR. This situation is not handled in xterm
// and currently results in a crash in xterm. Given no other known
// terminal [to me] implements XTREVWRAP2, I decided to just mimic
// the behavior of xterm up and not including the crash by wrapping
// up to the (0, 0) and stopping there. My reasoning is that for an
// appropriately sized value of "count" this is the behavior that xterm
// would have. This is unit tested.
// If our previous line is not wrapped then we are done.
// Save cursor position and further state.
//
// The primary and alternate screen have distinct save state. One saved state
// is kept per screen (main / alternative). If for the current screen state
// was already saved it is overwritten.
// Restore cursor position and other state.
//
// The primary and alternate screen have distinct save state.
// If no save was done before values are reset to their initial values.
// Set the style first because it can fail
// Regardless of the error here, we revert back to an unstyled
// cursor. It is more important that the restore succeeds in
// other attributes because terminals have no way to communicate
// failure back.
// Ensure our screen is consistent
// Set the character protection mode for the terminal.
// screen.protected_mode is NEVER reset to ".off" because
// logic such as eraseChars depends on knowing what the
// _most recent_ mode was.
// Perform a semantic prompt command.
//
// If there is an error, we do our best to get the terminal into
// some coherent state, since callers typically can't handle errors
// (since they're sending sequences via the pty).
// "First do a fresh-line."
// "Subsequent text (until a OSC "133;B" or OSC "133;I" command)
// is a prompt string (as if followed by OSC 133;P;k=i\007)."
// This is a kitty-specific flag that notes that the shell
// is NOT capable of redraw. Redraw defaults to true so this
// usually just disables it, but either is possible.
// Handle click_events as a priority over cl. click_events
// is another Kitty-specific extension that converts clicks
// within a prompt area to SGR mouse events and defers to the
// shell to handle them.
// If click_events was not set or disabled, fallback to `cl`.
// The "aid" and "cl" options are also valid for this
// command but we don't yet handle these in any meaningful way.
// Spec:
// Same as OSC "133;A" but may first implicitly terminate a
// previous command: if the options specify an aid and there
// is an active (open) command with matching aid, finish the
// innermost such command (as well as any other commands
// nested more deeply). If no aid is specified, treat as an
// aid whose value is the empty string.
// Ghostty:
// We don't currently do explicit command tracking in any way
// so there is no need to terminate prior commands. We just
// perform the `A` action.
// Explicit start of prompt. Optional after an A or N command.
// The k (kind) option specifies the type of prompt:
// regular primary prompt (k=i or default),
// right-side prompts (k=r), or prompts for continuation lines (k=c or k=s).
// End of prompt and start of user input, terminated by a OSC
// "133;C" or another prompt (OSC "133;P").
// End of prompt and start of user input, terminated by end-of-line.
// "End of input, and start of output."
// If our current row is marked as a prompt and we're
// at column zero then we assume we're un-prompting. This
// is a heuristic to deal with fish, mostly. The issue that
// fish brings up is that it has no PS2 equivalent and its
// builtin OSC133 marking doesn't output continuation lines
// as k=s. So, we assume when we get a newline with a prompt
// cursor that the new line is also a prompt. But fish changes
// to output on the newline. So if we're at col 0 we just assume
// we're overwriting the prompt.
// From a terminal state perspective, this doesn't really do
// anything. Other terminals appear to do nothing here. I think
// its reasonable at this point to reset our semantic content
// state but the spec doesn't really say what to do.
// OSC 133;L
// Spec: "If the cursor is the initial column (left, assuming
// left-to-right writing), do nothing" This specification is very under
// specified. We are taking the liberty to assume that in a left/right
// margin context, if the cursor is outside of the left margin, we treat
// it as being at the left margin for the purposes of this command.
// This is arbitrary. If someone has a better reasonable idea we can
// apply it.
// The semantic prompt type. This is used when tracking a line type and
// requires integration with the shell. By default, we mark a line as "none"
// meaning we don't know what type it is.
//
// See: https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md
// Returns true if the cursor is currently at a prompt. Another way to look
// at this is it returns false if the shell is currently outputting something.
// This requires shell integration (semantic prompt integration).
//
// If the shell integration doesn't exist, this will always return false.
// If we're on the secondary screen, we're never at a prompt.
// If our page row is a prompt then we're always at a prompt
// Otherwise, determine our cursor state
// Horizontal tab moves the cursor to the next tabstop, clearing
// the screen to the left the tabstop.
// Move the cursor right
// If the last cursor position was a tabstop we return. We do
// "last cursor position" because we want a space to be written
// at the tabstop unless we're at the end (the while condition).
// Same as horizontalTab but moves to the previous tabstop instead of the next.
// With origin mode enabled, our leftmost limit is the left margin.
// If we're already at the edge of the screen, then we're done.
// Move the cursor left
// Clear tab stops.
// Set a tab stop on the current cursor.
// TODO: test
// TODO: test
// Move the cursor to the next line in the scrolling region, possibly scrolling.
//
// If the cursor is outside of the scrolling region: move the cursor one line
// down if it is not on the bottom-most line of the screen.
//
// If the cursor is inside the scrolling region:
//   If the cursor is on the bottom-most line of the scrolling region:
//     invoke scroll up with amount=1
//   If the cursor is not on the bottom-most line of the scrolling region:
//     move the cursor one line down
//
// This unsets the pending wrap state without wrapping.
// Unset pending wrap state
// We handle our cursor semantic prompt state AFTER doing the
// scrolling, because we may need to apply to new rows.
// Always reset any semantic content clear-eol state.
//
// The specification is not clear what "end-of-line" means. If we
// discover that there are more scenarios we should be unsetting
// this we should document and test it.
// If we aren't clearing our state at EOL and we're not output,
// then we mark the new row as a prompt continuation. This is
// to work around shells that don't send OSC 133 k=s sequences
// for continuations.
//
// This can be a false positive if the shell changes content
// type later and outputs something. We handle that in the
// semanticPrompt function.
// This should never be set in the output mode.
// Outside of the scroll region we move the cursor one line down.
// We only move down if we're not already at the bottom of
// the screen.
// If the cursor is inside the scrolling region and on the bottom-most
// line, then we scroll up. If our scrolling region is the full screen
// we create scrollback.
// Scrolling dirties the images because it updates their placements pins.
// If our scrolling region is at the top, we create scrollback.
// Slow path for left and right scrolling region margins.
// PERF(mitchellh): If we have an SGR background set then
// we need to preserve that background in our erased rows.
// scrollUp does that but eraseRowBounded below does not.
// However, scrollUp is WAY slower. We should optimize this
// case to work in the eraseRowBounded codepath and remove
// this check.
// Otherwise use a fast path function from PageList to efficiently
// scroll the contents of the scrolling region.
// Preserve old cursor just for assertions
// eraseRow and eraseRowBounded will end up moving the cursor pin
// up by 1, so we need to move it back down. A `cursorReload`
// would be better option but this is more efficient and this is
// a super hot path so we do this instead.
// The operations above can prune our cursor style so we need to
// update. This should never fail because the above can only FREE
// memory.
// Increase cursor by 1, maximum to bottom of scroll region
// Move the cursor to the previous line in the scrolling region, possibly
// scrolling.
//
// If the cursor is outside of the scrolling region, move the cursor one
// line up if it is not on the top-most line of the screen.
//
// If the cursor is inside the scrolling region:
//
//   * If the cursor is on the top-most line of the scrolling region:
//     invoke scroll down with amount=1
//   * If the cursor is not on the top-most line of the scrolling region:
//     move the cursor one line up
// Set Cursor Position. Move cursor to the position indicated
// by row and column (1-indexed). If column is 0, it is adjusted to 1.
// If column is greater than the right-most column it is adjusted to
// the right-most column. If row is 0, it is adjusted to 1. If row is
// greater than the bottom-most row it is adjusted to the bottom-most
// row.
// If cursor origin mode is set the cursor row will be moved relative to
// the top margin row and adjusted to be above or at bottom-most row in
// the current scroll region.
//
// If origin mode is set and left and right margin mode is set the cursor
// will be moved relative to the left margin column and adjusted to be on
// or left of the right margin column.
// Unset pending wrap state
// Calculate our new x/y
// If the y is unchanged then this is fast pointer math
// If everything changed we do an absolute change which is slightly slower
// log.info("set cursor position: col={} row={}", .{ self.screens.active.cursor.x, self.screens.active.cursor.y });
// Set Top and Bottom Margins If bottom is not specified, 0 or bigger than
// the number of the bottom-most row, it is adjusted to the number of the
// bottom most row.
//
// If top < bottom set the top and bottom row of the scroll region according
// to top and bottom and move the cursor to the top-left cell of the display
// (when in cursor origin mode is set to the top-left cell of the scroll region).
//
// Otherwise: Set the top and bottom row of the scroll region to the top-most
// and bottom-most line of the screen.
//
// Top and bottom are 1-indexed.
// DECSLRM
// We must have this mode enabled to do anything
// Scroll the text down by one row.
// Preserve our x/y to restore.
// Move to the top of the scroll region
// Removes amount lines from the top of the scroll region. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up
// is filled with empty lines.
//
// The new lines are created according to the current SGR state.
//
// Does not change the (absolute) cursor position.
// Preserve our x/y to restore.
// If our scroll region is at the top and we have no left/right
// margins then we move the scrolled out text into the scrollback.
// Scrolling dirties the images because it updates their placements pins.
// Clamp count to the scroll region height.
// TODO: Create an optimized version that can scroll N times
// This isn't critical because in most cases, scrollUp is used
// with count=1, but it's still a big optimization opportunity.
// Move our cursor to the bottom of the scroll region so we can
// use the cursorScrollAbove function to create scrollback
// Move to the top of the scroll region
// Options for scrolling the viewport of the terminal grid.
// Scroll to the top of the scrollback
// Scroll to the bottom, i.e. the top of the active area
// Scroll by some delta amount, up is negative.
// Scroll the viewport of the terminal grid.
// To be called before shifting a row (as in insertLines and deleteLines)
//
// Takes care of boundary conditions such as potentially split wide chars
// across scrolling region boundaries and orphaned spacer heads at line
// ends.
// If our scrolling region includes the rightmost column then we
// need to turn any spacer heads in to normal empty cells, since
// once we move them they no longer correspond with soft-wrapped
// wide characters.
//
// If it contains either of the 2 leftmost columns, then the wide
// characters in the first column which may be associated with a
// spacer head will be either moved or cleared, so we also need
// to turn the spacer heads in to empty cells in that case.
// If the leftmost or rightmost cells of our scrolling region
// are parts of wide chars, we need to clear the cells' contents
// since they'd be split by the move.
// TODO(qwerasd): `insertLines` and `deleteLines` are 99% identical,
// the majority of their logic can (and should) be abstracted in to
// a single shared helper function, probably on `Screen` not here.
// I'm just too lazy to do that rn :p
// Insert amount lines at the current cursor row. The contents of the line
// at the current cursor row and below (to the bottom-most line in the
// scrolling region) are shifted down by amount lines. The contents of the
// amount bottom-most lines in the scroll region are lost.
//
// This unsets the pending wrap state without wrapping. If the current cursor
// position is outside of the current scroll region it does nothing.
//
// If amount is greater than the remaining number of lines in the scrolling
// region it is adjusted down (still allowing for scrolling out every remaining
// line in the scrolling region)
//
// In left and right margin mode the margins are respected; lines are only
// scrolled in the scroll region.
//
// All cleared space is colored according to the current SGR state.
//
// Moves the cursor to the left margin.
// Rare, but happens
// If the cursor is outside the scroll region we do nothing.
// Scrolling dirties the images because it updates their placements pins.
// At the end we need to return the cursor to the row it started on.
// Always unset pending wrap
// We have a slower path if we have left or right scroll margins.
// Remaining rows from our cursor to the bottom of the scroll region.
// We can only insert lines up to our remaining lines in the scroll
// region. So we take whichever is smaller.
// Create a new tracked pin which we'll use to navigate the page list
// so that if we need to adjust capacity it will be properly tracked.
// This error scenario means that our GPA is OOM. This is not a
// situation we can gracefully handle. We can't just ignore insertLines
// because it'll result in a corrupted screen. Ideally in the future
// we flag the state as broken and show an error message to the user.
// For now, we panic.
// Our current y position relative to the cursor
// Traverse from the bottom up
// If this is one of the lines we need to shift, do so
// If our scrolling region is full width, then we unset wrap.
// If our page doesn't match, then we need to do a copy from
// one page to another. This is the slow path.
// Adjust our page capacity to make
// room for we didn't have space for
// Rehash the sets
// Increase style memory
// Increase string memory
// Increase hyperlink memory
// Increase grapheme memory
// System OOM. We have no way to recover from this
// currently. We should probably change insertLines
// to raise an error here.
// The page can't accommodate the managed memory required
// for this operation. We previously just corrupted
// memory here so a crash is better. The right long
// term solution is to allocate a new page here
// move this row to the new page, and start over.
// Continue the loop to try handling this row again.
// Swap the src/dst cells. This ensures that our dst gets the
// proper shifted rows and src gets non-garbage cell data that
// we can clear.
// Ensure what we did didn't corrupt the page
// Left/right scroll margins we have to
// copy cells, which is much slower...
// Clear the cells for this row, it has been shifted.
// Mark the row as dirty
// We have successfully processed a line.
// Move our pin up to the next row.
// Removes amount lines from the current cursor row down. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up is
// filled with empty lines.
//
// If the current cursor position is outside of the current scroll region it
// does nothing. If amount is greater than the remaining number of lines in the
// scrolling region it is adjusted down.
//
// In left and right margin mode the margins are respected; lines are only
// scrolled in the scroll region.
//
// If the cell movement splits a multi cell character that character cleared,
// by replacing it by spaces, keeping its current attributes. All other
// cleared space is colored according to the current SGR state.
//
// Moves the cursor to the left margin.
// Rare, but happens
// If the cursor is outside the scroll region we do nothing.
// Scrolling dirties the images because it updates their placements pins.
// At the end we need to return the cursor to the row it started on.
// Always unset pending wrap
// We have a slower path if we have left or right scroll margins.
// Remaining rows from our cursor to the bottom of the scroll region.
// We can only insert lines up to our remaining lines in the scroll
// region. So we take whichever is smaller.
// Create a new tracked pin which we'll use to navigate the page list
// so that if we need to adjust capacity it will be properly tracked.
// See insertLines
// Our current y position relative to the cursor
// Traverse from the top down
// If this is one of the lines we need to shift, do so
// If our scrolling region is full width, then we unset wrap.
// If our page doesn't match, then we need to do a copy from
// one page to another. This is the slow path.
// Adjust our page capacity to make
// room for we didn't have space for
// Rehash the sets
// Increase style memory
// Increase string memory
// Increase hyperlink memory
// Increase grapheme memory
// See insertLines
// Continue the loop to try handling this row again.
// Swap the src/dst cells. This ensures that our dst gets the
// proper shifted rows and src gets non-garbage cell data that
// we can clear.
// Ensure what we did didn't corrupt the page
// Left/right scroll margins we have to
// copy cells, which is much slower...
// Clear the cells for this row, it's from out of bounds.
// Mark the row as dirty
// We have successfully processed a line.
// Move our pin down to the next row.
// Inserts spaces at current cursor position moving existing cell contents
// to the right. The contents of the count right-most columns in the scroll
// region are lost. The cursor position is not changed.
//
// This unsets the pending wrap state without wrapping.
//
// The inserted cells are colored according to the current SGR state.
// Unset pending wrap state without wrapping. Note: this purposely
// happens BEFORE the scroll region check below, because that's what
// xterm does.
// If our cursor is outside the margins then do nothing. We DO reset
// wrap state still so this must remain below the above logic.
// If our count is larger than the remaining amount, we just erase right.
// We only do this if we can erase the entire line (no right margin).
// if (right_limit == self.cols and
//     count > right_limit - self.screens.active.cursor.x)
// {
//     self.eraseLine(.right, false);
//     return;
// }
// left is just the cursor position but as a multi-pointer
// If our X is a wide spacer tail then we need to erase the
// previous cell too so we don't split a multi-cell character.
// Remaining cols from our cursor to the right margin.
// We can only insert blanks up to our remaining cols
// This is the amount of space at the right of the scroll region
// that will NOT be blank, so we need to shift the correct cols right.
// "scroll_amount" is the number of such cols.
// If our last cell we're shifting is wide, then we need to clear
// it to be empty so we don't split the multi-cell char.
// We work backwards so we don't overwrite data.
// Insert blanks. The blanks preserve the background color.
// Our row is always dirty
// Removes amount characters from the current cursor position to the right.
// The remaining characters are shifted to the left and space from the right
// margin is filled with spaces.
//
// If amount is greater than the remaining number of characters in the
// scrolling region, it is adjusted down.
//
// Does not change the cursor position.
// If our cursor is outside the margins then do nothing. We DO reset
// wrap state still so this must remain below the above logic.
// left is just the cursor position but as a multi-pointer
// Remaining cols from our cursor to the right margin.
// We can only insert blanks up to our remaining cols
// This is the amount of space at the right of the scroll region
// that will NOT be blank, so we need to shift the correct cols right.
// "scroll_amount" is the number of such cols.
// Insert blanks. The blanks preserve the background color.
// Our row's soft-wrap is always reset.
// Our row is always dirty
// If our last cell is a wide char then we need to also clear the
// cell beyond it since we can't just split a wide char.
// Handle any boundary conditions on the edges of the erased area.
//
// TODO(qwerasd): This isn't actually correct if you take in to account
// protected modes. We need to figure out how to make `clearCells` or at
// least `clearUnprotectedCells` handle boundary conditions...
// Reset our row's soft-wrap.
// Mark our cursor row as dirty
// Clear the cells
// If we never had a protection mode, then we can assume no cells
// are protected and go with the fast path. If the last protection
// mode was not ISO we also always ignore protection attributes.
// Erase the line.
// Get our start/end positions depending on mode.
// If our X is a wide spacer tail then we need to erase the
// previous cell too so we don't split a multi-cell character.
// Reset our row's soft-wrap.
// If our x is a wide char we need to delete the tail too.
// Note that it seems like complete should reset the soft-wrap
// state of the line but in xterm it does not.
// All modes will clear the pending wrap state and we know we have
// a valid mode at this point.
// We always mark our row as dirty
// Start of our cells
// We respect protected attributes if explicitly requested (probably
// a DECSEL sequence) or if our last protected mode was ISO even if its
// not currently set.
// If we're not respecting protected attributes, we can use a fast-path
// to fill the entire line.
// Erase the display.
// We respect protected attributes if explicitly requested (probably
// a DECSEL sequence) or if our last protected mode was ISO even if its
// not currently set.
// Unsets pending wrap state
// Clear all Kitty graphics state for this screen
// If we're on the primary screen and our last non-empty row is
// a prompt, then we do a scroll_complete instead. This is a
// heuristic to get the generally desirable behavior that ^L
// at a prompt scrolls the screen contents prior to clearing.
// Most shells send `ESC [ H ESC [ 2 J` so we can't just check
// our current cursor position. See #905
// Go from the bottom of the active up and see if we're
// at a prompt.
// If we're at a prompt or input area, then we are at a prompt.
// If we have command output, then we're most certainly not
// at a prompt.
// If we fail, we just fall back to doing a normal clear
// so we don't worry about the error.
// All active area
// Unsets pending wrap state
// Clear all Kitty graphics state for this screen
// Cleared screen dirty bit
// All lines to the right (including the cursor)
// All lines below
// Unsets pending wrap state. Should be done by eraseLine.
// Erase to the left (including the cursor)
// All lines above
// Unsets pending wrap state
// Resets all margins and fills the whole screen with the character 'E'
//
// Sets the cursor to the top left corner.
// Clear our stylistic attributes. This is the only thing that can
// fail so we do it first so we can undo it.
// Reset margins, also sets cursor to top-left
// Origin mode is disabled
// Move our cursor to the top-left
// Use clearRows instead of eraseDisplay because we must NOT respect
// protected attributes here.
// Fill with Es by moving the cursor but reset it after.
// DECALN does not respect protected state. Verified with xterm.
// If we have a ref-counted style, increase
// We messed with the page so assert its integrity here.
// Reset the cursor to the top-left
// Execute a kitty graphics command. The buf is used to populate with
// the response that should be sent as an APC sequence. The response will
// be a full, valid APC sequence.
//
// If an error occurs, the caller should response to the pty that a
// an error occurred otherwise the behavior of the graphics protocol is
// undefined.
// Set a style attribute.
// Print the active attributes as a string. This is used to respond to DECRQSS
// requests.
//
// Boolean attributes are printed first, followed by foreground color, then
// background color. Each attribute is separated by a semicolon.
// The SGR response always starts with a 0. See https://vt100.net/docs/vt510-rm/DECRPSS
// The modes for DECCOLM.
// DECCOLM changes the terminal width between 80 and 132 columns. This
// function call will do NOTHING unless `setDeccolmSupported` has been
// called with "true".
//
// This breaks the expectation around modern terminals that they resize
// with the window. This will fix the grid at either 80 or 132 columns.
// The rows will continue to be variable.
// If DEC mode 40 isn't enabled, then this is ignored. We also make
// sure that we don't have deccolm set because we want to fully ignore
// set mode.
// Enable it
// Resize to the requested size
// Erase our display and move our cursor.
// Resize the underlying terminal.
// If our cols/rows didn't change then we're done
// Resize our tabstops
// Resize primary screen, which supports reflow
// Alternate screen, if it exists, doesn't reflow
// Whenever we resize we just mark it as a screen clear
// Set our size
// Reset the scrolling region
// Set the pwd for the terminal.
// Returns the pwd for the terminal, if any. The memory is owned by the
// Terminal and is not copied. It is safe until a reset or setPwd.
// Switch to the given screen type (alternate or primary).
//
// This does NOT handle behaviors such as clearing the screen,
// copying the cursor, etc. This should be handled by downstream
// callers.
//
// After calling this function, the `self.screen` field will point
// to the current screen, and the returned value will be the previous
// screen. If the return value is null, then the screen was not
// switched because it was already the active screen.
//
// Note: This is written in a generic way so that we can support
// more than two screens in the future if needed. There isn't
// currently a spec for this, but it is something I think might
// be useful in the future.
// If we're already on the requested screen we do nothing.
// We always end hyperlink state when switching screens.
// We need to do this on the original screen.
// Switch the screens/
// Inherit our Kitty image storage limit from the primary
// screen if we have to initialize.
// The new screen should not have any hyperlinks set
// Bring our charset state with us
// Clear our selection
// Mark kitty images as dirty so they redraw. Without this set
// the images will remain where they were (the dirty bit on
// the screen only tracks the terminal grid, not the images).
// Mark our terminal as dirty to redraw the grid.
// Finalize the switch
// Switch screen via a mode switch (e.g. mode 47, 1047, 1049).
// This is a much more opinionated operation than `switchScreen`
// since it also handles the behaviors of the specific mode,
// such as clearing the screen, saving/restoring the cursor,
// etc.
//
// This should be used for legacy compatibility with VT protocols,
// but more modern usage should use `switchScreen` instead and handle
// details like clearing the screen, cursor saving, etc. manually.
// The behavior in this function is completely based on reading
// the xterm source, specifically "charproc.c" for
// `srm_ALTBUF`, `srm_OPT_ALTBUF`, and `srm_OPT_ALTBUF_CURSOR`.
// We shouldn't touch anything in here without adding a unit
// test AND verifying the behavior with xterm.
// If we're disabling 1047 and we're on alt screen then
// we clear the screen.
// 1049 unconditionally saves the cursor on enabling, even
// if we're already on the alternate screen.
// Switch screens first to whatever we're going to.
// For these modes, we need to copy the cursor. We only copy
// the cursor if the screen actually changed, otherwise the
// cursor is already copied. The cursor is copied regardless
// of destination screen.
// Mode 1049 restores cursor on the primary screen when
// we disable it.
// When we enter alt screen with 1049, we always copy the
// cursor from the primary screen (if we weren't already
// on it).
// Modal screen changes. These map to the literal terminal
// modes to enable or disable alternate screen modes. They each
// have subtle behaviors so we define them as an enum here.
// Legacy alternate screen mode. This goes to the alternate
// screen or primary screen and only copies the cursor. The
// screen is not erased.
// Alternate screen mode where the alternate screen is cleared
// on exit. The primary screen is never cleared. The cursor is
// copied.
// Save primary screen cursor, switch to alternate screen,
// and clear the alternate screen on entry. On exit,
// do not clear the screen, and restore the cursor on the
// primary screen.
// Return the current string value of the terminal. Newlines are
// encoded as "\n". This omits any formatting such as fg/bg.
//
// The caller must free the string.
// Same as plainString, but respects row wrap state when building the string.
// Full reset.
//
// This will attempt to free the existing screen memory but if that fails
// this will reuse the existing memory. In the latter case, memory may
// be wasted (since its unused) but it isn't leaked.
// Ensure we're back on primary screen
// Reset our screens
// Rest our basic state
// Always mark dirty so we redraw everything
// Returns true if the point is dirty, used for testing.
// Clear all dirty bits. Testing only.
// Basic grid writing
// The first row should be dirty
// Basic grid writing
// Old row is dirty because cursor moved from there
// Basic grid writing
// Get our initial grapheme capacity.
// Print glitch text until our capacity changes
// We're testing to make sure that grapheme capacity gets increased.
// This used to crash the terminal. This is not allowed so we should
// just ignore it.
// Should not be dirty since we changed nothing.
// https://github.com/mitchellh/ghostty/issues/1400
// This would crash for issue 1400. So the assertion here is
// that we simply do not crash.
// Our first row just had a spacer head added which does not affect
// rendering so only the place where the wide char was printed
// should be marked.
// BUT old row is dirty because cursor moved from there
// This prints a space so we should be dirty.
// verify we have styles in our style map
// Go back and overwrite with no style
// verify our style is gone
// verify we have styles in our style map
// Go back and overwrite with no style
// verify our style is gone
// https://github.com/mitchellh/ghostty/issues/289
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have 6 cells taken up
// Assert various properties about our screen to verify
// we have all expected cells.
// Disable grapheme clustering
// Disable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/1482
// We should have 1 narrow cell.
// Assert various properties about our screen to verify
// we have all expected cells.
// Disable grapheme clustering
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/289
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have 2 cells taken up. It is one character but "wide".
// Row should be dirty
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// This is: "#︎" (number sign with text presentation selector)
// VS15 should combine with the base character into a single grapheme cluster,
// taking 1 cell (narrow character).
// Row should be dirty
// The base emoji should be in cell 0 with the skin tone as a grapheme
// Enable grapheme clustering
// This is: "#️" (number sign with emoji presentation selector)
// VS16 should combine with the base character into a single grapheme cluster,
// taking 2 cells (wide character).
// Row should be dirty
// The base emoji should be in cell 0 with the skin tone as a grapheme
// Enable grapheme clustering
// This is: "👋🏿" (waving hand with dark skin tone)
// The skin tone should combine with the base emoji into a single grapheme cluster,
// taking 2 cells (wide character).
// Row should be dirty
// The base emoji should be in cell 0 with the skin tone as a grapheme
// Enable grapheme clustering
// This is: "🏿" (which may not render correctly in your editor!)
// We should have 4 cells taken up. Importantly, the skin tone
// should not join with the quotes.
// Row should be dirty
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/289
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have 2 cells taken up. It is one character but "wide".
// Enable grapheme clustering
// We should have 2 cells taken up. It is one character but "wide".
// VS15 should send us back a cell since our char is no longer wide.
// Enable grapheme clustering
// Character takes up one cell
// Enable grapheme clustering
// We should have 2 cells taken up. It is one character but "wide".
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// We should have 2 cells taken up. It is one character but "wide".
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// We only move one because we're in a pending wrap state.
// VS15 should clear the pending wrap state
// Enable grapheme clustering
// Enable grapheme clustering
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/1482
// We should have 1 cells taken up, and narrow.
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/1482
// We should have 2 cells taken up, from two separate narrow characters.
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/1482
// We should have 1 cells taken up, and narrow.
// Assert various properties about our screen to verify
// we have all expected cells.
// Enable grapheme clustering
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/289
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have 2 cells taken up. It is one character but "wide".
// We should have one cell with graphemes
// Move back and overwrite wide
// Enable grapheme clustering
// https://github.com/mitchellh/ghostty/issues/289
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have 2 cells taken up. It is one character but "wide".
// We should have one cell with graphemes
// Move back and overwrite wide
// Make sure we're not at cursor.x == 0 for the next char.
// U+0600 ARABIC NUMBER SIGN (Prepend)
// We should have 3 cells taken up, each narrow. Note that this is
// **incorrect** grapheme break behavior, since a Prepend code point should
// not break with the one following it per UAX #29 GB9b. However, as an
// optimization we assume a grapheme break when c <= 255, and note that
// this deviation only affects these very uncommon scenarios (e.g. the
// Arabic number sign should precede Arabic-script digits).
// This is what we'd expect if we did break correctly:
// try testing.expectEqual(@as(usize, 2), t.screens.active.cursor.x);
// Assert various properties about our screen to verify
// we have all expected cells.
// This is what we'd expect if we did break correctly:
// try testing.expect(cell.hasGrapheme());
// try testing.expectEqualSlices(u21, &.{'1'}, list_cell.node.data.lookupGrapheme(cell).?);
// This is what we'd expect if we did break correctly:
// try testing.expectEqual(@as(u21, 0), cell.content.codepoint);
// Basic grid writing
// Make newlines so we create scrollback
// 3 pushes hello off the screen
// Scroll to the top
// Type
// G1 should have no effect
// No dirty to configure charset
// Basic grid writing
// G1 should have no effect
// No dirty to configure charset
// Basic grid writing
// Invokecharset but should not mark dirty on its own
// Basic grid writing
// Basic grid writing
// Mark our prompt.
// Should not make anything dirty on its own.
// Write and wrap
// This puts our cursor at the end and there is NO SPACE for a
// wide character.
// Make sure we printed nothing
// Should not be dirty since we didn't modify anything
// This puts our cursor at the end and there is NO SPACE for a
// wide character.
// Should not be dirty since we didn't modify anything
// This puts our cursor at the end and there is NO SPACE for a
// wide character.
// Should not be dirty since we didn't modify anything
// Writing our X on the first line should mark only that line dirty.
// Writing our Y should wrap. It marks both rows dirty because the
// cursor moved.
// Both rows dirty because the cursor moved
// Setup our hyperlink and print
// Verify all our cells have a hyperlink
// Setup our hyperlink and print
// Verify all our cells have a hyperlink
// Setup our hyperlink and print
// Verify all our cells have a hyperlink
// Setup our hyperlink and print
// Verify all our cells have a hyperlink
// Setup our hyperlink and print
// Verify all our cells have a hyperlink
// Print and CR.
// CR should not mark row dirty because it doesn't change rendering.
// LF marks row dirty due to cursor movement
// Basic grid writing
// Basic grid writing
// Basic grid writing
// BS
// HT
// HT
// HT at the end
// Edge of screen
// HT
// HT
// HT
// Probably outdated, but dates back to the original terminal implementation.
// Setting it to 0 should keep it zero (1 based)
// Should clamp to size
// Should reset pending wrap
// Origin mode
// No change without a scroll region
// Set the scroll region
// Mark the rows we moved as dirty.
// This is dirty because the cursor moves from this row
// For the line being deleted, create a refcounted style
// verify we have styles in our style map
// verify we have no styles in our style map
// Fill up the first page minus 3 rows
// Add content that will cross a page boundary
// Verify we now have a second page
// Initial value
// Move to row 2
// Insert two lines
// This should do nothing
// Initial value
// Initial value
// Move to row 2
// Insert a bunch of  lines
// Disable grapheme clustering
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// Viewport should have moved. Our entire page should've scrolled!
// The viewport moving will cause our render state to make the full
// frame as dirty.
// This is dirty because the cursor moves from this row
// First row gets some hyperlinks
// Second row preserves hyperlink where we didn't scroll
// This is dirty because the cursor moves from this row
// This is dirty because the cursor moves from this row
// When in primary screen with full-width scroll region at top,
// scrollUp (CSI S) should push lines into scrollback like xterm.
// Fill the screen with content
// Scroll up by 1, which should push "AAAAA" into scrollback
// The cursor row (new empty row) should be dirty
// The active screen should now show BBBBB through EEEEE plus one blank line
// Now scroll to the top to see scrollback - AAAAA should be there
// Should see AAAAA in scrollback
// When max_scrollback is 0, scrollUp should still work but not retain history
// Active screen should show scrolled content
// Scroll to top - should be same as active since no scrollback
// When max_scrollback is 0 and top margin is set, should use deleteLines path
// Set top margin (not at row 0)
// First row preserved, rest scrolled
// When max_scrollback is 0 with left/right margins, uses deleteLines path
// Set left/right margins (columns 2-6, 1-indexed = indices 1-5)
// cols 1-5 scroll, col 0 and cols 6+ preserved
// This is dirty because the cursor moves from this row
// First row preserves hyperlink where we didn't scroll
// Second row gets some hyperlinks
// verify we have styles in our style map
// verify we have no styles in our style map
// This is a test for a bug: https://github.com/ghostty-org/ghostty/issues/2817
// To explain the setup:
// (1) We need our wide characters starting on an even (1-based) column.
// (2) We need our cursor to be in the middle somewhere.
// (3) We need our count to be less than our cursor X and on a split cell.
// The bug was that we split the wrong cell boundaries.
// Initial value
// Initial value
// Set our scroll region
// Fill up the first page minus 3 rows
// Add content that will cross a page boundary
// Verify we now have a second page
// Initial value
// We should be
// Initial value
// We should be
// try testing.expectEqual(@as(usize, 0), t.screens.active.cursor.x);
// try testing.expectEqual(@as(usize, 2), t.screens.active.cursor.y);
// Initial value
// We should be
// try testing.expectEqual(@as(usize, 0), t.screens.active.cursor.x);
// try testing.expectEqual(@as(usize, 2), t.screens.active.cursor.y);
// Initial value
// Initial value
// +-----+
// |AAAAA| < Wrapped
// |BBBB*| < Wrapped     (continued)
// |WWCCC| < Non-wrapped (continued)
// +-----+
// where * represents a spacer head cell
// and WW is the wide character.
// Delete the top line
// +-----+
// |BBBB | < Non-wrapped
// |WWCCC| < Non-wrapped
// |     | < Non-wrapped
// +-----+
// This should convert the spacer head to
// a regular empty cell, and un-set wrap.
// Initial value
// +-----+
// |AAAAA| < Wrapped
// |BBBB*| < Wrapped     (continued)
// |WWCCC| < Non-wrapped (continued)
// +-----+
// where * represents a spacer head cell
// and WW is the wide character.
// Delete the top line
//    ###  <- scrolling region
// +-----+
// |AABB | < Wrapped
// |BBCCC| < Wrapped     (continued)
// |WW   | < Non-wrapped (continued)
// +-----+
// This should convert the spacer head to
// a regular empty cell, but due to the
// left scrolling margin, wrap state should
// remain.
// Initial value
// +-----+
// |AAAAA| < Wrapped
// |BBBB*| < Wrapped     (continued)
// |WWCCC| < Non-wrapped (continued)
// +-----+
// where * represents a spacer head cell
// and WW is the wide character.
// Delete the top line
//  ####   <- scrolling region
// +-----+
// |BBBBA| < Wrapped
// |WWCC | < Wrapped     (continued)
// |    C| < Non-wrapped (continued)
// +-----+
// This should convert the spacer head to
// a regular empty cell, but due to the
// right scrolling margin, wrap state should
// remain.
// Initial value
// +-----+
// |AAAAA| < Wrapped
// |BBBB*| < Wrapped     (continued)
// |WWCCC| < Non-wrapped (continued)
// +-----+
// where * represents a spacer head cell
// and WW is the wide character.
// Delete the top line
//    ##   <- scrolling region
// +-----+
// |AABBA| < Wrapped
// |BBCC*| < Wrapped     (continued)
// |WW  C| < Non-wrapped (continued)
// +-----+
// Because there is both a left scrolling
// margin > 1 and a right scrolling margin
// the spacer head should remain, and the
// wrap state should be untouched.
// Initial value
// +-----+
// |AAAAA| < Wrapped
// |BBBB*| < Wrapped     (continued)
// |WWCCC| < Non-wrapped (continued)
// +-----+
// where * represents a spacer head cell
// and WW is the wide character.
// Delete the top line
//   ###   <- scrolling region
// +-----+
// |ABBBA| < Wrapped
// |B CC | < Wrapped     (continued)
// |    C| < Non-wrapped (continued)
// +-----+
// Because the left margin is 1, the wide
// char is split, and therefore removed,
// along with the spacer head - however,
// wrap state should be untouched.
// Initial value
// +-----+
// |AAAAA|
// |WWBWW|
// +-----+
// where WW represents a wide character
// Delete the top line
//   ###   <- scrolling region
// +-----+
// |A B A|
// |     |
// +-----+
// The two wide chars, because they're
// split by the edge of the scrolling
// region, get removed.
// This should do nothing
// verify we have no styles in our style map
// verify we have no styles in our style map
// Initial value
// Initial value
// Initial value
// Add protected mode. A previous version of DECALN accidentally preserved
// protected mode which left dangling managed memory.
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// NOTE: this is not verified with conformance tests, so these
// tests might actually be verifying wrong behavior.
// NOTE: this is not verified with conformance tests, so these
// tests might actually be verifying wrong behavior.
// NOTE: this is not verified with conformance tests, so these
// tests might actually be verifying wrong behavior.
// Disable grapheme clustering
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have one cell with graphemes
// We should have no graphemes
// Enable grapheme clustering
// This is: 👨‍👩‍👧 (which may or may not render correctly)
// We should have one cell with graphemes
// We should have no graphemes
// osc "8;;http://example.com"
// printf "link"
// printf "\r"
// csi "3@"
// echo
//
// link should be preserved, blanks should not be linked
// Verify all our cells have a hyperlink
// EXPLANATION(qwerasd):
//
// There are 3 or 4 boundaries to be concerned with in deleteChars,
// depending on how you count them. Consider the following terminal:
//
//   +--------+
// 0 |.ABCDEF.|
//   : ^      : (^ = cursor)
//   +--------+
//
// if we DCH 3 we get
//
//   +--------+
// 0 |.DEF....|
//   +--------+
//
// The boundaries exist at the following points then:
//
//   +--------+
// 0 |.ABCDEF.|
//   :11 22 33:
//   +--------+
//
// I'm counting 2 for double since it's both the end of the deleted
// content and the start of the content that is shifted in to place.
//
// Now consider wide characters (represented as `WW`) at these boundaries:
//
//   +--------+
// 0 |WWaWWbWW|
//   : ^      : (^ = cursor)
//   : ^^^    : (^ = deleted by DCH 3)
//   +--------+
//
// -> DCH 3
// -> The first 2 wide characters are split & destroyed (verified in xterm)
//
//   +--------+
// 0 |..bWW...|
//   +--------+
// EXPLANATION(qwerasd):
// (cont. from "Terminal: deleteChars wide char boundary conditions")
//
// Additionally consider soft-wrapped wide chars (`H` = spacer head):
//
//   +--------+
// 0 |.......H…
// 1 …WWabcdeH…
//   : ^      : (^ = cursor)
//   : ^^^    : (^ = deleted by DCH 3)
// 2 …WW......|
//   +--------+
//
// -> DCH 3
// -> First wide character split and destroyed, including spacer head,
//    second spacer head removed (verified in xterm).
// -> Wrap state of row reset
//
//   +--------+
// 0 |........|
// 1 |.cde....|
// 2 |WW......|
//   +--------+
//
// scroll region
//    VVVVVV
//  +-######-+
//  |.abcdeWW|
//  : ^      : (^ = cursor)
//  +--------+
//
// DCH 1
// NOTE: This behavior is slightly inconsistent with xterm. xterm
// _visually_ splits the wide character (half the wide character shows
// up in col 6 and half in col 8). In all other wide char split scenarios,
// xterm clears the cell. Therefore, we've chosen to clear the cell here.
// Given we have space, we also could actually preserve it, but I haven't
// yet found a terminal that behaves that way. We should be open to
// revisiting this behavior but for now we're going with the simpler
// impl.
// Tests that restoreCursor falls back to default style when
// manualStyleUpdate fails with OutOfSpace (can't split a 1-row page
// and styles are at max capacity).
// Use a single row so the page can't be split
// Set a style and save the cursor
// Clear the style
// Fill the style map to max capacity
// Fill all style slots using the StyleSet's layout capacity which accounts
// for the load factor. The capacity in the layout is the actual max number
// of items that can be stored.
// Restore cursor - should fall back to default style since page
// can't be split (1 row) and styles are at max capacity
// The style should be reset to default because OutOfSpace occurred
// Set our cursur
// Erasing the display may detect that our style is no longer in use
// and prune our style, which we don't want because its still our
// active cursor.
// Prompt
// Start input but end it on EOL
// Write some output
// Prompt
// Start input but end it on EOL
// Write some output
// This tests the Fish shell workaround: when in prompt mode and we get
// a newline, assume the new row is a prompt continuation (since Fish
// doesn't emit OSC133 k=s markers for continuation lines).
// Start a prompt
// Verify first row is marked as prompt
// Now do a linefeed while still in prompt mode
// The new row should automatically be marked as prompt continuation
// The cursor semantic content should still be prompt
// Input mode should NOT trigger prompt continuation on newline
// (only prompt mode does, not input mode)
// Start a prompt then switch to input
// Linefeed while in input mode
// The new row should be marked as prompt continuation
// Our cursor should still be in input
// Output mode should NOT trigger prompt continuation
// Complete prompt cycle: prompt -> input -> output
// Linefeed while in output mode
// The new row should NOT be marked as a prompt
// This tests the second Fish heuristic: when Fish emits a newline
// then immediately sends OSC133C (start output) at column 0, we
// should clear the prompt continuation mark we just set.
// Start a prompt
// Simulate Fish behavior: newline first (which marks next row as prompt)
// Verify the new row is marked as prompt continuation
// Now Fish sends OSC133C at column 0 (cursor is still at x=0)
// The prompt continuation should be cleared
// If we're not at column 0, we shouldn't clear the prompt mark
// Start a prompt on a row
// Move to a new line and mark it as prompt continuation manually
// Verify the row is marked as prompt continuation
// Now send OSC133C but cursor is NOT at column 0
// The prompt continuation should NOT be cleared (we're not at x=0)
// Multiple newlines should each mark their row as prompt continuation
// Start a prompt
// Multiple newlines
// First row should be prompt
// Second and third rows should be prompt continuation
// Verify default state is none
// OSC 133;A with click_events=1
// OSC 133;A with click_events=0
// Should remain none since click_events=0 doesn't activate anything
// OSC 133;A with cl=m (multiple)
// OSC 133;A with both click_events=1 and cl=m
// click_events should take priority
// OSC 133;A with click_events=0 and cl=v
// Should fall back to cl since click_events is disabled
// OSC 133;A with no click-related options
// Input is also a prompt
// But once we say we're starting output, we're not a prompt
// (cursor is not at x=0, so the Fish heuristic doesn't trigger)
// Still a prompt because this line has a prompt
// Until we know we're at a prompt again
// Secondary screen is never a prompt
// Origin mode should be reset and the cursor should be moved
// https://github.com/mitchellh/ghostty/issues/1607
// Create a tracked pin
// https://github.com/mitchellh/ghostty/issues/272
// This is also tested in depth in screen resize tests but I want to keep
// this test around to ensure we don't regress at multiple layers.
// https://github.com/mitchellh/ghostty/issues/723
// This was found via fuzzing so its highly specific.
// https://github.com/mitchellh/ghostty/issues/1343
// Verify our cursor is still in the same place
// Pending wrap should be reset
// Print on primary screen
// Go to alt screen with mode 47
// Screen should be empty
// Print on alt screen. This should be off center because
// we copy the cursor over from the primary screen
// Go back to primary
// Primary screen should still have the original content
// Go back to alt screen with mode 47
// Screen should retain content
// Color our cursor red
// Go to alt screen with mode 47
// Verify that our style is set
// Set a new style
// Go back to primary
// Verify that our style is still set
// Print on primary screen
// Go to alt screen with mode 47
// Screen should be empty
// Print on alt screen. This should be off center because
// we copy the cursor over from the primary screen
// Go back to primary
// Primary screen should still have the original content
// Go back to alt screen with mode 1047
// Screen should be empty
// Color our cursor red
// Go to alt screen with mode 47
// Verify that our style is set
// Set a new style
// Go back to primary
// Verify that our style is still set
// Print on primary screen
// Go to alt screen with mode 47
// Screen should be empty
// Print on alt screen. This should be off center because
// we copy the cursor over from the primary screen
// Go back to primary
// Primary screen should still have the original content
// Write, our cursor should be restored back.
// Go back to alt screen with mode 1049
// Screen should be empty
//
// --- Original Ghostty Comments End: src/terminal/Terminal.zig

// The primary terminal emulation structure. This represents a single
// "terminal" containing a grid of characters and exposes various operations
// on that grid. This also maintains the scrollback buffer.

import osc
import strings

// Default tabstop interval
const tabstop_interval = 8

// ============================================================
// Terminal struct
// ============================================================

pub struct Terminal {
pub mut:
	// The set of screens behind this terminal (e.g. primary vs alternate).
	screens ScreenSet

	// Whether we're currently writing to the status line (DECSASD and DECSSDT).
	// We don't support a status line currently so we just black hole this
	// data so that it doesn't mess up our main display.
	status_display StatusDisplay = .main

	// Where the tabstops are.
	tabstops Tabstops

	// The size of the terminal.
	rows u16
	cols u16

	// The size of the screen in pixels. This is used for pty events and images.
	width_px  u32
	height_px u32
	// Configured Kitty image storage limit. ImageStorage itself remains in
	// the kitty module behind Screen.kitty_images to avoid an import cycle.
	kitty_image_limit usize = 320 * 1000 * 1000

	// The current scrolling region.
	scrolling_region ScrollingRegion

	// The last reported pwd, if any.
	pwd string

	// The color state for this terminal.
	colors Colors

	// The previous printed character. This is used for the repeat previous
	// char CSI (ESC [ <n> b).
	previous_char ?u32

	// The modes that this terminal currently has active.
	modes ModeState

	// The most recently set mouse shape for the terminal.
	mouse_shape MouseShape = .text

	// These are just a packed set of flags we may set on the terminal.
	flags TerminalFlags
}

// ============================================================
// Nested types
// ============================================================

// The various color configurations a terminal maintains and that can
// be set dynamically via OSC, with defaults usually coming from a
// configuration.
pub struct Colors {
pub mut:
	background DynamicRGB
	foreground DynamicRGB
	cursor     DynamicRGB
	palette    DynamicPalette
}

// colors_default provides the default Colors value.
// DynamicRGB and DynamicPalette are defined in color.v.
pub const colors_default = Colors{
	palette: dynamic_palette_default_val
}

pub struct RGB {
pub:
	r u8
	g u8
	b u8
}

// This is a set of dirty flags the renderer can use to determine
// what parts of the screen need to be redrawn. It is up to the renderer
// to clear these flags.
//
// This only contains dirty flags for terminal state, not for the screen
// state. The screen state has its own dirty flags.
pub struct Dirty {
pub mut:
	// Set when the color palette is modified in any way.
	palette bool

	// Set when the reverse colors mode is modified.
	reverse_colors bool

	// Screen clear of some kind. This can be due to a screen change,
	// erase display, etc.
	clear bool

	// Set when the pre-edit is modified.
	preedit bool
}

// The event types that can be reported for mouse-related activities.
// These are all mutually exclusive (hence in a single enum).
pub enum MouseEvents {
	none
	x10 // 9
	normal // 1000
	button // 1002
	any // 1003
}

// Returns true if this event sends motion events.
pub fn (self MouseEvents) motion() bool {
	return self == .button || self == .any
}

// The format of mouse events when enabled.
// These are all mutually exclusive (hence in a single enum).
pub enum MouseFormat {
	x10
	utf8 // 1005
	sgr // 1006
	urxvt // 1015
	sgr_pixels // 1016
}

// Scrolling region is the area of the screen designated where scrolling
// occurs. When scrolling the screen, only this viewport is scrolled.
pub struct ScrollingRegion {
pub mut:
	// Top and bottom of the scroll region (0-indexed)
	// Precondition: top < bottom
	top    u16
	bottom u16

	// Left/right scroll regions.
	// Precondition: right > left
	// Precondition: right <= cols - 1
	left  u16
	right u16
}

pub struct Options {
pub:
	cols           u16
	rows           u16
	max_scrollback int = 10_000
	colors         Colors = terminal.colors_default

	// The default mode state. When the terminal gets a reset, it
	// will revert back to this state.
	// The default mode state includes wraparound (bit 0) and
	// cursor visible (bit 2), matching DEC mode defaults.
	default_modes ModePacked = build_default_modes()
}

pub struct ModePacked {
pub mut:
	// One bit per Mode (indexed by the Mode enum position). This is u64
	// because there are more than 32 modes; a u32 would alias modes >= 32
	// onto modes 0-7.
	data u64
}

pub struct TerminalFlags {
pub mut:
	// This supports a Kitty extension where programs using semantic
	// prompts (OSC133) can annotate their new prompts with `redraw=0` to
	// disable clearing the prompt on resize.
	shell_redraws_prompt PromptRedraw = .true_

	// This is set via ESC[4;2m. Any other modify key mode just sets
	// this to false and we act in mode 1 by default.
	modify_other_keys_2 bool

	// The mouse event mode and format. These are set to the last
	// set mode in modes. You can't get the right event/format to use
	// based on modes alone because modes don't show you what order
	// this was called so we have to track it separately.
	mouse_event  MouseEvents = .none
	mouse_format MouseFormat = .x10

	// Set via the XTSHIFTESCAPE sequence. If true (XTSHIFTESCAPE = 1)
	// then we want to capture the shift key for the mouse protocol
	// if the configuration allows it.
	mouse_shift_capture MouseShiftCaptureState = .null_

	// True if the window is focused.
	focused bool = true

	// True if the terminal is in a password entry mode. This is set
	// to true based on termios state.
	password_input bool

	// True if the terminal should perform selection scrolling.
	selection_scroll bool

	// Dirty flag used only by the search thread. The renderer is expected
	// to set this to true if the viewport was dirty as it was rendering.
	// This is used by the search thread to more efficiently re-search the
	// viewport and active area.
	//
	// Since the renderer is going to inspect the viewport/active area ANYWAYS,
	// this lets our search thread do less work and hold the lock less time,
	// resulting in more throughput for everything.
	search_viewport_dirty bool

	// Dirty flags for the renderer.
	dirty Dirty
}

pub enum MouseShiftCaptureState {
	null_
	false_
	true_
}

// Options for scrolling the viewport of the terminal grid.
pub enum ScrollViewport {
	// Scroll to the top of the scrollback
	top
	// Scroll to the bottom, i.e. the top of the active area
	bottom
	// Scroll by some delta amount, up is negative.
	delta
}

// The modes for DECCOLM.
pub enum DeccolmMode as u8 {
	cols_80  = 0
	cols_132 = 1
}

// Modal screen changes. These map to the literal terminal
// modes to enable or disable alternate screen modes.
pub enum SwitchScreenMode {
	// Legacy alternate screen mode. This goes to the alternate
	// screen or primary screen and only copies the cursor. The
	// screen is not erased.
	mode_47

	// Alternate screen mode where the alternate screen is cleared
	// on exit. The primary screen is never cleared. The cursor is
	// copied.
	mode_1047

	// Save primary screen cursor, switch to alternate screen,
	// and clear the alternate screen on entry. On exit,
	// do not clear the screen, and restore the cursor on the
	// primary screen.
	mode_1049
}

// ============================================================
// ScreenSet: manages primary and alternate screens
// ============================================================

pub struct ScreenSet {
pub mut:
	primary       &Screen = unsafe { nil }
	alternate_ptr &Screen = unsafe { nil }
	active        &Screen = unsafe { nil }
	active_key    ScreenKey = .primary
}

pub enum ScreenKey {
	primary
	alternate
}

pub fn ScreenSet.init(cols u16, rows u16, max_scrollback int) !ScreenSet {
	mut init_primary := Screen.init(u32(cols), u32(rows), u32(max_scrollback))
	primary := unsafe { &Screen(memdup(&init_primary, int(sizeof(Screen)))) }
	return ScreenSet{
		primary: primary
		active: primary
	}
}

pub fn (mut self ScreenSet) deinit() {
	self.primary.deinit()
	if self.alternate_ptr != unsafe { nil } {
		self.alternate_ptr.deinit()
	}
}

pub fn (mut self ScreenSet) get(key ScreenKey) ?&Screen {
	match key {
		.primary {
			return self.primary
		}
		.alternate {
			if self.alternate_ptr != unsafe { nil } {
				return self.alternate_ptr
			}
			return none
		}
	}
}

pub fn (mut self ScreenSet) switch_to(key ScreenKey) {
	match key {
		.primary {
			self.active = self.primary
			self.active_key = .primary
		}
		.alternate {
			if self.alternate_ptr != unsafe { nil } {
				self.active = self.alternate_ptr
				self.active_key = .alternate
			}
		}
	}
}

pub fn (mut self ScreenSet) remove(key ScreenKey) {
	match key {
		.alternate {
			if self.alternate_ptr != unsafe { nil } {
				self.alternate_ptr.deinit()
			}
			self.alternate_ptr = unsafe { nil }
		}
		.primary {}
	}
	// never remove primary
}

// ============================================================
// ModeState: terminal modes
// ============================================================

pub struct ModeState {
pub mut:
	values  ModePacked
	saved   ModePacked
	default ModePacked
}

pub fn (self ModeState) get(mode Mode) bool {
	bit := u64(1) << (int(mode) & 63)
	return (self.values.data & bit) != 0
}

pub fn (mut self ModeState) set(mode Mode, val bool) {
	bit := u64(1) << (int(mode) & 63)
	if val {
		self.values.data |= bit
	} else {
		self.values.data &= ~bit
	}
}

pub fn (mut self ModeState) reset() {
	self.values = self.default
}

pub enum Mode {
	wraparound // = 0
	origin // = 1
	cursor_visible // = 2
	insert // = 3
	linefeed // = 4
	grapheme_cluster // = 5 (mode 2027)
	reverse_wrap // = 6
	reverse_wrap_extended // = 7
	enable_left_and_right_margin // = 8
	enable_mode_3 // = 9 (DECCOLM support)
	column_132 // = 10
	bracketed_paste // = 11
	focus_event // = 12
	cursor_blinking // = 13
	autorepeat // = 14
	reverse_colors // = 15
	alt_screen_legacy // = 16 (mode 47)
	alt_screen // = 17 (mode 1047)
	alt_screen_save_cursor_clear_enter // = 18 (mode 1049)
	save_cursor // = 19 (mode 1048)
	synchronized_output // = 20
	in_band_size_reports // = 21 (mode 2048)
	mouse_event_x10 // = 22 (mode 9)
	mouse_event_normal // = 23 (mode 1000)
	mouse_event_button // = 24 (mode 1002)
	mouse_event_any // = 25 (mode 1003)
	mouse_format_utf8 // = 26 (mode 1005)
	mouse_format_sgr // = 27 (mode 1006)
	mouse_format_urxvt // = 28 (mode 1015)
	mouse_format_sgr_pixels // = 29 (mode 1016)
	disable_keyboard // = 30 (KAM, ANSI mode 2)
	send_receive_mode // = 31 (SRM, ANSI mode 12)
	cursor_keys // = 32 (DECCKM, DEC mode 1)
	slow_scroll // = 33 (DEC mode 4)
	keypad_keys // = 34 (DEC mode 66)
	mouse_alternate_scroll // = 35 (DEC mode 1007)
	ignore_keypad_with_numlock // = 36 (DEC mode 1035)
	alt_esc_prefix // = 37 (DEC mode 1036)
	alt_sends_escape // = 38 (DEC mode 1039)
	report_color_scheme // = 39 (DEC mode 2031)
}

// ============================================================
// Mouse shape
// ============================================================

pub enum MouseShape {
	default_
	context_menu
	help
	pointer
	progress
	wait
	cell
	crosshair
	text
	vertical_text
	alias
	copy
	move
	no_drop
	not_allowed
	grab
	grabbing
	all_scroll
	col_resize
	row_resize
	n_resize
	e_resize
	s_resize
	w_resize
	ne_resize
	nw_resize
	se_resize
	sw_resize
	ew_resize
	ns_resize
	nesw_resize
	nwse_resize
	zoom_in
	zoom_out
}

// ============================================================
// Prompt redraw
// ============================================================

pub enum PromptRedraw {
	false_
	true_
	last
}

// ============================================================
// Initialize a new terminal.
// ============================================================

pub fn Terminal.init(opts Options) !Terminal {
	cols := opts.cols
	rows := opts.rows

	mut screen_set := ScreenSet.init(cols, rows, opts.max_scrollback)!

	return Terminal{
		cols: cols
		rows: rows
		screens: screen_set
		tabstops: Tabstops.init(int(cols), terminal.tabstop_interval)!
		scrolling_region: ScrollingRegion{
			top: 0
			bottom: rows - 1
			left: 0
			right: cols - 1
		}
		colors: opts.colors
		modes: ModeState{
			values: opts.default_modes
			default: opts.default_modes
		}
	}
}

pub fn (mut self Terminal) deinit() {
	self.tabstops.deinit()
	self.screens.deinit()
}

// Return a terminal.Stream that can process VT streams and update this
// terminal state. The streams will only process read-only data that
// modifies terminal state. Sequences that query or otherwise require
// output will be ignored.
// vt_stream creates a ReadonlyStream that wraps this terminal.
// The stream parses VT sequences and applies them to the terminal.
pub fn (mut self Terminal) vt_stream() ReadonlyStream {
	return ReadonlyStream.init(mut self)
}

// vt_handler creates just the handler portion (without stream parser).
pub fn (mut self Terminal) vt_handler() ReadonlyHandler {
	return ReadonlyHandler.init(mut self)
}

// ============================================================
// Print functions
// ============================================================

// Print UTF-8 encoded string to the terminal.
pub fn (mut self Terminal) print_string(str string) ! {
	for c in str.runes() {
		if c == `\n` {
			self.carriage_return()
			self.linefeed()!
		} else {
			self.print(u32(c))!
		}
	}
}

// Print the previous printed character a repeated amount of times.
pub fn (mut self Terminal) print_repeat(count_req int) ! {
	if c := self.previous_char {
		count := if count_req < 1 { 1 } else { count_req }
		for _ in 0 .. count {
			self.print(c)!
		}
	}
}

// Print a single codepoint to the terminal.
pub fn (mut self Terminal) print(c u32) ! {
	// If we're not on the main display, do nothing for now
	if self.status_display != .main {
		return
	}

	// After doing any printing, wrapping, scrolling, etc. we want to ensure
	// that our screen remains in a consistent state.
	defer { self.screens.active.assert_integrity() }

	// Our right margin depends where our cursor is now.
	right_limit := if self.screens.active.cursor.x > self.scrolling_region.right {
		self.cols
	} else {
		self.scrolling_region.right + 1
	}

	// Perform grapheme clustering if grapheme support is enabled (mode 2027).
	// This is MUCH slower than the normal path so the conditional below is
	// purposely ordered in least-likely to most-likely so we can drop out
	// as quickly as possible.
	if c > 255 && self.modes.get(.grapheme_cluster) && self.screens.active.cursor.x > 0 {
		// We need the previous cell to determine if we're at a grapheme
		// break or not. If we are NOT, then we are still combining the
		// same grapheme. Otherwise, we can stay in this cell.
		//
		mut left := u32(1)
		// If we have wraparound, then we always use the prev col.
		// If we do not have wraparound, the logic is trickier. If
		// we're not on the last column, then we just use the previous
		// column. Otherwise, we need to check if there is text to
		// figure out if we're attaching to the prev or current.
		if !self.modes.get(.wraparound) && self.screens.active.cursor.x == right_limit - 1 {
			cur := self.cursor_cell_ref(0)
			left = if cur.codepoint_val() == 0 { u32(1) } else { u32(0) }
		}

		// If the previous cell is a wide spacer tail, then we actually
		// want to use the cell before that because that has the actual
		// content.
		mut prev_left := left
		mut prev := self.cursor_cell_ref(left)
		if prev.wide == .spacer_tail {
			prev_left = left + 1
			prev = self.cursor_cell_ref(left + 1)
		}

		// The absolute column of the prev cell. We compute this now BECAUSE
		// the cursor may move during VS16/VS15 handling below, and the
		// grapheme must always attach to this specific cell (ghostty keeps
		// a pointer; we keep the column). This is on the cursor's row.
		base_col := int(self.screens.active.cursor.x) - int(prev_left)

		// If our cell has no content, then this is a new cell and
		// necessarily a grapheme break.
		if prev.codepoint_val() == 0 {
			// break out of grapheme handling; fall through to width path
		} else {
			brk := grapheme_break_cell(prev, c)

			// If we can NOT break, this means that "c" is part of a
			// grapheme with the previous char.
			if !brk {
				// If this is an emoji variation selector then we need to
				// modify the cell width accordingly. VS16 makes the
				// character wide and VS15 makes it narrow.
				if c == 0xFE0F || c == 0xFE0E {
					// Check if it is a valid variation sequence. Without the
					// emoji-variation-sequences.txt table we treat any
					// wide-capable base (>= 0x1F000 emoji block or already
					// wide) as valid; otherwise ignore the char.
					if !is_emoji_vs_base(prev.codepoint) {
						return
					}

					if c == 0xFE0F {
						// VS16: make wide, unless already wide.
						if prev.wide != .wide {
							// Move our cursor back to the previous.
							self.screens.active.cursor_left(prev_left)

							// If we don't have space for the wide char, we need
							// to insert spacers and wrap.
							if self.screens.active.cursor.x == right_limit - 1 {
								if !self.modes.get(.wraparound) {
									return
								}
								spacer := if right_limit == self.cols {
									CellWide.spacer_head
								} else {
									CellWide.narrow
								}
								self.print_cell(0, spacer)
								self.print_wrap()!
							}

							base := prev.codepoint
							self.print_cell(base, .wide)

							// Write our spacer
							self.screens.active.cursor_right(1)
							self.print_cell(0, .spacer_tail)

							// Move the cursor again so we're beyond our spacer
							if self.screens.active.cursor.x == right_limit - 1 {
								self.screens.active.cursor.pending_wrap = true
							} else {
								self.screens.active.cursor_right(1)
							}
						}
					} else {
						// VS15 (0xFE0E): make narrow.
						if prev.wide == .wide {
							// Prev cell is no longer wide (absolute column).
							self.cell_set_wide_abs(base_col, .narrow)
							// Remove the wide spacer tail (cell just after prev)
							self.cell_set_wide_abs(base_col + 1, .narrow)

							// Back track the cursor so that we don't end up
							// with an extra space after the character.
							if self.screens.active.cursor.x == right_limit - 1 {
								self.screens.active.cursor.pending_wrap = false
							} else {
								self.screens.active.cursor_left(1)
							}
						}
					}
				}

				self.screens.active.cursor_mark_dirty()
				self.append_grapheme_abs(base_col, c)!
				return
			}
		}
	}

	// Determine the width of this character so we can handle
	// non-single-width characters properly. We have a fast-path for
	// byte-sized characters since they're so common. We can ignore
	// control characters because they're always filtered prior.
	width := if c <= 0xFF { u16(1) } else { codepoint_width(c) }

	// Attach zero-width characters to our cell as grapheme data.
	if width == 0 {
		// If we have grapheme clustering enabled, we don't blindly attach
		// any zero width character to our cells and we instead just ignore
		// it.
		if self.modes.get(.grapheme_cluster) {
			return
		}

		// If we're at cell zero, then this is malformed data and we don't
		// print anything or even store this. Zero-width characters are
		// ALWAYS attached to some other non-zero-width character at the
		// time of writing.
		if self.screens.active.cursor.x == 0 {
			return
		}

		// Find our previous cell (skipping a wide spacer tail).
		mut prev_left := u32(1)
		mut prev := self.cursor_cell_ref(1)
		if prev.wide == .spacer_tail {
			prev_left = 2
			prev = self.cursor_cell_ref(2)
		}

		// If our previous cell has no text, ignore the zero-width char.
		if !prev.has_text() {
			return
		}

		// If this is a emoji variation selector, prev must be an emoji.
		if c == 0xFE0F || c == 0xFE0E {
			if !is_extended_pictographic(prev.codepoint) {
				return
			}
		}

		self.append_grapheme_at(prev_left, c)!
		return
	}

	// We have a printable character, save it
	self.previous_char = c

	// If we're soft-wrapping, then handle that first.
	if self.screens.active.cursor.pending_wrap && self.modes.get(.wraparound) {
		self.print_wrap()!
	}

	// If we have insert mode enabled then we need to handle that. We
	// only do insert mode if we're not at the end of the line.
	if self.modes.get(.insert) && self.screens.active.cursor.x + width < self.cols {
		self.insert_blanks(int(width))
	}

	if width == 1 {
		// Single cell is very easy: just write in the cell
		self.screens.active.cursor_mark_dirty()
		self.print_cell(c, .narrow)
	} else if width == 2 {
		if (right_limit - self.scrolling_region.left) > 1 {
			// Wide character requires a spacer. We print this by
			// using two cells: the first is flagged "wide" and has the
			// wide char. The second is guaranteed to be a spacer if
			// we're not at the end of the line.
			if self.screens.active.cursor.x == right_limit - 1 {
				// If we don't have wraparound enabled then we don't print
				// this character at all and don't move the cursor.
				if !self.modes.get(.wraparound) {
					return
				}

				// We only create a spacer head if we're at the real edge
				// of the screen.
				spacer_wide := if right_limit == self.cols {
					CellWide.spacer_head
				} else {
					CellWide.narrow
				}
				self.print_cell(0, spacer_wide)
				self.print_wrap()!
			}

			self.screens.active.cursor_mark_dirty()
			self.print_cell(c, .wide)
			self.screens.active.cursor_right(1)
			self.print_cell(0, .spacer_tail)
		} else {
			// This is pretty broken, terminals should never be only 1-wide.
			self.screens.active.cursor_mark_dirty()
			self.print_cell(0, .narrow)
		}
	}

	// If we're at the column limit, then we need to wrap the next time.
	// In this case, we don't move the cursor.
	if self.screens.active.cursor.x == right_limit - 1 {
		self.screens.active.cursor.pending_wrap = true
		return
	}

	// Move the cursor
	self.screens.active.cursor_right(1)
}

fn (mut self Terminal) print_cell(unmapped_c u32, wide CellWide) {
	defer { self.screens.active.assert_integrity() }

	// Map through charset
	c := self.map_charset(unmapped_c)

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cell_x := int(self.screens.active.cursor.x)
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		if cell_x >= row.cells.len {
			return
		}

		old_cell := row.cells[cell_x]

		// If the wide property of this cell is different, we may need to
		// clear some cells.
		if old_cell.wide != wide {
			match old_cell.wide {
				.narrow {} // Do nothing
				.wide {
					// Previous cell was wide. Clear the tail.
					if cell_x + 1 < row.cells.len {
						row.cells[cell_x + 1] = CellData{}
					}
				}
				.spacer_tail {
					// Previous cell was spacer_tail. Clear the wide cell before it.
					if cell_x > 0 {
						row.cells[cell_x - 1] = CellData{}
					}
				}
				.spacer_head {}
			}
			// TODO: investigate
		}

		// If the prior value had graphemes, clear those
		if old_cell.has_grapheme {
			row.cells[cell_x].graphemes = []
			row.cells[cell_x].has_grapheme = false
			// Update row grapheme flag
			mut has_any := false
			for cell in row.cells {
				if cell.has_grapheme {
					has_any = true
					break
				}
			}
			row.grapheme = has_any
		}

		// Write the cell
		row.cells[cell_x] = CellData{
			codepoint: u32(c)
			content_tag: .codepoint
			style_id: self.screens.active.cursor.style_id
			wide: wide
			is_protected: self.screens.active.cursor.is_protected
			semantic_content: self.screens.active.cursor.semantic_content
			style: self.screens.active.cursor.style
		}

		// Update row flags
		if self.screens.active.cursor.style_id != terminal.default_style_id {
			row.styled = true
		}

		// Handle hyperlink
		if self.screens.active.cursor.hyperlink_id > 0 {
			self.screens.active.cursor_set_hyperlink() or {}
		} else if old_cell.has_hyperlink {
			row.cells[cell_x].has_hyperlink = false
			// Update row hyperlink flag
			mut has_hl := false
			for cell in row.cells {
				if cell.has_hyperlink {
					has_hl = true
					break
				}
			}
			row.hyperlink = has_hl
		}
	}
}

fn (mut self Terminal) map_charset(unmapped_c u32) u32 {
	// A single shift applies to exactly one printed character.
	slot := if once := self.screens.active.charset.single_shift {
		self.screens.active.charset.single_shift = none
		once
	} else {
		self.screens.active.charset.gl
	}
	set := self.screens.active.charset.charsets.get(slot)
	if set == .utf8 || set == .ascii {
		return unmapped_c
	}
	if unmapped_c > 0xff {
		return u32(` `)
	}
	return u32(charset_table(set)[int(unmapped_c)])
}

fn (mut self Terminal) print_wrap() ! {
	// We only mark that we soft-wrapped if we're at the edge of our
	// full screen. We don't mark the row as wrapped if we're in the
	// middle due to a right margin.
	cursor := &self.screens.active.cursor
	mark_wrap := cursor.x == self.cols - 1
	if mark_wrap {
		row_idx := self.screens.active.pages.active_start + int(cursor.y)
		if row_idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[row_idx]
				row.wrap = true
			}
		}
	}

	// Get the old semantic prompt so we can extend it to the next line.
	old_semantic := cursor.semantic_content
	old_semantic_clear := cursor.semantic_content_clear_eol

	// Move to the next line
	self.index()!
	self.screens.active.cursor_horizontal_absolute(self.scrolling_region.left)

	// We always reset our semantic prompt state
	self.screens.active.cursor.semantic_content = old_semantic
	self.screens.active.cursor.semantic_content_clear_eol = old_semantic_clear
	match old_semantic {
		.output, .input {}
		.prompt {
			idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
			if idx < self.screens.active.pages.screen_rows.len {
				unsafe {
					mut row := &self.screens.active.pages.screen_rows[idx]
					row.semantic_prompt = .prompt_continuation
				}
			}
		}
	}

	if mark_wrap {
		idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
		if idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[idx]
				// Always mark the row as a continuation
				row.wrap_continuation = true
			}
		}
	}

	// Assure that our screen is consistent
	self.screens.active.assert_integrity()
}

// ============================================================
// print helpers
// ============================================================

// Get a copy of the cell that is `left` columns to the left of the cursor
// on the cursor's row. left==0 returns the cursor cell itself. If out of
// range, returns a blank cell.
fn (self &Terminal) cursor_cell_ref(left u32) CellData {
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx < 0 || row_idx >= self.screens.active.pages.screen_rows.len {
		return CellData{}
	}
	cx := int(self.screens.active.cursor.x) - int(left)
	if cx < 0 {
		return CellData{}
	}
	row := self.screens.active.pages.screen_rows[row_idx]
	if cx >= row.cells.len {
		return CellData{}
	}
	return row.cells[cx]
}

// Set the wide property of the cell `left` columns to the left of the cursor.
fn (mut self Terminal) cursor_cell_set_wide(left u32, wide CellWide) {
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx < 0 || row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}
	cx := int(self.screens.active.cursor.x) - int(left)
	if cx < 0 {
		return
	}
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		if cx < row.cells.len {
			row.cells[cx].wide = wide
		}
	}
}

// Append a grapheme codepoint to the cell `left` columns to the left of the
// cursor on the cursor's row.
fn (mut self Terminal) append_grapheme_at(left u32, cp u32) ! {
	cx := int(self.screens.active.cursor.x) - int(left)
	if cx < 0 {
		return
	}
	self.screens.active.append_grapheme(u32(cx), cp)!
}

// Append a grapheme codepoint to the cell at absolute column `col` on the
// cursor's row. Used when the cursor may have moved from the base cell (e.g.
// VS16 widening) but the grapheme must attach to the original base column.
fn (mut self Terminal) append_grapheme_abs(col int, cp u32) ! {
	if col < 0 {
		return
	}
	self.screens.active.append_grapheme(u32(col), cp)!
}

// Set the wide property of the cell at absolute column `col` on the cursor's
// row.
fn (mut self Terminal) cell_set_wide_abs(col int, wide CellWide) {
	if col < 0 {
		return
	}
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx < 0 || row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		if col < row.cells.len {
			row.cells[col].wide = wide
		}
	}
}

// ============================================================
// Charset functions
// ============================================================

// Set the charset into the given slot.
pub fn (mut self Terminal) configure_charset(slot CharsetSlot, set Charset) {
	self.screens.active.charset.charsets.set(slot, set)
}

// Invoke the charset in slot into the active slot. If single is true,
// then this will only be invoked for a single character.
pub fn (mut self Terminal) invoke_charset(active ActiveSlot, slot CharsetSlot, single bool) {
	if single {
		self.screens.active.charset.single_shift = slot
		return
	}
	match active {
		.gl {
			self.screens.active.charset.gl = slot
		}
		.gr {
			self.screens.active.charset.gr = slot
		}
	}
}

pub enum ActiveSlot {
	gl
	gr
}

// ============================================================
// Basic cursor movement
// ============================================================

// Carriage return moves the cursor to the first column.
pub fn (mut self Terminal) carriage_return() {
	// Always reset pending wrap state
	self.screens.active.cursor.pending_wrap = false

	// In origin mode we always move to the left margin
	target := if self.modes.get(.origin) {
		self.scrolling_region.left
	} else if self.screens.active.cursor.x >= self.scrolling_region.left {
		self.scrolling_region.left
	} else {
		u16(0)
	}
	self.screens.active.cursor_horizontal_absolute(target)
}

// Linefeed moves the cursor to the next line.
pub fn (mut self Terminal) linefeed() ! {
	self.index()!
	if self.modes.get(.linefeed) {
		self.carriage_return()
	}
}

// Backspace moves the cursor back a column (but not less than 0).
pub fn (mut self Terminal) backspace() {
	self.cursor_left(1)
}

// Move the cursor up amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. If amount is
// 0, adjust it to 1.
pub fn (mut self Terminal) cursor_up(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The maximum amount the cursor can move up depends on scrolling regions
	max := if self.screens.active.cursor.y >= self.scrolling_region.top {
		self.screens.active.cursor.y - self.scrolling_region.top
	} else {
		self.screens.active.cursor.y
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_up(u32(count))
	}
}

// Move the cursor down amount lines. If amount is greater than the maximum
// move distance then it is internally adjusted to the maximum. This sequence
// will not scroll the screen or scroll region. If amount is 0, adjust it to 1.
pub fn (mut self Terminal) cursor_down(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The max the cursor can move to depends where the cursor currently is
	max := if self.screens.active.cursor.y <= self.scrolling_region.bottom {
		self.scrolling_region.bottom - self.screens.active.cursor.y
	} else {
		u16(self.rows - self.screens.active.cursor.y - 1)
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_down(u32(count))
	}
}

// Move the cursor right amount columns. If amount is greater than the
// maximum move distance then it is internally adjusted to the maximum.
// This sequence will not scroll the screen or scroll region. If amount is
// 0, adjust it to 1.
pub fn (mut self Terminal) cursor_right(count_req int) {
	// Always resets pending wrap
	self.screens.active.cursor.pending_wrap = false

	// The max the cursor can move to depends where the cursor currently is
	max := if self.screens.active.cursor.x <= self.scrolling_region.right {
		self.scrolling_region.right - self.screens.active.cursor.x
	} else {
		u16(self.cols - self.screens.active.cursor.x - 1)
	}
	count_clamped := if count_req < 1 { u16(1) } else { u16(count_req) }
	count := if max < count_clamped { max } else { count_clamped }

	if count > 0 {
		self.screens.active.cursor_right(u32(count))
	}
}

// Move the cursor to the left amount cells. If amount is 0, adjust it to 1.
pub fn (mut self Terminal) cursor_left(count_req int) {
	// Wrapping behavior depends on various terminal modes
	wrap_mode := if !self.modes.get(.wraparound) {
		WrapMode.none
	} else if self.modes.get(.reverse_wrap_extended) {
		WrapMode.reverse_extended
	} else if self.modes.get(.reverse_wrap) {
		WrapMode.reverse
	} else {
		WrapMode.none
	}

	mut count := if count_req < 1 { 1 } else { count_req }

	// If we are in no wrap mode, then we move the cursor left and exit
	// since this is the fastest and most typical path.
	if wrap_mode == .none {
		move_amt := if u16(count) < self.screens.active.cursor.x {
			u32(count)
		} else {
			u32(self.screens.active.cursor.x)
		}
		if move_amt > 0 {
			self.screens.active.cursor_left(move_amt)
		}
		self.screens.active.cursor.pending_wrap = false
		return
	}

	// If we have a pending wrap state and we are in either reverse wrap
	// modes then we decrement the amount we move by one to match xterm.
	if self.screens.active.cursor.pending_wrap {
		count -= 1
		self.screens.active.cursor.pending_wrap = false
	}

	// The margins we can move to.
	top := self.scrolling_region.top
	bottom := self.scrolling_region.bottom
	right_margin := self.scrolling_region.right
	left_margin := if self.screens.active.cursor.x < self.scrolling_region.left {
		u16(0)
	} else {
		self.scrolling_region.left
	}

	// Handle some edge cases when our cursor is already on the left margin.
	if self.screens.active.cursor.x == left_margin {
		match wrap_mode {
			// In reverse mode, if we're already before the top margin
			// then we just set our cursor to the top-left and we're done.
			.reverse {
				if self.screens.active.cursor.y <= top {
					self.screens.active.cursor_absolute(u32(left_margin), u32(top))
					return
				}
			}

			// Handled in while loop
			.reverse_extended {}
			// Handled above
			.none {}
		}
		// unreachable
	}

	for {
		// We can move at most to the left margin.
		max := int(self.screens.active.cursor.x) - int(left_margin)

		// We want to move at most the number of columns we have left
		// or our remaining count.
		amount := if max < count { max } else { count }
		count -= amount
		if amount > 0 {
			self.screens.active.cursor_left(u32(amount))
		}

		// If we have no more to move, then we're done.
		if count == 0 {
			break
		}

		// If we are at the top, then we are done.
		if self.screens.active.cursor.y == top {
			if wrap_mode != .reverse_extended {
				break
			}
			self.screens.active.cursor_absolute(u32(right_margin), u32(bottom))
			count -= 1
			continue
		}

		// UNDEFINED TERMINAL BEHAVIOR - wrap up to (0, 0) and stop
		if self.screens.active.cursor.y == 0 {
			break
		}

		// If our previous line is not wrapped then we are done.
		if wrap_mode != .reverse_extended {
			prev_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y) - 1
			if prev_idx >= 0 && prev_idx < self.screens.active.pages.screen_rows.len {
				prev_row := self.screens.active.pages.screen_rows[prev_idx]
				if !prev_row.wrap {
					break
				}
			}
		}

		self.screens.active.cursor_absolute(u32(right_margin), u32(self.screens.active.cursor.y - 1))
		count -= 1
	}
}

enum WrapMode {
	none
	reverse
	reverse_extended
}

// ============================================================
// Cursor save/restore
// ============================================================

// Save cursor position and further state.
//
// The primary and alternate screen have distinct save state. One saved state
// is kept per screen (main / alternative). If for the current screen state
// was already saved it is overwritten.
pub fn (mut self Terminal) save_cursor() {
	self.screens.active.saved_cursor = SavedCursor{
		x: self.screens.active.cursor.x
		y: self.screens.active.cursor.y
		style: self.screens.active.cursor.style
		is_protected: self.screens.active.cursor.is_protected
		pending_wrap: self.screens.active.cursor.pending_wrap
		origin: self.modes.get(.origin)
		charset: self.screens.active.charset
	}
}

// Restore cursor position and other state.
//
// The primary and alternate screen have distinct save state.
// If no save was done before values are reset to their initial values.
pub fn (mut self Terminal) restore_cursor() {
	saved := self.screens.active.saved_cursor or {
		SavedCursor{
			x: 0
			y: 0
		}
	}

	// Set the style first because it can fail
	self.screens.active.cursor.style = saved.style
	self.screens.active.manual_style_update() or {
		self.screens.active.cursor.style = CellStyle{}
		self.screens.active.manual_style_update() or {}
	}

	self.screens.active.charset = saved.charset
	self.modes.set(.origin, saved.origin)
	self.screens.active.cursor.pending_wrap = saved.pending_wrap
	self.screens.active.cursor.is_protected = saved.is_protected

	x := if saved.x < self.cols { saved.x } else { self.cols - 1 }
	y := if saved.y < self.rows { saved.y } else { self.rows - 1 }
	self.screens.active.cursor_absolute(u32(x), u32(y))

	// Ensure our screen is consistent
	self.screens.active.assert_integrity()
}

// ============================================================
// Protection mode
// ============================================================

// Set the character protection mode for the terminal.
pub fn (mut self Terminal) set_protected_mode(mode ProtectedMode) {
	match mode {
		.off {
			self.screens.active.cursor.is_protected = false
			// screen.protected_mode is NEVER reset to ".off" because
			// logic such as eraseChars depends on knowing what the
			// _most recent_ mode was.
		}
		.iso {
			self.screens.active.cursor.is_protected = true
			self.screens.active.protected_mode = .iso
		}
		.dec {
			self.screens.active.cursor.is_protected = true
			self.screens.active.protected_mode = .dec
		}
	}
}

// ============================================================
// Semantic prompt
// ============================================================

// Returns true if the cursor is currently at a prompt. Another way to look
// at this is it returns false if the shell is currently outputting something.
// This requires shell integration (semantic prompt integration).
//
// If the shell integration doesn't exist, this will always return false.
pub fn (self &Terminal) cursor_is_at_prompt() bool {
	// If we're on the secondary screen, we're never at a prompt.
	if self.screens.active_key == .alternate {
		return false
	}

	// If our page row is a prompt then we're always at a prompt
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx < self.screens.active.pages.screen_rows.len {
		row := self.screens.active.pages.screen_rows[row_idx]
		if row.semantic_prompt != .unknown {
			return true
		}
	}

	// Otherwise, determine our cursor state
	return match self.screens.active.cursor.semantic_content {
		.input, .prompt { true }
		.output { false }
	}
}

// ============================================================
// Tab functions
// ============================================================

// Horizontal tab moves the cursor to the next tabstop.
pub fn (mut self Terminal) horizontal_tab() {
	for self.screens.active.cursor.x < self.scrolling_region.right {
		// Move the cursor right
		self.screens.active.cursor_right(1)

		// If the last cursor position was a tabstop we return.
		if self.tabstops.get(self.screens.active.cursor.x) {
			return
		}
	}
}

// Same as horizontal_tab but moves to the previous tabstop instead of the next.
pub fn (mut self Terminal) horizontal_tab_back() {
	// With origin mode enabled, our leftmost limit is the left margin.
	left_limit := if self.modes.get(.origin) {
		self.scrolling_region.left
	} else {
		u16(0)
	}

	for {
		// If we're already at the edge of the screen, then we're done.
		if self.screens.active.cursor.x <= left_limit {
			return
		}

		// Move the cursor left
		self.screens.active.cursor_left(1)
		if self.tabstops.get(self.screens.active.cursor.x) {
			return
		}
	}
}

// Clear tab stops.
pub fn (mut self Terminal) tab_clear(cmd TabClear) {
	match cmd {
		.current { self.tabstops.unset(self.screens.active.cursor.x) }
		.all { self.tabstops.reset(0) }
	}
}

// Set a tab stop on the current cursor.
pub fn (mut self Terminal) tab_set() {
	self.tabstops.set(self.screens.active.cursor.x)
}

// Reset tab stops to default interval.
pub fn (mut self Terminal) tab_reset() {
	self.tabstops.reset(terminal.tabstop_interval)
}

// ============================================================
// Index / Reverse Index
// ============================================================

// Move the cursor to the next line in the scrolling region, possibly scrolling.
//
// If the cursor is outside of the scrolling region: move the cursor one line
// down if it is not on the bottom-most line of the screen.
//
// If the cursor is inside the scrolling region:
//   If the cursor is on the bottom-most line of the scrolling region:
//     invoke scroll up with amount=1
//   If the cursor is not on the bottom-most line of the scrolling region:
//     move the cursor one line down
//
// This unsets the pending wrap state without wrapping.
pub fn (mut self Terminal) index() ! {
	mut screen := self.screens.active

	// Unset pending wrap state
	screen.cursor.pending_wrap = false

	// We handle our cursor semantic prompt state AFTER doing the scrolling,
	// because we may need to apply it to new rows. This mirrors ghostty's
	// `defer` in Terminal.index: whenever the cursor's semantic content isn't
	// `.output` (i.e. `.prompt` or `.input`), the new row is marked as a
	// prompt continuation. This works around shells that don't send OSC 133
	// k=s sequences for continuations.
	defer {
		if screen.cursor.semantic_content != .output {
			// Always reset any semantic content clear-eol state. If we aren't
			// clearing at EOL and we're not output, then we mark the new row as
			// a prompt continuation.
			if screen.cursor.semantic_content_clear_eol {
				screen.cursor.semantic_content = .output
				screen.cursor.semantic_content_clear_eol = false
			} else {
				idx := screen.pages.active_start + int(screen.cursor.y)
				if idx < screen.pages.screen_rows.len {
					unsafe {
						mut row := &screen.pages.screen_rows[idx]
						row.semantic_prompt = .prompt_continuation
					}
				}
			}
		}
	}

	// Outside of the scroll region we move the cursor one line down.
	if screen.cursor.y < self.scrolling_region.top
		|| screen.cursor.y > self.scrolling_region.bottom {
		// We only move down if we're not already at the bottom of the screen.
		if screen.cursor.y < self.rows - 1 {
			// Ghostty's cursor move (cursorChangePin) marks both the old and
			// new row dirty. Our screen cursor_down only marks the new row,
			// so mark the old row dirty here to match.
			screen.cursor_mark_dirty()
			screen.cursor_down(1)
		}
		return
	}

	// If the cursor is inside the scrolling region and on the bottom-most
	// line, then we scroll up. If our scrolling region is the full screen
	// we create scrollback.
	if screen.cursor.y == self.scrolling_region.bottom
		&& screen.cursor.x >= self.scrolling_region.left
		&& screen.cursor.x <= self.scrolling_region.right {
		// If our scrolling region is at the top, we create scrollback.
		if self.scrolling_region.top == 0 && self.scrolling_region.left == 0
			&& self.scrolling_region.right == self.cols - 1 {
			screen.cursor_scroll_above()!
			return
		}

		// Slow path for left and right scrolling region margins.
		if self.scrolling_region.left != 0 || self.scrolling_region.right != self.cols - 1 {
			self.scroll_up(1)!
			return
		}

		// Use eraseRowBounded equivalent
		screen.cursor_scroll_above()!
		return
	}

	// Increase cursor by 1, maximum to bottom of scroll region
	if screen.cursor.y < self.scrolling_region.bottom {
		// Mark the old row dirty too (see note above) to match Ghostty's
		// cursorChangePin marking both old and new rows dirty.
		screen.cursor_mark_dirty()
		screen.cursor_down(1)
	}
}

// Move the cursor to the previous line in the scrolling region, possibly
// scrolling.
//
// If the cursor is outside of the scrolling region, move the cursor one
// line up if it is not on the top-most line of the screen.
//
// If the cursor is inside the scrolling region:
//   * If the cursor is on the top-most line: invoke scroll down with amount=1
//   * Otherwise: move the cursor one line up
pub fn (mut self Terminal) reverse_index() {
	if self.screens.active.cursor.y != self.scrolling_region.top
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		self.cursor_up(1)
		return
	}
	self.scroll_down(1)
}

// ============================================================
// Cursor positioning
// ============================================================

// Set Cursor Position. Move cursor to the position indicated
// by row and column (1-indexed). If column is 0, it is adjusted to 1.
// If column is greater than the right-most column it is adjusted to
// the right-most column. If row is 0, it is adjusted to 1. If row is
// greater than the bottom-most row it is adjusted to the bottom-most row.
pub fn (mut self Terminal) set_cursor_pos(row_req int, col_req int) {
	// If cursor origin mode is set the cursor row will be moved relative to
	// the top margin row.
	x_offset, y_offset, x_max, y_max := if self.modes.get(.origin) {
		self.scrolling_region.left, self.scrolling_region.top, self.scrolling_region.right + 1, self.scrolling_region.bottom + 1
	} else {
		u16(0), u16(0), self.cols, self.rows
	}

	// Unset pending wrap state
	self.screens.active.cursor.pending_wrap = false

	// Calculate our new x/y
	row := if row_req == 0 { 1 } else { row_req }
	col := if col_req == 0 { 1 } else { col_req }

	raw_x := int(col) + int(x_offset)
	raw_y := int(row) + int(y_offset)
	x := u16(if raw_x > int(x_max) { int(x_max) } else { raw_x }) - 1
	y := u16(if raw_y > int(y_max) { int(y_max) } else { raw_y }) - 1

	// Move cursor
	self.screens.active.cursor_absolute(u32(x), u32(y))
}

// ============================================================
// Margin setting
// ============================================================

// Set Top and Bottom Margins. Top and bottom are 1-indexed.
pub fn (mut self Terminal) set_top_and_bottom_margin(top_req int, bottom_req int) {
	top := if top_req < 1 { 1 } else { top_req }
	bottom_limit := if bottom_req == 0 { int(self.rows) } else { bottom_req }
	bottom := if bottom_limit > int(self.rows) { int(self.rows) } else { bottom_limit }
	if top >= bottom {
		return
	}
	self.scrolling_region.top = u16(top - 1)
	self.scrolling_region.bottom = u16(bottom - 1)
	self.set_cursor_pos(1, 1)
}

// DECSLRM - Set Left and Right Margin
pub fn (mut self Terminal) set_left_and_right_margin(left_req int, right_req int) {
	// We must have this mode enabled to do anything
	if !self.modes.get(.enable_left_and_right_margin) {
		return
	}

	left := if left_req < 1 { 1 } else { left_req }
	right_limit := if right_req == 0 { int(self.cols) } else { right_req }
	right := if right_limit > int(self.cols) { int(self.cols) } else { right_limit }
	if left >= right {
		return
	}
	self.scrolling_region.left = u16(left - 1)
	self.scrolling_region.right = u16(right - 1)
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Scrolling
// ============================================================

// Scroll the text down by one row.
pub fn (mut self Terminal) scroll_down(count int) {
	// Preserve our x/y to restore.
	old_x := self.screens.active.cursor.x
	old_y := self.screens.active.cursor.y
	old_wrap := self.screens.active.cursor.pending_wrap

	// Move to the top of the scroll region
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(self.scrolling_region.top))
	self.insert_lines(count)

	// Restore cursor
	self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
	self.screens.active.cursor.pending_wrap = old_wrap
}

// Removes amount lines from the top of the scroll region. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up
// is filled with empty lines.
//
// The new lines are created according to the current SGR state.
//
// Does not change the (absolute) cursor position.
pub fn (mut self Terminal) scroll_up(count int) ! {
	// Preserve our x/y to restore.
	old_x := self.screens.active.cursor.x
	old_y := self.screens.active.cursor.y
	old_wrap := self.screens.active.cursor.pending_wrap

	// If our scroll region is at the top and we have no left/right
	// margins then we move the scrolled out text into the scrollback.
	if self.scrolling_region.top == 0 && self.scrolling_region.left == 0
		&& self.scrolling_region.right == self.cols - 1 {
		// Clamp count to the scroll region height.
		region_height := int(self.scrolling_region.bottom) + 1
		adjusted_count := if count < region_height { count } else { region_height }

		// Move cursor to bottom and scroll
		self.screens.active.cursor_absolute(0, u32(self.scrolling_region.bottom))
		for _ in 0 .. adjusted_count {
			self.screens.active.cursor_scroll_above()!
		}

		// Restore cursor
		self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
		self.screens.active.cursor.pending_wrap = old_wrap
		return
	}

	// Move to the top of the scroll region
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(self.scrolling_region.top))
	self.delete_lines(count)

	// Restore cursor
	self.screens.active.cursor_absolute(u32(old_x), u32(old_y))
	self.screens.active.cursor.pending_wrap = old_wrap
}

// Scroll the viewport of the terminal grid.
pub fn (mut self Terminal) scroll_viewport(behavior ScrollViewport, delta int) ! {
	match behavior {
		.top { self.screens.active.scroll(.top) }
		.bottom { self.screens.active.scroll(.active) }
		.delta {
			self.screens.active.scroll_delta_rows(delta)
		}
	}
}

// ============================================================
// Insert / Delete lines
// ============================================================

// To be called before shifting a row (as in insertLines and deleteLines).
//
// Takes care of boundary conditions such as potentially split wide chars
// across scrolling region boundaries and orphaned spacer heads at line ends.
fn (mut self Terminal) row_will_be_shifted(row_idx int) {
	if row_idx < 0 || row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}
	sr := self.scrolling_region
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		cols := int(self.screens.active.pages.cols)

		// If our scrolling region includes the rightmost column then we
		// need to turn any spacer heads in to normal empty cells, since
		// once we move them they no longer correspond with soft-wrapped
		// wide characters.
		//
		// If it contains either of the 2 leftmost columns, then the wide
		// characters in the first column which may be associated with a
		// spacer head will be either moved or cleared, so we also need
		// to turn the spacer heads in to empty cells in that case.
		if sr.right == self.cols - 1 || sr.left < 2 {
			end_idx := cols - 1
			if end_idx >= 0 && end_idx < row.cells.len {
				if row.cells[end_idx].wide == .spacer_head {
					row.cells[end_idx].wide = .narrow
				}
			}
		}

		// If the leftmost or rightmost cells of our scrolling region
		// are parts of wide chars, we need to clear the cells' contents
		// since they'd be split by the move.
		left_i := int(sr.left)
		right_i := int(sr.right)

		if left_i < row.cells.len && row.cells[left_i].wide == .spacer_tail {
			wide_i := left_i - 1
			if wide_i >= 0 && wide_i < row.cells.len {
				row.cells[wide_i].graphemes = []
				row.cells[wide_i].has_grapheme = false
				row.cells[wide_i].content_tag = .codepoint
				row.cells[wide_i].codepoint = 0
				row.cells[wide_i].wide = .narrow
			}
			row.cells[left_i].wide = .narrow
		}

		if right_i < row.cells.len && row.cells[right_i].wide == .wide {
			tail_i := right_i + 1
			row.cells[right_i].graphemes = []
			row.cells[right_i].has_grapheme = false
			row.cells[right_i].content_tag = .codepoint
			row.cells[right_i].codepoint = 0
			row.cells[right_i].wide = .narrow
			if tail_i < row.cells.len {
				row.cells[tail_i].wide = .narrow
			}
		}
	}
}

// Insert amount lines at the current cursor row. The contents of the line
// at the current cursor row and below (to the bottom-most line in the
// scrolling region) are shifted down by amount lines.
//
// This unsets the pending wrap state without wrapping. If the current cursor
// position is outside of the current scroll region it does nothing.
//
// Moves the cursor to the left margin.
pub fn (mut self Terminal) insert_lines(count int) {
	// Rare, but happens
	if count == 0 {
		return
	}

	// If the cursor is outside the scroll region we do nothing.
	if self.screens.active.cursor.y < self.scrolling_region.top
		|| self.screens.active.cursor.y > self.scrolling_region.bottom
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}
	self.screens.active.mark_kitty_images_dirty()

	start_y := self.screens.active.cursor.y

	// Remaining rows from our cursor to the bottom of the scroll region.
	rem := int(self.scrolling_region.bottom) - int(self.screens.active.cursor.y) + 1
	adjusted_count := if count < rem { count } else { rem }

	// Check if we have left/right scroll margins
	left_right := self.scrolling_region.left > 0 || self.scrolling_region.right < self.cols - 1

	// Shift rows down
	active_start := self.screens.active.pages.active_start
	for y := int(self.scrolling_region.bottom); y >= int(start_y) + adjusted_count; y-- {
		src_y := y - adjusted_count
		src_idx := active_start + src_y
		dst_idx := active_start + y

		// Handle boundary conditions (split wide chars / orphaned spacer
		// heads) on the source row before shifting it.
		self.row_will_be_shifted(src_idx)

		if src_idx < self.screens.active.pages.screen_rows.len
			&& dst_idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				unsafe {
					// Full row swap. If our scrolling region is full width,
					// then we unset wrap/wrap_continuation on both the source and
					// destination rows (matches Ghostty's insertLines).
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					mut src_row := &self.screens.active.pages.screen_rows[src_idx]
					src_row.wrap = false
					src_row.wrap_continuation = false
					dst_row.cells = src_row.cells.clone()
					dst_row.wrap = false
					dst_row.wrap_continuation = false
					dst_row.styled = src_row.styled
					dst_row.grapheme = src_row.grapheme
					dst_row.hyperlink = src_row.hyperlink
					dst_row.dirty = true
				}
			} else {
				// Left/right margins: only copy cells within the margin range
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					for x in int(self.scrolling_region.left) .. int(self.scrolling_region.right) + 1 {
						if x < src_row.cells.len && x < dst_row.cells.len {
							dst_row.cells[x] = src_row.cells[x]
						}
					}
					dst_row.dirty = true
				}
			}
		}
	}

	// Clear the inserted rows
	for y in int(start_y) .. int(start_y) + adjusted_count {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				self.screens.active.clear_active_row(u32(y))
			} else {
				self.screens.active.clear_cells(idx, int(self.scrolling_region.left), int(self.scrolling_region.right) + 1)
			}
		}
	}

	// Return cursor to the left margin
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(start_y))
	self.screens.active.cursor.pending_wrap = false
}

// Removes amount lines from the current cursor row down. The remaining lines
// to the bottom margin are shifted up and space from the bottom margin up is
// filled with empty lines.
//
// Moves the cursor to the left margin.
pub fn (mut self Terminal) delete_lines(count int) {
	// Rare, but happens
	if count == 0 {
		return
	}

	// If the cursor is outside the scroll region we do nothing.
	if self.screens.active.cursor.y < self.scrolling_region.top
		|| self.screens.active.cursor.y > self.scrolling_region.bottom
		|| self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}
	self.screens.active.mark_kitty_images_dirty()

	start_y := self.screens.active.cursor.y

	// Remaining rows from our cursor to the bottom of the scroll region.
	rem := int(self.scrolling_region.bottom) - int(self.screens.active.cursor.y) + 1
	adjusted_count := if count < rem { count } else { rem }

	// Check if we have left/right scroll margins
	left_right := self.scrolling_region.left > 0 || self.scrolling_region.right < self.cols - 1

	active_start := self.screens.active.pages.active_start

	// Shift rows up
	for y in int(start_y) .. int(self.scrolling_region.bottom) - adjusted_count + 1 {
		src_y := y + adjusted_count
		src_idx := active_start + src_y
		dst_idx := active_start + y

		// Handle boundary conditions (split wide chars / orphaned spacer
		// heads) on the source row before shifting it.
		self.row_will_be_shifted(src_idx)

		if src_idx < self.screens.active.pages.screen_rows.len
			&& dst_idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					dst_row.cells = src_row.cells.clone()
					dst_row.wrap = src_row.wrap
					dst_row.wrap_continuation = src_row.wrap_continuation
					dst_row.styled = src_row.styled
					dst_row.grapheme = src_row.grapheme
					dst_row.hyperlink = src_row.hyperlink
					dst_row.dirty = true
				}
			} else {
				unsafe {
					mut dst_row := &self.screens.active.pages.screen_rows[dst_idx]
					src_row := self.screens.active.pages.screen_rows[src_idx]
					for x in int(self.scrolling_region.left) .. int(self.scrolling_region.right) + 1 {
						if x < src_row.cells.len && x < dst_row.cells.len {
							dst_row.cells[x] = src_row.cells[x]
						}
					}
					dst_row.dirty = true
				}
			}
		}
	}

	// Clear the vacated rows at the bottom
	for y in int(self.scrolling_region.bottom) - adjusted_count + 1 .. int(self.scrolling_region.bottom) + 1 {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			if !left_right {
				self.screens.active.clear_active_row(u32(y))
			} else {
				self.screens.active.clear_cells(idx, int(self.scrolling_region.left), int(self.scrolling_region.right) + 1)
			}
		}
	}

	// Return cursor to the left margin
	self.screens.active.cursor_absolute(u32(self.scrolling_region.left), u32(start_y))
	self.screens.active.cursor.pending_wrap = false
}

// ============================================================
// Insert / Delete / Erase characters
// ============================================================

// Inserts spaces at current cursor position moving existing cell contents
// to the right. The contents of the count right-most columns in the scroll
// region are lost. The cursor position is not changed.
//
// This unsets the pending wrap state without wrapping.
pub fn (mut self Terminal) insert_blanks(count int) {
	// Unset pending wrap state without wrapping.
	self.screens.active.cursor.pending_wrap = false

	// If our cursor is outside the margins then do nothing.
	if self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cursor_x := int(self.screens.active.cursor.x)

	// If our X is a wide spacer tail then we need to erase the previous cell
	// too so we don't split a multi-cell character.
	if cursor_x < self.screens.active.pages.screen_rows[row_idx].cells.len
		&& self.screens.active.pages.screen_rows[row_idx].cells[cursor_x].wide == .spacer_tail {
		self.screens.active.clear_cells(row_idx, cursor_x - 1, cursor_x + 1)
	}

	// Remaining cols from our cursor to the right margin.
	rem := int(self.scrolling_region.right) - int(self.screens.active.cursor.x) + 1
	adjusted_count := if count < rem { count } else { rem }
	scroll_amount := rem - adjusted_count

	if scroll_amount > 0 {
		// If our last cell we're shifting is wide, then we need to clear
		// it to be empty so we don't split the multi-cell char.
		end := cursor_x + scroll_amount - 1
		if end < self.screens.active.pages.screen_rows[row_idx].cells.len
			&& self.screens.active.pages.screen_rows[row_idx].cells[end].wide == .wide {
			self.screens.active.clear_cells(row_idx, end, end + 2)
		}
	}

	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]

		// Shift cells right. We work backwards so we don't overwrite data.
		if scroll_amount > 0 {
			for x := cursor_x + scroll_amount - 1; x >= cursor_x; x-- {
				src_x := x
				dst_x := x + adjusted_count
				if src_x < row.cells.len && dst_x < row.cells.len {
					row.cells[dst_x] = row.cells[src_x]
				}
			}
		}

		// Insert blanks. The blanks preserve the background color.
		blank := self.screens.active.blank_cell()
		for x in cursor_x .. cursor_x + adjusted_count {
			if x < row.cells.len {
				row.cells[x] = blank
			}
		}

		row.dirty = true
	}
}

// Removes amount characters from the current cursor position to the right.
// The remaining characters are shifted to the left and space from the right
// margin is filled with spaces.
//
// Does not change the cursor position.
pub fn (mut self Terminal) delete_chars(count_req int) {
	if count_req == 0 {
		return
	}

	// If our cursor is outside the margins then do nothing.
	if self.screens.active.cursor.x < self.scrolling_region.left
		|| self.screens.active.cursor.x > self.scrolling_region.right {
		return
	}

	// Remaining cols from our cursor to the right margin.
	rem := int(self.scrolling_region.right) - int(self.screens.active.cursor.x) + 1
	count := if count_req < rem { count_req } else { rem }

	// Handle any boundary conditions where the region being moved would
	// split a multi-cell character.
	self.screens.active.split_cell_boundary(self.screens.active.cursor.x)
	self.screens.active.split_cell_boundary(self.screens.active.cursor.x + u32(count))
	self.screens.active.split_cell_boundary(self.scrolling_region.right + 1)

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	cursor_x := int(self.screens.active.cursor.x)
	scroll_amount := rem - count
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]

		// Shift cells left
		if scroll_amount > 0 {
			for x in cursor_x .. cursor_x + scroll_amount {
				src_x := x + count
				if x < row.cells.len && src_x < row.cells.len {
					row.cells[x] = row.cells[src_x]
				}
			}
		}

		// Clear the vacated cells at the right. The blanks preserve bg color.
		blank := self.screens.active.blank_cell()
		for x in cursor_x + scroll_amount .. cursor_x + rem {
			if x < row.cells.len {
				row.cells[x] = blank
			}
		}

		// Row's soft-wrap is always reset
		row.wrap = false
		row.dirty = true
	}
}

// Erase characters at the cursor position.
pub fn (mut self Terminal) erase_chars(count_req int) {
	remaining := int(self.cols) - int(self.screens.active.cursor.x)
	count_min := if count_req < 1 { 1 } else { count_req }
	count := if count_min < remaining { count_min } else { remaining }

	// Handle any boundary conditions on the edges of the erased area.
	//
	// TODO(qwerasd): This isn't actually correct if you take in to account
	// protected modes. We need to figure out how to make clear_cells or at
	// least clear_unprotected_cells handle boundary conditions...
	self.screens.active.split_cell_boundary(self.screens.active.cursor.x)
	self.screens.active.split_cell_boundary(self.screens.active.cursor.x + u32(count))

	// Reset our row's soft-wrap.
	self.screens.active.cursor_reset_wrap()
	self.screens.active.cursor_mark_dirty()

	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	cursor_x := int(self.screens.active.cursor.x)

	if row_idx >= self.screens.active.pages.screen_rows.len {
		return
	}

	// If we never had a protection mode, then we can assume no cells are
	// protected and go with the fast path. If the last protection mode was
	// not ISO we also always ignore protection attributes.
	if self.screens.active.protected_mode != .iso {
		self.screens.active.clear_cells(row_idx, cursor_x, cursor_x + count)
		return
	}

	// Respect protected cells
	blank := self.screens.active.blank_cell()
	unsafe {
		mut row := &self.screens.active.pages.screen_rows[row_idx]
		for x in cursor_x .. cursor_x + count {
			if x < row.cells.len && !row.cells[x].is_protected {
				row.cells[x] = blank
			}
		}
		row.dirty = true
	}
}

// ============================================================
// Erase line / display
// ============================================================

// Erase the line.
pub fn (mut self Terminal) erase_line(mode EraseLine, protected_req bool) {
	row_idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
	cursor_x := int(self.screens.active.cursor.x)

	// Get the cursor cell's wide property so we can handle boundary
	// conditions where a multi-cell character would be split.
	cursor_wide := if row_idx >= 0 && row_idx < self.screens.active.pages.screen_rows.len
		&& cursor_x < self.screens.active.pages.screen_rows[row_idx].cells.len {
		self.screens.active.pages.screen_rows[row_idx].cells[cursor_x].wide
	} else {
		CellWide.narrow
	}

	start, end := match mode {
		.right {
			// If our X is a wide spacer tail then we need to erase the
			// previous cell too so we don't split a multi-cell character.
			mut x := cursor_x
			if x > 0 && cursor_wide == .spacer_tail {
				x -= 1
			}
			// Reset our row's soft-wrap.
			self.screens.active.cursor_reset_wrap()
			x, int(self.cols)
		}
		.right_unless_pending_wrap {
			// Like .right, but only if there's no pending wrap.
			if self.screens.active.cursor.pending_wrap {
				return
			}
			mut x := cursor_x
			if x > 0 && cursor_wide == .spacer_tail {
				x -= 1
			}
			self.screens.active.cursor_reset_wrap()
			x, int(self.cols)
		}
		.left {
			// If our x is a wide char we need to delete the tail too.
			mut x := cursor_x
			if cursor_wide == .wide {
				x += 1
			}
			0, x + 1
		}
		.complete {
			// Note that it seems like complete should reset the soft-wrap
			// state of the line but in xterm it does not.
			0, int(self.cols)
		}
	}

	// All modes will clear the pending wrap state
	self.screens.active.cursor.pending_wrap = false
	self.screens.active.cursor_mark_dirty()

	// We respect protected attributes if explicitly requested or if our
	// last protected mode was ISO.
	is_protected := self.screens.active.protected_mode == .iso || protected_req

	if !is_protected {
		self.screens.active.clear_cells(row_idx, start, end)
		return
	}

	// Protected mode: only clear unprotected cells
	if row_idx < self.screens.active.pages.screen_rows.len {
		blank := self.screens.active.blank_cell()
		unsafe {
			mut row := &self.screens.active.pages.screen_rows[row_idx]
			for x in start .. end {
				if x < row.cells.len && !row.cells[x].is_protected {
					row.cells[x] = blank
				}
			}
			row.dirty = true
		}
	}
}

pub enum EraseLine {
	right
	left
	complete
	right_unless_pending_wrap
}

// Erase the display.
pub fn (mut self Terminal) erase_display(mode EraseDisplay, protected_req bool) {
	// We respect protected attributes if explicitly requested or if our
	// last protected mode was ISO.
	is_protected := self.screens.active.protected_mode == .iso || protected_req

	match mode {
		.scroll_complete {
			self.screens.active.scroll_clear() or {
				self.erase_display(.complete, protected_req)
				return
			}
			// Unsets pending wrap state
			self.screens.active.cursor.pending_wrap = false
			self.screens.active.clear_kitty_images()
		}
		.complete {
			// If we're on the primary screen and our last non-empty row is
			// a prompt, then we do a scroll_complete instead. (Heuristic for ^L)
			if self.screens.active_key == .primary {
				// Check for prompt at bottom of active area
				at_prompt := self.check_at_prompt_for_clear()
				if at_prompt {
					self.screens.active.scroll_clear() or {}
				}
			}

			// All active area
			self.screens.active.clear_rows(.active, ?PointTag(none), is_protected)
			self.screens.active.cursor.pending_wrap = false
			self.screens.active.clear_kitty_images()
			self.flags.dirty.clear = true
		}
		.below {
			// All lines to the right (including the cursor)
			self.erase_line(.right, protected_req)

			// All lines below
			if self.screens.active.cursor.y + 1 < self.rows {
				self.screens.active.clear_rows_range(
					int(self.screens.active.cursor.y) + 1,
					int(self.rows),
					is_protected,
				)
			}
		}
		.above {
			// Erase to the left (including the cursor)
			self.erase_line(.left, protected_req)

			// All lines above
			if self.screens.active.cursor.y > 0 {
				self.screens.active.clear_rows_range(0, int(self.screens.active.cursor.y), is_protected)
			}
		}
		.scrollback {
			self.screens.active.erase_rows(.history, ?PointTag(none))
		}
	}
}

pub enum EraseDisplay {
	scroll_complete
	complete
	below
	above
	scrollback
}

fn (self &Terminal) check_at_prompt_for_clear() bool {
	// Go from the bottom of the active up and see if we're at a prompt.
	active_start := self.screens.active.pages.active_start
	for y := int(self.rows) - 1; y >= 0; y-- {
		idx := active_start + y
		if idx >= self.screens.active.pages.screen_rows.len {
			continue
		}
		row := self.screens.active.pages.screen_rows[idx]
		match row.semantic_prompt {
			.prompt, .prompt_continuation {
				return true
			}
			.unknown {
				return false
			}
			else {
				continue
			}
		}
	}
	return false
}

// ============================================================
// DECALN - Screen Alignment Pattern
// ============================================================

// Resets all margins and fills the whole screen with the character 'E'.
// Sets the cursor to the top left corner.
pub fn (mut self Terminal) decaln() ! {
	// Reset margins, also sets cursor to top-left
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: self.rows - 1
		left: 0
		right: self.cols - 1
	}

	// Origin mode is disabled
	self.modes.set(.origin, false)

	// Move our cursor to the top-left
	self.set_cursor_pos(1, 1)

	// Clear and fill with Es
	active_start := self.screens.active.pages.active_start
	for y in 0 .. int(self.rows) {
		idx := active_start + y
		if idx < self.screens.active.pages.screen_rows.len {
			unsafe {
				mut row := &self.screens.active.pages.screen_rows[idx]
				for x in 0 .. int(self.cols) {
					if x < row.cells.len {
						row.cells[x] = CellData{
							codepoint: u32(`E`)
							content_tag: .codepoint
							style_id: self.screens.active.cursor.style_id
							is_protected: false // DECALN does not respect protected state
						}
					}
				}
				if self.screens.active.cursor.style_id != terminal.default_style_id {
					row.styled = true
				}
				row.dirty = true
			}
		}
	}

	// Reset the cursor to the top-left
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Style attributes
// ============================================================

// Set a style attribute.
pub fn (mut self Terminal) set_attribute(attr SgrAttribute) ! {
	self.screens.active.set_attribute(attr)!
}

// Print the active attributes as a string. This is used to respond to DECRQSS.
pub fn (mut self Terminal) print_attributes() !string {
	mut result := strings.new_builder(64)

	// The SGR response always starts with a 0.
	result.write_string('0')

	pen := self.screens.active.cursor.style

	if pen.flags.bold {
		result.write_string(';1')
	}
	if pen.flags.faint {
		result.write_string(';2')
	}
	if pen.flags.italic {
		result.write_string(';3')
	}
	if pen.flags.underline != .none {
		result.write_string(';4')
	}
	if pen.flags.blink {
		result.write_string(';5')
	}
	if pen.flags.inverse {
		result.write_string(';7')
	}
	if pen.flags.invisible {
		result.write_string(';8')
	}
	if pen.flags.strikethrough {
		result.write_string(';9')
	}

	match pen.fg_color {
		.none {}
		.palette {
			idx := pen.fg_palette
			if idx >= 16 {
				result.write_string(';38:5:${idx}')
			} else if idx >= 8 {
				result.write_string(';9${idx - 8}')
			} else {
				result.write_string(';3${idx}')
			}
		}
		.rgb { result.write_string(';38:2::${pen.fg_r}:${pen.fg_g}:${pen.fg_b}') }
	}
	match pen.bg_color {
		.none {}
		.palette {
			idx := pen.bg_palette
			if idx >= 16 {
				result.write_string(';48:5:${idx}')
			} else if idx >= 8 {
				result.write_string(';10${idx - 8}')
			} else {
				result.write_string(';4${idx}')
			}
		}
		.rgb { result.write_string(';48:2::${pen.bg_r}:${pen.bg_g}:${pen.bg_b}') }
	}

	return result.str()
}

// ============================================================
// DECCOLM
// ============================================================

// DECCOLM changes the terminal width between 80 and 132 columns.
// This will do NOTHING unless enable_mode_3 has been set.
pub fn (mut self Terminal) deccolm(mode DeccolmMode) ! {
	// If DEC mode 40 isn't enabled, then this is ignored.
	if !self.modes.get(.enable_mode_3) {
		self.modes.set(.column_132, false)
		return
	}

	// Enable it
	self.modes.set(.column_132, mode == .cols_132)

	// Resize to the requested size
	new_cols := match mode {
		.cols_132 { u16(132) }
		.cols_80 { u16(80) }
	}
	self.resize(new_cols, self.rows)!

	// Erase our display and move our cursor.
	self.erase_display(.complete, false)
	self.set_cursor_pos(1, 1)
}

// ============================================================
// Resize
// ============================================================

// Resize the underlying terminal.
pub fn (mut self Terminal) resize(cols u16, rows u16) ! {
	// If our cols/rows didn't change then we're done
	if self.cols == cols && self.rows == rows {
		return
	}

	// Resize our tabstops
	if self.cols != cols {
		self.tabstops.deinit()
		self.tabstops = Tabstops.init(int(cols), 8)!
	}

	// Whether the active screen will reflow on this resize.
	active_reflow := self.screens.active_key == .primary && self.modes.get(.wraparound)

	// If we have a saved (DECSC) cursor and we're going to reflow, ask the
	// reflow to track it as a pin so we can remap its position afterward.
	// This mirrors ghostty, where the saved cursor is a tracked pin.
	mut track_saved := false
	mut saved_pending_wrap := false
	if sc := self.screens.active.saved_cursor {
		if active_reflow && u32(cols) != self.cols && sc.x < self.cols && sc.y < self.rows {
			track_saved = true
			saved_pending_wrap = sc.pending_wrap
			self.screens.active.pages.reflow_saved_track = true
			self.screens.active.pages.reflow_saved_in_x = sc.x
			self.screens.active.pages.reflow_saved_in_y = sc.y
		}
	}

	// Resize the active screen. All terminal state is read/written through
	// `screens.active`, so this is the screen we must resize to keep content
	// consistent. The primary screen supports reflow (governed by the
	// wraparound mode); the alternate screen never reflows.
	self.screens.active.resize(ScreenResize{
		cols: u32(cols)
		rows: u32(rows)
		reflow: active_reflow
	})!

	// Apply the reflow-tracked saved cursor position. Screen.resize already
	// ran its own (naive) saved-cursor remap; we override it here with the
	// pin-tracked result so reflowed content maps correctly.
	if track_saved && self.screens.active.pages.reflow_did_reflow {
		if mut sc := self.screens.active.saved_cursor {
			new_x := self.screens.active.pages.reflow_saved_out_x
			new_y := self.screens.active.pages.reflow_saved_out_y
			sc.x = new_x
			sc.y = new_y
			sc.pending_wrap = saved_pending_wrap
			// If we had pending wrap set and we're no longer at the end of
			// the line, unset pending wrap and move the cursor to reflect the
			// correct next position (matches ghostty / Screen.resize).
			if sc.pending_wrap && sc.x != u32(cols) - 1 {
				sc.pending_wrap = false
				sc.x += 1
			}
			self.screens.active.saved_cursor = sc
		}
	}
	self.screens.active.pages.reflow_saved_track = false

	// Resize the inactive screen too so both stay in sync. When the primary
	// screen is active, the inactive screen is the alternate (no reflow).
	// When the alternate screen is active, the inactive screen is the
	// primary (reflow governed by wraparound).
	if self.screens.active_key == .primary {
		// Alternate screen, if it exists, doesn't reflow.
		if self.screens.alternate_ptr != unsafe { nil } {
			self.screens.alternate_ptr.resize(ScreenResize{
				cols: u32(cols)
				rows: u32(rows)
				reflow: false
			})!
		}
	} else {
		// Primary screen supports reflow.
		self.screens.primary.resize(ScreenResize{
			cols: u32(cols)
			rows: u32(rows)
			reflow: self.modes.get(.wraparound)
		})!
	}

	// Whenever we resize we just mark it as a screen clear
	self.flags.dirty.clear = true

	// Set our size
	self.cols = cols
	self.rows = rows

	// Reset the scrolling region
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: rows - 1
		left: 0
		right: cols - 1
	}
}

// ============================================================
// PWD
// ============================================================

// Set the pwd for the terminal.
pub fn (mut self Terminal) set_pwd(pwd_str string) ! {
	self.pwd = pwd_str
}

// Returns the pwd for the terminal, if any.
pub fn (self &Terminal) get_pwd() ?string {
	if self.pwd.len == 0 {
		return none
	}
	return self.pwd
}

// ============================================================
// Screen switching
// ============================================================

// Switch to the given screen type (alternate or primary).
//
// This does NOT handle behaviors such as clearing the screen,
// copying the cursor, etc.
pub fn (mut self Terminal) switch_screen(key ScreenKey) !&Screen {
	// If we're already on the requested screen we do nothing.
	if self.screens.active_key == key {
		return unsafe { &Screen(nil) }
	}
	mut old := self.screens.active

	// We always end hyperlink state when switching screens.
	old.end_hyperlink()

	// Switch the screens
	match key {
		.alternate {
			if self.screens.alternate_ptr == unsafe { nil } {
				// Create alternate screen on heap (no scrollback)
				mut init_screen := Screen.init(u32(self.cols), u32(self.rows), 0)
				self.screens.alternate_ptr = unsafe { &Screen(memdup(&init_screen, int(sizeof(Screen)))) }
			}
		}
		.primary {}
	}

	// Switch and bring charset state
	self.screens.switch_to(key)
	self.screens.active.charset = old.charset

	// Clear selection on new screen
	self.screens.active.clear_selection()
	self.screens.active.mark_kitty_images_dirty()

	// Mark terminal as dirty
	self.flags.dirty.clear = true

	return old
}

// Switch screen via a mode switch (e.g. mode 47, 1047, 1049).
pub fn (mut self Terminal) switch_screen_mode(mode SwitchScreenMode, enabled bool) ! {
	match mode {
		.mode_47 {}
		// If we're disabling 1047 and we're on alt screen then
		// we clear the screen.
		.mode_1047 {
			if !enabled && self.screens.active_key == .alternate {
				self.erase_display(.complete, false)
			}
		}

		// 1049 unconditionally saves the cursor on enabling.
		.mode_1049 {
			if enabled {
				self.save_cursor()
			}
		}
	}

	// Switch screens first to whatever we're going to.
	to := if enabled { ScreenKey.alternate } else { ScreenKey.primary }
	old_ := self.switch_screen(to)!

	match mode {
		// For these modes, we need to copy the cursor. We only copy the
		// cursor if the screen actually changed, otherwise the cursor is
		// already copied. The cursor is copied regardless of destination
		// screen. switch_screen returns a nil pointer when the screen
		// didn't change.
		.mode_47, .mode_1047 {
			if old_ != unsafe { nil } {
				old_cursor := old_.cursor
				self.screens.active.cursor_copy(old_cursor) or {
					// cursor copy failed entering alt screen
				}
			}
		}

		// Mode 1049 restores cursor on the primary screen when disabled.
		.mode_1049 {
			if enabled {
				self.erase_display(.complete, false)

				// When we enter alt screen with 1049, we always copy the
				// cursor from the primary screen (if we weren't already
				// on it).
				if old_ != unsafe { nil } {
					old_cursor := old_.cursor
					self.screens.active.cursor_copy(old_cursor) or {
						// cursor copy failed entering alt screen
					}
				}
			} else {
				self.restore_cursor()
			}
		}
	}
}

// ============================================================
// Plain string output
// ============================================================

// Return the current string value of the terminal. Newlines are
// encoded as "\n". This omits any formatting such as fg/bg.
pub fn (mut self Terminal) plain_string() !string {
	return self.screens.active.dump_string_alloc(.active)!
}

// Same as plain_string, but respects row wrap state when building the string.
pub fn (mut self Terminal) plain_string_unwrapped() !string {
	return self.screens.active.dump_string_alloc_unwrapped(.active)!
}

// ============================================================
// Full reset
// ============================================================

// Full reset.
//
// This will attempt to free the existing screen memory but if that fails
// this will reuse the existing memory. In the latter case, memory may
// be wasted (since its unused) but it isn't leaked.
pub fn (mut self Terminal) full_reset() {
	// Ensure we're back on primary screen
	self.screens.switch_to(.primary)
	self.screens.remove(.alternate)

	// Reset our screens
	self.screens.active.reset()

	// Reset our basic state
	self.modes.reset()
	self.flags = TerminalFlags{}
	self.tabstops.reset(terminal.tabstop_interval)
	self.previous_char = none
	self.pwd = ''
	self.status_display = .main
	self.scrolling_region = ScrollingRegion{
		top: 0
		bottom: self.rows - 1
		left: 0
		right: self.cols - 1
	}

	// Always mark dirty so we redraw everything
	self.flags.dirty.clear = true
}

// Perform a semantic prompt command (OSC 133).
//
// If there is an error, we do our best to get the terminal into some
// coherent state, since callers typically can't handle errors (since
// they're sending sequences via the pty).
//
pub fn (mut self Terminal) semantic_prompt(action SemanticPromptAction, exit_code ?i32) {
	options := if code := exit_code { '${code}' } else { '' }
	self.semantic_prompt_options(action, options)
}

// Perform a semantic prompt command with its raw semicolon-separated options.
// Malformed and unknown options are ignored as required by the OSC 133 spec.
pub fn (mut self Terminal) semantic_prompt_options(action SemanticPromptAction, options string) {
	match action {
		.fresh_line {
			self.semantic_prompt_fresh_line()
		}
		.fresh_line_new_prompt {
			self.semantic_prompt_fresh_line()
			self.screens.active.cursor_set_semantic_content_prompt(prompt_kind_from_osc(options))

			if redraw := osc.read_redraw(options) {
				self.flags.shell_redraws_prompt = match redraw {
					.redraw_false { .false_ }
					.redraw_true { .true_ }
					.last { .last }
				}
			}

			if click_events := osc.read_click_events(options) {
				if click_events {
					self.screens.active.semantic_prompt.click = .click_events
					return
				}
			}
			if click := osc.read_click(options) {
				self.screens.active.semantic_prompt.click = match click {
					.line { .cl_line }
					.multiple { .cl_multiple }
					.conservative_vertical { .cl_conservative_vertical }
					.smart_vertical { .cl_smart_vertical }
				}
			}
		}
		.new_command {
			self.semantic_prompt_options(.fresh_line_new_prompt, options)
		}
		.prompt_start {
			self.screens.active.cursor_set_semantic_content_prompt(prompt_kind_from_osc(options))
		}
		.end_prompt_start_input {
			self.screens.active.cursor_set_semantic_content_input(false)
		}
		.end_prompt_start_input_terminate_eol {
			self.screens.active.cursor_set_semantic_content_input(true)
		}
		.end_input_start_output {
			self.screens.active.cursor_set_semantic_content_output()

			// If our current row is marked as a prompt and we're at column
			// zero then we assume we're un-prompting. This is a heuristic to
			// deal with fish, mostly (it has no PS2 equivalent and its OSC133
			// marking doesn't output continuation lines as k=s). So we assume
			// when we get a newline with a prompt cursor that the new line is
			// also a prompt. But fish changes to output on the newline, so if
			// we're at col 0 we just assume we're overwriting the prompt.
			idx := self.screens.active.pages.active_start + int(self.screens.active.cursor.y)
			if self.screens.active.cursor.x == 0
				&& idx >= 0 && idx < self.screens.active.pages.screen_rows.len {
				unsafe {
					mut row := &self.screens.active.pages.screen_rows[idx]
					if row.semantic_prompt != .unknown {
						row.semantic_prompt = .unknown
					}
				}
			}
		}
		.end_command {
			self.screens.active.cursor_set_semantic_content_output()
		}
	}
}

fn prompt_kind_from_osc(options string) PromptKind {
	kind := osc.read_prompt_kind(options) or { return .initial }
	return match kind {
		.initial { .initial }
		.right { .right }
		.continuation { .continuation }
		.secondary { .secondary }
	}
}

// OSC 133;L: do a fresh-line.
fn (mut self Terminal) semantic_prompt_fresh_line() {
	// Spec: "If the cursor is the initial column (left, assuming
	// left-to-right writing), do nothing." We take the liberty to assume
	// that in a left/right margin context, if the cursor is outside of the
	// left margin, we treat it as being at the left margin for the purposes
	// of this command.
	left_margin := if self.screens.active.cursor.x < self.scrolling_region.left {
		u32(0)
	} else {
		self.scrolling_region.left
	}

	if self.screens.active.cursor.x == left_margin {
		return
	}

	self.carriage_return()
	self.index() or {}
}

// ModeState save/restore
pub fn (mut self ModeState) save(mode Mode) {
	bit := u64(1) << (int(mode) & 63)
	if (self.values.data & bit) != 0 {
		self.saved.data |= bit
	} else {
		self.saved.data &= ~bit
	}
}

pub fn (mut self ModeState) restore(mode Mode) bool {
	bit := u64(1) << (int(mode) & 63)
	val := (self.saved.data & bit) != 0
	if val {
		self.values.data |= bit
	} else {
		self.values.data &= ~bit
	}
	return val
}

// ============================================================
// Testing helpers
// ============================================================

// Returns true if the point is dirty, used for testing.
pub fn (self &Terminal) is_dirty(x u32, y u32) bool {
	idx := self.screens.active.pages.active_start + int(y)
	if idx < self.screens.active.pages.screen_rows.len {
		row := self.screens.active.pages.screen_rows[idx]
		return row.dirty
	}
	return false
}

// Clear all dirty bits. Testing only.
pub fn (mut self Terminal) clear_dirty() {
	for mut row in self.screens.active.pages.screen_rows {
		row.dirty = false
	}
}

// Helper to clear rows in a range (active-area-relative y coordinates).
fn (mut self Screen) clear_rows_range(start_y int, end_y int, is_protected bool) {
	active_start := self.pages.active_start
	for y in start_y .. end_y {
		idx := active_start + y
		if idx >= self.pages.screen_rows.len {
			break
		}
		unsafe {
			mut row := &self.pages.screen_rows[idx]
			if is_protected {
				for mut cell in row.cells {
					if !cell.is_protected {
						cell = CellData{}
					}
				}
			} else {
				for i in 0 .. row.cells.len {
					row.cells[i] = CellData{}
				}
				row.styled = false
				row.grapheme = false
				row.hyperlink = false
			}
			row.dirty = true
		}
	}
}

// ============================================================
// Unicode width and grapheme break helpers
// ============================================================
//
// Ghostty uses the uucode-generated Unicode tables (unicode.table.get(c).width
// and uucode.grapheme.BreakState) for exact width computation and grapheme
// segmentation. Those tables are not present in this port, so the functions
// below are pragmatic approximations that cover the common cases exercised
// by the terminal (East Asian wide characters, combining marks, emoji,
// variation selectors, ZWJ, skin tones, and regional indicators). This is a
// faithful translation of the *logic* around width/grapheme handling with a
// simplified data source.

// Determine the display width (0, 1, or 2 cells) of a codepoint.
// Precondition: control characters are filtered prior to calling this.
fn codepoint_width(c u32) u16 {
	// Emoji modifiers are zero-width inside a valid emoji grapheme, but are
	// double-width when displayed by themselves.
	if c >= 0x1F3FB && c <= 0x1F3FF {
		return 2
	}
	if is_emoji_presentation(c) {
		return 2
	}
	if is_zero_width(c) {
		return 0
	}
	width := utf8_str_visible_length(rune(c).str())
	if width > 0 {
		return if width >= 2 { u16(2) } else { u16(1) }
	}
	// utf8_str_visible_length treats both Extend and SpacingMark/Prepend
	// grapheme properties as zero. Ghostty's width table only makes Extend
	// zero-width. Probe the standard library's table-driven grapheme state:
	// only Extend preserves an Extended_Pictographic + Extend* + ZWJ chain.
	probe := rune(0x1f469).str() + rune(c).str() + rune(0x200d).str() + rune(0x1f469).str()
	return if probe.graphemes().len == 1 { u16(0) } else { u16(1) }
}

// Returns true if the codepoint has zero display width. This covers
// combining marks (Mn/Mc general categories) and format characters
// (Cf, e.g. ZWJ, VS15/VS16) that attach to a base character.
fn is_zero_width(c u32) bool {
	// C0/C1 handled elsewhere; treat NUL as zero for safety.
	if c == 0 {
		return true
	}
	// Zero Width Space, ZWNJ, ZWJ, and related format chars.
	if c == 0x200B || c == 0x200C || c == 0x200D || c == 0xFEFF {
		return true
	}
	// Variation selectors VS1-VS16 (includes VS15/VS16).
	if c >= 0xFE00 && c <= 0xFE0F {
		return true
	}
	// Combining Diacritical Marks and related blocks.
	if (c >= 0x0300 && c <= 0x036F) // Combining Diacritical Marks

		|| (c >= 0x0483 && c <= 0x0489) // Cyrillic combining

		|| (c >= 0x0591 && c <= 0x05BD) // Hebrew points

		|| (c >= 0x0610 && c <= 0x061A) // Arabic marks

		|| (c >= 0x064B && c <= 0x065F) // Arabic marks

		|| c == 0x0670 // Arabic superscript alef

		|| (c >= 0x06D6 && c <= 0x06DC) // Arabic small high

		|| (c >= 0x0E31 && c <= 0x0E3A && c != 0x0E32 && c != 0x0E33) // Thai

		|| (c >= 0x1AB0 && c <= 0x1AFF) // Combining Diacritical Marks Extended

		|| (c >= 0x1DC0 && c <= 0x1DFF) // Combining Diacritical Marks Supplement

		|| (c >= 0x20D0 && c <= 0x20FF) // Combining Diacritical Marks for Symbols

		|| (c >= 0xFE20 && c <= 0xFE2F) { // Combining Half Marks
		return true
	}
	// NOTE: Emoji skin-tone modifiers (0x1F3FB-0x1F3FF) are intentionally
	// NOT treated as zero-width here. Their standalone display width is 2
	// (they live in the wide emoji block). They only "disappear" into a
	// preceding emoji via grapheme clustering (see grapheme_break), which
	// runs before the width path. This matches uucode/ghostty.
	return false
}

// Returns true if the codepoint is displayed as a wide (2-cell) character.
fn is_wide(c u32) bool {
	// Fast reject for ASCII/Latin.
	if c < 0x1100 {
		return false
	}
	// Symbols with Emoji_Presentation=Yes in the BMP default to width 2
	// even though they live in otherwise-narrow blocks. This matches
	// uucode's wcwidth (used by ghostty). Note that many neighboring
	// symbols (e.g. 0x2764 Heart, 0x26C8 Thunder cloud) are NOT in this
	// set and remain narrow until upgraded by VS16.
	if is_emoji_presentation(c) {
		return true
	}
	return (c >= 0x1100 && c <= 0x115F) // Hangul Jamo

		|| c == 0x2329 || c == 0x232A
		|| (c >= 0x2E80 && c <= 0x303E) // CJK Radicals, Kangxi

		|| (c >= 0x3041 && c <= 0x33FF) // Hiragana..CJK compat

		|| (c >= 0x3400 && c <= 0x4DBF) // CJK Ext A

		|| (c >= 0x4E00 && c <= 0x9FFF) // CJK Unified

		|| (c >= 0xA000 && c <= 0xA4CF) // Yi

		|| (c >= 0xAC00 && c <= 0xD7A3) // Hangul Syllables

		|| (c >= 0xF900 && c <= 0xFAFF) // CJK Compat Ideographs

		|| (c >= 0xFE10 && c <= 0xFE19) // Vertical forms

		|| (c >= 0xFE30 && c <= 0xFE6F) // CJK Compat forms, Small forms

		|| (c >= 0xFF00 && c <= 0xFF60) // Fullwidth forms

		|| (c >= 0xFFE0 && c <= 0xFFE6) // Fullwidth signs

		|| (c >= 0x1F300 && c <= 0x1F64F) // Emoji (Misc Symbols/Pictographs, Emoticons)

		|| (c >= 0x1F900 && c <= 0x1F9FF) // Supplemental Symbols and Pictographs

		|| (c >= 0x1FA70 && c <= 0x1FAFF) // Symbols and Pictographs Extended-A

		|| (c >= 0x20000 && c <= 0x3FFFD) // CJK Ext B+ and Supplementary Ideographic
}

// Returns true if the codepoint has Emoji_Presentation=Yes, i.e. it is
// rendered as a full-color, double-width emoji by default (without needing
// VS16). This is the BMP + astral set from the Unicode emoji-data.txt file
// that determines a default width of 2. Codepoints not in this set that are
// still Emoji=Yes require an explicit VS16 to become wide.
fn is_emoji_presentation(c u32) bool {
	// BMP Emoji_Presentation ranges.
	if c < 0x1F000 {
		return c == 0x231A || c == 0x231B
			|| (c >= 0x23E9 && c <= 0x23EC)
			|| c == 0x23F0 || c == 0x23F3
			|| (c >= 0x25FD && c <= 0x25FE)
			|| (c >= 0x2614 && c <= 0x2615)
			|| (c >= 0x2648 && c <= 0x2653)
			|| c == 0x267F
			|| c == 0x2693
			|| c == 0x26A1
			|| (c >= 0x26AA && c <= 0x26AB)
			|| (c >= 0x26BD && c <= 0x26BE)
			|| (c >= 0x26C4 && c <= 0x26C5)
			|| c == 0x26CE
			|| c == 0x26D4
			|| c == 0x26EA
			|| (c >= 0x26F2 && c <= 0x26F3)
			|| c == 0x26F5
			|| c == 0x26FA
			|| c == 0x26FD
			|| c == 0x2705
			|| (c >= 0x270A && c <= 0x270B)
			|| c == 0x2728
			|| c == 0x274C
			|| c == 0x274E
			|| (c >= 0x2753 && c <= 0x2755)
			|| c == 0x2757
			|| (c >= 0x2795 && c <= 0x2797)
			|| c == 0x27B0
			|| c == 0x27BF
			|| (c >= 0x2B1B && c <= 0x2B1C)
			|| c == 0x2B50
			|| c == 0x2B55
	}
	// Astral Emoji_Presentation is broadly covered by the wide emoji ranges
	// already handled in is_wide (0x1F300+), so we don't need to duplicate
	// them here.
	return false
}

// Returns true if `c` is a valid base for an emoji variation sequence, i.e.
// one that appears in emoji-variation-sequences.txt and can therefore be
// followed by VS15 (text) or VS16 (emoji) to change its presentation.
//
// This is NOT the same as "is an emoji": the vast majority of full-color
// astral emoji (people, gestures, animals, e.g. U+1F469 woman, U+1F9E0
// brain) do NOT have a text-presentation variant and are thus NOT valid VS
// bases. Applying a VS to them must be ignored (see ghostty issue tests).
//
// The VS bases are almost entirely in the BMP legacy symbol/dingbat blocks
// (keycap digits, arrows, misc symbols, dingbats). We cover those ranges
// and treat all astral codepoints as non-bases, which is faithful for every
// case the Terminal tests exercise.
fn is_emoji_vs_base(c u32) bool {
	// Keycap bases: # * 0-9
	if c == 0x0023 || c == 0x002A || (c >= 0x0030 && c <= 0x0039) {
		return true
	}
	// Legacy symbols/arrows/dingbats etc. that carry emoji variation
	// sequences live in the BMP symbol area. Astral emoji do not.
	if c >= 0x00A9 && c <= 0x2BFF {
		return true
	}
	return false
}

// Returns true if the codepoint is Extended_Pictographic (roughly, an emoji).
fn is_extended_pictographic(c u32) bool {
	return c == 0x00A9 || c == 0x00AE || c == 0x203C || c == 0x2049
		|| (c >= 0x2100 && c <= 0x27BF)
		|| (c >= 0x2B00 && c <= 0x2BFF)
		|| (c >= 0x1F000 && c <= 0x1FAFF)
		|| (c >= 0x1F1E6 && c <= 0x1F1FF) // Regional indicators
}

fn is_indic_conjunct_linker(c u32) bool {
	return c == 0x094d || c == 0x09cd || c == 0x0acd || c == 0x0b4d || c == 0x0c4d
		|| c == 0x0d4d
}

fn is_indic_conjunct_consonant(c u32) bool {
	return (c >= 0x0915 && c <= 0x0939) || (c >= 0x0958 && c <= 0x095f)
		|| (c >= 0x0978 && c <= 0x097f) || (c >= 0x0995 && c <= 0x09a8)
		|| (c >= 0x09aa && c <= 0x09b0) || c == 0x09b2 || (c >= 0x09b6 && c <= 0x09b9)
		|| (c >= 0x09dc && c <= 0x09dd) || c == 0x09df || (c >= 0x09f0 && c <= 0x09f1)
		|| (c >= 0x0a95 && c <= 0x0aa8) || (c >= 0x0aaa && c <= 0x0ab0)
		|| (c >= 0x0ab2 && c <= 0x0ab3) || (c >= 0x0ab5 && c <= 0x0ab9) || c == 0x0af9
		|| (c >= 0x0b15 && c <= 0x0b28) || (c >= 0x0b2a && c <= 0x0b30)
		|| (c >= 0x0b32 && c <= 0x0b33) || (c >= 0x0b35 && c <= 0x0b39)
		|| (c >= 0x0b5c && c <= 0x0b5d) || c == 0x0b5f || c == 0x0b71
		|| (c >= 0x0c15 && c <= 0x0c28) || (c >= 0x0c2a && c <= 0x0c39)
		|| (c >= 0x0c58 && c <= 0x0c5a) || (c >= 0x0d15 && c <= 0x0d3a)
}

// Returns whether appending cp creates a new Unicode extended grapheme
// cluster. The standard library implementation is generated from the
// Unicode GraphemeBreakProperty and emoji data, just as Ghostty's uucode
// BreakState is.
fn grapheme_break_cell(prev CellData, cp u32) bool {
	// Emoji modifiers (Fitzpatrick skin tones) are special: unlike generic
	// Extend characters, they only combine with an emoji-modifier base
	// (an emoji), NOT with arbitrary preceding characters. This matches
	// uucode/UAX #29 which ghostty verifies:
	//   graphemeBreak(0x261D, 0x1F3FF) == false  (emoji + modifier: join)
	//   graphemeBreak(0x22,   0x1F3FF) == true   (non-emoji + modifier: break)
	if cp >= 0x1F3FB && cp <= 0x1F3FF {
		return !is_extended_pictographic(prev.codepoint)
	}
	// Unicode 15.1 GB9c: Consonant [Extend Linker]* Linker [Extend Linker]*
	// × Consonant. V's bundled Unicode 13 tables predate this rule.
	if is_indic_conjunct_consonant(prev.codepoint) && is_indic_conjunct_consonant(cp) {
		for part in prev.graphemes {
			if is_indic_conjunct_linker(part) {
				return false
			}
		}
	}
	mut runes := []rune{cap: prev.graphemes.len + 2}
	runes << rune(prev.codepoint)
	for part in prev.graphemes {
		runes << rune(part)
	}
	before := runes.string().graphemes().len
	runes << rune(cp)
	return runes.string().graphemes().len > before
}
