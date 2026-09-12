module input

// Key encoding for terminal input. Translates key events into the proper
// escape sequences based on terminal mode state (legacy, xterm modifyOtherKeys,
// fixterms, and Kitty keyboard protocol).

// KittyFlags represents the Kitty keyboard protocol flags.
// These flags control what information is reported in key events.
pub struct KittyFlags {
pub mut:
	disambiguate      bool
	report_events     bool
	report_alternates bool
	report_all        bool
	report_associated bool
}

// int returns the raw integer value of the flags bitmask.
pub fn (f KittyFlags) int() u8 {
	mut v := u8(0)
	if f.disambiguate {
		v |= 1
	}
	if f.report_events {
		v |= 2
	}
	if f.report_alternates {
		v |= 4
	}
	if f.report_all {
		v |= 8
	}
	if f.report_associated {
		v |= 16
	}
	return v
}

// Options that affect key encoding behavior. This is a mix of behavior
// from terminal state as well as application configuration.
pub struct Options {
pub mut:
	// Terminal DEC mode 1
	cursor_key_application bool
	// Terminal DEC mode 66
	keypad_key_application bool
	// Terminal DEC mode 1035
	ignore_keypad_with_numlock bool
	// Terminal DEC mode 1036
	alt_esc_prefix bool
	// xterm "modifyOtherKeys mode 2". Details here:
	// https://invisible-island.net/xterm/modified-keys.html
	modify_other_keys_state_2 bool
	// Kitty keyboard protocol flags.
	kitty_flags KittyFlags
	// Determines whether the "option" key on macOS is treated
	// as "alt" or not. See the Ghostty `macos_option-as-alt` config
	// docs for a more detailed description of why this is needed.
	macos_option_as_alt OptionAsAlt = .false_
}

// encode encodes the key event in the proper format given the options.
// For example, this will properly encode a key press such as "ctrl+A"
// to Kitty format if Kitty encoding is enabled.
//
// Not all key events will result in output. Returns an empty string
// if no output should be sent.
pub fn encode(event KeyEvent, opts Options) string {
	if opts.kitty_flags.int() != 0 {
		return kitty_encode(event, opts)
	}
	return legacy_encode(event, opts)
}

