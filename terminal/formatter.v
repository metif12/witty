module terminal

// --- Original Ghostty Comments Start: src/terminal/formatter.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/terminal/formatter.zig
//
// Formats available.
// Plain text.
// Include VT sequences to preserve colors, styles, URLs, etc.
// This is predominantly SGR sequences but may contain others as needed.
//
// Note that for reference colors, like palette indices, this will
// vary based on the formatter and you should see the docs. For example,
// PageFormatter with VT will emit SGR sequences with palette indices,
// not the color itself.
//
// For VT, newlines will be emitted as `\r\n` so that the cursor properly
// moves back to the beginning prior emitting follow-up lines.
// HTML output.
//
// This will emit inline styles for as much styling as possible,
// in the interest of simplicity and ease of editing. This isn't meant
// to build the most beautiful or efficient HTML, but rather to be
// stylistically correct.
//
// For colors, RGB values are emitted as inline CSS (#RRGGBB) while palette
// indices use CSS variables (var(--vt-palette-N)). The palette colors are
// emitted by TerminalFormatter.Extra.palette as a <style> block if you
// want to also include that. But if you only format a screen or lower,
// the formatter doesn't have access to the current palette to render it.
//
// Newlines are emitted as actual '\n' characters. Consumers should use
// CSS white-space: pre or pre-wrap to preserve spacing and alignment.
// Unicode codepoint range to replace.
// Asserts: range[0] <= range[1]
// Replacement value for this range.
// A single replacement codepoint.
// A UTF-8 encoded string to replace with. Asserts the
// UTF-8 encoding (must be valid).
// Common encoding options regardless of what exact formatter is used.
// The format to emit.
// Whether to unwrap soft-wrapped lines. If false, this will emit the
// screen contents as it is rendered on the page in the given size.
// Trim trailing whitespace on lines with other text. Trailing blank
// lines are always trimmed. This only affects trailing whitespace
// on rows that have at least one other cell with text. Whitespace
// is currently only space characters (0x20).
// Replace matching Unicode codepoints with some other values.
// This will use the last matching range found in the list.
// Set a background and foreground color to use for the "screen".
// For styled formats, this will emit the proper sequences or styles.
// If set, then styled formats in `emit` will use this palette to
// emit colors directly as RGB. If this is null, styled formats will
// still work but will use deferred palette styling (e.g. CSS variables
// for HTML or the actual palette indexes for VT).
// Maps byte positions in formatted output to PageList pins.
//
// Used by formatters that operate on PageLists to track the source position
// of each byte written. The caller is responsible for freeing the map.
// Terminal formatter formats the active terminal screen.
//
// This will always only emit data related to the currently active screen.
// If you want to emit data for a specific screen (e.g. primary vs alt), then
// switch to that screen in the terminal prior to using this.
//
// If you want to emit data for all screens (a less common operation), then
// you must create a no-content TerminalFormatter followed by multiple
// explicit ScreenFormatter calls. This isn't a common operation so this
// little extra work should be acceptable.
//
// For styled formatting, this will emit the palette colors at the
// beginning so that the output can be rendered properly according to
// the current terminal state.
// The terminal to format.
// The common options
// The content to include.
// Extra stuff to emit, such as terminal modes, palette, cursor, etc.
// This information is ONLY emitted when the format is "vt".
// If non-null, then `map` will contain the Pin of every byte
// byte written to the writer offset by the byte index. It is the
// caller's responsibility to free the map.
//
// Note that some emitted bytes may not correspond to any Pin, such as
// the extra data around terminal state (palette, modes, etc.). For these,
// we'll map it to the most previous pin so there is some continuity but
// its an arbitrary choice.
//
// Warning: there is a significant performance hit to track this
// Emit the palette using OSC 4 sequences.
// Emit terminal modes that differ from their defaults using CSI h/l
// sequences. Defaults are according to the Ghostty defaults which
// are generally match most terminal defaults. This will include
// things like current screen, bracketed mode, mouse event reporting,
// etc.
// Emit scrolling region state using DECSTBM and DECSLRM sequences.
// Emit tabstop positions by clearing all tabs (CSI 3 g) and setting
// each configured tabstop with HTS.
// Emit the present working directory using OSC 7.
// Emit keyboard modes such as ModifyOtherKeys using CSI > 4 m
// sequences.
// The screen extras to emit. TerminalFormatter always only
// emits data for the currently active screen. If you want to emit
// data for all screens, you should manually construct a no-content
// terminal formatter, followed by screen formatters.
// Emit nothing.
// Emit style-relevant information only such as palettes.
// Emit everything. This reconstructs the terminal state as closely
// as possible.
// Emit palette before screen content if using VT format. Technically
// we could do this after but this way if replay is slow for whatever
// reason the colors will be right right away.
// For HTML, we emit CSS to setup our palette variables.
// If we have a pin_map, add the bytes we wrote to map.
// Map all those bytes to the same pin. Use the top left to ensure
// the node pointer is always properly initialized.
// Emit terminal modes that differ from defaults. We probably have
// some modes we want to emit before and some after, but for now for
// simplicity we just emit them all before. If we make this more complex
// later we should add test cases for it.
// If we have a pin_map, add the bytes we wrote to map.
// Map all those bytes to the same pin. Use the top left to ensure
// the node pointer is always properly initialized.
// Extra terminal state to emit after the screen contents so that
// it doesn't impact the emitted contents.
// Emit scrolling region using DECSTBM and DECSLRM
// DECSTBM: top and bottom margins (1-indexed)
// Only emit if not the full screen
// DECSLRM: left and right margins (1-indexed)
// Only emit if not the full width
// Emit tabstop positions
// Clear all tabs (CSI 3 g)
// Set each configured tabstop by moving cursor and using HTS
// Move cursor to the column (1-indexed)
// Set tab (HTS)
// Emit keyboard modes such as ModifyOtherKeys
// Only emit if modify_other_keys_2 is true
// Emit present working directory using OSC 7
// If we have a pin_map, add the bytes we wrote to map.
// Screen formatter formats a single terminal screen (e.g. primary vs alt).
// The screen to format.
// The common options
// The content to include.
// Extra stuff to emit, such as cursor, style, hyperlinks, etc.
// This information is ONLY emitted when the format is "vt".
// If non-null, then `map` will contain the Pin of every byte
// byte written to the writer offset by the byte index. It is the
// caller's responsibility to free the map.
//
// Note that some emitted bytes may not correspond to any Pin, such as
// the extra data around screen state. For these, we'll map it to the
// most previous pin so there is some continuity but its an arbitrary
// choice.
//
// Warning: there is a significant performance hit to track this
// Emit no content, only terminal state such as modes, palette, etc.
// via extra.
// Emit the content specified by the selection. Null for all.
// The selection is inclusive on both ends.
// Emit cursor position using CUP (CSI H).
// Emit current SGR style state based on the cursor's active style_id.
// This reconstructs the SGR attributes (bold, italic, colors, etc.) at
// the cursor position.
// Emit current hyperlink state using OSC 8 sequences.
// This sets the active hyperlink based on cursor.hyperlink_id.
// Emit character protection mode using DECSCA.
// Emit Kitty keyboard protocol state using CSI > u and CSI = sequences.
// Emit character set designations and invocations.
// This includes G0-G3 designations (ESC ( ) * +) and GL/GR invocations.
// Emit nothing.
// Emit style-relevant information only.
// Emit everything. This reconstructs the screen state as closely
// as possible.
// Emit our pagelist contents according to our selection.
// Emit extra screen state after content if we care. The state has
// to be emitted after since some state such as cursor position and
// style are impacted by content rendering.
// HTML doesn't preserve any screen state because it has
// nothing to do with rendering.
// Emit current SGR style state
// Emit current hyperlink state using OSC 8
// Start hyperlink with uri (and explicit id if present)
// Emit character protection mode using DECSCA
// DEC protected mode
// Emit Kitty keyboard protocol state using CSI = u
// Emit character set designations and invocations
// Emit G0-G3 designations
// Emit GL invocation if not G0
// Emit GR invocation if not G2
// Emit cursor position using CUP (CSI H)
// CUP is 1-indexed
// If we have a pin_map, we need to count how many bytes the extras
// will emit so we can map them all to the same pin. We do this by
// formatting to a discarding writer with content=none.
// Map all those bytes to the same pin. Use the first page node
// to ensure the node pointer is always properly initialized.
// There is a weird Zig miscompilation here on 0.15.2.
// If I return the m.map.items value directly then we
// get undefined memory (even though we're copying a
// Pin struct). If we duplicate here like this we do
// not.
// PageList formatter formats multiple pages as represented by a PageList.
// The pagelist to format.
// The common options
// The bounds of the PageList to format. The top left and bottom right
// MUST be ordered properly.
// If true, the boundaries define a rectangle selection where start_x
// and end_x apply to every row, not just the first and last.
// If non-null, then `map` will contain the Pin of every byte
// byte written to the writer offset by the byte index. It is the
// caller's responsibility to free the map.
//
// Warning: there is a significant performance hit to track this
// If we keep track of pins, we'll need this.
// For rectangle selection, apply start_x and end_x to all chunks
// Otherwise only on the first/last, respectively.
// If we're tracking pins, then we setup a point map for the
// page formatter (cause it can't track pins). And then we convert
// this to pins later.
// If we're tracking pins then grab our points and write them
// to our pin map.
// Page formatter.
//
// For styled formatting such as VT, this will emit references for palette
// colors. If you want to capture the palette as-is at the type of formatting,
// you'll have to emit the sequences for setting up the palette prior to
// this formatting. (TODO: A function to do this)
// The page to format.
// The common options
// Start and end points within the page to format. If end x is not given
// then it will be the full width. If end y is not given then it will be
// the full height.
//
// The start and end are both inclusive, so equal values will still
// return a non-empty result (i.e. a single cell or row).
//
// The start x is considered the X in the first row and end X is
// X in the final row. This isn't a rectangle selection by default.
//
// If start X falls on the second column of a wide character, then
// the entire character will be included (as if you specified the
// previous column).
// If true, the start x/y and end x/y define a rectangle selection.
// In this case, the boundaries will apply to every row, not just
// the first and last.
// If non-null, then `map` will contain the x/y coordinate of every
// byte written to the writer offset by the byte index. It is the
// caller's responsibility to free the map.
//
// The x/y coordinate will be the coordinates within the page.
//
// Warning: there is a significant performance hit to track this
// The previous trailing state from the prior page. If you're iterating
// over multiple pages this helps ensure that unwrapping and other
// accounting works properly.
// Trailing state. This is used to ensure that rows wrapped across
// multiple pages are unwrapped properly, as well as other accounting
// we may do in the future.
// Initializes a page formatter. Other options can be set directly on the
// struct after initialization and before calling `format()`.
// Continue our prior trailing state if we have it, but only if we're
// starting from the beginning (start_y and start_x are both 0).
// If a non-zero start position is specified, ignore trailing state.
// Setup our starting column and perform some validation for overflows.
// Note: start_x only applies to the first row, end_x only applies to the last row.
// Setup our starting row and perform some validation for overflows.
// Edge case: if our end x/y falls on a spacer head AND we're unwrapping,
// then we move the x/y to the start of the next row (if available).
// Move to next row if available
//
// TODO: if unavailable, we should add to our trailing state
//
// so the pagelist formatter can be aware and maybe add
// another page
// If we only have a single row, validate that start_x <= end_x
// Wrap HTML output in monospace font styling
// Setup our div. We use a buffer here that should always
// fit the stuff we need, in order to make counting bytes easier.
// Monospace and whitespace preserving
// Background/foreground colors
// OSC 10 sets foreground color, OSC 11 sets background color
// Our style for non-plain formats
// Determine the x range for this row
// - First row: start_x to end of row (or end_x if single row)
// - Last row: start of row to end_x
// - Middle rows: full width
// The end is always straightforward
// The first we have to check if our start X falls on the
// tail of a wide character.
// Include the prior cell to get the full wide char
// If we're a spacer head on our first row then we
// skip this whole row.
// If this row is blank, accumulate to avoid a bunch of extra
// work later. If it isn't blank, make sure we dump all our
// blanks.
// Reset style before emitting newlines to prevent background
// colors from bleeding into the next line's leading cells.
// Plaintext just uses standard newlines because newlines
// on their own usually move the cursor back in anywhere
// you type plaintext.
// VT uses \r\n because in a raw pty, \n alone doesn't
// guarantee moving the cursor back to column 0. \r
// makes it work for sure.
// HTML uses just \n because HTML rendering will move
// the cursor back.
// \r and \n map to the row that ends with this newline.
// If we're continuing (trailing state) then this will be
// in a prior page, so we just map to the first row of this
// page.
// The first one inherits the x value.
// All others have x = 0 since they reference their prior
// blank line.
// If we're not wrapped, we always add a newline so after
// the row is printed we can add a newline.
// If the row doesn't continue a wrap then we need to reset
// our blank cell count.
// Go through each cell and print it
// Skip spacers. These happen naturally when wide characters
// are printed again on the screen (for well-behaved terminals!)
// If we have a zero value, then we accumulate a counter. We
// only want to turn zero values into spaces if we have a non-zero
// char sometime later.
// If we're emitting styled output (not plaintext) and
// the cell has some kind of styling or is not empty
// then this isn't blank.
// Cells with no text are blank
// Trailing spaces are blank. We know it is trailing
// because if we get a non-empty cell later we'll
// fill the blanks.
// This cell is not blank. If we have accumulated blank cells
// then we want to emit them now.
// Map each blank cell to its coordinate. Blank cells can span
// multiple rows if they carry over from wrap continuation.
// We have space in this row
// Wrap to previous row
// Can't go back further, just use (0, 0)
// If we aren't emitting styled output then we don't
// have to worry about styles.
// Get our cell style.
// If the style hasn't changed, don't bloat output.
// If we had a previous style, we need to close it,
// because we've confirmed we have some new style
// (which is maybe default).
// For VT, we only close if we're switching to a default
// style because any non-default style will emit
// a \x1b[0m as the start of a VT coloring sequence.
// Unreachable because of the styled() check at the
// top of this block.
// At this point, we can copy our style over
// If we're just the default style now, we're done.
// New style, emit it.
// If we have a point map, we map the style to
// this cell.
// We combine codepoint and graphemes because both have
// shared style handling. We use comptime to dup it.
// If we have a point map, all codepoints map to this
// cell.
// Cells with only background color (no text). Emit a space
// with the appropriate background color SGR sequence.
// If the style is non-default, we need to close our style tag.
// Close the monospace wrapper for HTML output
// Blank cells get an empty space that isn't replaced by anything
// because it isn't really a space. We do this so that formatting
// is preserved if we're emitting styles.
// Search for our replacement
// If no replacement, write it directly.
// For HTML, emit ASCII (< 0x80) directly, but encode
// all non-ASCII as numeric entities to avoid encoding
// detection issues (fixes #9426). We can't set the
// meta tag because we emit partial HTML so this ensures
// proper unicode handling.
// Returns the style for the given cell. If there is no styling this
// will return the default style.
// We use `display: inline` so that the div doesn't impact
// layout since we're primarily using it as a CSS wrapper.
// Verify we have only a single page
// Create the formatter
// Test our point map.
// Verify output
// Verify our point map
// Verify we have only a single page
// Create the formatter
// Test our point map.
// Verify output
// Note: we don't test the trailing state, which may have bugs
// with unwrap...
// Verify our point map
// Verify we have only a single page
// Create the formatter
// Test our point map.
// Full string
// Verify our point map
// Wide only (from start)
// Verify our point map
// Wide only (from tail)
// Verify our point map
// Verify we have only a single page
// Create the formatter
// Test our point map.
// Full string
// Verify our point map
// Full string (ending on spacer head)
// Verify our point map
// Wide only (from start)
// Verify our point map
// Wide only (from tail)
// Verify our point map
// Verify we have only a single page
// Create the formatter
// Verify output
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output. We expect there to be no trailing newlines because
// we can't differentiate trailing blank lines as being meaningful because
// the page formatter can't see the cursor position.
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output. We expect there to be no trailing newlines because
// we can't differentiate trailing blank lines as being meaningful because
// the page formatter can't see the cursor position.
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output. We expect there to be no trailing newlines because
// we can't differentiate trailing blank lines as being meaningful because
// the page formatter can't see the cursor position.
// Verify point map
// Verify point map
// Blank cells are reset when row is not a wrap continuation
// Verify point map
// Surgically modify the first row to be a wrap continuation
// Blank cells are preserved when row is a wrap continuation with unwrap enabled
// Verify point map - 3 spaces from prior trailing state + "world"
// The 3 blank cells can't go back beyond (0,0) so they all map to (0,0)
// Without unwrap, wrapped lines show as separate lines
// Verify point map
// With unwrap, wrapped lines are joined together
// Verify point map
// Without unwrap, wrapped lines show as separate lines
// Verify point map
// With unwrap, wrapped lines are joined together
// Verify point map - unwrapped text spans 3 rows
// Verify point map
// Verify point map
// Verify point map
// Verify point map is empty
// Should clamp to page.size.rows and work normally
// Verify point map
// Verify point map is empty
// Verify point map
// Verify point map
// First row: "world" (start_x=6 to end of row)
// Second row: "test case" (full row)
// Third row: "foo" (start to end_x=2, inclusive)
// Verify point map
// Verify point map is empty
// Verify point map
// Verify point map is empty
// Should NOT output the 5 newlines from trailing_state because start_y is non-zero
// Verify point map
// Should NOT output the 2 newlines or 8 spaces from trailing_state because start_x is non-zero
// Verify point map
// SHOULD output the 2 newlines from trailing_state because both start_y and start_x are 0
// Verify point map
// Verify we have only a single page
// Create the formatter
// Verify output
// Verify point map
// Verify point map
// Verify point map - style sequences should point to first character they style
// \x1b[0m = 4 bytes, \x1b[1m = 4 bytes, total 8 bytes of style sequences
// All style bytes should map to the first styled character at (0, 0)
// Then "hello" maps to its respective positions
// Verify point map matches output length
// Verify point map - style sequences should point to first character they style
// \x1b[0m = 4 bytes, \x1b[38;5;1m = 9 bytes, total 13 bytes of style sequences
// All style bytes should map to the first styled character at (0, 0)
// Then "red" maps to its respective positions
// Should emit OSC 10 for foreground, OSC 11 for background, then the text
// Note: style is reset before newline to prevent background colors from
// bleeding to the next line's leading cells.
// Verify point map matches output length
// Verify point map matches output length
// Verify pin map
// Fill the first page almost completely
// Verify we're still on one page
// Add one more newline to push content to a second page
// Write content on the second page
// Format the entire PageList
// Verify pin map
// First part (trimmed blank lines) maps to first node
// "page one" (8 chars) maps to first node
// \n - maps to last node as it represents the transition to new page
// "page two" (8 chars) maps to last node
// Fill the first page with soft-wrapped content
// Verify we're on two pages due to wrapping
// Format without unwrap - should show line breaks
// Verify pin map
// First part (trimmed blank lines) maps to first node
// First line maps to first node
// \n - maps to last node as it represents the transition to new page
// "d test" (6 chars) maps to last node
// Fill the first page with soft-wrapped content
// Verify we're on two pages due to wrapping
// Format with unwrap - should join the wrapped lines
// Verify pin map
// First part (trimmed blank lines) maps to first node
// First line from first page
// "d test" (6 chars) from last page
// Fill the first page almost completely
// Verify we're still on one page
// Add one more newline to push content to a second page
// New content is still styled
// Format the entire PageList with VT
// Verify pin map
// Just verify we have entries for both pages in the pin map
// Verify pin map
// "world" starts at x=6, y=0
// Fill first page almost completely
// Verify we're still on one page
// Push to second page
// Verify pin map
// "world" (5 chars) from first page
// \n - maps to last node as it represents the transition to new page
// "foo" (3 chars) from last page
// Verify pin map
// Verify pin map
// "hello world" (11 chars) on y=0
// \n
// "tes" (3 chars) on y=1
// Modify some palette colors using VT sequences
// Create a second terminal and apply the output
// Verify the palettes match
// Verify pin map
// Verify pin map
// "hello" (5 chars)
// "\n" maps to end of first line
// "world" (5 chars)
// Modify some palette colors using VT sequences
// Verify pin map - palette bytes should be mapped to top left
// Verify pin map
// "line2" (5 chars) from row 1
// Verify pin map
// Verify pin map
// "hello" (5 chars)
// "\n" maps to end of first line
// "world" (5 chars)
// Verify pin map
// "line2" (5 chars) from row 1
// Position cursor at a specific location
// Create a second terminal and apply the output
// Verify cursor positions match
// Verify pin map - the extras should be mapped to the last pin
// Content bytes map to their positions
// Extra bytes (cursor position) map to last content pin
// Set some style attributes
// Create a second terminal and apply the output
// Verify styles match
// Verify pin map
// Set a hyperlink
// Create a second terminal and apply the output
// Verify hyperlinks match
// Verify pin map
// Enable protection mode
// Create a second terminal and apply the output
// Verify protection state matches
// Verify pin map
// Set kitty keyboard flags (disambiguate + report_events = 3)
// Create a second terminal and apply the output
// Verify kitty keyboard state matches
// Verify pin map
// Set G0 to DEC special and shift to G1
// Create a second terminal and apply the output
// Verify charset state matches
// Verify pin map
// Set scrolling region: top=5, bottom=20
// Create a second terminal and apply the output
// Verify scrolling regions match
// Enable some modes that differ from defaults
// Create a second terminal and apply the output
// Verify modes match
// Clear all tabs and set custom tabstops
// Create a second terminal and apply the output
// Verify tabstops match (columns are 0-indexed in the API)
// Set modify other keys mode 2
// Create a second terminal and apply the output
// Verify keyboard mode matches
// Set pwd using OSC 7
// Create a second terminal and apply the output
// Verify pwd matches
// Set bold, then italic, then reset
// Plain text without styles should be wrapped in monospace div
// Set red foreground, blue background
// Modify some palette colors
// Verify palette CSS variables are emitted
// Verify point map length matches output
// Opening wrapper div
// Verify each character maps correctly, accounting for escaping
// < (4 bytes: &lt;) -> x=0
// t (1 byte) -> x=1
// a (1 byte) -> x=2
// g (1 byte) -> x=3
// > (4 bytes: &gt;) -> x=4
// & (5 bytes: &amp;) -> x=5
// " (6 bytes: &quot;) -> x=6
// ' (5 bytes: &#39;) -> x=7
// t (1 byte) -> x=8
// e (1 byte) -> x=9
// x (1 byte) -> x=10
// t (1 byte) -> x=11
// Box drawing characters that caused issue #9426
// Expected: box drawing chars as numeric entities
// ╰ = U+2570 = 9584, ─ = U+2500 = 9472, ❯ = U+276F = 10095
// ASCII should be emitted directly
// Mix of ASCII and Unicode entities
// Set a custom palette color and use it
// Without palette option - should emit palette index
// With palette option - should emit RGB directly
// Set a custom palette color and use it
// Without palette option - should emit CSS variable
// With palette option - should emit RGB directly
// Set bold, then reset with SGR 0
// The reset should properly close the bold style
// Replace 'o' with 'x'
// Verify point map - each output byte should map to original cell position
// "hello world" -> "hellx wxrld"
// h e l l o   w o r l d
// 0 1 2 3 4 5 6 7 8 9 10
// Replace 'o' with 'x', then with 'y' - should prefer last
// Replace 'o' with a multi-byte string
// Verify point map - string replacements should all map to the original cell
// "hello" -> "hellXYZ"
// h e l l o
// 0 1 2 3 4
// All bytes of the replacement string "XYZ" should point to position 4 (where 'o' was)
// Replace 'b' through 'e' with 'X'
// Replace 'a'-'m' with 'A' and 'n'-'z' with 'Z'
// h e l l o   w o r l d
// A A A A Z   Z Z Z A A
// Replace lightning bolt with fire emoji
// Verify point map
// "hello ⚡ world"
// h e l l o   ⚡   w o r l  d
// 0 1 2 3 4 5 6   8 9 10 11 12
// Note: ⚡ is a wide character occupying cells 6-7
// 🔥 is 4 UTF-8 bytes, all should map to cell 6 (where ⚡ was)
// " world" follows
// Replace 'e' with 'X' in styled text
// Should preserve styles while replacing text
// "red text" becomes "rXd tXxt"
// VT format uses \x1b[38;5;1m for palette color 1
// Empty map should not change anything
// This test reproduces a bug where trailing cells with background color
// but no text are emitted as plain spaces without SGR sequences.
// This causes TUIs like htop to lose background colors on rehydration.
// Simulate a TUI row: "CPU:" with text, then trailing cells with red background
// to end of line (no text after the colored region).
// \x1b[41m sets red background, then EL fills rest of row with that bg.
// Reset colors and move to next line with different content
// The output should preserve the red background SGR for trailing cells on line 1.
// Bug: the first row outputs "CPU:\r\n" only - losing the background color fill.
// The red background should appear BEFORE the newline, not after.
// Find position of CRLF
// No CRLF found, fail the test
// Check that red background (48;5;1) appears BEFORE the newline (on line 1)
// This should be true but currently fails due to the bug
//
// --- Original Ghostty Comments End: src/terminal/formatter.zig

