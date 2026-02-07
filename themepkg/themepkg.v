module themepkg

import os
import global_state

// Location of possible themes. The order of this enum matters because it
// defines the priority of theme search (from top to bottom).
pub enum Location {
	user      // XDG config dir
	resources // Ghostty resources dir
}

// Returns the directory for the given theme based on this location type.
//
// This will return an empty string if the directory type doesn't exist
// or is invalid for any reason. For example, it is perfectly valid to
// install and run Ghostty without the resources directory.
pub fn (l Location) dir() string {
	match l {
		.user {
			config_dir := os.config_dir() or { return '' }
			return os.join_path(config_dir, 'ghostty', 'themes')
		}
		.resources {
			// Use the global_state resources_dir to find the themes
			// directory within the application resources.
			resources_path := global_state.state.resources_dir.app()
			if resources_path.len == 0 {
				return ''
			}
			return os.join_path(resources_path, 'themes')
		}
	}
}

pub fn (l Location) str() string {
	return match l {
		.user { 'user' }
		.resources { 'resources' }
	}
}

// LocationEntry holds a location and its directory path.
pub struct LocationEntry {
pub:
	location Location
	dir      string
}

// An iterator that returns all possible directories for finding themes in
// order of priority.
pub struct LocationIterator {
mut:
	i int
}

pub fn LocationIterator.new() LocationIterator {
	return LocationIterator{}
}

pub fn (mut self LocationIterator) next() ?LocationEntry {
	locations := [Location.user, Location.resources]
	for self.i < locations.len {
		loc := locations[self.i]
		self.i += 1
		d := loc.dir()
		if d.len > 0 {
			return LocationEntry{
				location: loc
				dir:      d
			}
		}
	}
	return none
}

pub fn (mut self LocationIterator) reset() {
	self.i = 0
}
