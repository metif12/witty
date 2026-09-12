module diagnostics

fn test_diagnostic_location_width_and_format() {
	large := usize(usize(-1) >> 1) + 1
	cli := Diagnostic{
		location: CliLocation{
			index: large
		}
		key: 'font-size'
		message: 'invalid value'
	}
	assert cli.format() == 'cli:${large}:font-size: invalid value'

	file := Diagnostic{
		location: FileLocation{
			path: 'ghostty.conf'
			line: large
		}
		message: 'unknown field'
	}
	assert file.format() == 'ghostty.conf:${large}: unknown field'
}

fn test_diagnostic_list_contains_location() {
	mut list := DiagnosticList{}
	assert !list.contains_location(.none)
	assert !list.contains_location(.cli)
	assert !list.contains_location(.file)

	list.append(Diagnostic{
		message: 'plain'
	})
	list.append(Diagnostic{
		location: CliLocation{
			index: 1
		}
		message: 'argument'
	})
	list.append(Diagnostic{
		location: FileLocation{
			path: 'ghostty.conf'
			line: 2
		}
		message: 'file'
	})
	assert list.contains_location(.none)
	assert list.contains_location(.cli)
	assert list.contains_location(.file)
}

fn test_diagnostic_clone_preserves_pointer_width_locations() {
	large := usize(usize(-1) >> 1) + 1
	for location in [Location(CliLocation{
		index: large
	}), Location(FileLocation{
		path: 'ghostty.conf'
		line: large
	})] {
		cloned := (Diagnostic{
			location: location
			key: 'key'
			message: 'message'
		}).clone()
		match cloned.location {
			CliLocation {
				assert cloned.location.index == large
			}
			FileLocation {
				assert cloned.location.line == large
			}
			NoneLocation {
				assert false, 'unexpected empty location'
			}
		}
	}
}