/*
  Source: formatter.zig — 5,939 lines
  Output: formatter.v — 1,149 lines + formatter_test.v — 1,117 lines = 2,266 V lines total

  The V translation is significantly more compact because:
  - Zig's comptime patterns, explicit allocator passing, and Writer generics are replaced by V's strings.Builder
  - Zig's verbose test infrastructure (custom allocators, errdefer, error unions) becomes simple V test functions
  - Zig's writer API is represented by returned strings

*/

import math
import strings

// Formats available.
pub enum Format as u8 {
	// Plain text.
	plain
	// Include VT sequences to preserve colors, styles, URLs, etc.
	// This is predominantly SGR sequences but may contain others as needed.
	//
	// Note that for reference colors, like palette indices, this will
	// vary based on the formatter and you should see the docs. For example,
	// PageFormatter with VT will emit SGR sequences with palette indices,
	// not the color itself.
	//
	// For VT, newlines will be emitted as `\r\n` so that the cursor properly
	// moves back to the beginning prior emitting follow-up lines.
	vt
	// HTML output.
	//
	// This will emit inline styles for as much styling as possible,
	// in the interest of simplicity and ease of editing. This isn't meant
	// to build the most beautiful or efficient HTML, but rather to be
	// stylistically correct.
	//
	// For colors, RGB values are emitted as inline CSS (#RRGGBB) while palette
	// indices use CSS variables (var(--vt-palette-N)). The palette colors are
	// emitted by TerminalFormatter.Extra.palette as a <style> block if you
	// want to also include that. But if you only format a screen or lower,
	// the formatter doesn't have access to the current palette to render it.
	//
	// Newlines are emitted as actual '\n' characters. Consumers should use
	// CSS white-space: pre or pre-wrap to preserve spacing and alignment.
	html
}

