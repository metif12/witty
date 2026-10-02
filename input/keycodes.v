module input

// --- Original Ghostty Comments Start: src/input/keycodes.zig
//
// Source: /Users/alexander/code/3rd/ghostty/src/input/keycodes.zig
//
// Based on the Chromium source. The Chromium source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// https://source.chromium.org/chromium/chromium/src/+/main:ui/events/keycodes/dom/dom_code_data.inc
// The full list of entries for the current platform.
// Entry contains the USB code, native keycode, and W3C dom code for
// the current platform.
// A map from code to key. This isn't meant to be used at runtime
// (though it could), so it isn't exported. It it used to build the
// key value for Entry.
// The codes for the table from the Chromium data set. These are ALL the
// codes, not just the ones that are supported by the current platform.
// These are `pub` but you shouldn't use this because it uses way more
// memory than is necessary.
//
// The format is: usb, evdev, xkb, win, mac, code
// All of the full entries. This is marked pub but it should NOT be referenced
// directly because it contains too much data for normal usage. Use `entries`
// instead which contains just the relevant data for the target platform.
//   USB     evdev    XKB     Win     Mac   Code
// =========================================
// Non-USB codes
// =========================================
//   USB     evdev    XKB     Win     Mac   Code
// =========================================
// USB Usage Page 0x01: Generic Desktop Page
// =========================================
// Sleep could be encoded as USB#0c0032, but there's no corresponding WakeUp
// in the 0x0c USB page.
//   USB     evdev    XKB     Win     Mac
// =========================================
// USB Usage Page 0x07: Keyboard/Keypad Page
// =========================================
// TODO(garykac):
// XKB#005c ISO Level3 Shift (AltGr)
// XKB#005e <>||
// XKB#006d Linefeed
// XKB#008a SunProps cf. USB#0700a3 CrSel/Props
// XKB#008e SunOpen
// Mac#003f kVK_Function
// Mac#000a kVK_ISO_Section (ISO keyboards only)
// Mac#0066 kVK_JIS_Eisu (USB#07008a Henkan?)
//   USB     evdev    XKB     Win     Mac
// USB#070032 never appears on keyboards that have USB#070031.
// Platforms use the same scancode as for the two keys.
// Hence this code can only be generated synthetically
// (e.g. in a DOM Level 3 KeyboardEvent).
// The keycap varies on international keyboards:
//   Dan: '*  Dutch: <>  Ger: #'  UK: #~
// TODO(garykac): Verify Mac intl keyboard.
// .{ 0x070032, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// TODO(garykac): CapsLock requires special handling for each platform.
// PrintScreen is effectively F13 on Mac OS X.
// USB#0x070049 Insert, labeled "Help/Insert" on Mac -- see note M1 at top.
// Delete (Forward Delete) named DEL because DELETE conflicts with <windows.h>
// USB#070064 is not present on US keyboard.
// This key is typically located near LeftShift key.
// The keycap varies on international keyboards:
//   Dan: <> Dutch: ][ Ger: <> UK: \|
// USB#0x070065 Application Menu (next to RWin key) -- see note L2 at top.
// USB#0x070073 -- see note W1 at top.
// USB#0x070075 Help -- see note M1 at top.
// USB#0x070076 Keyboard Menu -- see note L2 at top.
// .{ 0x070076, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070078, 0x0080, 0x0088, 0x0000, 0xffff, ""},
// .{ 0x070082, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070083, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070084, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// International1
// USB#070086 is used on AS/400 keyboards. Standard Keypad_= is USB#070067.
// .{ 0x070086, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#070087 is used for Brazilian /? and Japanese _ 'ro'.
// International2
// USB#070088 is used as Japanese Hiragana/Katakana key.
// International3
// USB#070089 is used as Japanese Yen key.
// International4
// USB#07008a is used as Japanese Henkan (Convert) key.
// International5
// USB#07008b is used as Japanese Muhenkan (No-convert) key.
// .{ 0x07008c, 0x005f, 0x0067, 0x005c, 0xffff, ""},
// .{ 0x07008d, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07008e, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07008f, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// LANG1
// USB#070090 is used as Korean Hangul/English toggle key, and as the Kana key
// on the Apple Japanese keyboard.
// LANG2
// USB#070091 is used as Korean Hanja conversion key, and as the Eisu key on
// the Apple Japanese keyboard.
// LANG3
// USB#070092 is used as Japanese Katakana key.
// LANG4
// USB#070093 is used as Japanese Hiragana key.
// LANG5
// USB#070094 is used as Japanese Zenkaku/Hankaku (Fullwidth/halfwidth) key.
// Not mapped on Windows -- see note W1 at top.
// .{ 0x070095, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070096, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070097, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070098, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x070099, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07009a, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x07009c Keyboard Clear -- see note L1 at top.
// .{ 0x07009c, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07009d, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07009e, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x07009f, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700a0, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700a1, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700a2, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x0700a3 Props -- see note L2 at top.
// .{ 0x0700a4, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b0, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b1, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b2, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b3, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b4, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b5, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b8, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700b9, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700ba, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700bc, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700bd, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700be, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700bf, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c0, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c1, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c2, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c3, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c4, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c5, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c6, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c7, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c8, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700c9, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700ca, 0x0000, 0x0000, 0x0000, 0xffff, ""},
//           NUMPAD_DOUBLE_VERTICAL_BAR),  // Keypad_||
// .{ 0x0700cb, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700cc, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700cd, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700ce, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700cf, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700d5, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700d6, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x0700d8 Keypad Clear -- see note L1 at top.
// .{ 0x0700da, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700db, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700dc, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0700dd, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0700de - #0700df are reserved.
// USB#0700e2: left Alt key (Mac left Option key).
// USB#0700e3: left GUI key, e.g. Windows, Mac Command, ChromeOS Search.
// USB#0700e6: right Alt key (Mac right Option key).
// USB#0700e7: right GUI key, e.g. Windows, Mac Command, ChromeOS Search.
// USB#0700e8 - #07ffff are reserved
// ==================================
// USB Usage Page 0x0c: Consumer Page
// ==================================
// AL = Application Launch
// AC = Application Control
// TODO(garykac): Many XF86 keys have multiple scancodes mapping to them.
// We need to map all of these into a canonical USB scancode without
// confusing the reverse-lookup - most likely by simply returning the first
// found match.
// TODO(garykac): Find appropriate mappings for:
// Win#e03c Music - USB#0c0193 is AL_AVCapturePlayback
// Win#e064 Pictures
// XKB#0080 XF86LaunchA
// XKB#0099 XF86Send
// XKB#009b XF86Xfer
// XKB#009c XF86Launch1
// XKB#009d XF86Launch2
// XKB... remaining XF86 keys
// KEY_BRIGHTNESS* added in Linux 3.16
// http://www.usb.org/developers/hidpage/HUTRR41.pdf
//
// Keyboard backlight/illumination spec update.
// https://www.usb.org/sites/default/files/hutrr73_-_fn_key_and_keyboard_backlight_brightness_0.pdf
//   USB     evdev    XKB     Win     Mac   Code
//              USB     evdev    XKB     Win     Mac
// .{ 0x0c00e6, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0150, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0151, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0152, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0153, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0154, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// .{ 0x0c0155, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0c0183: AL Consumer Control Configuration
// USB#0x0c018a AL_EmailReader
// USB#0x0c018d: AL Contacts/Address Book
// USB#0x0c018e: AL Calendar/Schedule
// USB#0x0c018f AL Task/Project Manager
// .{ 0x0c018f, 0x0241, 0x0249, 0x0000, 0xffff, ""},
// USB#0x0c0190: AL Log/Journal/Timecard
// .{ 0x0c0190, 0x0242, 0x024a, 0x0000, 0xffff, ""},
// USB#0x0c0192: AL_Calculator
// USB#0c0194: My Computer (AL_LocalMachineBrowser)
// USB#0x0c019e: AL Terminal Lock/Screensaver
// USB#0x0c019f AL Control Panel
// USB#0x0c01a2: AL Select Task/Application
// USB#0x0c01a7: AL_Documents
// USB#0x0c01ae: AL Keyboard Layout
// USB#0c01b4: Home Directory (AL_FileBrowser) (Explorer)
// .{ 0x0c01b4, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x0c01b7: AL Audio Browser
// USB#0x0c0201: AC New
// USB#0x0c0203: AC Close
// USB#0x0c0207: AC Close
// USB#0x0c0208: AC Print
// USB#0x0c0221:  AC_Search
// USB#0x0c0223:  AC_Home
// USB#0x0c0224:  AC_Back
// USB#0x0c0225:  AC_Forward
// USB#0x0c0226:  AC_Stop
// USB#0x0c0227:  AC_Refresh (Reload)
// USB#0x0c022a:  AC_Bookmarks (Favorites)
// USB#0x0c0230:  AC Full Screen View
// .{ 0x0c0230, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x0c0231:  AC Normal View
// .{ 0x0c0231, 0x0000, 0x0000, 0x0000, 0xffff, ""},
// USB#0x0c0279:  AC Redo/Repeat
// USB#0x0c0289:  AC_Reply
// USB#0x0c028b:  AC_ForwardMsg (MailForward)
// USB#0x0c028c:  AC_Send
// USB#0x0c029d:  AC Next Keyboard Layout Select
//
// --- Original Ghostty Comments End: src/input/keycodes.zig

