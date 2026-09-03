module terminal

// Terminal module exports reference.
//
// Source: main.zig (82 lines)
//
// In Zig, main.zig is the module root that re-exports all types from
// sub-modules. In V, modules auto-export all pub symbols, so this file
// serves as documentation of what the terminal module exposes.
//
// The terminal module provides the following major types and sub-modules:
//
// == Core types (from terminal.v, screen.v, types.v) ==
//   Terminal          - The main terminal emulator struct
//   Screen            - Screen with cursor, selection, pages
//   CellData          - Cell content data
//   RowData           - Row metadata
//   CellStyle         - Cell styling (colors, attributes)
//   StyleFlags        - Individual style attribute flags
//
// == Page management (from page.v, page_list.v) ==
//   Page              - A single page of terminal content
//   PageCapacity      - Capacity configuration for a page
//   PageNode          - A node in the page linked list
//   PageNodeList      - Doubly-linked list of page nodes
//   PageList          - Full page list with iterators
//   PagePin           - A position pin within the page list
//
// == Selection (from selection.v) ==
//   Selection         - Text selection with ordering and containment
//
// == Rendering (from render.v) ==
//   RenderState       - State needed for rendering
//   RenderColors      - Color configuration for rendering
//   RenderCursor      - Cursor rendering information
//   RenderRow         - A row prepared for rendering
//   RenderCell        - A cell prepared for rendering
//
// == Colors (from color.v) ==
//   TerminalColor     - Color type (none, palette, rgb)
//   BoldColor         - Bold color override configuration
//   RGB               - RGB color value
//
// == Parser (from parser.v) ==
//   VTParser          - VT100/ANSI escape sequence parser
//   ParserState       - Parser state machine states
//   ParserAction      - Actions produced by the parser
//   CSIAction         - CSI dispatch data
//   ESCAction         - ESC dispatch data
//   DCSAction         - DCS hook data
//   OscCommand        - OSC command data
//
// == Parse table (from parse_table.v) ==
//   TransitionAction  - Actions for state transitions
//   Transition        - State transition table entry
//   Table             - The full transition table type
//   transition_table  - The generated transition table constant
//
// == Ref-counted set (from ref_counted_set.v) ==
//   RefCountedSet     - Reference-counted set for styles
//   RefCountedSetItem - An item in the set
//   RefCountedSetLayout - Memory layout for the set
//
// == Points and coordinates (from point.v) ==
//   Point             - Various point types for terminal coordinates
//   Coordinate        - Generic coordinate type
//
// == Size types (from size.v) ==
//   Offset            - Typed offset from base address
//   OffsetSlice       - Slice via offset and length
//   OffsetBuf         - Buffer offset from base pointer
//
// == Style (from style.v) ==
//   FgOpts            - Foreground color resolution options
//
// == SGR (from sgr.v) ==
//   Attribute         - SGR attribute types
//
// == Modes (from modes.v) ==
//   Mode              - Terminal mode flags
//
// == Cursor (from cursor_style.v) ==
//   CursorStyle       - Cursor appearance style
//
// == CSI (from csi.v) ==
//   EraseDisplay      - Erase display mode
//   EraseLine         - Erase line mode
//   TabClear          - Tab clear mode
//
// == ANSI (from ansi.v) ==
//   CursorStyleReq    - Cursor style request
//   DeviceAttributeReq - Device attribute request
//   ModifyKeyFormat   - Key modification format
//   ProtectedMode     - Protected mode setting
//   StatusLineType    - Status line type
//   StatusDisplay     - Status display mode
//
// == Formatter (from formatter.v) ==
//   VTFormatter       - VT sequence formatter
//   HTMLFormatter     - HTML output formatter
//
// == Stream (from stream.v) ==
//   Stream            - Terminal input stream processor
//   StreamAction      - Actions from stream processing
//
// == Stream readonly (from stream_readonly.v) ==
//   ReadonlyHandler   - Handler for read-only stream
//   ReadonlyStream    - Read-only stream processor
//
// == Bitmap allocator (from bitmap_allocator.v) ==
//   BitmapAllocator   - Bitmap-based memory allocator
//
// == UTF-8 decoder (from utf8decoder.v) ==
//   UTF8Decoder       - Streaming UTF-8 decoder
//
// == Internals (referenced by main.zig test block) ==
//   bitmap_allocator  - Bitmap-based allocator
//   ref_counted_set   - Reference-counted set
//   size              - Size and offset types
//
// Other Zig namespaces are V modules imported directly by consumers:
// `kitty`, `search`, and `tmux`. Character sets, X11 colors, string interning,
// and the primary/alternate ScreenSet are implemented in this module.
