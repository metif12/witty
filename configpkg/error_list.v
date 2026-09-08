// Translated from Ghostty's src/config/ErrorList.zig.

module configpkg

// ConfigError is ErrorList.Error. V does not support nested type declarations,
// so the containing type name is used as a prefix.
pub struct ConfigError {
pub:
	message string
}

pub struct ErrorList {
pub mut:
	list []ConfigError
}

// empty reports whether the list contains no errors.
pub fn (e ErrorList) empty() bool {
	return e.list.len == 0
}

// add appends an error to the list.
pub fn (mut e ErrorList) add(err ConfigError) {
	e.list << err
}
