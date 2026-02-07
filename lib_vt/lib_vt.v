// Translated from Ghostty's lib_vt.zig
//
// This is the public API of the ghostty-vt module.
//
// WARNING: The API is not guaranteed to be stable.
//
// The functionality is extremely stable, since it is extracted
// directly from Ghostty which has been used in real world scenarios
// by thousands of users for years. However, the API itself (functions,
// types, etc.) may change without warning. We're working on stabilizing
// this in the future.

module lib_vt

// The public API below reproduces a lot of terminal/main.v but
// is separate because (1) we need our root file to be in `src/`
// so we can access other directories and (2) we may want to withhold
// parts of `terminal` that are not ready for public consumption
// or are too Ghostty-internal.

import terminal

// Re-export key terminal types.
// In Zig these are pub const aliases; in V we use type aliases where
// possible and wrapper functions where needed.

// Core terminal types
pub type Terminal = terminal.Terminal
pub type Screen = terminal.Screen
pub type Selection = terminal.Selection
pub type RenderState = terminal.RenderState

// Page types
pub type Page = terminal.Page
pub type PageList = terminal.PageList

// Cell and style types
pub type CellData = terminal.CellData

// XTODO: The following re-exports from the Zig version need their
// corresponding V modules to be implemented first:
//
// pub const apc = terminal.apc
// pub const dcs = terminal.dcs
// pub const osc = terminal.osc
// pub const point = terminal.point
// pub const color = terminal.color
// pub const device_status = terminal.device_status
// pub const formatter = terminal.formatter
// pub const highlight = terminal.highlight
// pub const kitty = terminal.kitty
// pub const modes = terminal.modes
// pub const parse_table = terminal.parse_table
// pub const search = terminal.search
// pub const size = terminal.size
// pub const x11_color = terminal.x11_color
//
// pub const Charset = terminal.Charset
// pub const CharsetSlot = terminal.CharsetSlot
// pub const CharsetActiveSlot = terminal.CharsetActiveSlot
// pub const Cell = page.Cell
// pub const Coordinate = point.Coordinate
// pub const CSI = Parser.Action.CSI
// pub const DCS = Parser.Action.DCS
// pub const MouseShape = terminal.MouseShape
// pub const Parser = terminal.Parser
// pub const Pin = PageList.Pin
// pub const Point = point.Point
// pub const ScreenSet = terminal.ScreenSet
// pub const SizeReportStyle = terminal.SizeReportStyle
// pub const StringMap = terminal.StringMap
// pub const Style = terminal.Style
// pub const Stream = terminal.Stream
// pub const StreamAction = terminal.StreamAction
// pub const Cursor = Screen.Cursor
// pub const CursorStyle = Screen.CursorStyle
// pub const CursorStyleReq = terminal.CursorStyle
// pub const DeviceAttributeReq = terminal.DeviceAttributeReq
// pub const Mode = modes.Mode
// pub const ModePacked = modes.ModePacked
// pub const ModifyKeyFormat = terminal.ModifyKeyFormat
// pub const ProtectedMode = terminal.ProtectedMode
// pub const StatusLineType = terminal.StatusLineType
// pub const StatusDisplay = terminal.StatusDisplay
// pub const EraseDisplay = terminal.EraseDisplay
// pub const EraseLine = terminal.EraseLine
// pub const TabClear = terminal.TabClear
// pub const Attribute = terminal.Attribute

// XTODO: Terminal-specific input encoding is also part of libghostty-vt.
// In Zig this is a nested struct with re-exports from input/paste.zig,
// input/key.zig, and input/key_encode.zig. Needs V input module first.
//
// Input types would include:
// - PasteError, PasteOptions, is_safe_paste, encode_paste
// - Key, KeyAction, KeyEvent, KeyMods
// - KeyEncodeOptions, encode_key

// XTODO: C API exports.
// In Zig, when building as a C library, the comptime block exports
// functions like ghostty_key_event_new, ghostty_osc_new, etc.
// V doesn't have the same C export mechanism. This would need to be
// implemented using V's C interop features if a C library build is needed.
