module internal_os

import net.urllib

// ParseOptions extends the standard URI parser for the two cases Ghostty
// needs when handling OSC 7 working-directory reports.
pub struct ParseOptions {
pub:
	// Parse MAC addresses in the host component. Private Wi-Fi addresses on
	// macOS can appear here as rotating colon-separated MAC addresses.
	mac_address bool
	// Return everything after the authority as the path, including query and
	// fragment text.
	raw_path bool
}

// parse translates os/uri.zig's wrapper around the standard URI parser. The
// complete standard-library URL value is retained so callers can observe the
// port, query, fragment, user information, and raw path just as they can from
// Ghostty's std.Uri return value.
pub fn parse(text string, options ParseOptions) !urllib.URL {
	mut uri := urllib.parse(text) or {
		if options.mac_address {
			return parse_mac_uri(text, options)
		}
		return err
	}

	authority_start := text.index('://') or { -1 }
	mut path_start := text.len
	if authority_start >= 0 {
		start := authority_start + 3
		path_start = authority_path_start(text, start)

		// V's URL.hostname treats the final MAC octet as a port when it is
		// numeric. Ghostty repairs that parse and also accepts a real port
		// following a complete MAC address.
		if options.mac_address {
			mut authority := text[start..path_start].clone()
			if at := authority.last_index('@') {
				authority = authority[at + 1..]
			}
			if is_valid_mac_address(authority) {
				// urllib stores host and port in one string. Brackets preserve
				// the source's repaired unbracketed MAC host through hostname().
				uri.host = '[${authority}]'
			} else if colon := authority.last_index(':') {
				candidate := authority[..colon].clone()
				port := authority[colon + 1..].clone()
				if is_valid_mac_address(candidate) && valid_uri_port(port) {
					uri.host = '[${candidate}]:${port}'
				} else if authority.count(':') >= 5 && !authority.starts_with('[') {
					return error('invalid MAC address')
				}
			}
		}
	}

	if authority_start >= 0 {
		if options.raw_path {
			uri.path = text[path_start..]
			uri.raw_path = ''
			uri.force_query = false
			uri.raw_query = ''
			uri.fragment = ''
		} else {
			// V's pinned urllib treats a suffix ending in two question marks
			// as a force-query path. std.Uri splits at the first question mark.
			normalize_uri_tail(mut uri, text, path_start)!
		}
	}
	return uri
}

// parse_mac_uri retries a URI whose unbracketed MAC host was rejected as an
// invalid host/port combination. Replacing only the authority for the retry
// keeps all scheme, path, query, fragment, and percent-decoding validation in
// the standard parser.
fn parse_mac_uri(text string, options ParseOptions) !urllib.URL {
	scheme_end := text.index('://') or { return error('invalid URI') }
	authority_start := scheme_end + 3
	path_start := mac_authority_path_start(text, authority_start)

	authority := text[authority_start..path_start]
	mut host := authority
	if !is_valid_mac_address(host) {
		colon := authority.last_index(':') or { return error('invalid MAC address') }
		host = authority[..colon]
		if !is_valid_mac_address(host) || !valid_uri_port(authority[colon + 1..]) {
			return error('invalid MAC address')
		}
	}

	repaired := '${text[..authority_start]}localhost${text[path_start..]}'
	mut uri := urllib.parse(repaired)!
	uri.host = if is_valid_mac_address(authority) {
		'[${authority}]'
	} else {
		colon := authority.last_index(':') or { return error('invalid MAC address') }
		'[${authority[..colon]}]:${authority[colon + 1..]}'
	}
	if options.raw_path {
		uri.path = text[path_start..]
		uri.raw_path = ''
		uri.force_query = false
		uri.raw_query = ''
		uri.fragment = ''
	} else {
		normalize_uri_tail(mut uri, text, path_start)!
	}
	return uri
}

// The source's invalid-port recovery finds the host end using only a slash.
// Query and fragment delimiters are intentionally not accepted here.
fn mac_authority_path_start(text string, start int) int {
	for i in start .. text.len {
		if text[i] == `/` {
			return i
		}
	}
	return text.len
}

// authority_path_start returns the first byte after an authority. A URI path
// can be empty, so a query or fragment delimiter also terminates the host and
// is the start retained by Ghostty's raw_path option.
fn authority_path_start(text string, start int) int {
	for i in start .. text.len {
		if text[i] == `/` || text[i] == `?` || text[i] == `#` {
			return i
		}
	}
	return text.len
}

fn normalize_uri_tail(mut uri urllib.URL, text string, path_start int) ! {
	raw := text[path_start..]
	mut end := raw.len
	mut query_start := -1
	if query := raw.index('?') {
		end = query
		query_start = query
	}
	mut fragment_start := -1
	if fragment := raw.index('#') {
		fragment_start = fragment
		if fragment < end {
			end = fragment
			query_start = -1
		}
	}
	encoded_path := raw[..end]
	uri.path = urllib.path_unescape(encoded_path)!
	uri.raw_path = if uri.path == encoded_path { '' } else { encoded_path }
	if query_start >= 0 {
		query_end := if fragment_start >= 0 { fragment_start } else { raw.len }
		uri.raw_query = raw[query_start + 1..query_end]
		uri.force_query = uri.raw_query.len == 0
	} else {
		uri.raw_query = ''
		uri.force_query = false
	}
}

fn valid_uri_port(value string) bool {
	if value.len == 0 {
		return false
	}
	mut port := u32(0)
	for c in value.bytes() {
		if !c.is_digit() {
			return false
		}
		port = port * 10 + u32(c - `0`)
		if port > 65535 {
			return false
		}
	}
	return true
}

// is_valid_mac_address checks for exactly six colon-separated hexadecimal
// octets, matching os/uri.zig's recovery guard.
fn is_valid_mac_address(value string) bool {
	if value.len != 17 {
		return false
	}
	for i, c in value.bytes() {
		if i % 3 == 2 {
			if c != `:` {
				return false
			}
		} else if !c.is_hex_digit() {
			return false
		}
	}
	return true
}