// Based on the Chromium source. The Chromium source code is governed by a
// BSD-style license that can be found in the LICENSE file.
// https://source.chromium.org/chromium/chromium/src/+/main:ui/events/keycodes/dom/dom_code_data.inc
//
// Translated from Ghostty's keycodes.zig.
// The raw_entries table contains: USB, evdev, XKB, Win, Mac, W3C_code.
// For macOS, we use column index 4 (Mac) as the native keycode.
// The code_to_key map resolves W3C DOM code strings to Key enum values.

// KeycodeFullEntry contains the USB code, native keycode, W3C DOM code,
// and corresponding Key for the current platform for the current platform.
pub struct KeycodeFullEntry {
pub:
	key    Key // input key enum
	usb    u32 // USB HID usage code
	native u32 // native keycode of the current platform
	code   string // W3C DOM code
}

// Source raw_entries: USB, evdev, XKB, Windows, macOS, W3C code.
// Keys are the source code_to_key lookup; unknown codes stay unidentified.
struct RawKeycodeEntry {
	usb u32
	evdev u32
	xkb u32
	windows u32
	mac u32
	code string
	key Key
}

const raw_keycodes_entries = [
	RawKeycodeEntry{usb: 0x000000, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x000010, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Hyper", key: .unidentified},
	RawKeycodeEntry{usb: 0x000011, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Super", key: .unidentified},
	RawKeycodeEntry{usb: 0x000012, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Fn", key: .unidentified},
	RawKeycodeEntry{usb: 0x000013, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "FnLock", key: .unidentified},
	RawKeycodeEntry{usb: 0x000014, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Suspend", key: .unidentified},
	RawKeycodeEntry{usb: 0x000015, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Resume", key: .unidentified},
	RawKeycodeEntry{usb: 0x000016, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Turbo", key: .unidentified},
	RawKeycodeEntry{usb: 0x010082, evdev: 0x008e, xkb: 0x0096, windows: 0xe05f, mac: 0xffff, code: "Sleep", key: .unidentified},
	RawKeycodeEntry{usb: 0x010083, evdev: 0x008f, xkb: 0x0097, windows: 0xe063, mac: 0xffff, code: "WakeUp", key: .unidentified},
	RawKeycodeEntry{usb: 0x0100a9, evdev: 0x00f8, xkb: 0x0100, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0100b5, evdev: 0x00e3, xkb: 0x00eb, windows: 0x0000, mac: 0xffff, code: "DisplayToggleIntExt", key: .unidentified},
	RawKeycodeEntry{usb: 0x070000, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x070001, evdev: 0x0000, xkb: 0x0000, windows: 0x00ff, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x070002, evdev: 0x0000, xkb: 0x0000, windows: 0x00fc, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x070003, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x070004, evdev: 0x001e, xkb: 0x0026, windows: 0x001e, mac: 0x0000, code: "KeyA", key: .key_a},
	RawKeycodeEntry{usb: 0x070005, evdev: 0x0030, xkb: 0x0038, windows: 0x0030, mac: 0x000b, code: "KeyB", key: .key_b},
	RawKeycodeEntry{usb: 0x070006, evdev: 0x002e, xkb: 0x0036, windows: 0x002e, mac: 0x0008, code: "KeyC", key: .key_c},
	RawKeycodeEntry{usb: 0x070007, evdev: 0x0020, xkb: 0x0028, windows: 0x0020, mac: 0x0002, code: "KeyD", key: .key_d},
	RawKeycodeEntry{usb: 0x070008, evdev: 0x0012, xkb: 0x001a, windows: 0x0012, mac: 0x000e, code: "KeyE", key: .key_e},
	RawKeycodeEntry{usb: 0x070009, evdev: 0x0021, xkb: 0x0029, windows: 0x0021, mac: 0x0003, code: "KeyF", key: .key_f},
	RawKeycodeEntry{usb: 0x07000a, evdev: 0x0022, xkb: 0x002a, windows: 0x0022, mac: 0x0005, code: "KeyG", key: .key_g},
	RawKeycodeEntry{usb: 0x07000b, evdev: 0x0023, xkb: 0x002b, windows: 0x0023, mac: 0x0004, code: "KeyH", key: .key_h},
	RawKeycodeEntry{usb: 0x07000c, evdev: 0x0017, xkb: 0x001f, windows: 0x0017, mac: 0x0022, code: "KeyI", key: .key_i},
	RawKeycodeEntry{usb: 0x07000d, evdev: 0x0024, xkb: 0x002c, windows: 0x0024, mac: 0x0026, code: "KeyJ", key: .key_j},
	RawKeycodeEntry{usb: 0x07000e, evdev: 0x0025, xkb: 0x002d, windows: 0x0025, mac: 0x0028, code: "KeyK", key: .key_k},
	RawKeycodeEntry{usb: 0x07000f, evdev: 0x0026, xkb: 0x002e, windows: 0x0026, mac: 0x0025, code: "KeyL", key: .key_l},
	RawKeycodeEntry{usb: 0x070010, evdev: 0x0032, xkb: 0x003a, windows: 0x0032, mac: 0x002e, code: "KeyM", key: .key_m},
	RawKeycodeEntry{usb: 0x070011, evdev: 0x0031, xkb: 0x0039, windows: 0x0031, mac: 0x002d, code: "KeyN", key: .key_n},
	RawKeycodeEntry{usb: 0x070012, evdev: 0x0018, xkb: 0x0020, windows: 0x0018, mac: 0x001f, code: "KeyO", key: .key_o},
	RawKeycodeEntry{usb: 0x070013, evdev: 0x0019, xkb: 0x0021, windows: 0x0019, mac: 0x0023, code: "KeyP", key: .key_p},
	RawKeycodeEntry{usb: 0x070014, evdev: 0x0010, xkb: 0x0018, windows: 0x0010, mac: 0x000c, code: "KeyQ", key: .key_q},
	RawKeycodeEntry{usb: 0x070015, evdev: 0x0013, xkb: 0x001b, windows: 0x0013, mac: 0x000f, code: "KeyR", key: .key_r},
	RawKeycodeEntry{usb: 0x070016, evdev: 0x001f, xkb: 0x0027, windows: 0x001f, mac: 0x0001, code: "KeyS", key: .key_s},
	RawKeycodeEntry{usb: 0x070017, evdev: 0x0014, xkb: 0x001c, windows: 0x0014, mac: 0x0011, code: "KeyT", key: .key_t},
	RawKeycodeEntry{usb: 0x070018, evdev: 0x0016, xkb: 0x001e, windows: 0x0016, mac: 0x0020, code: "KeyU", key: .key_u},
	RawKeycodeEntry{usb: 0x070019, evdev: 0x002f, xkb: 0x0037, windows: 0x002f, mac: 0x0009, code: "KeyV", key: .key_v},
	RawKeycodeEntry{usb: 0x07001a, evdev: 0x0011, xkb: 0x0019, windows: 0x0011, mac: 0x000d, code: "KeyW", key: .key_w},
	RawKeycodeEntry{usb: 0x07001b, evdev: 0x002d, xkb: 0x0035, windows: 0x002d, mac: 0x0007, code: "KeyX", key: .key_x},
	RawKeycodeEntry{usb: 0x07001c, evdev: 0x0015, xkb: 0x001d, windows: 0x0015, mac: 0x0010, code: "KeyY", key: .key_y},
	RawKeycodeEntry{usb: 0x07001d, evdev: 0x002c, xkb: 0x0034, windows: 0x002c, mac: 0x0006, code: "KeyZ", key: .key_z},
	RawKeycodeEntry{usb: 0x07001e, evdev: 0x0002, xkb: 0x000a, windows: 0x0002, mac: 0x0012, code: "Digit1", key: .digit_1},
	RawKeycodeEntry{usb: 0x07001f, evdev: 0x0003, xkb: 0x000b, windows: 0x0003, mac: 0x0013, code: "Digit2", key: .digit_2},
	RawKeycodeEntry{usb: 0x070020, evdev: 0x0004, xkb: 0x000c, windows: 0x0004, mac: 0x0014, code: "Digit3", key: .digit_3},
	RawKeycodeEntry{usb: 0x070021, evdev: 0x0005, xkb: 0x000d, windows: 0x0005, mac: 0x0015, code: "Digit4", key: .digit_4},
	RawKeycodeEntry{usb: 0x070022, evdev: 0x0006, xkb: 0x000e, windows: 0x0006, mac: 0x0017, code: "Digit5", key: .digit_5},
	RawKeycodeEntry{usb: 0x070023, evdev: 0x0007, xkb: 0x000f, windows: 0x0007, mac: 0x0016, code: "Digit6", key: .digit_6},
	RawKeycodeEntry{usb: 0x070024, evdev: 0x0008, xkb: 0x0010, windows: 0x0008, mac: 0x001a, code: "Digit7", key: .digit_7},
	RawKeycodeEntry{usb: 0x070025, evdev: 0x0009, xkb: 0x0011, windows: 0x0009, mac: 0x001c, code: "Digit8", key: .digit_8},
	RawKeycodeEntry{usb: 0x070026, evdev: 0x000a, xkb: 0x0012, windows: 0x000a, mac: 0x0019, code: "Digit9", key: .digit_9},
	RawKeycodeEntry{usb: 0x070027, evdev: 0x000b, xkb: 0x0013, windows: 0x000b, mac: 0x001d, code: "Digit0", key: .digit_0},
	RawKeycodeEntry{usb: 0x070028, evdev: 0x001c, xkb: 0x0024, windows: 0x001c, mac: 0x0024, code: "Enter", key: .enter},
	RawKeycodeEntry{usb: 0x070029, evdev: 0x0001, xkb: 0x0009, windows: 0x0001, mac: 0x0035, code: "Escape", key: .escape},
	RawKeycodeEntry{usb: 0x07002a, evdev: 0x000e, xkb: 0x0016, windows: 0x000e, mac: 0x0033, code: "Backspace", key: .backspace},
	RawKeycodeEntry{usb: 0x07002b, evdev: 0x000f, xkb: 0x0017, windows: 0x000f, mac: 0x0030, code: "Tab", key: .tab},
	RawKeycodeEntry{usb: 0x07002c, evdev: 0x0039, xkb: 0x0041, windows: 0x0039, mac: 0x0031, code: "Space", key: .space},
	RawKeycodeEntry{usb: 0x07002d, evdev: 0x000c, xkb: 0x0014, windows: 0x000c, mac: 0x001b, code: "Minus", key: .minus},
	RawKeycodeEntry{usb: 0x07002e, evdev: 0x000d, xkb: 0x0015, windows: 0x000d, mac: 0x0018, code: "Equal", key: .equal},
	RawKeycodeEntry{usb: 0x07002f, evdev: 0x001a, xkb: 0x0022, windows: 0x001a, mac: 0x0021, code: "BracketLeft", key: .bracket_left},
	RawKeycodeEntry{usb: 0x070030, evdev: 0x001b, xkb: 0x0023, windows: 0x001b, mac: 0x001e, code: "BracketRight", key: .bracket_right},
	RawKeycodeEntry{usb: 0x070031, evdev: 0x002b, xkb: 0x0033, windows: 0x002b, mac: 0x002a, code: "Backslash", key: .backslash},
	RawKeycodeEntry{usb: 0x070033, evdev: 0x0027, xkb: 0x002f, windows: 0x0027, mac: 0x0029, code: "Semicolon", key: .semicolon},
	RawKeycodeEntry{usb: 0x070034, evdev: 0x0028, xkb: 0x0030, windows: 0x0028, mac: 0x0027, code: "Quote", key: .quote},
	RawKeycodeEntry{usb: 0x070035, evdev: 0x0029, xkb: 0x0031, windows: 0x0029, mac: 0x0032, code: "Backquote", key: .backquote},
	RawKeycodeEntry{usb: 0x070036, evdev: 0x0033, xkb: 0x003b, windows: 0x0033, mac: 0x002b, code: "Comma", key: .comma},
	RawKeycodeEntry{usb: 0x070037, evdev: 0x0034, xkb: 0x003c, windows: 0x0034, mac: 0x002f, code: "Period", key: .period},
	RawKeycodeEntry{usb: 0x070038, evdev: 0x0035, xkb: 0x003d, windows: 0x0035, mac: 0x002c, code: "Slash", key: .slash},
	RawKeycodeEntry{usb: 0x070039, evdev: 0x003a, xkb: 0x0042, windows: 0x003a, mac: 0x0039, code: "CapsLock", key: .caps_lock},
	RawKeycodeEntry{usb: 0x07003a, evdev: 0x003b, xkb: 0x0043, windows: 0x003b, mac: 0x007a, code: "F1", key: .f1},
	RawKeycodeEntry{usb: 0x07003b, evdev: 0x003c, xkb: 0x0044, windows: 0x003c, mac: 0x0078, code: "F2", key: .f2},
	RawKeycodeEntry{usb: 0x07003c, evdev: 0x003d, xkb: 0x0045, windows: 0x003d, mac: 0x0063, code: "F3", key: .f3},
	RawKeycodeEntry{usb: 0x07003d, evdev: 0x003e, xkb: 0x0046, windows: 0x003e, mac: 0x0076, code: "F4", key: .f4},
	RawKeycodeEntry{usb: 0x07003e, evdev: 0x003f, xkb: 0x0047, windows: 0x003f, mac: 0x0060, code: "F5", key: .f5},
	RawKeycodeEntry{usb: 0x07003f, evdev: 0x0040, xkb: 0x0048, windows: 0x0040, mac: 0x0061, code: "F6", key: .f6},
	RawKeycodeEntry{usb: 0x070040, evdev: 0x0041, xkb: 0x0049, windows: 0x0041, mac: 0x0062, code: "F7", key: .f7},
	RawKeycodeEntry{usb: 0x070041, evdev: 0x0042, xkb: 0x004a, windows: 0x0042, mac: 0x0064, code: "F8", key: .f8},
	RawKeycodeEntry{usb: 0x070042, evdev: 0x0043, xkb: 0x004b, windows: 0x0043, mac: 0x0065, code: "F9", key: .f9},
	RawKeycodeEntry{usb: 0x070043, evdev: 0x0044, xkb: 0x004c, windows: 0x0044, mac: 0x006d, code: "F10", key: .f10},
	RawKeycodeEntry{usb: 0x070044, evdev: 0x0057, xkb: 0x005f, windows: 0x0057, mac: 0x0067, code: "F11", key: .f11},
	RawKeycodeEntry{usb: 0x070045, evdev: 0x0058, xkb: 0x0060, windows: 0x0058, mac: 0x006f, code: "F12", key: .f12},
	RawKeycodeEntry{usb: 0x070046, evdev: 0x0063, xkb: 0x006b, windows: 0xe037, mac: 0xffff, code: "PrintScreen", key: .print_screen},
	RawKeycodeEntry{usb: 0x070047, evdev: 0x0046, xkb: 0x004e, windows: 0x0046, mac: 0xffff, code: "ScrollLock", key: .scroll_lock},
	RawKeycodeEntry{usb: 0x070048, evdev: 0x0077, xkb: 0x007f, windows: 0x0045, mac: 0xffff, code: "Pause", key: .pause},
	RawKeycodeEntry{usb: 0x070049, evdev: 0x006e, xkb: 0x0076, windows: 0xe052, mac: 0x0072, code: "Insert", key: .insert},
	RawKeycodeEntry{usb: 0x07004a, evdev: 0x0066, xkb: 0x006e, windows: 0xe047, mac: 0x0073, code: "Home", key: .home},
	RawKeycodeEntry{usb: 0x07004b, evdev: 0x0068, xkb: 0x0070, windows: 0xe049, mac: 0x0074, code: "PageUp", key: .page_up},
	RawKeycodeEntry{usb: 0x07004c, evdev: 0x006f, xkb: 0x0077, windows: 0xe053, mac: 0x0075, code: "Delete", key: .delete},
	RawKeycodeEntry{usb: 0x07004d, evdev: 0x006b, xkb: 0x0073, windows: 0xe04f, mac: 0x0077, code: "End", key: .end},
	RawKeycodeEntry{usb: 0x07004e, evdev: 0x006d, xkb: 0x0075, windows: 0xe051, mac: 0x0079, code: "PageDown", key: .page_down},
	RawKeycodeEntry{usb: 0x07004f, evdev: 0x006a, xkb: 0x0072, windows: 0xe04d, mac: 0x007c, code: "ArrowRight", key: .arrow_right},
	RawKeycodeEntry{usb: 0x070050, evdev: 0x0069, xkb: 0x0071, windows: 0xe04b, mac: 0x007b, code: "ArrowLeft", key: .arrow_left},
	RawKeycodeEntry{usb: 0x070051, evdev: 0x006c, xkb: 0x0074, windows: 0xe050, mac: 0x007d, code: "ArrowDown", key: .arrow_down},
	RawKeycodeEntry{usb: 0x070052, evdev: 0x0067, xkb: 0x006f, windows: 0xe048, mac: 0x007e, code: "ArrowUp", key: .arrow_up},
	RawKeycodeEntry{usb: 0x070053, evdev: 0x0045, xkb: 0x004d, windows: 0xe045, mac: 0x0047, code: "NumLock", key: .num_lock},
	RawKeycodeEntry{usb: 0x070054, evdev: 0x0062, xkb: 0x006a, windows: 0xe035, mac: 0x004b, code: "NumpadDivide", key: .numpad_divide},
	RawKeycodeEntry{usb: 0x070055, evdev: 0x0037, xkb: 0x003f, windows: 0x0037, mac: 0x0043, code: "NumpadMultiply", key: .numpad_multiply},
	RawKeycodeEntry{usb: 0x070056, evdev: 0x004a, xkb: 0x0052, windows: 0x004a, mac: 0x004e, code: "NumpadSubtract", key: .numpad_subtract},
	RawKeycodeEntry{usb: 0x070057, evdev: 0x004e, xkb: 0x0056, windows: 0x004e, mac: 0x0045, code: "NumpadAdd", key: .numpad_add},
	RawKeycodeEntry{usb: 0x070058, evdev: 0x0060, xkb: 0x0068, windows: 0xe01c, mac: 0x004c, code: "NumpadEnter", key: .numpad_enter},
	RawKeycodeEntry{usb: 0x070059, evdev: 0x004f, xkb: 0x0057, windows: 0x004f, mac: 0x0053, code: "Numpad1", key: .numpad_1},
	RawKeycodeEntry{usb: 0x07005a, evdev: 0x0050, xkb: 0x0058, windows: 0x0050, mac: 0x0054, code: "Numpad2", key: .numpad_2},
	RawKeycodeEntry{usb: 0x07005b, evdev: 0x0051, xkb: 0x0059, windows: 0x0051, mac: 0x0055, code: "Numpad3", key: .numpad_3},
	RawKeycodeEntry{usb: 0x07005c, evdev: 0x004b, xkb: 0x0053, windows: 0x004b, mac: 0x0056, code: "Numpad4", key: .numpad_4},
	RawKeycodeEntry{usb: 0x07005d, evdev: 0x004c, xkb: 0x0054, windows: 0x004c, mac: 0x0057, code: "Numpad5", key: .numpad_5},
	RawKeycodeEntry{usb: 0x07005e, evdev: 0x004d, xkb: 0x0055, windows: 0x004d, mac: 0x0058, code: "Numpad6", key: .numpad_6},
	RawKeycodeEntry{usb: 0x07005f, evdev: 0x0047, xkb: 0x004f, windows: 0x0047, mac: 0x0059, code: "Numpad7", key: .numpad_7},
	RawKeycodeEntry{usb: 0x070060, evdev: 0x0048, xkb: 0x0050, windows: 0x0048, mac: 0x005b, code: "Numpad8", key: .numpad_8},
	RawKeycodeEntry{usb: 0x070061, evdev: 0x0049, xkb: 0x0051, windows: 0x0049, mac: 0x005c, code: "Numpad9", key: .numpad_9},
	RawKeycodeEntry{usb: 0x070062, evdev: 0x0052, xkb: 0x005a, windows: 0x0052, mac: 0x0052, code: "Numpad0", key: .numpad_0},
	RawKeycodeEntry{usb: 0x070063, evdev: 0x0053, xkb: 0x005b, windows: 0x0053, mac: 0x0041, code: "NumpadDecimal", key: .numpad_decimal},
	RawKeycodeEntry{usb: 0x070064, evdev: 0x0056, xkb: 0x005e, windows: 0x0056, mac: 0x000a, code: "IntlBackslash", key: .unidentified},
	RawKeycodeEntry{usb: 0x070065, evdev: 0x007f, xkb: 0x0087, windows: 0xe05d, mac: 0x006e, code: "ContextMenu", key: .context_menu},
	RawKeycodeEntry{usb: 0x070066, evdev: 0x0074, xkb: 0x007c, windows: 0xe05e, mac: 0xffff, code: "Power", key: .unidentified},
	RawKeycodeEntry{usb: 0x070067, evdev: 0x0075, xkb: 0x007d, windows: 0x0059, mac: 0x0051, code: "NumpadEqual", key: .numpad_equal},
	RawKeycodeEntry{usb: 0x070068, evdev: 0x00b7, xkb: 0x00bf, windows: 0x0064, mac: 0x0069, code: "F13", key: .f13},
	RawKeycodeEntry{usb: 0x070069, evdev: 0x00b8, xkb: 0x00c0, windows: 0x0065, mac: 0x006b, code: "F14", key: .f14},
	RawKeycodeEntry{usb: 0x07006a, evdev: 0x00b9, xkb: 0x00c1, windows: 0x0066, mac: 0x0071, code: "F15", key: .f15},
	RawKeycodeEntry{usb: 0x07006b, evdev: 0x00ba, xkb: 0x00c2, windows: 0x0067, mac: 0x006a, code: "F16", key: .f16},
	RawKeycodeEntry{usb: 0x07006c, evdev: 0x00bb, xkb: 0x00c3, windows: 0x0068, mac: 0x0040, code: "F17", key: .f17},
	RawKeycodeEntry{usb: 0x07006d, evdev: 0x00bc, xkb: 0x00c4, windows: 0x0069, mac: 0x004f, code: "F18", key: .f18},
	RawKeycodeEntry{usb: 0x07006e, evdev: 0x00bd, xkb: 0x00c5, windows: 0x006a, mac: 0x0050, code: "F19", key: .f19},
	RawKeycodeEntry{usb: 0x07006f, evdev: 0x00be, xkb: 0x00c6, windows: 0x006b, mac: 0x005a, code: "F20", key: .f20},
	RawKeycodeEntry{usb: 0x070070, evdev: 0x00bf, xkb: 0x00c7, windows: 0x006c, mac: 0xffff, code: "F21", key: .f21},
	RawKeycodeEntry{usb: 0x070071, evdev: 0x00c0, xkb: 0x00c8, windows: 0x006d, mac: 0xffff, code: "F22", key: .f22},
	RawKeycodeEntry{usb: 0x070072, evdev: 0x00c1, xkb: 0x00c9, windows: 0x006e, mac: 0xffff, code: "F23", key: .f23},
	RawKeycodeEntry{usb: 0x070073, evdev: 0x00c2, xkb: 0x00ca, windows: 0x0076, mac: 0xffff, code: "F24", key: .f24},
	RawKeycodeEntry{usb: 0x070074, evdev: 0x0086, xkb: 0x008e, windows: 0x0000, mac: 0xffff, code: "Open", key: .unidentified},
	RawKeycodeEntry{usb: 0x070075, evdev: 0x008a, xkb: 0x0092, windows: 0xe03b, mac: 0xffff, code: "Help", key: .unidentified},
	RawKeycodeEntry{usb: 0x070077, evdev: 0x0084, xkb: 0x008c, windows: 0x0000, mac: 0xffff, code: "Select", key: .unidentified},
	RawKeycodeEntry{usb: 0x070079, evdev: 0x0081, xkb: 0x0089, windows: 0x0000, mac: 0xffff, code: "Again", key: .unidentified},
	RawKeycodeEntry{usb: 0x07007a, evdev: 0x0083, xkb: 0x008b, windows: 0xe008, mac: 0xffff, code: "Undo", key: .unidentified},
	RawKeycodeEntry{usb: 0x07007b, evdev: 0x0089, xkb: 0x0091, windows: 0xe017, mac: 0xffff, code: "Cut", key: .cut},
	RawKeycodeEntry{usb: 0x07007c, evdev: 0x0085, xkb: 0x008d, windows: 0xe018, mac: 0xffff, code: "Copy", key: .copy},
	RawKeycodeEntry{usb: 0x07007d, evdev: 0x0087, xkb: 0x008f, windows: 0xe00a, mac: 0xffff, code: "Paste", key: .paste},
	RawKeycodeEntry{usb: 0x07007e, evdev: 0x0088, xkb: 0x0090, windows: 0x0000, mac: 0xffff, code: "Find", key: .unidentified},
	RawKeycodeEntry{usb: 0x07007f, evdev: 0x0071, xkb: 0x0079, windows: 0xe020, mac: 0x004a, code: "AudioVolumeMute", key: .unidentified},
	RawKeycodeEntry{usb: 0x070080, evdev: 0x0073, xkb: 0x007b, windows: 0xe030, mac: 0x0048, code: "AudioVolumeUp", key: .unidentified},
	RawKeycodeEntry{usb: 0x070081, evdev: 0x0072, xkb: 0x007a, windows: 0xe02e, mac: 0x0049, code: "AudioVolumeDown", key: .unidentified},
	RawKeycodeEntry{usb: 0x070085, evdev: 0x0079, xkb: 0x0081, windows: 0x007e, mac: 0x005f, code: "NumpadComma", key: .unidentified},
	RawKeycodeEntry{usb: 0x070087, evdev: 0x0059, xkb: 0x0061, windows: 0x0073, mac: 0x005e, code: "IntlRo", key: .unidentified},
	RawKeycodeEntry{usb: 0x070088, evdev: 0x005d, xkb: 0x0065, windows: 0x0070, mac: 0xffff, code: "KanaMode", key: .unidentified},
	RawKeycodeEntry{usb: 0x070089, evdev: 0x007c, xkb: 0x0084, windows: 0x007d, mac: 0x005d, code: "IntlYen", key: .unidentified},
	RawKeycodeEntry{usb: 0x07008a, evdev: 0x005c, xkb: 0x0064, windows: 0x0079, mac: 0xffff, code: "Convert", key: .unidentified},
	RawKeycodeEntry{usb: 0x07008b, evdev: 0x005e, xkb: 0x0066, windows: 0x007b, mac: 0xffff, code: "NonConvert", key: .unidentified},
	RawKeycodeEntry{usb: 0x070090, evdev: 0x007a, xkb: 0x0082, windows: 0x0072, mac: 0x0068, code: "Lang1", key: .unidentified},
	RawKeycodeEntry{usb: 0x070091, evdev: 0x007b, xkb: 0x0083, windows: 0x0071, mac: 0x0066, code: "Lang2", key: .unidentified},
	RawKeycodeEntry{usb: 0x070092, evdev: 0x005a, xkb: 0x0062, windows: 0x0078, mac: 0xffff, code: "Lang3", key: .unidentified},
	RawKeycodeEntry{usb: 0x070093, evdev: 0x005b, xkb: 0x0063, windows: 0x0077, mac: 0xffff, code: "Lang4", key: .unidentified},
	RawKeycodeEntry{usb: 0x070094, evdev: 0x0055, xkb: 0x005d, windows: 0x0000, mac: 0xffff, code: "Lang5", key: .unidentified},
	RawKeycodeEntry{usb: 0x07009b, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Abort", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700a3, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "Props", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700b6, evdev: 0x00b3, xkb: 0x00bb, windows: 0x0000, mac: 0xffff, code: "NumpadParenLeft", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700b7, evdev: 0x00b4, xkb: 0x00bc, windows: 0x0000, mac: 0xffff, code: "NumpadParenRight", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700bb, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadBackspace", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d0, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadMemoryStore", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d1, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadMemoryRecall", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d2, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadMemoryClear", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d3, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadMemoryAdd", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d4, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadMemorySubtract", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d7, evdev: 0x0076, xkb: 0x007e, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d8, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadClear", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700d9, evdev: 0x0000, xkb: 0x0000, windows: 0x0000, mac: 0xffff, code: "NumpadClearEntry", key: .unidentified},
	RawKeycodeEntry{usb: 0x0700e0, evdev: 0x001d, xkb: 0x0025, windows: 0x001d, mac: 0x003b, code: "ControlLeft", key: .control_left},
	RawKeycodeEntry{usb: 0x0700e1, evdev: 0x002a, xkb: 0x0032, windows: 0x002a, mac: 0x0038, code: "ShiftLeft", key: .shift_left},
	RawKeycodeEntry{usb: 0x0700e2, evdev: 0x0038, xkb: 0x0040, windows: 0x0038, mac: 0x003a, code: "AltLeft", key: .alt_left},
	RawKeycodeEntry{usb: 0x0700e3, evdev: 0x007d, xkb: 0x0085, windows: 0xe05b, mac: 0x0037, code: "MetaLeft", key: .meta_left},
	RawKeycodeEntry{usb: 0x0700e4, evdev: 0x0061, xkb: 0x0069, windows: 0xe01d, mac: 0x003e, code: "ControlRight", key: .control_right},
	RawKeycodeEntry{usb: 0x0700e5, evdev: 0x0036, xkb: 0x003e, windows: 0x0036, mac: 0x003c, code: "ShiftRight", key: .shift_right},
	RawKeycodeEntry{usb: 0x0700e6, evdev: 0x0064, xkb: 0x006c, windows: 0xe038, mac: 0x003d, code: "AltRight", key: .alt_right},
	RawKeycodeEntry{usb: 0x0700e7, evdev: 0x007e, xkb: 0x0086, windows: 0xe05c, mac: 0x0036, code: "MetaRight", key: .meta_right},
	RawKeycodeEntry{usb: 0x0c0060, evdev: 0x0166, xkb: 0x016e, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0061, evdev: 0x0172, xkb: 0x017a, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c006f, evdev: 0x00e1, xkb: 0x00e9, windows: 0x0000, mac: 0xffff, code: "BrightnessUp", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0070, evdev: 0x00e0, xkb: 0x00e8, windows: 0x0000, mac: 0xffff, code: "BrightnessDown", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0072, evdev: 0x01af, xkb: 0x01b7, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0073, evdev: 0x0250, xkb: 0x0258, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0074, evdev: 0x0251, xkb: 0x0259, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0075, evdev: 0x00f4, xkb: 0x00fc, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0079, evdev: 0x00e6, xkb: 0x00ee, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c007a, evdev: 0x00e5, xkb: 0x00ed, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c007c, evdev: 0x00e4, xkb: 0x00ec, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0083, evdev: 0x0195, xkb: 0x019d, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c008c, evdev: 0x00a9, xkb: 0x00b1, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c008d, evdev: 0x016a, xkb: 0x0172, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0094, evdev: 0x00ae, xkb: 0x00b6, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c009c, evdev: 0x019a, xkb: 0x01a2, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c009d, evdev: 0x019b, xkb: 0x01a3, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b0, evdev: 0x00cf, xkb: 0x00d7, windows: 0x0000, mac: 0xffff, code: "MediaPlay", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b1, evdev: 0x00c9, xkb: 0x00d1, windows: 0x0000, mac: 0xffff, code: "MediaPause", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b2, evdev: 0x00a7, xkb: 0x00af, windows: 0x0000, mac: 0xffff, code: "MediaRecord", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b3, evdev: 0x00d0, xkb: 0x00d8, windows: 0x0000, mac: 0xffff, code: "MediaFastForward", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b4, evdev: 0x00a8, xkb: 0x00b0, windows: 0x0000, mac: 0xffff, code: "MediaRewind", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b5, evdev: 0x00a3, xkb: 0x00ab, windows: 0xe019, mac: 0xffff, code: "MediaTrackNext", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b6, evdev: 0x00a5, xkb: 0x00ad, windows: 0xe010, mac: 0xffff, code: "MediaTrackPrevious", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b7, evdev: 0x00a6, xkb: 0x00ae, windows: 0xe024, mac: 0xffff, code: "MediaStop", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00b8, evdev: 0x00a1, xkb: 0x00a9, windows: 0xe02c, mac: 0xffff, code: "Eject", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00cd, evdev: 0x00a4, xkb: 0x00ac, windows: 0xe022, mac: 0xffff, code: "MediaPlayPause", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00cf, evdev: 0x0246, xkb: 0x024e, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00d8, evdev: 0x024a, xkb: 0x0252, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00d9, evdev: 0x0249, xkb: 0x0251, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c00e5, evdev: 0x00d1, xkb: 0x00d9, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0183, evdev: 0x00ab, xkb: 0x00b3, windows: 0xe06d, mac: 0xffff, code: "MediaSelect", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0184, evdev: 0x01a5, xkb: 0x01ad, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0186, evdev: 0x01a7, xkb: 0x01af, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c018a, evdev: 0x009b, xkb: 0x00a3, windows: 0xe06c, mac: 0xffff, code: "LaunchMail", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c018d, evdev: 0x01ad, xkb: 0x01b5, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c018e, evdev: 0x018d, xkb: 0x0195, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0192, evdev: 0x008c, xkb: 0x0094, windows: 0xe021, mac: 0xffff, code: "LaunchApp2", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0194, evdev: 0x0090, xkb: 0x0098, windows: 0xe06b, mac: 0xffff, code: "LaunchApp1", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0196, evdev: 0x0096, xkb: 0x009e, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c019e, evdev: 0x0098, xkb: 0x00a0, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c019f, evdev: 0x0243, xkb: 0x024b, windows: 0x0000, mac: 0xffff, code: "LaunchControlPanel", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01a2, evdev: 0x0244, xkb: 0x024c, windows: 0x0000, mac: 0xffff, code: "SelectTask", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01a7, evdev: 0x00eb, xkb: 0x00f3, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01ab, evdev: 0x01b0, xkb: 0x01b8, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01ae, evdev: 0x0176, xkb: 0x017e, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01b1, evdev: 0x0245, xkb: 0x024d, windows: 0x0000, mac: 0xffff, code: "LaunchScreenSaver", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01cb, evdev: 0x0247, xkb: 0x024f, windows: 0x0000, mac: 0xffff, code: "LaunchAssistant", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c01b7, evdev: 0x0188, xkb: 0x0190, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0201, evdev: 0x00b5, xkb: 0x00bd, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0203, evdev: 0x00ce, xkb: 0x00d6, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0207, evdev: 0x00ea, xkb: 0x00f2, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0208, evdev: 0x00d2, xkb: 0x00da, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0221, evdev: 0x00d9, xkb: 0x00e1, windows: 0xe065, mac: 0xffff, code: "BrowserSearch", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0223, evdev: 0x00ac, xkb: 0x00b4, windows: 0xe032, mac: 0xffff, code: "BrowserHome", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0224, evdev: 0x009e, xkb: 0x00a6, windows: 0xe06a, mac: 0xffff, code: "BrowserBack", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0225, evdev: 0x009f, xkb: 0x00a7, windows: 0xe069, mac: 0xffff, code: "BrowserForward", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0226, evdev: 0x0080, xkb: 0x0088, windows: 0xe068, mac: 0xffff, code: "BrowserStop", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0227, evdev: 0x00ad, xkb: 0x00b5, windows: 0xe067, mac: 0xffff, code: "BrowserRefresh", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c022a, evdev: 0x009c, xkb: 0x00a4, windows: 0xe066, mac: 0xffff, code: "BrowserFavorites", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c022d, evdev: 0x01a2, xkb: 0x01aa, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c022e, evdev: 0x01a3, xkb: 0x01ab, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0232, evdev: 0x0174, xkb: 0x017c, windows: 0x0000, mac: 0xffff, code: "ZoomToggle", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0279, evdev: 0x00b6, xkb: 0x00be, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c0289, evdev: 0x00e8, xkb: 0x00f0, windows: 0x0000, mac: 0xffff, code: "MailReply", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c028b, evdev: 0x00e9, xkb: 0x00f1, windows: 0x0000, mac: 0xffff, code: "MailForward", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c028c, evdev: 0x00e7, xkb: 0x00ef, windows: 0x0000, mac: 0xffff, code: "MailSend", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c029d, evdev: 0x0248, xkb: 0x0250, windows: 0x0000, mac: 0xffff, code: "KeyboardLayoutSelect", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c029f, evdev: 0x0078, xkb: 0x0080, windows: 0x0000, mac: 0xffff, code: "ShowAllWindows", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c02a2, evdev: 0x00cc, xkb: 0x00d4, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
	RawKeycodeEntry{usb: 0x0c02d0, evdev: 0x0279, xkb: 0x0281, windows: 0x0000, mac: 0xffff, code: "", key: .unidentified},
 ]

// The same OS-specific native column selected by Ghostty's entries builder.
pub const keycodes_entries = native_keycodes_entries()

fn native_keycodes_entries() []KeycodeFullEntry {
	mut result := []KeycodeFullEntry{cap: raw_keycodes_entries.len}
	for raw in raw_keycodes_entries {
		native := $if windows { raw.windows } $else $if linux || freebsd { raw.xkb } $else $if macos || ios { raw.mac } $else {
			$compile_error('unsupported native keycode platform')
			u32(0)
		}
		result << KeycodeFullEntry{key: raw.key, usb: raw.usb, native: native, code: raw.code}
	}
	return result
}

pub fn native_keycode_to_key(native u32) Key {
	for entry in keycodes_entries {
		if entry.native == native { return entry.key }
	}
	return .unidentified
}

pub fn xkb_keycode_to_key(native u32) Key {
	for raw in raw_keycodes_entries {
		if raw.xkb == native { return raw.key }
	}
	return .unidentified
}

pub fn windows_keycode_to_key(native u32) Key {
	for raw in raw_keycodes_entries {
		if raw.windows == native { return raw.key }
	}
	return .unidentified
}

pub fn mac_keycode_to_key(native u32) Key {
	for raw in raw_keycodes_entries {
		if raw.mac == native { return raw.key }
	}
	return .unidentified
}
