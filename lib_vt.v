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

module main

// The public API below reproduces a lot of terminal/main.v but
// is separate because (1) we need our root file to be in `src/`
// so we can access other directories and (2) we may want to withhold
// parts of `terminal` that are not ready for public consumption
// or are too Ghostty-internal.

import terminal
import input

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

pub type Cell = terminal.CellData

pub type Charset = terminal.Charset

pub type CharsetSlot = terminal.CharsetSlot

pub type CharsetActiveSlot = terminal.ActiveSlot

pub type Coordinate = terminal.Coordinate

pub type CSI = terminal.CSIAction

pub type DCS = terminal.DCSAction

pub type Parser = terminal.VTParser

pub type Pin = terminal.PagePin

pub type Point = terminal.Point

pub type ScreenSet = terminal.ScreenSet

pub type SizeReportStyle = terminal.SizeReportStyle

pub type StringMap = terminal.StringMap

pub type Style = terminal.CellStyle

pub type Stream = terminal.Stream

pub type StreamAction = terminal.StreamEvent

pub type Cursor = terminal.Cursor

pub type CursorStyle = terminal.CursorStyle

pub type CursorStyleReq = terminal.AnsiCursorStyle

pub type DeviceAttributeReq = terminal.DeviceAttributeReq

pub type Mode = terminal.Mode

pub type ModePacked = terminal.ModePacked

pub type ModifyKeyFormat = terminal.ModifyKeyFormat

pub type ProtectedMode = terminal.ProtectedMode

pub type StatusLineType = terminal.StatusLineType

pub type StatusDisplay = terminal.StatusDisplay

pub type EraseDisplay = terminal.EraseDisplay

pub type EraseLine = terminal.EraseLine

pub type TabClear = terminal.TabClear

pub type Attribute = terminal.SgrAttribute

pub type ReadonlyHandler = terminal.ReadonlyHandler

pub type ReadonlyStream = terminal.ReadonlyStream

pub type Scrollbar = terminal.Scrollbar

// V has no nested public module declarations, so the APIs under Zig's
// `lib_vt.input` namespace use an Input prefix at this module boundary.
pub type InputPasteOptions = input.PasteOptions

pub type InputKey = input.Key

pub type InputKeyAction = input.KeyAction

pub type InputKeyEvent = input.KeyEvent

pub type InputKeyMods = input.Mods

pub type InputKeyEncodeOptions = input.Options

pub fn input_is_safe_paste(data string) bool {
	return input.paste_is_safe(data)
}

pub fn input_encode_paste(data string, opts InputPasteOptions) [3]string {
	return input.paste_encode(data, opts)
}

pub fn input_encode_key(event InputKeyEvent, opts InputKeyEncodeOptions) string {
	return input.encode(event, opts)
}

// Package-level APIs that are namespaces in Zig are V modules (`osc`,
// `kitty`, `search`, and so on) and are imported directly by V callers. The
// C-facing wrappers live in the `terminal_c` module; V does not require Zig's
// comptime @export aggregation to make those callable.
