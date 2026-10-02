module termio

// Zig 0.15.2 std.os.windows.{wtf8ToWtf16Le,normalizePath,
// getNamespacePrefix,getUnprefixedPathType}; helpers used by std.fs.cwd().access
// in Ghostty Exec.Subprocess.start. The input may contain lone surrogates.
fn windows_path_wtf16(path string) ![]u16 {
	mut result := []u16{cap: path.len + 1}
	mut i := 0
	for i < path.len {
		first := path[i]
		n := if first <= 0x7f {
			1
		} else if first >= 0xc0 && first <= 0xdf {
			2
		} else if first >= 0xe0 && first <= 0xef {
			3
		} else if first >= 0xf0 && first <= 0xf7 {
			4
		} else {
			return error('InvalidWtf8')
		}
		if i + n > path.len { return error('InvalidWtf8') }
		mut value := u32(first & [u8(0), 0x7f, 0x1f, 0x0f, 0x07][n])
		for j in 1 .. n {
			if path[i + j] & 0xc0 != 0x80 { return error('InvalidWtf8') }
			value = (value << 6) | u32(path[i + j] & 0x3f)
		}
		if (n == 2 && value < 0x80) || (n == 3 && value < 0x800) || (n == 4 && (value < 0x10000 || value > 0x10ffff)) {
			return error('InvalidWtf8')
		}
		if value < 0x10000 {
			result << u16(value)
		} else {
			result << u16((value - 0x10000) >> 10) + 0xd800
			result << u16(value & 0x3ff) + 0xdc00
		}
		i += n
	}
	if result.len > 32767 { return error('NameTooLong') }
	return result
}

fn windows_path_normalize(mut path []u16) !int {
	for i, c in path { if c == u16(`/`) { path[i] = u16(`\\`) } }
	// std.mem.collapseRepeatsLen.
	mut new_len := 0
	for c in path {
		if new_len == 0 || c != u16(`\\`) || path[new_len - 1] != u16(`\\`) {
			path[new_len] = c
			new_len++
		}
	}
	prefix := if new_len >= 1 && path[0] == u16(`\\`) {
		1
	} else if new_len >= 2 && path[1] == u16(`:`) {
		if new_len >= 3 && path[2] == u16(`\\`) { 3 } else { 2 }
	} else {
		0
	}
	mut p := unsafe { path[prefix..new_len] }
	assert p.len == 0 || p[0] != u16(`\\`)
	mut write := 0
	mut read := 0
	for read < p.len {
		if p[read] == u16(`.`) {
			if read + 1 == p.len { return prefix + write }
			after := p[read + 1]
			if after == u16(`\\`) {
				read += 2
				continue
			}
			if after == u16(`.`) && (read + 2 == p.len || p[read + 2] == u16(`\\`)) {
				if write == 0 { return error('TooManyParentDirs') }
				assert write >= 2
				write--
				for {
					write--
					if write == 0 { break }
					if p[write] == u16(`\\`) {
						write++
						break
					}
				}
				if read + 2 == p.len { return prefix + write }
				read += 3
				continue
			}
		}
		for {
			if read == p.len { return prefix + write }
			p[write] = p[read]
			write++
			if p[read] == u16(`\\`) { break }
			read++
		}
		read++
	}
	return prefix + write
}

enum WindowsNamespace {
	none
	local_device
	verbatim
	fake_verbatim
	nt
}

enum WindowsPathType {
	unc_absolute
	drive_absolute
	drive_relative
	rooted
	relative
	root_local_device
}

fn windows_path_separator(c u16) bool { return c == u16(`/`) || c == u16(`\\`) }

fn windows_path_namespace(path []u16) WindowsNamespace {
	if path.len < 4 || !windows_path_separator(path[0]) || !windows_path_separator(path[3]) {
		return .none
	}
	all_backslash := path[0] == u16(`\\`) && path[3] == u16(`\\`)
	if path[1] == u16(`?`) && path[2] == u16(`?`) && all_backslash { return .nt }
	if !windows_path_separator(path[1]) { return .none }
	return match path[2] {
		u16(`?`) {
			if all_backslash && path[1] == u16(`\\`) {
				WindowsNamespace.verbatim
			} else {
				WindowsNamespace.fake_verbatim
			}
		}
		u16(`.`) { WindowsNamespace.local_device }
		else { WindowsNamespace.none }
	}
}

fn windows_path_type(path []u16) WindowsPathType {
	if path.len == 0 { return .relative }
	if windows_path_separator(path[0]) {
		if path.len < 2 || !windows_path_separator(path[1]) { return .rooted }
		if path.len == 3 && (path[2] == u16(`.`) || path[2] == u16(`?`)) {
			return .root_local_device
		}
		return .unc_absolute
	}
	if path.len < 2 || path[1] != u16(`:`) { return .relative }
	if path.len > 2 && windows_path_separator(path[2]) { return .drive_absolute }
	return .drive_relative
}
