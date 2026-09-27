// Translated from Ghostty's config/Config.zig FontStyle declaration.
module fontstyle

// Kind preserves the declaration-order tag of the FontStyle union.
pub enum Kind as u8 {
	default_
	false_
	name
}

pub struct FontStyleDefault {}

pub struct FontStyleFalse {}

pub struct FontStyleName {
pub:
	name string
}

// FontStyle is the tagged value used by the four font-style options. Only the
// active named arm owns a string, matching Config.FontStyle in Ghostty.
pub type FontStyle = FontStyleDefault | FontStyleFalse | FontStyleName

pub fn (s FontStyle) tag() Kind {
	return match s {
		FontStyleDefault { .default_ }
		FontStyleFalse { .false_ }
		FontStyleName { .name }
	}
}

pub fn (s FontStyle) is_false() bool {
	return s is FontStyleFalse
}

pub fn (mut s FontStyle) parse_cli(input ?string) ! {
	s = FontStyle.parse(input)!
}

pub fn FontStyle.parse(input ?string) !FontStyle {
	value := input or { return error_with_code('value_required', 1) }
	return match value {
		'default' { FontStyleDefault{} }
		'false' { FontStyleFalse{} }
		else { FontStyleName{ name: value } }
	}
}

pub fn (s FontStyle) name_value() ?string {
	return match s {
		FontStyleDefault, FontStyleFalse { none }
		FontStyleName { s.name }
	}
}

pub fn (s FontStyle) clone() FontStyle {
	return match s {
		FontStyleDefault, FontStyleFalse { s }
		FontStyleName { FontStyleName{ name: s.name.clone() } }
	}
}

pub fn (s FontStyle) format_entry() string {
	return match s {
		FontStyleDefault { 'default' }
		FontStyleFalse { 'false' }
		FontStyleName { s.name }
	}
}