// kitty_encode performs Kitty keyboard protocol encoding of the key event.
fn kitty_encode(event KeyEvent, opts Options) string {
	// This should never happen but we'll check anyway.
	if opts.kitty_flags.int() == 0 {
		return legacy_encode(event, opts)
	}

	// We only process "press" events unless report events is active
	if event.action == .release {
		if !opts.kitty_flags.report_events {
			return ''
		}
		// Enter, backspace, and tab do not report release events unless "report
		// all" is set
		if !opts.kitty_flags.report_all {
			match event.key {
				.enter, .backspace, .tab {
					return ''
				}
				else {}
			}
		}
	}

	all_mods := event.mods
	effective_mods := event.effective_mods()
	binding_mods := effective_mods.binding()

	// Find the entry for this key in the kitty table.
	mut entry_ := ?KittyEntry(none)

	// Functional or predefined keys
	for e in kitty_entries {
		if e.key == event.key {
			entry_ = e
			break
		}
	}

	// Otherwise, we use our unicode codepoint from UTF8. We
	// always use the unshifted value.
	if entry_ == none && event.unshifted_codepoint > 0 {
		entry_ = KittyEntry{
			key: event.key
			code: event.unshifted_codepoint
			final_byte: `u`
			modifier: false
		}
	}

	// Preprocessing
	mut skip_preprocessing := false

	// When composing, the only keys sent are plain modifiers.
	if event.composing {
		if e := entry_ {
			if e.modifier {
				skip_preprocessing = true
			}
		}
		if !skip_preprocessing {
			return ''
		}
	}

	if !skip_preprocessing {
		// IME confirmation still sends an enter key so if we have enter
		// and UTF8 text we just send it directly since we assume that is
		// what's happening.
		if event.utf8.len > 0 {
			match event.key {
				.enter {
					if !is_control_utf8(event.utf8) {
						return event.utf8
					}
				}
				.backspace {
					if !is_control_utf8(event.utf8) {
						return ''
					}
				}
				else {}
			}
		}

		// If we're reporting all then we always send CSI sequences.
		if !opts.kitty_flags.report_all {
			// The only exceptions are Enter, Tab, Backspace which still generate
			// the same bytes as in legacy mode
			if binding_mods.empty() {
				match event.key {
					.enter {
						return '\r'
					}
					.tab {
						return '\t'
					}
					.backspace {
						return '\x7f'
					}
					else {}
				}
			}

			// Send plain-text non-modified text directly to the terminal.
			// We don't send release events because those are specially encoded.
			if event.utf8.len > 0 && binding_mods.empty() && event.action != .release {
				// We only do this for printable characters.
				mut all_printable := true
				runes := event.utf8.runes()
				for r in runes {
					if is_control(u32(r)) {
						all_printable = false
						break
					}
				}
				if all_printable && runes.len > 0 {
					return event.utf8
				}
			}
		}
	}

	entry := entry_ or { return '' }

	// If this is just a modifier we require "report all" to send the sequence.
	if entry.modifier && !opts.kitty_flags.report_all {
		return ''
	}

	// Build the KittySequence
	mut seq := KittySequence{
		key_code: entry.code
		final_byte: entry.final_byte
		mods: KittyMods.from_input(event.action, event.key, all_mods)
	}

	if opts.kitty_flags.report_events {
		seq.event = match event.action {
			.press { .press }
			.release { .release }
			.repeat { .repeat }
		}
	}

	if opts.kitty_flags.report_alternates {
		// Break early if this is a control key
		if !is_control(seq.key_code) {
			runes := event.utf8.runes()
			if runes.len > 0 {
				cp1 := u32(runes[0])
				has_cp2 := runes.len > 1

				// Set the first alternate (shifted version)
				if cp1 != seq.key_code && seq.mods.shift {
					seq.alternates[0] = cp1
				}

				// Set the base layout key
				if base := event.key.codepoint() {
					if base != seq.key_code && (cp1 != base && !has_cp2) {
						seq.alternates[1] = base
					}
				}
			} else {
				// No UTF-8 so we can't report a shifted key but we can still
				// report a base layout key.
				if base := event.key.codepoint() {
					if base != seq.key_code {
						seq.alternates[1] = base
					}
				}
			}
		}
	}

	if opts.kitty_flags.report_associated && seq.event != .release {
		// Determine if the Alt modifier should be treated as an actual
		// modifier (in which case it prevents associated text) or as
		// the macOS Option key, which does not prevent associated text.
		mut alt_prevents_text := true
		$if macos {
			alt_prevents_text = match opts.macos_option_as_alt {
				.left { all_mods.sides.alt == .left }
				.right { all_mods.sides.alt == .right }
				.true_ { true }
				.false_ { false }
			}
		}

		if !seq.mods.prevents_text(alt_prevents_text) {
			seq.text = event.utf8
		}
	}

	return seq.encode_seq()
}

