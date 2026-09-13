// Translated from Ghostty's config/Config.zig FontStyle declaration.
module fontstyle

// Kind is the flattened tag of the FontStyle union.
pub enum Kind as u8 {
	default_
	false_
	name
}

// FontStyle is the tagged value used by the four font-style options. A named
// style is kept distinct from the special default and false values.
pub struct FontStyle {
pub:
	kind Kind
	name string
}

pub fn (mut s FontStyle) parse_cli(input ?string) ! {
	s = FontStyle.parse(input)!
}

pub fn FontStyle.parse(input ?string) !FontStyle {
	value := input or { return error_with_code('value_required', 1) }
	return match value {
		'default' { FontStyle{ kind: .default_ } }
		'false' { FontStyle{ kind: .false_ } }
		else { FontStyle{ kind: .name, name: value } }
	}
}

pub fn (s FontStyle) name_value() ?string {
	return if s.kind == .name { s.name } else { none }
}

pub fn (s FontStyle) clone() FontStyle {
	return FontStyle{
		...s
		name: s.name.clone()
	}
}

pub fn (s FontStyle) format_entry() string {
	return match s.kind {
		.default_ { 'default' }
		.false_ { 'false' }
		.name { s.name }
	}
}
