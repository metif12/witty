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
// and corresponding Key for the current platform (macOS).
pub struct KeycodeFullEntry {
pub:
	key    Key    // input key enum
	usb    u32    // USB HID usage code
	native u32    // native keycode (macOS virtual key code)
	code   string // W3C DOM code
}

// keycodes_entries is the full list of keycode entries for macOS.
// Each entry maps a macOS native virtual key code to a Key.
// Entries with native == 0xffff are unmapped on macOS but included
// for completeness (they will never match a real keycode).
//
// The format is derived from the raw_entries table in keycodes.zig.
// For macOS the native column is index 4 (Mac virtual key codes).
pub const keycodes_entries = [
	// USB       evdev  XKB    Win    Mac    Code
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000000 ""
	//
	// =========================================
	// Non-USB codes
	// =========================================
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000010 "Hyper"
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000011 "Super"
	KeycodeEntry{ native: 0xffff, key: .fn_key },       // 0x000012 "Fn"
	KeycodeEntry{ native: 0xffff, key: .fn_lock },      // 0x000013 "FnLock"
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000014 "Suspend"
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000015 "Resume"
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x000016 "Turbo"
	//
	// =========================================
	// USB Usage Page 0x01: Generic Desktop Page
	// =========================================
	KeycodeEntry{ native: 0xffff, key: .sleep },        // 0x010082 "Sleep"
	KeycodeEntry{ native: 0xffff, key: .wake_up },      // 0x010083 "WakeUp"
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x0100a9 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x0100b5 "DisplayToggleIntExt"
	//
	// =========================================
	// USB Usage Page 0x07: Keyboard/Keypad Page
	// =========================================
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x070000 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x070001 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x070002 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified }, // 0x070003 ""
	KeycodeEntry{ native: 0x0000, key: .key_a },        // 0x070004 "KeyA"
	KeycodeEntry{ native: 0x000b, key: .key_b },        // 0x070005 "KeyB"
	KeycodeEntry{ native: 0x0008, key: .key_c },        // 0x070006 "KeyC"
	KeycodeEntry{ native: 0x0002, key: .key_d },        // 0x070007 "KeyD"
	KeycodeEntry{ native: 0x000e, key: .key_e },        // 0x070008 "KeyE"
	KeycodeEntry{ native: 0x0003, key: .key_f },        // 0x070009 "KeyF"
	KeycodeEntry{ native: 0x0005, key: .key_g },        // 0x07000a "KeyG"
	KeycodeEntry{ native: 0x0004, key: .key_h },        // 0x07000b "KeyH"
	KeycodeEntry{ native: 0x0022, key: .key_i },        // 0x07000c "KeyI"
	KeycodeEntry{ native: 0x0026, key: .key_j },        // 0x07000d "KeyJ"
	KeycodeEntry{ native: 0x0028, key: .key_k },        // 0x07000e "KeyK"
	KeycodeEntry{ native: 0x0025, key: .key_l },        // 0x07000f "KeyL"
	KeycodeEntry{ native: 0x002e, key: .key_m },        // 0x070010 "KeyM"
	KeycodeEntry{ native: 0x002d, key: .key_n },        // 0x070011 "KeyN"
	KeycodeEntry{ native: 0x001f, key: .key_o },        // 0x070012 "KeyO"
	KeycodeEntry{ native: 0x0023, key: .key_p },        // 0x070013 "KeyP"
	KeycodeEntry{ native: 0x000c, key: .key_q },        // 0x070014 "KeyQ"
	KeycodeEntry{ native: 0x000f, key: .key_r },        // 0x070015 "KeyR"
	KeycodeEntry{ native: 0x0001, key: .key_s },        // 0x070016 "KeyS"
	KeycodeEntry{ native: 0x0011, key: .key_t },        // 0x070017 "KeyT"
	KeycodeEntry{ native: 0x0020, key: .key_u },        // 0x070018 "KeyU"
	KeycodeEntry{ native: 0x0009, key: .key_v },        // 0x070019 "KeyV"
	KeycodeEntry{ native: 0x000d, key: .key_w },        // 0x07001a "KeyW"
	KeycodeEntry{ native: 0x0007, key: .key_x },        // 0x07001b "KeyX"
	KeycodeEntry{ native: 0x0010, key: .key_y },        // 0x07001c "KeyY"
	KeycodeEntry{ native: 0x0006, key: .key_z },        // 0x07001d "KeyZ"
	KeycodeEntry{ native: 0x0012, key: .digit_1 },      // 0x07001e "Digit1"
	KeycodeEntry{ native: 0x0013, key: .digit_2 },      // 0x07001f "Digit2"
	KeycodeEntry{ native: 0x0014, key: .digit_3 },      // 0x070020 "Digit3"
	KeycodeEntry{ native: 0x0015, key: .digit_4 },      // 0x070021 "Digit4"
	KeycodeEntry{ native: 0x0017, key: .digit_5 },      // 0x070022 "Digit5"
	KeycodeEntry{ native: 0x0016, key: .digit_6 },      // 0x070023 "Digit6"
	KeycodeEntry{ native: 0x001a, key: .digit_7 },      // 0x070024 "Digit7"
	KeycodeEntry{ native: 0x001c, key: .digit_8 },      // 0x070025 "Digit8"
	KeycodeEntry{ native: 0x0019, key: .digit_9 },      // 0x070026 "Digit9"
	KeycodeEntry{ native: 0x001d, key: .digit_0 },      // 0x070027 "Digit0"
	KeycodeEntry{ native: 0x0024, key: .enter },         // 0x070028 "Enter"
	KeycodeEntry{ native: 0x0035, key: .escape },        // 0x070029 "Escape"
	KeycodeEntry{ native: 0x0033, key: .backspace },     // 0x07002a "Backspace"
	KeycodeEntry{ native: 0x0030, key: .tab },           // 0x07002b "Tab"
	KeycodeEntry{ native: 0x0031, key: .space },         // 0x07002c "Space"
	KeycodeEntry{ native: 0x001b, key: .minus },         // 0x07002d "Minus"
	KeycodeEntry{ native: 0x0018, key: .equal },         // 0x07002e "Equal"
	KeycodeEntry{ native: 0x0021, key: .bracket_left },  // 0x07002f "BracketLeft"
	KeycodeEntry{ native: 0x001e, key: .bracket_right }, // 0x070030 "BracketRight"
	KeycodeEntry{ native: 0x002a, key: .backslash },     // 0x070031 "Backslash"
	KeycodeEntry{ native: 0x0029, key: .semicolon },     // 0x070033 "Semicolon"
	KeycodeEntry{ native: 0x0027, key: .quote },         // 0x070034 "Quote"
	KeycodeEntry{ native: 0x0032, key: .backquote },     // 0x070035 "Backquote"
	KeycodeEntry{ native: 0x002b, key: .comma },         // 0x070036 "Comma"
	KeycodeEntry{ native: 0x002f, key: .period },        // 0x070037 "Period"
	KeycodeEntry{ native: 0x002c, key: .slash },         // 0x070038 "Slash"
	KeycodeEntry{ native: 0x0039, key: .caps_lock },     // 0x070039 "CapsLock"
	KeycodeEntry{ native: 0x007a, key: .f1 },            // 0x07003a "F1"
	KeycodeEntry{ native: 0x0078, key: .f2 },            // 0x07003b "F2"
	KeycodeEntry{ native: 0x0063, key: .f3 },            // 0x07003c "F3"
	KeycodeEntry{ native: 0x0076, key: .f4 },            // 0x07003d "F4"
	KeycodeEntry{ native: 0x0060, key: .f5 },            // 0x07003e "F5"
	KeycodeEntry{ native: 0x0061, key: .f6 },            // 0x07003f "F6"
	KeycodeEntry{ native: 0x0062, key: .f7 },            // 0x070040 "F7"
	KeycodeEntry{ native: 0x0064, key: .f8 },            // 0x070041 "F8"
	KeycodeEntry{ native: 0x0065, key: .f9 },            // 0x070042 "F9"
	KeycodeEntry{ native: 0x006d, key: .f10 },           // 0x070043 "F10"
	KeycodeEntry{ native: 0x0067, key: .f11 },           // 0x070044 "F11"
	KeycodeEntry{ native: 0x006f, key: .f12 },           // 0x070045 "F12"
	KeycodeEntry{ native: 0xffff, key: .print_screen },  // 0x070046 "PrintScreen"
	KeycodeEntry{ native: 0xffff, key: .scroll_lock },   // 0x070047 "ScrollLock"
	KeycodeEntry{ native: 0xffff, key: .pause },         // 0x070048 "Pause"
	KeycodeEntry{ native: 0x0072, key: .insert },        // 0x070049 "Insert"
	KeycodeEntry{ native: 0x0073, key: .home },          // 0x07004a "Home"
	KeycodeEntry{ native: 0x0074, key: .page_up },       // 0x07004b "PageUp"
	KeycodeEntry{ native: 0x0075, key: .delete },        // 0x07004c "Delete"
	KeycodeEntry{ native: 0x0077, key: .end },           // 0x07004d "End"
	KeycodeEntry{ native: 0x0079, key: .page_down },     // 0x07004e "PageDown"
	KeycodeEntry{ native: 0x007c, key: .arrow_right },   // 0x07004f "ArrowRight"
	KeycodeEntry{ native: 0x007b, key: .arrow_left },    // 0x070050 "ArrowLeft"
	KeycodeEntry{ native: 0x007d, key: .arrow_down },    // 0x070051 "ArrowDown"
	KeycodeEntry{ native: 0x007e, key: .arrow_up },      // 0x070052 "ArrowUp"
	KeycodeEntry{ native: 0x0047, key: .num_lock },      // 0x070053 "NumLock"
	KeycodeEntry{ native: 0x004b, key: .numpad_divide }, // 0x070054 "NumpadDivide"
	KeycodeEntry{ native: 0x0043, key: .numpad_multiply }, // 0x070055 "NumpadMultiply"
	KeycodeEntry{ native: 0x004e, key: .numpad_subtract }, // 0x070056 "NumpadSubtract"
	KeycodeEntry{ native: 0x0045, key: .numpad_add },     // 0x070057 "NumpadAdd"
	KeycodeEntry{ native: 0x004c, key: .numpad_enter },   // 0x070058 "NumpadEnter"
	KeycodeEntry{ native: 0x0053, key: .numpad_1 },       // 0x070059 "Numpad1"
	KeycodeEntry{ native: 0x0054, key: .numpad_2 },       // 0x07005a "Numpad2"
	KeycodeEntry{ native: 0x0055, key: .numpad_3 },       // 0x07005b "Numpad3"
	KeycodeEntry{ native: 0x0056, key: .numpad_4 },       // 0x07005c "Numpad4"
	KeycodeEntry{ native: 0x0057, key: .numpad_5 },       // 0x07005d "Numpad5"
	KeycodeEntry{ native: 0x0058, key: .numpad_6 },       // 0x07005e "Numpad6"
	KeycodeEntry{ native: 0x0059, key: .numpad_7 },       // 0x07005f "Numpad7"
	KeycodeEntry{ native: 0x005b, key: .numpad_8 },       // 0x070060 "Numpad8"
	KeycodeEntry{ native: 0x005c, key: .numpad_9 },       // 0x070061 "Numpad9"
	KeycodeEntry{ native: 0x0052, key: .numpad_0 },       // 0x070062 "Numpad0"
	KeycodeEntry{ native: 0x0041, key: .numpad_decimal },  // 0x070063 "NumpadDecimal"
	KeycodeEntry{ native: 0x000a, key: .intl_backslash },  // 0x070064 "IntlBackslash"
	KeycodeEntry{ native: 0x006e, key: .context_menu },    // 0x070065 "ContextMenu"
	KeycodeEntry{ native: 0xffff, key: .power },           // 0x070066 "Power"
	KeycodeEntry{ native: 0x0051, key: .numpad_equal },    // 0x070067 "NumpadEqual"
	KeycodeEntry{ native: 0x0069, key: .f13 },             // 0x070068 "F13"
	KeycodeEntry{ native: 0x006b, key: .f14 },             // 0x070069 "F14"
	KeycodeEntry{ native: 0x0071, key: .f15 },             // 0x07006a "F15"
	KeycodeEntry{ native: 0x006a, key: .f16 },             // 0x07006b "F16"
	KeycodeEntry{ native: 0x0040, key: .f17 },             // 0x07006c "F17"
	KeycodeEntry{ native: 0x004f, key: .f18 },             // 0x07006d "F18"
	KeycodeEntry{ native: 0x0050, key: .f19 },             // 0x07006e "F19"
	KeycodeEntry{ native: 0x005a, key: .f20 },             // 0x07006f "F20"
	KeycodeEntry{ native: 0xffff, key: .f21 },             // 0x070070 "F21"
	KeycodeEntry{ native: 0xffff, key: .f22 },             // 0x070071 "F22"
	KeycodeEntry{ native: 0xffff, key: .f23 },             // 0x070072 "F23"
	KeycodeEntry{ native: 0xffff, key: .f24 },             // 0x070073 "F24"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x070074 "Open"
	KeycodeEntry{ native: 0xffff, key: .help },            // 0x070075 "Help"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x070077 "Select"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x070079 "Again"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x07007a "Undo"
	KeycodeEntry{ native: 0xffff, key: .cut },             // 0x07007b "Cut"
	KeycodeEntry{ native: 0xffff, key: .copy },            // 0x07007c "Copy"
	KeycodeEntry{ native: 0xffff, key: .paste },           // 0x07007d "Paste"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x07007e "Find"
	KeycodeEntry{ native: 0x004a, key: .audio_volume_mute }, // 0x07007f "AudioVolumeMute"
	KeycodeEntry{ native: 0x0048, key: .audio_volume_up },   // 0x070080 "AudioVolumeUp"
	KeycodeEntry{ native: 0x0049, key: .audio_volume_down }, // 0x070081 "AudioVolumeDown"
	KeycodeEntry{ native: 0x005f, key: .numpad_comma },      // 0x070085 "NumpadComma"
	KeycodeEntry{ native: 0x005e, key: .intl_ro },           // 0x070087 "IntlRo"
	KeycodeEntry{ native: 0xffff, key: .kana_mode },         // 0x070088 "KanaMode"
	KeycodeEntry{ native: 0x005d, key: .intl_yen },          // 0x070089 "IntlYen"
	KeycodeEntry{ native: 0xffff, key: .convert },           // 0x07008a "Convert"
	KeycodeEntry{ native: 0xffff, key: .non_convert },       // 0x07008b "NonConvert"
	KeycodeEntry{ native: 0x0068, key: .unidentified },      // 0x070090 "Lang1"
	KeycodeEntry{ native: 0x0066, key: .unidentified },      // 0x070091 "Lang2"
	KeycodeEntry{ native: 0xffff, key: .unidentified },      // 0x070092 "Lang3"
	KeycodeEntry{ native: 0xffff, key: .unidentified },      // 0x070093 "Lang4"
	KeycodeEntry{ native: 0xffff, key: .unidentified },      // 0x070094 "Lang5"
	KeycodeEntry{ native: 0xffff, key: .unidentified },      // 0x07009b "Abort"
	KeycodeEntry{ native: 0xffff, key: .unidentified },      // 0x0700a3 "Props"
	KeycodeEntry{ native: 0xffff, key: .numpad_paren_left }, // 0x0700b6 "NumpadParenLeft"
	KeycodeEntry{ native: 0xffff, key: .numpad_paren_right }, // 0x0700b7 "NumpadParenRight"
	KeycodeEntry{ native: 0xffff, key: .numpad_backspace },   // 0x0700bb "NumpadBackspace"
	KeycodeEntry{ native: 0xffff, key: .numpad_memory_store },    // 0x0700d0 "NumpadMemoryStore"
	KeycodeEntry{ native: 0xffff, key: .numpad_memory_recall },   // 0x0700d1 "NumpadMemoryRecall"
	KeycodeEntry{ native: 0xffff, key: .numpad_memory_clear },    // 0x0700d2 "NumpadMemoryClear"
	KeycodeEntry{ native: 0xffff, key: .numpad_memory_add },      // 0x0700d3 "NumpadMemoryAdd"
	KeycodeEntry{ native: 0xffff, key: .numpad_memory_subtract }, // 0x0700d4 "NumpadMemorySubtract"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0700d7 ""
	KeycodeEntry{ native: 0xffff, key: .numpad_clear },    // 0x0700d8 "NumpadClear"
	KeycodeEntry{ native: 0xffff, key: .numpad_clear_entry }, // 0x0700d9 "NumpadClearEntry"
	KeycodeEntry{ native: 0x003b, key: .control_left },    // 0x0700e0 "ControlLeft"
	KeycodeEntry{ native: 0x0038, key: .shift_left },      // 0x0700e1 "ShiftLeft"
	KeycodeEntry{ native: 0x003a, key: .alt_left },        // 0x0700e2 "AltLeft"
	KeycodeEntry{ native: 0x0037, key: .meta_left },       // 0x0700e3 "MetaLeft"
	KeycodeEntry{ native: 0x003e, key: .control_right },   // 0x0700e4 "ControlRight"
	KeycodeEntry{ native: 0x003c, key: .shift_right },     // 0x0700e5 "ShiftRight"
	KeycodeEntry{ native: 0x003d, key: .alt_right },       // 0x0700e6 "AltRight"
	KeycodeEntry{ native: 0x0036, key: .meta_right },      // 0x0700e7 "MetaRight"
	//
	// ==================================
	// USB Usage Page 0x0c: Consumer Page
	// ==================================
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0060 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0061 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c006f "BrightnessUp"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0070 "BrightnessDown"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0072 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0073 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0074 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0075 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0079 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c007a ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c007c ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0083 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c008c ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c008d ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0094 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c009c ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c009d ""
	KeycodeEntry{ native: 0xffff, key: .media_play_pause }, // 0x0c00b0 "MediaPlay"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00b1 "MediaPause"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00b2 "MediaRecord"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00b3 "MediaFastForward"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00b4 "MediaRewind"
	KeycodeEntry{ native: 0xffff, key: .media_track_next },     // 0x0c00b5 "MediaTrackNext"
	KeycodeEntry{ native: 0xffff, key: .media_track_previous }, // 0x0c00b6 "MediaTrackPrevious"
	KeycodeEntry{ native: 0xffff, key: .media_stop },      // 0x0c00b7 "MediaStop"
	KeycodeEntry{ native: 0xffff, key: .eject },           // 0x0c00b8 "Eject"
	KeycodeEntry{ native: 0xffff, key: .media_play_pause }, // 0x0c00cd "MediaPlayPause"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00cf ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00d8 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00d9 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c00e5 ""
	KeycodeEntry{ native: 0xffff, key: .media_select },    // 0x0c0183 "MediaSelect"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0184 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0186 ""
	KeycodeEntry{ native: 0xffff, key: .launch_mail },     // 0x0c018a "LaunchMail"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c018d ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c018e ""
	KeycodeEntry{ native: 0xffff, key: .launch_app_2 },    // 0x0c0192 "LaunchApp2"
	KeycodeEntry{ native: 0xffff, key: .launch_app_1 },    // 0x0c0194 "LaunchApp1"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0196 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c019C ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c019e ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c019f "LaunchControlPanel"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01a2 "SelectTask"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01a7 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01ab ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01ae ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01b1 "LaunchScreenSaver"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01cb "LaunchAssistant"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c01b7 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0201 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0203 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0207 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0208 ""
	KeycodeEntry{ native: 0xffff, key: .browser_search },    // 0x0c0221 "BrowserSearch"
	KeycodeEntry{ native: 0xffff, key: .browser_home },      // 0x0c0223 "BrowserHome"
	KeycodeEntry{ native: 0xffff, key: .browser_back },      // 0x0c0224 "BrowserBack"
	KeycodeEntry{ native: 0xffff, key: .browser_forward },   // 0x0c0225 "BrowserForward"
	KeycodeEntry{ native: 0xffff, key: .browser_stop },      // 0x0c0226 "BrowserStop"
	KeycodeEntry{ native: 0xffff, key: .browser_refresh },   // 0x0c0227 "BrowserRefresh"
	KeycodeEntry{ native: 0xffff, key: .browser_favorites }, // 0x0c022a "BrowserFavorites"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c022d ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c022e ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0232 "ZoomToggle"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0279 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c0289 "MailReply"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c028b "MailForward"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c028c "MailSend"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c029d "KeyboardLayoutSelect"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c029f "ShowAllWindows"
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c02a2 ""
	KeycodeEntry{ native: 0xffff, key: .unidentified },    // 0x0c02d0 ""
]

// mac_keycode_to_key maps a macOS virtual key code to a Key enum value.
// Returns .unidentified if the keycode is not recognized.
// Mac virtual key codes range from 0x00 to 0x7e, so a linear scan
// of the keycodes_entries table is used (same approach as apprt).
pub fn mac_keycode_to_key(native u32) Key {
	for entry in keycodes_entries {
		if entry.native == native {
			return entry.key
		}
	}
	return .unidentified
}