// legacy_encode performs legacy encoding of the key event. "Legacy" in this case
// is referring to the behavior of traditional terminals, plus
// xterm's `modifyOtherKeys`, plus Paul Evans's "fixterms" spec.
// These together combine the legacy protocol because they're all
// meant to be extensions that do not change any existing behavior
// and therefore safe to combine.
fn legacy_encode(event KeyEvent, opts Options) string {
	all_mods := event.mods
	effective_mods := event.effective_mods()
	binding_mods := effective_mods.binding()

	// Legacy encoding only does press/repeat
	if event.action != .press && event.action != .repeat {
		return ''
	}

	// If we're in a dead key state then we never emit a sequence.
	if event.composing {
		return ''
	}

	// If we match a PC style function key then that is our result.
	if sequence := pc_style_function_key(event.key, all_mods, opts.cursor_key_application, opts.keypad_key_application, opts.ignore_keypad_with_numlock, opts.modify_other_keys_state_2) {
		// If we have UTF-8 text, then we never emit PC style function
		// keys. Many function keys (escape, enter, backspace) have
		// a specific meaning when dead keys are active.
		if event.utf8.len > 0 {
			match event.key {
				.backspace {
					if !is_control_utf8(event.utf8) {
						return ''
					}
				}
				.enter, .escape {
					if !is_control_utf8(event.utf8) {
						// don't use pc_style; fall through to text encoding
					} else {
						return sequence
					}
				}
				else {
					return sequence
				}
			}
			// For enter/escape with non-control UTF8, fall through
			if event.key != .enter && event.key != .escape {
				return sequence
			}
		} else {
			return sequence
		}
	}

	// If we match a control sequence, we output that directly.
	if ch := ctrl_seq(event.key, event.utf8, event.unshifted_codepoint, all_mods) {
		// C0 sequences support alt-as-esc prefixing.
		if binding_mods.alt {
			return '\x1b' + [ch].bytestr()
		}
		return [ch].bytestr()
	}

	// If we have no UTF8 text then the only possibility is the
	// alt-prefix handling of unshifted codepoints.
	utf8 := event.utf8
	if utf8.len == 0 {
		if b := legacy_alt_prefix(event, binding_mods, all_mods, opts) {
			return '\x1b' + [b].bytestr()
		}
		return ''
	}

	// In modify other keys state 2, we send the CSI 27 sequence
	// for any char with a modifier.
	if opts.modify_other_keys_state_2 {
		runes := utf8.runes()
		if runes.len == 1 {
			codepoint := u32(runes[0])

			// The mods we encode for this are just the binding mods
			mut mods_binding := event.mods.binding()
			$if macos {
				match opts.macos_option_as_alt {
					.false_ {}
					.true_ {
						// alt stays as-is
					}
					.left {
						if event.mods.sides.alt == .left {
							// alt stays as-is
						} else {
							mods_binding.alt = false
						}
					}
					.right {
						if event.mods.sides.alt == .right {
							// alt stays as-is
						} else {
							mods_binding.alt = false
						}
					}
				}
			}

			// This copies xterm's `ModifyOtherKeys` function
			mut should_modify := false

			// xterm IsControlInput
			if codepoint >= 0x40 && codepoint <= 0x7F {
				should_modify = true
			}

			if !should_modify {
				// If we have anything other than shift pressed, encode.
				mut mods_no_shift := mods_binding
				mods_no_shift.shift = false
				if !mods_no_shift.empty() {
					should_modify = true
				}
			}

			if !should_modify {
				// We only have shift pressed. We only allow space.
				if codepoint == u32(` `) {
					should_modify = true
				}
			}

			if should_modify {
				for i, modset in fk_modifiers {
					if mods_binding.equal(modset) {
						code := i + 2
						return '\x1b[27;${code};${codepoint}~'
					}
				}
			}
		}
	}

	// Let's see if we should apply fixterms to this codepoint.
	// At this stage of key processing, we only need to apply fixterms
	// to unicode codepoints if we have ctrl set.
	if event.mods.ctrl {
		// Important: we want to use the original mods here, not the
		// effective mods.
		runes := event.utf8.runes()
		if runes.len == 1 {
			mut csi_u_mods := CsiUMods.from_input(event.mods)
			mut ch := u32(runes[0])

			// If our character is A to Z and we have shift set, then
			// we lowercase it. This is a Kitty-specific behavior that
			// we choose to follow and diverge from the fixterms spec.
			if ch >= u32(`A`) && ch <= u32(`Z`) && csi_u_mods.shift {
				ch = ch + 32 // toLower
			}

			// If our unshifted codepoint is identical to the shifted
			// then we consider shift. Otherwise, we do not because the
			// shift key was used to obtain the character.
			if event.unshifted_codepoint != ch {
				csi_u_mods.shift = false
			}

			return '\x1b[${ch};${csi_u_mods.seq_int()}u'
		}
	}

	// If we have alt-pressed and alt-esc-prefix is enabled, then
	// we need to prefix the utf8 sequence with an esc.
	if b := legacy_alt_prefix(event, binding_mods, all_mods, opts) {
		return '\x1b' + [b].bytestr()
	}

	// If we are on macOS, command+keys do not encode text.
	$if macos {
		if all_mods.super_ {
			return ''
		}
	}

	return utf8
}

