module internal_os

import log

#include <locale.h>

fn C.setlocale(category int, locale &char) &char

// ensure_locale initializes libc's process locale from the environment. If an
// invalid LANG prevents that, it retries the platform default and finally the
// UTF-8 locale used by Ghostty as its fallback.
pub fn ensure_locale() ! {
	lang := getenv('LANG')
	$if macos {
		mut needs_cocoa_locale := true
		if value := lang {
			needs_cocoa_locale = value.len == 0
		}
		if needs_cocoa_locale {
			set_lang_from_cocoa()
		}
	}

	if value := set_process_locale('') {
		log.info('setlocale from env result=${value}')
		return
	}

	if old_lang := getenv('LANG') {
		if old_lang.len > 0 {
			// Do both, as upstream does, so LANG is guaranteed not to retain
			// the invalid value on any supported C runtime.
			setenv('LANG', '')
			unsetenv('LANG')
			if value := set_process_locale('') {
				log.info('setlocale after unset lang result=${value}')
				if value != 'C' {
					return
				}
			}
		}
	}

	log.warn('setlocale failed with LANG and system default. Falling back to en_US.UTF-8')
	if value := set_process_locale('en_US.UTF-8') {
		setenv('LANG', 'en_US.UTF-8')
		log.info('setlocale default result=${value}')
		return
	}
	log.warn('setlocale failed even with the fallback, uncertain results')
}

fn set_process_locale(value string) ?string {
	result := C.setlocale(C.LC_ALL, &char(value.str))
	if isnil(result) {
		return none
	}
	return unsafe { cstring_to_vstring(result) }
}
