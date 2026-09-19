module internal_os

import macos

fn macos_system_locale() ?macos.SystemLocale {
	return macos.system_locale()
}

fn macos_preferred_languages() []string {
	return macos.preferred_languages()
}

fn set_lang_from_cocoa() {
	locale := macos_system_locale() or { return }
	lang_value := '${locale.language}_${locale.country}.UTF-8'
	// The pinned implementation uses a 128-byte fixed buffer.
	if lang_value.len >= 128 || setenv('LANG', lang_value) < 0 {
		return
	}

	preferred := macos_preferred_languages()
	mut canonical := []string{cap: preferred.len}
	mut total_len := 0
	for language in preferred {
		value := canonicalize_locale(language) + '.UTF-8'
		total_len += value.len
		if canonical.len > 0 {
			total_len++
		}
		// Match upstream's 1024-byte buffer including its terminator.
		if total_len >= 1024 {
			return
		}
		canonical << value
	}
	if canonical.len > 0 {
		setenv('LANGUAGE', canonical.join(':'))
	}
}
