module internal_os

fn test_parse_uri_mac_address() ! {
	uri1 := parse_uri('file://00:12:34:56:78:90/path', UriParseOptions{
		mac_address: true
	})!
	assert uri1.scheme == 'file'
	assert uri1.host == '00:12:34:56:78:90'
	assert uri1.path == '/path'

	uri2 := parse_uri('file://00:12:34:56:78:90:999/path', UriParseOptions{
		mac_address: true
	})!
	assert uri2.host == '00:12:34:56:78:90'
	assert uri2.path == '/path'

	uri3 := parse_uri('file://ab:cd:ef:ab:cd:ef/path', UriParseOptions{
		mac_address: true
	})!
	assert uri3.host == 'ab:cd:ef:ab:cd:ef'

	uri4 := parse_uri('file://ab:cd:ef:ab:cd:ef:999/path', UriParseOptions{
		mac_address: true
	})!
	assert uri4.host == 'ab:cd:ef:ab:cd:ef'

	uri5 := parse_uri('file://00:12:34:56:78:90', UriParseOptions{
		mac_address: true
	})!
	assert uri5.host == '00:12:34:56:78:90'
	assert uri5.path == ''

	uri6 := parse_uri('file://ab:cd:ef:ab:cd:ef', UriParseOptions{
		mac_address: true
	})!
	assert uri6.host == 'ab:cd:ef:ab:cd:ef'
	assert uri6.path == ''
}

fn test_parse_uri_invalid_mac_address() {
	parse_uri('file://zz:zz:zz:zz:zz:00/path', UriParseOptions{
		mac_address: true
	}) or {
		assert err.msg() == 'invalid MAC address'
		return
	}
	assert false, 'expected invalid MAC address'
}

fn test_parse_uri_raw_path() ! {
	text := 'file://localhost/path??#fragment'
	uri1 := parse_uri(text, UriParseOptions{})!
	assert uri1.scheme == 'file'
	assert uri1.host == 'localhost'
	assert uri1.path == '/path'

	uri2 := parse_uri(text, UriParseOptions{
		raw_path: true
	})!
	assert uri2.scheme == 'file'
	assert uri2.host == 'localhost'
	assert uri2.path == '/path??#fragment'

	uri3 := parse_uri('file://localhost', UriParseOptions{
		raw_path: true
	})!
	assert uri3.host == 'localhost'
	assert uri3.path == ''
}

fn test_parse_uri_decodes_path() ! {
	uri := parse_uri('file://localhost/a%20path/%E2%98%83', UriParseOptions{})!
	assert uri.path == '/a path/☃'
}
