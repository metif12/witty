module internal_os

import dl
import os

const ghostty_gettext_domain = 'com.mitchellh.ghostty'

// Supported application locales. The order is significant: callers with
// incomplete locale information use the first matching language.
pub const supported_locales = [
	'zh_CN.UTF-8',
	'de_DE.UTF-8',
	'fr_FR.UTF-8',
	'ja_JP.UTF-8',
	'nl_NL.UTF-8',
	'nb_NO.UTF-8',
	'ru_RU.UTF-8',
	'uk_UA.UTF-8',
	'pl_PL.UTF-8',
	'ko_KR.UTF-8',
	'mk_MK.UTF-8',
	'tr_TR.UTF-8',
	'id_ID.UTF-8',
	'es_BO.UTF-8',
	'es_AR.UTF-8',
	'pt_BR.UTF-8',
	'ca_ES.UTF-8',
	'it_IT.UTF-8',
	'bg_BG.UTF-8',
	'ga_IE.UTF-8',
	'hu_HU.UTF-8',
	'he_IL.UTF-8',
	'zh_TW.UTF-8',
	'hr_HR.UTF-8',
	'lt_LT.UTF-8',
]!

type GettextFunction = fn (&char, &char) &char

type BindTextDomainFunction = fn (&char, &char) &char

type TextDomainFunction = fn (&char) &char

struct I18nState {
mut:
	handle          voidptr
	dgettext_symbol voidptr
	bind_symbol     voidptr
	domain_symbol   voidptr
}

struct I18nStateSingleton {
mut:
	state I18nState
}

const i18n_state_singleton = &I18nStateSingleton{}

fn get_i18n_state() &I18nState {
	return unsafe { &i18n_state_singleton.state }
}

// init binds Ghostty's gettext domain to the locale directory adjacent to the
// application resource directory. If gettext is unavailable the application
// remains usable and translations fall back to their message IDs.
pub fn init(resources_dir string) ! {
	$if windows {
		return
	}
	share_dir := i18n_share_dir(resources_dir) or { return error('InvalidResourcesDir') }
	load_gettext() or { return }
	state := get_i18n_state()
	if isnil(state.bind_symbol) {
		return
	}
	locale_dir := os.join_path(share_dir, 'locale')
	unsafe {
		bind := BindTextDomainFunction(state.bind_symbol)
		if isnil(bind(&char(ghostty_gettext_domain.str), &char(locale_dir.str))) {
			return error('unable to bind gettext domain')
		}
	}
}

// i18n_share_dir is std.fs.path.dirname's POSIX behavior. In particular, a
// basename and a basename with trailing slashes have no directory component;
// os.dir maps both to a usable string and would hide InvalidResourcesDir.
fn i18n_share_dir(path string) ?string {
	if path.len == 0 {
		return none
	}
	mut end := path.len - 1
	for path[end] == `/` {
		if end == 0 {
			return none
		}
		end--
	}
	for path[end] != `/` {
		if end == 0 {
			return none
		}
		end--
	}
	if end == 0 {
		return if path[0] == `/` { '/' } else { none }
	}
	return path[..end]
}

// init_global_domain makes unqualified gettext calls use Ghostty's
// domain. Fully owning runtimes such as GTK call this during startup.
pub fn init_global_domain() ! {
	load_gettext() or { return }
	state := get_i18n_state()
	if isnil(state.domain_symbol) {
		return
	}
	unsafe {
		set_domain := TextDomainFunction(state.domain_symbol)
		if isnil(set_domain(&char(ghostty_gettext_domain.str))) {
			return error('unable to set gettext domain')
		}
	}
}

// translate_c translates a null-terminated message and preserves gettext's
// stable pointer contract. The input pointer is returned when no catalog or
// gettext runtime is available.
pub fn translate_c(msgid &char) &char {
	if isnil(msgid) {
		return unsafe { msgid }
	}
	load_gettext() or { return unsafe { msgid } }
	state := get_i18n_state()
	if isnil(state.dgettext_symbol) {
		return unsafe { msgid }
	}
	unsafe {
		gettext := GettextFunction(state.dgettext_symbol)
		return gettext(&char(ghostty_gettext_domain.str), msgid)
	}
}

pub fn translate(msgid string) string {
	translated := translate_c(&char(msgid.str))
	if isnil(translated) {
		return msgid
	}
	return unsafe { cstring_to_vstring(translated) }
}

// static_locale is the V equivalent of Ghostty's compile-time locale
// validator. V cannot return an input-dependent comptime string, so invalid
// callers fail immediately when this helper is evaluated.
pub fn static_locale(value string) string {
	for locale in supported_locales {
		if locale == value {
			return locale
		}
	}
	panic('unsupported locale: ${value}')
}

// canonicalize_locale handles the locale spellings that gettext does not
// canonicalize correctly on Darwin. Other locale names are normalized to
// POSIX separators while preserving their encoding suffix.
pub fn canonicalize_locale(locale string) string {
	parts := locale.split('-')
	if parts.len >= 2 && parts[0] == 'zh' {
		script := parts[1]
		region := if parts.len >= 3 { parts[2] } else { '' }
		if script == 'Hans' {
			return if region == 'SG' { 'zh_SG' } else { 'zh_CN' }
		}
		if script == 'Hant' {
			return match region {
				'MO' { 'zh_MO' }
				'HK' { 'zh_HK' }
				else { 'zh_TW' }
			}
		}
	}
	return locale.replace('-', '_')
}

pub fn shutdown_i18n() {
	mut state := get_i18n_state()
	if !isnil(state.handle) {
		dl.close(state.handle)
	}
	state.handle = unsafe { nil }
	state.dgettext_symbol = unsafe { nil }
	state.bind_symbol = unsafe { nil }
	state.domain_symbol = unsafe { nil }
}

fn load_gettext() ! {
	mut state := get_i18n_state()
	if !isnil(state.handle) {
		return
	}

	candidates := $if macos { ['/opt/homebrew/opt/gettext/lib/libintl.8.dylib',
		'/usr/local/opt/gettext/lib/libintl.8.dylib', 'libintl.8.dylib', 'libintl.dylib'] } $else $if linux { [
		'libc.so.6',
		'libintl.so.8',
		'libintl.so',
	] } $else $if freebsd { ['libintl.so', 'libintl.so.8'] } $else { []string{} }

	for candidate in candidates {
		handle := dl.open(candidate, dl.rtld_lazy | dl.rtld_local)
		if isnil(handle) {
			continue
		}
		dgettext_symbol := dl.sym(handle, 'dgettext')
		if isnil(dgettext_symbol) {
			dl.close(handle)
			continue
		}
		state.handle = handle
		state.dgettext_symbol = dgettext_symbol
		state.bind_symbol = dl.sym(handle, 'bindtextdomain')
		state.domain_symbol = dl.sym(handle, 'textdomain')
		return
	}
	return error('gettext runtime not found')
}