// Returns true if the format emits styled output.
pub fn (self Format) styled() bool {
	return match self {
		.plain { false }
		.html, .vt { true }
	}
}

// Unicode codepoint range to replace.
pub struct CodepointMap {
pub:
	// Unicode codepoint range to replace.
	// range[0] <= range[1]
	range_start u32
	range_end   u32
	// Replacement value for this range.
	replacement CodepointReplacement
}

// Replacement value: either a single codepoint or a string.
pub type CodepointReplacement = CodepointRepl | StringRepl

pub struct CodepointRepl {
pub:
	codepoint u32
}

pub struct StringRepl {
pub:
	str string
}

// Common encoding options regardless of what exact formatter is used.
pub struct FormatOptions {
pub:
	// The format to emit.
	emit Format = .plain
	// Whether to unwrap soft-wrapped lines. If false, this will emit the
	// screen contents as it is rendered on the page in the given size.
	unwrap bool
	// Trim trailing whitespace on lines with other text. Trailing blank
	// lines are always trimmed. This only affects trailing whitespace
	// on rows that have at least one other cell with text. Whitespace
	// is currently only space characters (0x20).
	trim bool = true
	// Replace matching Unicode codepoints with some other values.
	// This will use the last matching range found in the list.
	codepoint_map []CodepointMap
	// Set a background and foreground color to use for the "screen".
	// For styled formats, this will emit the proper sequences or styles.
	background ?RGB
	foreground ?RGB
	// If set, then styled formats in `emit` will use this palette to
	// emit colors directly as RGB. If this is null, styled formats will
	// still work but will use deferred palette styling (e.g. CSS variables
	// for HTML or the actual palette indexes for VT).
	palette ?[]RGB
}