// legacy_alt_prefix returns the byte to alt-prefix, or none if no
// alt prefix should be applied.
fn legacy_alt_prefix(event KeyEvent, binding_mods Mods, mods Mods, opts Options) ?u8 {
	// This only takes effect with alt pressed
	if !binding_mods.alt || !opts.alt_esc_prefix {
		return none
	}

	// On macOS, we only handle option like alt in certain circumstances.
	$if macos {
		match opts.macos_option_as_alt {
			.false_ {
				return none
			}
			.left {
				if mods.sides.alt == .right {
					return none
				}
			}
			.right {
				if mods.sides.alt == .left {
					return none
				}
			}
			.true_ {}
		}
	}

	// Otherwise, we require utf8 to already have the byte represented.
	utf8 := event.utf8
	if utf8.len == 1 {
		return utf8[0]
	}

	// If UTF8 isn't set, we will allow unshifted codepoints through.
	if event.unshifted_codepoint > 0 && event.unshifted_codepoint < 256 {
		return u8(event.unshifted_codepoint)
	}

	// Else, we can't figure out the byte to alt-prefix.
	return none
}

// pc_style_function_key determines whether the key should be encoded in the xterm
// "PC-style Function Key" syntax (roughly). This is a hardcoded
// table of keys and modifiers that result in a specific sequence.
fn pc_style_function_key(keyval Key, mods Mods, cursor_key_application bool, keypad_key_application_req bool, ignore_keypad_with_numlock bool, modify_other_keys bool) ?string {
	// We only want binding-sensitive mods because lock keys
	// and directional modifiers (left/right) don't matter for
	// pc-style function keys.
	mods_int := mods.binding().int()

	// Keypad application keymode handling.
	// If mode 1035 is on, we always are in numerical keypad mode.
	keypad_key_application := if ignore_keypad_with_numlock {
		false
	} else {
		keypad_key_application_req
	}

	entries := get_function_key_entries(keyval)
	if entries.len == 0 {
		return none
	}

	for entry in entries {
		// Check cursor mode
		match entry.cursor {
			.any {}
			.normal {
				if cursor_key_application {
					continue
				}
			}
			.application {
				if !cursor_key_application {
					continue
				}
			}
		}

		// Check keypad mode
		match entry.keypad {
			.any {}
			.normal {
				if keypad_key_application {
					continue
				}
			}
			.application {
				if !keypad_key_application {
					continue
				}
			}
		}

		// Check modify_other_keys
		match entry.modify_other_keys {
			.any {}
			.set {
				if modify_other_keys {
					continue
				}
			}
			.set_other {
				if !modify_other_keys {
					continue
				}
			}
		}

		// Check mods
		entry_mods_int := entry.mods.int()
		if entry_mods_int == 0 {
			if mods_int != 0 && !entry.mods_empty_is_any {
				continue
			}
			// mods are either empty, or empty means any so we allow it.
		} else if entry_mods_int != mods_int {
			// any set mods require an exact match
			continue
		}

		return entry.sequence
	}

	return none
}

