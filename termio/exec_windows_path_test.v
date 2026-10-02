module termio

// Zig std.os.windows/test.zig removeDotDirs vectors exercise parent-directory
// removal and literal dot-prefixed names independently of a Windows kernel.
fn test_windows_path_normalization_source_vectors() {
	inputs := ['', '.', '.\\', '.\\.\\.', 'a', 'a\\', 'a\\b', 'a\\.', 'a\\b\\.', 'a\\.\\b', '.a\\.\\.\\.b\\',
		'a\\..', 'a\\..\\.\\.\\b', 'a\\..\\.\\.\\b\\.\\..\\.', 'a\\b\\..\\c']
	outputs := ['', '', '', '', 'a', 'a\\', 'a\\b', 'a\\', 'a\\b\\', 'a\\b', '.a\\.b\\', '', 'b',
		'', 'a\\c']
	for i, input in inputs {
		mut path := windows_path_wtf16(input) or { panic(err) }
		n := windows_path_normalize(mut path) or { panic(err) }
		assert path[..n] == windows_path_wtf16(outputs[i]) or { panic(err) }
	}
	for input in ['..', '..\\', '.\\..\\', '.\\.\\..\\', 'a\\..\\.\\.\\..', 'a\\..\\.\\.\\b\\.\\..\\.\\..'] {
		mut path := windows_path_wtf16(input) or { panic(err) }
		windows_path_normalize(mut path) or {
			assert err.msg() == 'TooManyParentDirs'
			continue
		}
		assert false, 'accepted excess parents: ${input}'
	}
}

fn test_windows_path_wtf8_preserves_source_surrogates() {
	assert windows_path_wtf16('\xed\xa0\x80') or { panic(err) } == [u16(0xd800)]
	assert windows_path_wtf16('\xf4\x8f\xbf\xbf') or { panic(err) } == [u16(0xdbff), u16(0xdfff)]
	for invalid in ['\xc0\xaf', '\xe0\x80\xbf', '\xf4\x90\x80\x80', '\xe1\x80', '\xff'] {
		windows_path_wtf16(invalid) or {
			assert err.msg() == 'InvalidWtf8'
			continue
		}
		assert false, 'accepted invalid WTF-8'
	}
}