// Predefined option sets.
pub const format_plain = FormatOptions{ emit: .plain }
pub const format_vt = FormatOptions{ emit: .vt }
pub const format_html = FormatOptions{ emit: .html }

// Maps every output byte to its source position in the flat screen storage.
pub struct PinMap {
pub mut:
	pins []Pin
}

// Maps every output byte to its source coordinate within a page.
pub struct PointMap {
pub mut:
	points []Coordinate
}

fn append_point_bytes(mapping &PointMap, point Coordinate, count int) {
	if mapping == unsafe { nil } || count <= 0 {
		return
	}
	unsafe {
		for _ in 0 .. count {
			mapping.points << point
		}
	}
}

fn append_pin_bytes(mapping &PinMap, pin Pin, count int) {
	if mapping == unsafe { nil } || count <= 0 {
		return
	}
	unsafe {
		for _ in 0 .. count {
			mapping.pins << pin
		}
	}
}

fn last_pin_or_origin(mapping &PinMap) Pin {
	if mapping != unsafe { nil } && mapping.pins.len > 0 {
		return mapping.pins[mapping.pins.len - 1]
	}
	return Pin{}
}

// Terminal formatter formats the active terminal screen.
//
// This will always only emit data related to the currently active screen.
// If you want to emit data for a specific screen (e.g. primary vs alt), then
// switch to that screen in the terminal prior to using this.
//
// If you want to emit data for all screens (a less common operation), then
// you must create a no-content TerminalFormatter followed by multiple
// explicit ScreenFormatter calls. This isn't a common operation so this
// little extra work should be acceptable.
//
// For styled formatting, this will emit the palette colors at the
// beginning so that the output can be rendered properly according to
// the current terminal state.
pub struct TerminalFormatter {
pub:
	// The terminal to format.
	terminal &Terminal
	// The common options
	opts FormatOptions
pub mut:
	// The content to include.
	content ScreenContent = ScreenContent(ScreenContentSelection{ sel: none })
	// Extra stuff to emit, such as terminal modes, palette, cursor, etc.
	// This information is ONLY emitted when the format is "vt".
	extra   TerminalExtra = terminal_extra_styles
	pin_map &PinMap = unsafe { nil }
}

// Extra stuff to emit for terminal formatting.
pub struct TerminalExtra {
mut:
	value u16
}

// Emit nothing.
pub const terminal_extra_none = TerminalExtra{}

// Emit style-relevant information only such as palettes.
pub const terminal_extra_styles = TerminalExtra{ value: 0b000110_000001 }

// Emit everything. This reconstructs the terminal state as closely as possible.
pub const terminal_extra_all = TerminalExtra{ value: 0b111111_111111 }

pub fn (self TerminalExtra) palette() bool {
	return self.value & (1 << 0) != 0
}

pub fn (mut self TerminalExtra) set_palette(value bool) {
	self.set_bit(1 << 0, value)
}

pub fn (self TerminalExtra) modes() bool {
	return self.value & (1 << 1) != 0
}

pub fn (mut self TerminalExtra) set_modes(value bool) {
	self.set_bit(1 << 1, value)
}

pub fn (self TerminalExtra) scrolling_region() bool {
	return self.value & (1 << 2) != 0
}

pub fn (mut self TerminalExtra) set_scrolling_region(value bool) {
	self.set_bit(1 << 2, value)
}

pub fn (self TerminalExtra) tabstops() bool {
	return self.value & (1 << 3) != 0
}

pub fn (mut self TerminalExtra) set_tabstops(value bool) {
	self.set_bit(1 << 3, value)
}

pub fn (self TerminalExtra) pwd() bool {
	return self.value & (1 << 4) != 0
}

pub fn (mut self TerminalExtra) set_pwd(value bool) {
	self.set_bit(1 << 4, value)
}

pub fn (self TerminalExtra) keyboard() bool {
	return self.value & (1 << 5) != 0
}

pub fn (mut self TerminalExtra) set_keyboard(value bool) {
	self.set_bit(1 << 5, value)
}

pub fn (self TerminalExtra) screen() ScreenExtra {
	return ScreenExtra.from_int(u8((self.value >> 6) & 0b11_1111))
}

pub fn (mut self TerminalExtra) set_screen(value ScreenExtra) {
	self.value = (self.value & 0b00_0000_111111) | (u16(value.int()) << 6)
}

pub fn (self TerminalExtra) int() u16 {
	return self.value
}

fn (mut self TerminalExtra) set_bit(mask u16, enabled bool) {
	if enabled {
		self.value |= mask
	} else {
		self.value &= ~mask
	}
}

pub fn TerminalFormatter.init(t &Terminal, opts FormatOptions) TerminalFormatter {
	return TerminalFormatter{
		terminal: unsafe { t }
		opts: opts
		content: ScreenContent(ScreenContentSelection{ sel: none })
		extra: terminal_extra_styles
		pin_map: unsafe { nil }
	}
}