// ctrl_seq returns the C0 byte for the key event if it should be used.
// This converts a key event into the expected terminal behavior
// such as Ctrl+C turning into 0x03, amongst many other translations.
//
// This will return none if the key event should not be converted
// into a C0 byte.
fn ctrl_seq(logical_key Key, utf8 string, unshifted_codepoint u32, mods Mods) ?u8 {
	// If ctrl is not pressed then we never do anything.
	if !mods.ctrl {
		return none
	}

	// We need to only get binding modifiers so we strip lock
	// keys, sides, etc.
	mut unset_mods := mods.binding()

	// Remove alt from our modifiers because it does not impact whether
	// we are generating a ctrl sequence and we handle the ESC-prefix
	// logic separately.
	unset_mods.alt = false

	mut ch := u8(0)
	mut got_char := false

	// If we have exactly one UTF8 byte, we assume that is the
	// character we want to convert to a C0 byte.
	if utf8.len == 1 {
		ch = utf8[0]
		got_char = true
	}

	if !got_char {
		// If we have a logical key that maps to a single byte
		// printable character, we use that.
		if cp := logical_key.codepoint() {
			if cp < 256 {
				// For this specific case, we only map to the key if
				// we have exactly ctrl pressed.
				ctrl_only := Mods{ ctrl: true }
				if unset_mods.int() != ctrl_only.int() {
					return none
				}
				ch = u8(cp)
				got_char = true
			}
		}
	}

	if !got_char {
		return none
	}

	// Remove shift if we have something outside of the US letter
	// range. This is so that characters such as `ctrl+shift+-`
	// generate the correct ctrl-seq (used by emacs).
	if unset_mods.shift && (ch < u8(`A`) || ch > u8(`Z`)) {
		// Special case for fixterms awkward case as specified.
		if ch != u8(`@`) {
			unset_mods.shift = false
		}
	}

	// If the character is uppercase, we convert it to lowercase.
	// We rely on the unshifted codepoint to do this.
	if ch >= u8(`A`) && ch <= u8(`Z`) && unshifted_codepoint > 0 {
		if unshifted_codepoint < 256 {
			ch = u8(unshifted_codepoint)
		}
	}

	// After unsetting, we only continue if we have ONLY control set.
	ctrl_only := Mods{ ctrl: true }
	if unset_mods.int() != ctrl_only.int() {
		return none
	}

	// If the character is already a control character (C0), and we have
	// only control pressed, we generally want to pass it through, UNLESS
	// it is one of the keys that fixterms specifies should be CSI u encoded
	// (Tab/Ctrl+i, Enter/Ctrl+m, Escape/Ctrl+[).
	if is_control(u32(ch)) {
		match ch {
			9, 13, 27 {
				// Fall through to allow CSI u encoding or other handling
			}
			else {
				return ch
			}
		}
	}

	// From Kitty's key encoding logic.
	return match ch {
		` ` { u8(0) }
		`/` { u8(31) }
		`0` { u8(48) }
		`1` { u8(49) }
		`2` { u8(0) }
		`3` { u8(27) }
		`4` { u8(28) }
		`5` { u8(29) }
		`6` { u8(30) }
		`7` { u8(31) }
		`8` { u8(127) }
		`9` { u8(57) }
		`?` { u8(127) }
		`@` { u8(0) }
		`\\` { u8(28) }
		`]` { u8(29) }
		`^` { u8(30) }
		`_` { u8(31) }
		`a` { u8(1) }
		`b` { u8(2) }
		`c` { u8(3) }
		`d` { u8(4) }
		`e` { u8(5) }
		`f` { u8(6) }
		`g` { u8(7) }
		`h` { u8(8) }
		`j` { u8(10) }
		`k` { u8(11) }
		`l` { u8(12) }
		`n` { u8(14) }
		`o` { u8(15) }
		`p` { u8(16) }
		`q` { u8(17) }
		`r` { u8(18) }
		`s` { u8(19) }
		`t` { u8(20) }
		`u` { u8(21) }
		`v` { u8(22) }
		`w` { u8(23) }
		`x` { u8(24) }
		`y` { u8(25) }
		`z` { u8(26) }
		`~` { u8(30) }
		// These are purposely NOT handled here because of the fixterms
		// specification: https://www.leonerd.org.uk/hacks/fixterms/
		// These are processed as CSI u.
		// 'i' => 0x09,
		// 'm' => 0x0D,
		// '[' => 0x1B,
		else {
			return none
		}
	}
}

// is_control returns true if this is an ASCII control character, matches libc implementation.
fn is_control(cp u32) bool {
	return cp < 0x20 || cp == 0x7F
}

// is_control_utf8 returns true if this string is comprised of a single
// control character. This returns false for multi-byte strings.
fn is_control_utf8(s string) bool {
	return s.len == 1 && is_control(u32(s[0]))
}

// CsiUMods is the bitmask for fixterm CSI u modifiers.
struct CsiUMods {
mut:
	shift bool
	alt   bool
	ctrl  bool
}

// from_input converts input mods to CSI u mods.
fn CsiUMods.from_input(mods Mods) CsiUMods {
	return CsiUMods{
		shift: mods.shift
		alt: mods.alt
		ctrl: mods.ctrl
	}
}

// int returns the raw integer bitmask value.
fn (m CsiUMods) int() u8 {
	mut v := u8(0)
	if m.shift {
		v |= 1
	}
	if m.alt {
		v |= 2
	}
	if m.ctrl {
		v |= 4
	}
	return v
}

// seq_int returns the integer value sent as part of the CSI u sequence.
// This adds 1 to the bitmask value as described in the spec.
fn (m CsiUMods) seq_int() int {
	return int(m.int()) + 1
}

// KittyMods is the bitfields for Kitty modifiers.
struct KittyMods {
mut:
	shift     bool
	alt       bool
	ctrl      bool
	super_    bool
	hyper     bool
	meta      bool
	caps_lock bool
	num_lock  bool
}

