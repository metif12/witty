module internal_os

import os

// is_valid validates a hostname according to RFC 1123. This is
// stricter than many platform helpers: empty labels and labels beginning or
// ending with a hyphen are rejected.
pub fn is_valid(hostname string) bool {
	if hostname.len == 0 || hostname[0] == `.` {
		return false
	}
	end := if hostname[hostname.len - 1] == `.` {
		if hostname.len == 1 {
			return false
		}
		hostname.len - 1
	} else {
		hostname.len
	}
	if end > 253 {
		return false
	}

	mut label_start := 0
	mut label_len := 0
	for i, c in hostname[..end].bytes() {
		match c {
			`.` {
				if label_len == 0 || label_len > 63 || !hostname[label_start].is_alnum()
					|| !hostname[i - 1].is_alnum() {
					return false
				}
				label_start = i + 1
				label_len = 0
			}
			`-` {
				label_len++
			}
			else {
				if !c.is_alnum() {
					return false
				}
				label_len++
			}
		}
	}
	if label_len == 0 || label_len > 63 || !hostname[label_start].is_alnum()
		|| !hostname[end - 1].is_alnum() {
		return false
	}
	return true
}

// is_local recognizes localhost and the hostname returned by the
// operating system.
pub fn is_local(hostname string) !bool {
	if hostname == 'localhost' {
		return true
	}
	our_hostname := os.hostname()!
	return hostname == our_hostname
}