pub fn (self TerminalFormatter) format() string {
	mut sb := strings.new_builder(1024)

	// Emit palette before screen content if using VT format.
	if self.extra.palette() {
		before := sb.len
		match self.opts.emit {
			.plain {}
			.vt {
				for i, rgb in self.terminal.colors.palette.current {
					sb.write_string('\x1b]4;${i};rgb:${hex02(rgb.r)}/${hex02(rgb.g)}/${hex02(rgb.b)}\x1b\\')
				}
			}

			// For HTML, we emit CSS to setup our palette variables.
			.html {
				sb.write_string('<style>:root{')
				for i, rgb in self.terminal.colors.palette.current {
					sb.write_string('--vt-palette-${i}: #${hex02(rgb.r)}${hex02(rgb.g)}${hex02(rgb.b)};')
				}
				sb.write_string('}</style>')
			}
		}
		append_pin_bytes(self.pin_map, Pin{}, sb.len - before)
	}

	// Emit terminal modes that differ from defaults.
	if self.opts.emit == .vt && self.extra.modes() {
		before := sb.len
		for entry in mode_entries {
			if entry.disabled {
				continue
			}
			current := self.terminal.modes.get(entry.mode)
			if current == entry.default_val {
				continue
			}
			tag := entry.mode.tag()
			prefix := if tag.ansi() { '' } else { '?' }
			suffix := if current { 'h' } else { 'l' }
			sb.write_string('\x1b[${prefix}${tag.value()}${suffix}')
		}
		append_pin_bytes(self.pin_map, Pin{}, sb.len - before)
	}

	// Format the active screen content
	mut screen_fmt := ScreenFormatter.init(self.terminal.screens.active, self.opts)
	screen_fmt.content = self.content
	screen_fmt.extra = self.extra.screen()
	screen_fmt.pin_map = self.pin_map
	sb.write_string(screen_fmt.format())

	// Extra terminal state to emit after the screen contents
	if self.opts.emit == .vt {
		before := sb.len
		prior_pin := last_pin_or_origin(self.pin_map)
		// Emit scrolling region using DECSTBM and DECSLRM
		if self.extra.scrolling_region() {
			region := self.terminal.scrolling_region
			// DECSTBM: top and bottom margins (1-indexed)
			// Only emit if not the full screen
			if region.top != 0 || region.bottom != self.terminal.rows - 1 {
				sb.write_string('\x1b[${region.top + 1};${region.bottom + 1}r')
			}
			// DECSLRM: left and right margins (1-indexed)
			// Only emit if not the full width
			if region.left != 0 || region.right != self.terminal.cols - 1 {
				sb.write_string('\x1b[${region.left + 1};${region.right + 1}s')
			}
		}

		// Emit tabstop positions
		if self.extra.tabstops() {
			// Clear all tabs (CSI 3 g)
			sb.write_string('\x1b[3g')
			// Set each configured tabstop by moving cursor and using HTS
			for col in 0 .. int(self.terminal.cols) {
				if self.terminal.tabstops.get(usize(col)) {
					// Move cursor to the column (1-indexed)
					sb.write_string('\x1b[${col + 1}G')
					// Set tab (HTS)
					sb.write_string('\x1bH')
				}
			}
		}

		// Emit keyboard modes such as ModifyOtherKeys
		if self.extra.keyboard() {
			// Only emit if modify_other_keys_2 is true
			if self.terminal.flags.modify_other_keys_2() {
				sb.write_string('\x1b[>4;2m')
			}
		}

		// Emit present working directory using OSC 7
		if self.extra.pwd() {
			if self.terminal.pwd.len > 0 {
				sb.write_string('\x1b]7;${self.terminal.pwd}\x1b\\')
			}
		}
		append_pin_bytes(self.pin_map, prior_pin, sb.len - before)
	}

	return sb.str()
}

// Screen formatter formats a single terminal screen (e.g. primary vs alt).
pub struct ScreenFormatter {
pub:
	// The screen to format.
	screen &Screen
	// The common options
	opts FormatOptions
pub mut:
	// The content to include.
	content ScreenContent = ScreenContent(ScreenContentSelection{ sel: none })
	// Extra stuff to emit, such as cursor, style, hyperlinks, etc.
	// This information is ONLY emitted when the format is "vt".
	extra   ScreenExtra = screen_extra_none
	pin_map &PinMap = unsafe { nil }
}

// Content to include in screen formatting.
pub type ScreenContent = ScreenContentNone | ScreenContentSelection

// Emit no content, only terminal state such as modes, palette, etc. via extra.
pub struct ScreenContentNone {}

// Emit the content specified by the selection. Null for all.
// The selection is inclusive on both ends.
pub struct ScreenContentSelection {
pub:
	sel ?Selection
}

// Extra stuff to emit for screen formatting.
pub struct ScreenExtra {
mut:
	value u8
}

// Emit nothing.
pub const screen_extra_none = ScreenExtra{}

// Emit style-relevant information only.
pub const screen_extra_styles = ScreenExtra{ value: 0b00_0110 }

// Emit everything.
pub const screen_extra_all = ScreenExtra{ value: 0b11_1111 }

pub fn ScreenExtra.from_int(value u8) ScreenExtra {
	return ScreenExtra{
		value: value & 0b11_1111
	}
}

pub fn (self ScreenExtra) cursor() bool {
	return self.value & (1 << 0) != 0
}

pub fn (mut self ScreenExtra) set_cursor(value bool) {
	self.set_bit(1 << 0, value)
}

pub fn (self ScreenExtra) style() bool {
	return self.value & (1 << 1) != 0
}

pub fn (mut self ScreenExtra) set_style(value bool) {
	self.set_bit(1 << 1, value)
}

pub fn (self ScreenExtra) hyperlink() bool {
	return self.value & (1 << 2) != 0
}

pub fn (mut self ScreenExtra) set_hyperlink(value bool) {
	self.set_bit(1 << 2, value)
}

pub fn (self ScreenExtra) protection() bool {
	return self.value & (1 << 3) != 0
}

pub fn (mut self ScreenExtra) set_protection(value bool) {
	self.set_bit(1 << 3, value)
}

pub fn (self ScreenExtra) kitty_keyboard() bool {
	return self.value & (1 << 4) != 0
}

pub fn (mut self ScreenExtra) set_kitty_keyboard(value bool) {
	self.set_bit(1 << 4, value)
}

pub fn (self ScreenExtra) charsets() bool {
	return self.value & (1 << 5) != 0
}

pub fn (mut self ScreenExtra) set_charsets(value bool) {
	self.set_bit(1 << 5, value)
}

pub fn (self ScreenExtra) int() u8 {
	return self.value
}

fn (mut self ScreenExtra) set_bit(mask u8, enabled bool) {
	if enabled {
		self.value |= mask
	} else {
		self.value &= ~mask
	}
}

// Returns true if any extra flags are set.
pub fn (self ScreenExtra) is_set() bool {
	return self.value != 0
}

pub fn ScreenFormatter.init(screen &Screen, opts FormatOptions) ScreenFormatter {
	return ScreenFormatter{
		screen: unsafe { screen }
		opts: opts
		content: ScreenContent(ScreenContentSelection{ sel: none })
		extra: screen_extra_none
		pin_map: unsafe { nil }
	}
}

// PageList formatter formats multiple linked pages as represented by a
// PageList. Trailing state is carried from one page to the next so blank rows
// and soft-wrapped lines spanning page boundaries are emitted exactly once.
pub struct PageListFormatter {
pub:
	// The linked page list to format.
	list &PageList
	// Common formatting options.
	opts FormatOptions
pub mut:
	// Inclusive ordered bounds. If absent, the complete page list is used.
	top_left     ?PagePin
	bottom_right ?PagePin
	// Apply the X bounds to every row rather than only the first and last.
	rectangle bool
	// Optional mapping from every output byte to its linked-page pin.
	pin_map &PagePinMap = unsafe { nil }
}

// PagePinMap maps every output byte to its source position in a PageList.
pub struct PagePinMap {
pub mut:
	pins []PagePin
}

pub fn PageListFormatter.init(list &PageList, opts FormatOptions) PageListFormatter {
	return PageListFormatter{
		list: unsafe { list }
		opts: opts
	}
}

pub fn (self PageListFormatter) format() string {
	tl := self.top_left or { self.list.get_top_left(.screen) }
	br := self.bottom_right or {
		self.list.get_bottom_right(.screen) or { panic('page list has no bottom-right pin') }
	}

	mut output := strings.new_builder(1024)
	mut point_map := PointMap{}
	mut trailing := ?TrailingState(none)
	mut iter := tl.page_iterator(.right_down, br)
	for {
		chunk := iter.next() or { break }
		assert chunk.start < chunk.end
		assert chunk.end > 0

		// PageFormatter is shared with the flat Screen representation. A linked
		// Page already uses the same RowData/CellData values, so this is a
		// read-only view over the current node rather than a data conversion.
		page := &chunk.node.data
		view := Pages{
			screen_rows: page.rows[..int(page.size.rows)]
			cols: u32(page.size.cols)
			rows: u32(page.size.rows)
		}
		mut formatter := PageFormatter.init(&view, self.opts)
		formatter.linked_page = page
		formatter.start_y = u32(chunk.start)
		formatter.end_y = u32(chunk.end - 1)
		formatter.trailing_state = trailing
		formatter.rectangle = self.rectangle

		if self.rectangle {
			formatter.start_x = u32(tl.x)
			formatter.end_x = u32(br.x)
		} else {
			if voidptr(chunk.node) == voidptr(tl.node) {
				formatter.start_x = u32(tl.x)
			}
			if voidptr(chunk.node) == voidptr(br.node) {
				formatter.end_x = u32(br.x)
			}
		}

		if self.pin_map != unsafe { nil } {
			point_map.points.clear()
			formatter.point_map = &point_map
		}

		result := formatter.format_with_state()
		output.write_string(result.output)
		trailing = result.state

		if self.pin_map != unsafe { nil } {
			unsafe {
				for point in point_map.points {
					self.pin_map.pins << PagePin{
						node: chunk.node
						x: u16(point.x)
						y: u16(point.y)
					}
				}
			}
		}
	}
	return output.str()
}