// from_input converts input mods to Kitty mods.
fn KittyMods.from_input(action KeyAction, k Key, mods Mods) KittyMods {
	_ = action
	_ = k
	return KittyMods{
		shift: mods.shift
		alt: mods.alt
		ctrl: mods.ctrl
		super_: mods.super_
		caps_lock: mods.caps_lock
		num_lock: mods.num_lock
	}
}

// prevents_text returns true if the modifiers prevent printable text.
//
// The alt_prevents_text parameter determines whether or not the Alt
// modifier prevents printable text. On Linux, this is always true. On
// macOS, this is only true if macos-option-as-alt is set.
fn (m KittyMods) prevents_text(alt_prevents_text bool) bool {
	return (m.alt && alt_prevents_text) || m.ctrl || m.super_ || m.hyper || m.meta
}

// int returns the raw integer bitmask value.
fn (m KittyMods) int() u8 {
	mut v := u8(0)
	if m.shift {
		v |= 1
	}
	if m.alt {
		v |= 2
	}
	if m.ctrl {
		v |= 4
	}
	if m.super_ {
		v |= 8
	}
	if m.hyper {
		v |= 16
	}
	if m.meta {
		v |= 32
	}
	if m.caps_lock {
		v |= 64
	}
	if m.num_lock {
		v |= 128
	}
	return v
}

// seq_int returns the integer value sent as part of the Kitty sequence.
// This adds 1 to the bitmask value as described in the spec.
fn (m KittyMods) seq_int() int {
	return int(m.int()) + 1
}

// KittyEvent represents the event type in a Kitty sequence.
// Values for the event code (see "event-type" in the Kitty spec).
enum KittyEvent as u8 {
	none_   = 0
	press   = 1
	repeat  = 2
	release = 3
}

// KittySequence represents a kitty key sequence and has helpers for encoding it.
// The sequence from the Kitty specification:
//
// CSI unicode-key-code:alternate-key-codes ; modifiers:event-type ; text-as-codepoints u
struct KittySequence {
mut:
	key_code   u32
	final_byte u8
	mods       KittyMods
	event      KittyEvent = .none_
	alternates [2]u32 // 0 = no alternate set
	text       string
}

// encode_seq encodes the KittySequence into a terminal escape sequence string.
fn (s KittySequence) encode_seq() string {
	if s.final_byte == `u` || s.final_byte == `~` {
		return s.encode_full()
	}
	return s.encode_special()
}

// encode_full encodes a full CSI u/~ sequence.
fn (s KittySequence) encode_full() string {
	mut result := '\x1b[${s.key_code}'

	// Write our alternates
	if s.alternates[0] != 0 {
		result += ':${s.alternates[0]}'
	}
	if s.alternates[1] != 0 {
		if s.alternates[0] == 0 {
			result += '::${s.alternates[1]}'
		} else {
			result += ':${s.alternates[1]}'
		}
	}

	// Mods and events section
	mods := s.mods.seq_int()
	mut emit_prior := false
	if s.event != .none_ && s.event != .press {
		result += ';${mods}:${int(s.event)}'
		emit_prior = true
	} else if mods > 1 {
		result += ';${mods}'
		emit_prior = true
	}

	// Text section
	if s.text.len > 0 {
		runes := s.text.runes()
		mut count := 0
		for r in runes {
			cp := u32(r)
			// If the codepoint is non-printable ASCII character, skip.
			if is_control(cp) {
				continue
			}

			// We need to add our ";". We need to add two if we didn't emit
			// the modifier section. We only do this initially.
			if count == 0 {
				if !emit_prior {
					result += ';'
				}
				result += ';'
			} else {
				result += ':'
			}

			result += '${cp}'
			count += 1
		}
	}

	result += [s.final_byte].bytestr()
	return result
}

// encode_special encodes a special key sequence (arrow keys, function keys, etc).
fn (s KittySequence) encode_special() string {
	mods := s.mods.seq_int()
	final_ch := [s.final_byte].bytestr()

	if s.event != .none_ {
		return '\x1b[1;${mods}:${int(s.event)}${final_ch}'
	}

	if mods > 1 {
		return '\x1b[1;${mods}${final_ch}'
	}

	return '\x1b[${final_ch}'
}
