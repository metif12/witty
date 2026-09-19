module internal_os

fn test_parse_uri_mac_address() ! {
	uri1 := parse('file://00:12:34:56:78:90/path', ParseOptions{
		mac_address: true
	})!
	assert uri1.scheme == 'file'
	assert uri1.hostname() == '00:12:34:56:78:90'
	assert uri1.path == '/path'
	assert uri1.port() == ''

	uri2 := parse('file://00:12:34:56:78:90:999/path', ParseOptions{
		mac_address: true
	})!
	assert uri2.hostname() == '00:12:34:56:78:90'
	assert uri2.port() == '999'
	assert uri2.path == '/path'

	uri3 := parse('file://ab:cd:ef:ab:cd:ef/path', ParseOptions{
		mac_address: true
	})!
	assert uri3.hostname() == 'ab:cd:ef:ab:cd:ef'

	uri4 := parse('file://ab:cd:ef:ab:cd:ef:999/path', ParseOptions{
		mac_address: true
	})!
	assert uri4.hostname() == 'ab:cd:ef:ab:cd:ef'
	assert uri4.port() == '999'

	uri5 := parse('file://00:12:34:56:78:90', ParseOptions{
		mac_address: true
	})!
	assert uri5.hostname() == '00:12:34:56:78:90'
	assert uri5.path == ''

	uri6 := parse('file://ab:cd:ef:ab:cd:ef', ParseOptions{
		mac_address: true
	})!
	assert uri6.hostname() == 'ab:cd:ef:ab:cd:ef'
	assert uri6.path == ''
}

fn test_parse_uri_invalid_mac_address() {
	parse('file://zz:zz:zz:zz:zz:00/path', ParseOptions{
		mac_address: true
	}) or {
		assert err.msg() == 'invalid MAC address'
		return
	}
	assert false, 'expected invalid MAC address'
}

fn test_parse_uri_raw_path() ! {
	text := 'file://localhost/path??#fragment'
	uri1 := parse(text, ParseOptions{})!
	assert uri1.scheme == 'file'
	assert uri1.hostname() == 'localhost'
	assert uri1.path == '/path'
	assert uri1.raw_query == '?'
	assert uri1.fragment == 'fragment'

	uri2 := parse(text, ParseOptions{
		raw_path: true
	})!
	assert uri2.scheme == 'file'
	assert uri2.hostname() == 'localhost'
	assert uri2.path == '/path??#fragment'
	assert uri2.raw_query == ''
	assert uri2.fragment == ''

	uri3 := parse('file://localhost', ParseOptions{
		raw_path: true
	})!
	assert uri3.hostname() == 'localhost'
	assert uri3.path == ''
}

fn test_parse_uri_raw_path_starts_at_query_or_fragment_without_slash() ! {
	query := parse('file://localhost?key=value#fragment', ParseOptions{
		raw_path: true
	})!
	assert query.hostname() == 'localhost'
	assert query.path == '?key=value#fragment'

	fragment := parse('file://localhost#fragment', ParseOptions{
		raw_path: true
	})!
	assert fragment.hostname() == 'localhost'
	assert fragment.path == '#fragment'
}

fn test_parse_uri_mac_address_recovery_uses_slash_boundary() {
	parse('file://ab:cd:ef:ab:cd:ef?key=value', ParseOptions{
		mac_address: true
		raw_path: true
	}) or {
		assert err.msg() == 'invalid MAC address'
		return
	}
	assert false, 'expected source invalid-port recovery to reject a query in the MAC host slice'
}

fn test_parse_uri_decodes_path() ! {
	uri := parse('file://localhost/a%20path/%E2%98%83', ParseOptions{})!
	assert uri.path == '/a path/☃'
}