pub fn (self ScreenFormatter) format() string {
	mut sb := strings.new_builder(1024)

	match self.content {
		ScreenContentNone {}
		ScreenContentSelection {
			// Emit our page content according to our selection.
			mut page_fmt := PageFormatter.init(&self.screen.pages, self.opts)
			mut point_map := PointMap{}
			if self.pin_map != unsafe { nil } {
				page_fmt.point_map = &point_map
			}
			if sel := self.content.sel {
				// Order the selection for formatting (start before end)
				s := if sel.start_pin.before(sel.end_pin) { sel.start_pin } else { sel.end_pin }
				e := if sel.start_pin.before(sel.end_pin) { sel.end_pin } else { sel.start_pin }
				page_fmt.start_x = s.x
				page_fmt.start_y = s.y
				page_fmt.end_x = e.x
				page_fmt.end_y = e.y
				page_fmt.rectangle = sel.rectangle
			}
			result := page_fmt.format_with_state()
			sb.write_string(result.output)
			if self.pin_map != unsafe { nil } {
				for point in point_map.points {
					append_pin_bytes(self.pin_map, Pin{
						x: point.x
						y: point.y
					}, 1)
				}
			}
		}
	}

	// Emit extra screen state after content if we care.
	match self.opts.emit {
		.plain {
			return sb.str()
		}
		.vt {
			if !self.extra.is_set() {
				return sb.str()
			}
		}

		// HTML doesn't preserve any screen state
		.html {
			return sb.str()
		}
	}

	// State emitted after content is mapped to the most recent content pin.
	extras_start := sb.len
	prior_pin := last_pin_or_origin(self.pin_map)

	// Emit current SGR style state
	if self.extra.style() {
		cursor := self.screen.cursor
		sb.write_string(format_style_vt(cursor.style))
	}

	// Emit current hyperlink state using OSC 8
	if self.extra.hyperlink() {
		if link := self.screen.cursor.hyperlink_state {
			// Start hyperlink with uri (and explicit id if present)
			match link.id {
				HyperlinkExplicitId {
					sb.write_string('\x1b]8;id=${link.id.value};${link.uri}\x1b\\')
				}
				HyperlinkImplicitId {
					sb.write_string('\x1b]8;;${link.uri}\x1b\\')
				}
			}
		}
	}

	// Emit character protection mode using DECSCA
	if self.extra.protection() {
		if self.screen.cursor.is_protected {
			// DEC protected mode
			sb.write_string('\x1b[1"q')
		}
	}

	// Emit Kitty keyboard protocol state using CSI = u
	if self.extra.kitty_keyboard() {
		flags := self.screen.kitty_keyboard.current().int()
		if flags != key_flags_disabled.int() {
			sb.write_string('\x1b[=${flags};1u')
		}
	}

	// Emit character set designations and invocations
	if self.extra.charsets() {
		cs := self.screen.charset

		// Emit G0-G3 designations
		for slot in [CharsetSlot.g0, .g1, .g2, .g3] {
			charset := cs.charsets.get(slot)
			if charset != .utf8 {
				// Only emit non-default charsets
				intermediate := match slot {
					.g0 { u8(`(`) }
					.g1 { u8(`)`) }
					.g2 { u8(`*`) }
					.g3 { u8(`+`) }
				}
				final_byte := match charset {
					.ascii { u8(`B`) }
					.british { u8(`A`) }
					.dec_special { u8(`0`) }
					else {
						continue
					}
				}
				sb.write_u8(0x1b)
				sb.write_u8(intermediate)
				sb.write_u8(final_byte)
			}
		}

		// Emit GL invocation if not G0
		if cs.gl != .g0 {
			seq := match cs.gl {
				.g0 { panic('unreachable') }
				.g1 { '\x0e' } // SO - Shift Out
				.g2 { '\x1bn' } // LS2
				.g3 { '\x1bo' }
			}
			// LS3
			sb.write_string(seq)
		}

		// Emit GR invocation if not G2
		if cs.gr != .g2 {
			seq := match cs.gr {
				.g0 { panic('unreachable') }
				.g1 { '\x1b~' } // LS1R
				.g2 { panic('unreachable') }
				.g3 { '\x1b|' }
			}
			// LS3R
			sb.write_string(seq)
		}
	}

	// Emit cursor position using CUP (CSI H)
	if self.extra.cursor() {
		cursor := self.screen.cursor
		// CUP is 1-indexed
		sb.write_string('\x1b[${cursor.y + 1};${cursor.x + 1}H')
	}
	append_pin_bytes(self.pin_map, prior_pin, sb.len - extras_start)

	return sb.str()
}

// Page formatter formats a single page (i.e., the Pages data).
//
// For styled formatting such as VT, this will emit references for palette
// colors. If you want to capture the palette as-is at the time of formatting,
// you'll have to emit the sequences for setting up the palette prior to
// this formatting.
pub struct PageFormatter {
pub:
	// The page data to format.
	pages &Pages
	// The common options
	opts FormatOptions
pub mut:
	// Start and end points within the page to format.
	// Start and end are both inclusive.
	start_x u32
	start_y u32
	end_x   ?u32
	end_y   ?u32
	// If true, the start x/y and end x/y define a rectangle selection.
	rectangle bool
	// The previous trailing state from the prior page.
	trailing_state ?TrailingState
	point_map      &PointMap = unsafe { nil }
	// The owning linked Page, when formatting through PageListFormatter. Its
	// style table is authoritative; flat Screen pages store styles inline.
	linked_page &Page = unsafe { nil }
}

// Trailing state for cross-page continuation.
pub struct TrailingState {
pub mut:
	rows  usize
	cells usize
}

pub const trailing_state_empty = TrailingState{ rows: 0, cells: 0 }

// Result of formatting with state.
pub struct FormatResult {
pub:
	output string
	state  TrailingState
}

pub fn PageFormatter.init(pages &Pages, opts FormatOptions) PageFormatter {
	return PageFormatter{
		pages: unsafe { pages }
		opts: opts
		start_x: 0
		start_y: 0
		end_x: none
		end_y: none
		rectangle: false
		trailing_state: none
		point_map: unsafe { nil }
	}
}

pub fn (self PageFormatter) format() string {
	return self.format_with_state().output
}

