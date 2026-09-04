module internal_os

import net.urllib

// UriParseOptions extends the standard URI parser for the two cases Ghostty
// needs when handling OSC 7 working-directory reports.
pub struct UriParseOptions {
pub:
	// Parse MAC addresses in the host component. Private Wi-Fi addresses on
	// macOS can appear here as rotating colon-separated MAC addresses.
	mac_address bool
	// Return everything after the authority as the path, including query and
	// fragment text.
	raw_path bool
}

// ParsedUri is the portion of a parsed URI used by Ghostty's OSC 7 handler.
pub struct ParsedUri {
pub:
	scheme string
	host   string
	path   string
}

// parse_uri translates os/uri.zig's parse wrapper. V's standard URI parser
// supplies validation and percent decoding; this function adds Ghostty's MAC
// address repair and raw-path options.
pub fn parse_uri(text string, options UriParseOptions) !ParsedUri {
	uri := urllib.parse(text) or {
		if options.mac_address {
			return parse_mac_uri(text, options)
		}
		return err
	}
	mut host := uri.hostname()

	authority_start := text.index('://') or { -1 }
	mut path_start := text.len
	if authority_start >= 0 {
		start := authority_start + 3
		for i in start .. text.len {
			if text[i] == `/` {
				path_start = i
				break
			}
		}

		// V's URL.hostname treats the final MAC octet as a port when it is
		// numeric. Ghostty repairs that parse and also accepts a real port
		// following a complete MAC address.
		if options.mac_address {
			mut authority := text[start..path_start].clone()
			if at := authority.last_index('@') {
				authority = authority[at + 1..]
			}
			if is_valid_mac_address(authority) {
				host = authority
			} else if colon := authority.last_index(':') {
				candidate := authority[..colon].clone()
				port := authority[colon + 1..].clone()
				if is_valid_mac_address(candidate) && valid_uri_port(port) {
					host = candidate
				} else if authority.count(':') >= 5 && !authority.starts_with('[') {
					return error('invalid MAC address')
				}
			}
		}
	}

	path := if options.raw_path && authority_start >= 0 {
		text[path_start..]
	} else if authority_start >= 0 {
		decoded_uri_path(text, path_start)!
	} else {
		uri.path
	}
	return ParsedUri{
		scheme: uri.scheme
		host: host
		path: path
	}
}

// parse_mac_uri retries a URI whose unbracketed MAC host was rejected as an
// invalid host/port combination. Replacing only the authority for the retry
// keeps all scheme, path, query, fragment, and percent-decoding validation in
// the standard parser.
fn parse_mac_uri(text string, options UriParseOptions) !ParsedUri {
	scheme_end := text.index('://') or { return error('invalid URI') }
	authority_start := scheme_end + 3
	mut path_start := text.len
	for i in authority_start .. text.len {
		if text[i] == `/` {
			path_start = i
			break
		}
	}

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
	uri := urllib.parse(repaired)!
	path := if options.raw_path {
		text[path_start..]
	} else {
		decoded_uri_path(text, path_start)!
	}
	return ParsedUri{
		scheme: uri.scheme
		host: host
		path: path
	}
}

fn decoded_uri_path(text string, path_start int) !string {
	raw := text[path_start..]
	mut end := raw.len
	if query := raw.index('?') {
		end = query
	}
	if fragment := raw.index('#') {
		if fragment < end {
			end = fragment
		}
	}
	return urllib.path_unescape(raw[..end])!
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
