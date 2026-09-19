module diagnostics

// A diagnostic message from parsing. This is used to provide additional
// human-friendly warnings and errors about the parsed data.
//
// All of the memory for the diagnostic is allocated from the arena
// associated with the config structure. If an arena isn't available
// then diagnostics are not supported.
pub struct Diagnostic {
pub:
	// The location where the diagnostic occurred.
	location Location = Location(NoneLocation{})
	// The key that caused the diagnostic. This is the field name
	// that was being parsed.
	key string
	// The human-readable message about what went wrong.
	message string
}

// Write the full user-friendly diagnostic message to a string.
pub fn (self Diagnostic) format() string {
	mut result := ''
	match self.location {
		NoneLocation {}
		CliLocation {
			result += 'cli:${self.location.index}:'
		}
		FileLocation {
			result += '${self.location.path}:${self.location.line}:'
		}
	}
	if self.key.len > 0 {
		result += '${self.key}: '
	} else if self.location !is NoneLocation {
		result += ' '
	}
	result += self.message
	return result
}

// Clone the diagnostic.
pub fn (self Diagnostic) clone() Diagnostic {
	return Diagnostic{
		location: self.location.clone()
		key: self.key.clone()
		message: self.message.clone()
	}
}

// The possible locations for a diagnostic message. This is used
// to provide context for the message.
pub type Location = NoneLocation | CliLocation | FileLocation

pub struct NoneLocation {}

// A CLI argument index (1-indexed).
pub struct CliLocation {
pub:
	index usize
}

// A file path and line number.
pub struct FileLocation {
pub:
	path string
	line usize
}

// LocationKind is the tag type for Location.
pub enum LocationKind as u8 {
	none
	cli
	file
}

// from_iter returns the current diagnostic location for iterators that expose
// a location() method. Other iterator types produce the location-less value.
// V strings are garbage-collected, so the source allocator argument is absent.
pub fn Location.from_iter[T](iter T) Location {
	mut result := Location(NoneLocation{})
	$for method in T.methods {
		$if method.name == 'location' {
			result = iter.$method()
		}
	}
	return result
}

// Clone the location.
pub fn (self Location) clone() Location {
	match self {
		NoneLocation {
			return NoneLocation{}
		}
		CliLocation {
			return CliLocation{
				index: self.index
			}
		}
		FileLocation {
			return FileLocation{
				path: self.path.clone()
				line: self.line
			}
		}
	}
}

// A list of diagnostics. The "_diagnostics" field must be this type
// for diagnostics to be supported. If this field is an incorrect type
// a compile-time error will be raised.
//
// This is implemented as a simple wrapper around an array list
// so that we can inject some logic around adding diagnostics
// and potentially in the future structure them differently.
pub struct DiagnosticList {
mut:
	// The list of diagnostics.
	list []Diagnostic
}

// Append a diagnostic to the list.
pub fn (mut self DiagnosticList) append(diag Diagnostic) {
	self.list << diag
}

// Returns true if the list is empty.
pub fn (self DiagnosticList) empty() bool {
	return self.list.len == 0
}

// Returns all diagnostics in the list.
pub fn (self DiagnosticList) items() []Diagnostic {
	return self.list
}

// Returns true if there are any diagnostics for the given location type.
pub fn (self DiagnosticList) contains_location(location LocationKind) bool {
	for diag in self.list {
		match location {
			.none {
				if diag.location is NoneLocation {
					return true
				}
			}
			.cli {
				if diag.location is CliLocation {
					return true
				}
			}
			.file {
				if diag.location is FileLocation {
					return true
				}
			}
		}
	}
	return false
}

// Clone the diagnostic list.
pub fn (self DiagnosticList) clone() DiagnosticList {
	mut result := DiagnosticList{}
	for diag in self.list {
		result.list << diag.clone()
	}
	return result
}