pub fn (self PageFormatter) format_with_state() FormatResult {
	mut blank_rows := usize(0)
	mut blank_cells := usize(0)

	// Continue our prior trailing state if we have it, but only if we're
	// starting from the beginning (start_y and start_x are both 0).
	// If a non-zero start position is specified, ignore trailing state.
	if state := self.trailing_state {
		if self.start_y == 0 && self.start_x == 0 {
			blank_rows = state.rows
			blank_cells = state.cells
		}
	}

	page_cols := self.pages.cols
	page_rows := u32(self.pages.screen_rows.len)

	// Setup our starting column and perform some validation for overflows.
	start_x := self.start_x
	if start_x >= page_cols {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	end_x_unclamped := self.end_x or { page_cols - 1 }
	mut end_x := math.min(end_x_unclamped, page_cols - 1)

	// Setup our starting row and perform some validation for overflows.
	start_y := self.start_y
	if start_y >= page_rows {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	end_y_unclamped := self.end_y or { page_rows - 1 }
	if start_y > end_y_unclamped {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}
	mut end_y := math.min(end_y_unclamped, page_rows - 1)

	// Edge case: if our end x/y falls on a spacer head AND we're unwrapping,
	// then we move the x/y to the start of the next row (if available).
	if self.opts.unwrap && !self.rectangle {
		final_row := self.pages.screen_rows[int(end_y)]
		if int(end_x) < final_row.cells.len {
			if final_row.cells[int(end_x)].wide == .spacer_head {
				if end_y < page_rows - 1 {
					end_y += 1
					end_x = 0
				}
			}
		}
	}

	// If we only have a single row, validate that start_x <= end_x
	if start_y == end_y && start_x > end_x {
		return FormatResult{
			output: ''
			state: TrailingState{ rows: blank_rows, cells: blank_cells }
		}
	}

	mut sb := strings.new_builder(1024)

	// Wrap HTML output in monospace font styling
	match self.opts.emit {
		.plain {}
		.html {
			before := sb.len
			sb.write_string('<div style="font-family: monospace; white-space: pre;')
			// Background/foreground colors
			if bg := self.opts.background {
				sb.write_string('background-color: #${hex02(bg.r)}${hex02(bg.g)}${hex02(bg.b)};')
			}
			if fg := self.opts.foreground {
				sb.write_string('color: #${hex02(fg.r)}${hex02(fg.g)}${hex02(fg.b)};')
			}
			sb.write_string('">')
			append_point_bytes(self.point_map, Coordinate{}, sb.len - before)
		}
		.vt {
			before := sb.len
			// OSC 10 sets foreground color, OSC 11 sets background color
			if fg := self.opts.foreground {
				sb.write_string('\x1b]10;rgb:${hex02(fg.r)}/${hex02(fg.g)}/${hex02(fg.b)}\x1b\\')
			}
			if bg := self.opts.background {
				sb.write_string('\x1b]11;rgb:${hex02(bg.r)}/${hex02(bg.g)}/${hex02(bg.b)}\x1b\\')
			}
			append_point_bytes(self.point_map, Coordinate{}, sb.len - before)
		}
	}

	// Our style for non-plain formats
	mut style := CellStyle{}

	for y_int in int(start_y) .. int(end_y) + 1 {
		y := u32(y_int)
		row := self.pages.screen_rows[y_int]
		cells := row.cells

		// Determine the x range for this row
		row_end_x := if self.rectangle || y == end_y {
			end_x + 1
		} else {
			page_cols
		}

		row_start_x := if start_x > 0 && (self.rectangle || y == start_y) {
			// Check if our start X falls on the tail of a wide character.
			match cells[int(start_x)].wide {
				.spacer_tail { start_x - 1 }
				.spacer_head {
					continue
				}
				else { start_x }
			}
		} else {
			u32(0)
		}

		// Get the subset of cells for this row
		cells_subset := cells[int(row_start_x)..int(row_end_x)]

		// If this row is blank, accumulate to avoid a bunch of extra work later.
		if !has_text_any(cells_subset) {
			blank_rows += 1
			continue
		}

		if blank_rows > 0 {
			// Reset style before emitting newlines to prevent background
			// colors from bleeding into the next line's leading cells.
			if !style.default() {
				before := sb.len
				sb.write_string(format_style_close(self.opts.emit))
				if self.point_map != unsafe { nil } {
					assert self.point_map.points.len > 0
					last := self.point_map.points[self.point_map.points.len - 1]
					append_point_bytes(self.point_map, last, sb.len - before)
				}
				style = CellStyle{}
			}

			newline := match self.opts.emit {
				// Plaintext just uses standard newlines
				.plain { '\n' }
				// VT uses \r\n because in a raw pty, \n alone doesn't
				// guarantee moving the cursor back to column 0.
				.vt { '\r\n' }
				// HTML uses just \n
				.html { '\n' }
			}

			map_start := if self.point_map != unsafe { nil } && self.point_map.points.len > 0 {
				self.point_map.points[self.point_map.points.len - 1]
			} else {
				Coordinate{}
			}
			for row_offset in usize(0) .. blank_rows {
				sb.write_string(newline)
				point := if row_offset == 0 {
					map_start
				} else {
					Coordinate{
						x: 0
						y: map_start.y + u32(row_offset)
					}
				}
				append_point_bytes(self.point_map, point, newline.len)
			}
			blank_rows = 0
		}

		// If we're not wrapped, we always add a newline so after
		// the row is printed we can add a newline.
		if !row.wrap || !self.opts.unwrap {
			blank_rows += 1
		}

		// If the row doesn't continue a wrap then we need to reset
		// our blank cell count.
		if !row.wrap_continuation || !self.opts.unwrap {
			blank_cells = 0
		}

		// Go through each cell and print it
		for cell_offset, cell in cells_subset {
			x := row_start_x + u32(cell_offset)

			// Skip spacers
			match cell.wide {
				.narrow, .wide {}
				.spacer_head, .spacer_tail {
					continue
				}
			}

			// If we have a zero value, then we accumulate a counter.
			if self.opts.emit.styled() && (!cell.is_empty() || cell.has_styling()) {
				// Not blank - styled cell with content or styling
			} else if !cell.has_text() {
				blank_cells += 1
				continue
			} else if cell.codepoint_val() == u32(` `) && self.opts.trim {
				blank_cells += 1
				continue
			}

			// This cell is not blank. If we have accumulated blank cells
			// then we want to emit them now.
			if blank_cells > 0 {
				mut blank_x := x
				mut blank_y := y
				mut blank_points := []Coordinate{cap: int(blank_cells)}
				for _ in usize(0) .. blank_cells {
					if blank_x > 0 {
						blank_x--
					} else if blank_y > 0 {
						blank_y--
						blank_x = page_cols - 1
					}
					blank_points << Coordinate{
						x: u16(blank_x)
						y: blank_y
					}
				}
				for point in blank_points {
					sb.write_u8(` `)
					append_point_bytes(self.point_map, point, 1)
				}
				blank_cells = 0
			}

			// Handle style changes
			if self.opts.emit.styled() {
				cell_style := self.cell_style(cell)

				// If the style hasn't changed, don't bloat output.
				if !cell_style.eql(&style) {
					// If we had a previous style, we need to close it
					if !style.default() {
						before := sb.len
						match self.opts.emit {
							.html { sb.write_string(format_style_close(self.opts.emit)) }
							.vt {
								if cell_style.default() {
									sb.write_string(format_style_close(self.opts.emit))
								}
							}
							.plain { panic('unreachable') }
						}
						written := sb.len - before
						if self.point_map != unsafe { nil } && written > 0 {
							assert self.point_map.points.len > 0
							last := self.point_map.points[self.point_map.points.len - 1]
							append_point_bytes(self.point_map, last, written)
						}
					}

					style = cell_style

					// If we're just the default style now, we're done.
					if !cell_style.default() {
						// New style, emit it.
						before := sb.len
						sb.write_string(self.format_style_open(style))
						append_point_bytes(self.point_map, Coordinate{
							x: u16(x)
							y: y
						}, sb.len - before)
					}
				}
			}

			// Write the cell content. Every output byte, including every byte
			// of UTF-8 and replacement strings, maps to this source cell.
			before_content := sb.len
			match cell.content_tag {
				.codepoint, .codepoint_grapheme {
					if !cell.has_text() {
						// Blank cells get an empty space for formatting preservation
						sb.write_u8(` `)
					} else {
						self.write_codepoint_with_replacement(mut sb, cell.codepoint)
						if cell.content_tag == .codepoint_grapheme {
							for cp in cell.graphemes {
								self.write_codepoint_with_replacement(mut sb, cp)
							}
						}
					}
				}
				.bg_color_palette, .bg_color_rgb {
					// Cells with only a background color still emit a space.
					sb.write_u8(` `)
				}
			}
			append_point_bytes(self.point_map, Coordinate{
				x: u16(x)
				y: y
			}, sb.len - before_content)
		}
	}

	// If the style is non-default, we need to close our style tag.
	if !style.default() {
		before := sb.len
		sb.write_string(format_style_close(self.opts.emit))
		if self.point_map != unsafe { nil } {
			assert self.point_map.points.len > 0
			last := self.point_map.points[self.point_map.points.len - 1]
			append_point_bytes(self.point_map, last, sb.len - before)
		}
	}

	// Close the monospace wrapper for HTML output
	if self.opts.emit == .html {
		before := sb.len
		sb.write_string('</div>')
		if self.point_map != unsafe { nil } {
			assert self.point_map.points.len > 0
			last := self.point_map.points[self.point_map.points.len - 1]
			append_point_bytes(self.point_map, last, sb.len - before)
		}
	}

	return FormatResult{
		output: sb.str()
		state: TrailingState{ rows: blank_rows, cells: blank_cells }
	}
}

// Write a codepoint with replacement map lookup.
fn (self PageFormatter) write_codepoint_with_replacement(mut sb strings.Builder, codepoint u32) {
	// Search for our replacement (last matching range wins)
	if self.opts.codepoint_map.len > 0 {
		for i_forward in 0 .. self.opts.codepoint_map.len {
			i := self.opts.codepoint_map.len - i_forward - 1
			entry := self.opts.codepoint_map[i]
			if entry.range_start <= codepoint && codepoint <= entry.range_end {
				match entry.replacement {
					CodepointRepl {
						self.write_codepoint(mut sb, entry.replacement.codepoint)
					}
					StringRepl {
						// Iterate over string as runes
						for ch in entry.replacement.str.runes() {
							self.write_codepoint(mut sb, u32(ch))
						}
					}
				}
				return
			}
		}
	}

	// No replacement, write directly.
	self.write_codepoint(mut sb, codepoint)
}

// Write a single codepoint in the appropriate format.
fn (self PageFormatter) write_codepoint(mut sb strings.Builder, codepoint u32) {
	match self.opts.emit {
		.plain, .vt {
			// Write as UTF-8
			write_utf8(mut sb, codepoint)
		}
		.html {
			match codepoint {
				u32(`<`) { sb.write_string('&lt;') }
				u32(`>`) { sb.write_string('&gt;') }
				u32(`&`) { sb.write_string('&amp;') }
				u32(`"`) { sb.write_string('&quot;') }
				u32(`'`) { sb.write_string('&#39;') }
				else {
					// For HTML, emit ASCII (< 0x80) directly, but encode
					// all non-ASCII as numeric entities to avoid encoding
					// detection issues.
					if codepoint < 0x80 {
						write_utf8(mut sb, codepoint)
					} else {
						sb.write_string('&#${codepoint};')
					}
				}
			}
		}
	}
}

// Returns the style for the given cell.
fn (self PageFormatter) cell_style(cell CellData) CellStyle {
	return match cell.content_tag {
		.codepoint, .codepoint_grapheme {
			if !cell.has_styling() {
				CellStyle{}
			} else if self.linked_page != unsafe { nil } {
				self.linked_page.styles.get(cell.style_id)
			} else {
				cell.style
			}
		}
		.bg_color_palette {
			CellStyle{
				bg_color: .palette
				bg_palette: cell.color_palette
			}
		}
		.bg_color_rgb {
			CellStyle{
				bg_color: .rgb
				bg_r: cell.color_rgb_r
				bg_g: cell.color_rgb_g
				bg_b: cell.color_rgb_b
			}
		}
	}
}

// Format a style open tag.
fn (self PageFormatter) format_style_open(style CellStyle) string {
	match self.opts.emit {
		.plain {
			panic('unreachable')
		}
		.vt {
			return format_style_vt_with_palette(style, self.opts.palette)
		}
		.html {
			return '<div style="display: inline;${format_style_html_with_palette(style, self.opts.palette)}">'
		}
	}
}

// ============================================================
// Style formatting helpers
// ============================================================

// Format a style as a VT (SGR) sequence.
pub fn format_style_vt(style CellStyle) string {
	return format_style_vt_with_palette(style, none)
}

// Format a style as a VT (SGR) sequence, optionally resolving palette colors.
fn format_style_vt_with_palette(style CellStyle, palette ?[]RGB) string {
	mut sb := strings.new_builder(64)
	sb.write_string('\x1b[0m')

	if style.flags.bold() {
		sb.write_string('\x1b[1m')
	}
	if style.flags.faint() {
		sb.write_string('\x1b[2m')
	}
	if style.flags.italic() {
		sb.write_string('\x1b[3m')
	}
	if style.flags.blink() {
		sb.write_string('\x1b[5m')
	}
	if style.flags.inverse() {
		sb.write_string('\x1b[7m')
	}
	if style.flags.invisible() {
		sb.write_string('\x1b[8m')
	}
	if style.flags.strikethrough() {
		sb.write_string('\x1b[9m')
	}
	if style.flags.overline() {
		sb.write_string('\x1b[53m')
	}
	match style.flags.underline() {
		.none {}
		.single { sb.write_string('\x1b[4m') }
		.double { sb.write_string('\x1b[4:2m') }
		.curly { sb.write_string('\x1b[4:3m') }
		.dotted { sb.write_string('\x1b[4:4m') }
		.dashed { sb.write_string('\x1b[4:5m') }
	}

	// Foreground color
	match style.fg_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.fg_palette)]
				sb.write_string('\x1b[38;2;${rgb.r};${rgb.g};${rgb.b}m')
			} else {
				sb.write_string('\x1b[38;5;${style.fg_palette}m')
			}
		}
		.rgb {
			sb.write_string('\x1b[38;2;${style.fg_r};${style.fg_g};${style.fg_b}m')
		}
		.none {}
	}

	// Background color
	match style.bg_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.bg_palette)]
				sb.write_string('\x1b[48;2;${rgb.r};${rgb.g};${rgb.b}m')
			} else {
				sb.write_string('\x1b[48;5;${style.bg_palette}m')
			}
		}
		.rgb {
			sb.write_string('\x1b[48;2;${style.bg_r};${style.bg_g};${style.bg_b}m')
		}
		.none {}
	}

	// Underline color
	match style.underline_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.underline_palette)]
				sb.write_string('\x1b[58;2;${rgb.r};${rgb.g};${rgb.b}m')
			} else {
				sb.write_string('\x1b[58;5;${style.underline_palette}m')
			}
		}
		.rgb {
			sb.write_string('\x1b[58;2;${style.underline_r};${style.underline_g};${style.underline_b}m')
		}
		.none {}
	}

	return sb.str()
}

