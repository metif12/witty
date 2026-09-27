module configpkg

import oniguruma

struct UrlRegexCase {
	input       string
	expect      string
	num_matches usize = 1
}

fn test_default_url_regex_matches_pinned_oniguruma_cases() {
	oniguruma.init([oniguruma.Encoding.utf8()])!
	defer { oniguruma.deinit() }
	mut regex := oniguruma.Regex.init(default_url_pattern, oniguruma.Options{}, oniguruma.Encoding.utf8(),
		oniguruma.Syntax.default_(), none)!
	defer { regex.deinit() }

	cases := [
		UrlRegexCase{'hello https://example.com world', 'https://example.com', 1},
		UrlRegexCase{'https://example.com/foo(bar) more', 'https://example.com/foo(bar)', 1},
		UrlRegexCase{'https://example.com/foo(bar)baz more', 'https://example.com/foo(bar)baz', 1},
		UrlRegexCase{'Link inside (https://example.com) parens', 'https://example.com', 1},
		UrlRegexCase{'Link period https://example.com. More text.', 'https://example.com', 1},
		UrlRegexCase{'Link trailing colon https://example.com, more text.', 'https://example.com', 1},
		UrlRegexCase{'Link in double quotes "https://example.com" and more', 'https://example.com', 1},
		UrlRegexCase{"Link in single quotes 'https://example.com' and more", 'https://example.com', 1},
		UrlRegexCase{'some file with https://google.com https://duckduckgo.com links.', 'https://google.com', 1},
		UrlRegexCase{'and links in it. links https://yahoo.com mailto:test@example.com ssh://1.2.3.4', 'https://yahoo.com', 1},
		UrlRegexCase{'also match http://example.com non-secure links', 'http://example.com', 1},
		UrlRegexCase{'match tel://+12123456789 phone numbers', 'tel://+12123456789', 1},
		UrlRegexCase{'match with query url https://example.com?query=1&other=2 and more text.', 'https://example.com?query=1&other=2', 1},
		UrlRegexCase{'url with dashes [mode 2027](https://github.com/contour-terminal/terminal-unicode-core) for better unicode support', 'https://github.com/contour-terminal/terminal-unicode-core', 1},
		UrlRegexCase{'dot.http://example.com', 'http://example.com', 1},
		UrlRegexCase{'weird characters https://example.com/~user/?query=1&other=2#hash and more', 'https://example.com/~user/?query=1&other=2#hash', 1},
		UrlRegexCase{'square brackets https://example.com/[foo] and more', 'https://example.com/[foo]', 1},
		UrlRegexCase{'[13]:TooManyStatements: TempFile#assign_temp_file_to_entity has approx 7 statements [https://example.com/docs/Too-Many-Statements.md]', 'https://example.com/docs/Too-Many-Statements.md', 1},
		UrlRegexCase{'match ftp://example.com ftp links', 'ftp://example.com', 1},
		UrlRegexCase{'match file://example.com file links', 'file://example.com', 1},
		UrlRegexCase{'match ssh://example.com ssh links', 'ssh://example.com', 1},
		UrlRegexCase{'match git://example.com git links', 'git://example.com', 1},
		UrlRegexCase{'match tel:+18005551234 tel links', 'tel:+18005551234', 1},
		UrlRegexCase{'match magnet:?xt=urn:btih:1234567890 magnet links', 'magnet:?xt=urn:btih:1234567890', 1},
		UrlRegexCase{'match ipfs://QmSomeHashValue ipfs links', 'ipfs://QmSomeHashValue', 1},
		UrlRegexCase{'match ipns://QmSomeHashValue ipns links', 'ipns://QmSomeHashValue', 1},
		UrlRegexCase{'match gemini://example.com gemini links', 'gemini://example.com', 1},
		UrlRegexCase{'match gopher://example.com gopher links', 'gopher://example.com', 1},
		UrlRegexCase{'match news:comp.infosystems.www.servers.unix news links', 'news:comp.infosystems.www.servers.unix', 1},
		UrlRegexCase{'/Users/ghostty.user/code/example.py', '/Users/ghostty.user/code/example.py', 1},
		UrlRegexCase{'/Users/ghostty.user/code/../example.py', '/Users/ghostty.user/code/../example.py', 1},
		UrlRegexCase{'/Users/ghostty.user/code/../example.py hello world', '/Users/ghostty.user/code/../example.py', 1},
		UrlRegexCase{'../example.py', '../example.py', 1},
		UrlRegexCase{'../example.py ', '../example.py ', 1},
		UrlRegexCase{'first time ../example.py contributor ', '../example.py', 1},
		UrlRegexCase{'[link](/home/user/ghostty.user/example)', '/home/user/ghostty.user/example', 1},
		UrlRegexCase{'Serving HTTP on :: port 8000 (http://[::]:8000/)', 'http://[::]:8000/', 1},
		UrlRegexCase{'IPv6 address https://[2001:db8::1]:8080/path', 'https://[2001:db8::1]:8080/path', 1},
		UrlRegexCase{'IPv6 localhost http://[::1]:3000', 'http://[::1]:3000', 1},
		UrlRegexCase{'Complex IPv6 https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/', 'https://[2001:db8:85a3:8d3:1319:8a2e:370:7348]:443/', 1},
		UrlRegexCase{'IPv6 with path https://[2001:db8::1]/path/to/resource', 'https://[2001:db8::1]/path/to/resource', 1},
		UrlRegexCase{'IPv6 with query https://[2001:db8::1]:8080/api?param=value&other=123', 'https://[2001:db8::1]:8080/api?param=value&other=123', 1},
		UrlRegexCase{'IPv6 compressed http://[2001:db8::]:80/', 'http://[2001:db8::]:80/', 1},
		UrlRegexCase{'IPv6 multiple zeros http://[2001:0:0:0:0:0:0:1]', 'http://[2001:0:0:0:0:0:0:1]', 1},
		UrlRegexCase{'IPv6 link-local https://[fe80::1234:5678:9abc]', 'https://[fe80::1234:5678:9abc]', 1},
		UrlRegexCase{'IPv6 multicast http://[ff02::1]/stream', 'http://[ff02::1]/stream', 1},
		UrlRegexCase{'IPv6 in markdown [link](http://[2001:db8::1]/docs)', 'http://[2001:db8::1]/docs', 1},
		UrlRegexCase{'./spaces-end.   ', './spaces-end.   ', 1},
		UrlRegexCase{'./space middle', './space middle', 1},
		UrlRegexCase{'../test folder/file.txt', '../test folder/file.txt', 1},
		UrlRegexCase{'/tmp/test folder/file.txt', '/tmp/test folder/file.txt', 1},
		UrlRegexCase{'src/config/url.zig', 'src/config/url.zig', 1},
		UrlRegexCase{'app/folder/file.rb:1', 'app/folder/file.rb:1', 1},
		UrlRegexCase{'modified:   src/config/url.zig', 'src/config/url.zig', 1},
		UrlRegexCase{'lib/ghostty/terminal.zig:42:10', 'lib/ghostty/terminal.zig:42:10', 1},
		UrlRegexCase{'some-pkg/src/file.txt more text', 'some-pkg/src/file.txt', 1},
	]

	for case in cases {
		mut region := regex.search(case.input, oniguruma.Options{})!
		starts := region.starts()
		ends := region.ends()
		assert region.count() == case.num_matches
		assert case.input[starts[0]..ends[0]] == case.expect
		region.deinit()
	}

	for input in ['input/output', 'foo/bar'] {
		if mut region := regex.search(input, oniguruma.Options{}) {
			region.deinit()
			assert false, 'unexpected URL match: ${input}'
		} else {
			assert oniguruma.is_error(err, .mismatch)
		}
	}
}