// Format a style as inline CSS for HTML output.
fn format_style_html_with_palette(style CellStyle, palette ?[]RGB) string {
	mut sb := strings.new_builder(128)

	// Colors
	match style.fg_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.fg_palette)]
				sb.write_string('color: rgb(${rgb.r}, ${rgb.g}, ${rgb.b});')
			} else {
				sb.write_string('color: var(--vt-palette-${style.fg_palette});')
			}
		}
		.rgb {
			sb.write_string('color: rgb(${style.fg_r}, ${style.fg_g}, ${style.fg_b});')
		}
		.none {}
	}

	match style.bg_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.bg_palette)]
				sb.write_string('background-color: rgb(${rgb.r}, ${rgb.g}, ${rgb.b});')
			} else {
				sb.write_string('background-color: var(--vt-palette-${style.bg_palette});')
			}
		}
		.rgb {
			sb.write_string('background-color: rgb(${style.bg_r}, ${style.bg_g}, ${style.bg_b});')
		}
		.none {}
	}
	match style.underline_color {
		.palette {
			if pal := palette {
				rgb := pal[int(style.underline_palette)]
				sb.write_string('text-decoration-color: rgb(${rgb.r}, ${rgb.g}, ${rgb.b});')
			} else {
				sb.write_string('text-decoration-color: var(--vt-palette-${style.underline_palette});')
			}
		}
		.rgb {
			sb.write_string('text-decoration-color: rgb(${style.underline_r}, ${style.underline_g}, ${style.underline_b});')
		}
		.none {}
	}

	// Text decoration line
	has_line := style.flags.underline() != .none || style.flags.strikethrough()
		|| style.flags.overline() || style.flags.blink()
	if has_line {
		sb.write_string('text-decoration-line:')
		if style.flags.underline() != .none {
			sb.write_string(' underline')
		}
		if style.flags.strikethrough() {
			sb.write_string(' line-through')
		}
		if style.flags.overline() {
			sb.write_string(' overline')
		}
		if style.flags.blink() {
			sb.write_string(' blink')
		}
		sb.write_string(';')
	}

	// Text decoration style
	match style.flags.underline() {
		.none {}
		.single { sb.write_string('text-decoration-style: solid;') }
		.double { sb.write_string('text-decoration-style: double;') }
		.curly { sb.write_string('text-decoration-style: wavy;') }
		.dotted { sb.write_string('text-decoration-style: dotted;') }
		.dashed { sb.write_string('text-decoration-style: dashed;') }
	}

	if style.flags.bold() {
		sb.write_string('font-weight: bold;')
	}
	if style.flags.italic() {
		sb.write_string('font-style: italic;')
	}
	if style.flags.faint() {
		sb.write_string('opacity: 0.5;')
	}
	if style.flags.invisible() {
		sb.write_string('visibility: hidden;')
	}
	if style.flags.inverse() {
		sb.write_string('filter: invert(100%);')
	}

	return sb.str()
}

// Format a style close tag.
fn format_style_close(emit Format) string {
	return match emit {
		.plain { '' }
		.vt { '\x1b[0m' }
		.html { '</div>' }
	}
}

// ============================================================
// Utility functions
// ============================================================

// Helper to format a u8 as a two-digit lowercase hex string.
fn hex02(val u8) string {
	hex_chars := '0123456789abcdef'.bytes()
	mut buf := [u8(0), 0]
	buf[0] = hex_chars[val >> 4]
	buf[1] = hex_chars[val & 0x0f]
	return buf[..].bytestr()
}

// Helper to write a unicode codepoint as UTF-8 bytes.
fn write_utf8(mut sb strings.Builder, codepoint u32) {
	if codepoint < 0x80 {
		sb.write_u8(u8(codepoint))
	} else if codepoint < 0x800 {
		sb.write_u8(u8(0xC0 | (codepoint >> 6)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	} else if codepoint < 0x10000 {
		sb.write_u8(u8(0xE0 | (codepoint >> 12)))
		sb.write_u8(u8(0x80 | ((codepoint >> 6) & 0x3F)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	} else {
		sb.write_u8(u8(0xF0 | (codepoint >> 18)))
		sb.write_u8(u8(0x80 | ((codepoint >> 12) & 0x3F)))
		sb.write_u8(u8(0x80 | ((codepoint >> 6) & 0x3F)))
		sb.write_u8(u8(0x80 | (codepoint & 0x3F)))
	}
}

// has_text_any is defined in types.v
