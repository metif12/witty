module internal_os

import buildcfg

fn test_locale_canonicalization_uses_source_gnulib_and_bounds() ! {
	$if macos || ios {
		if buildcfg.i18n {
			assert canonicalize_locale('en_US.UTF-8') == 'en_US.UTF_8'
			assert canonicalize_locale('English') == 'en'
			assert canonicalize_locale('zh-Hans') == 'zh_CN'
			assert canonicalize_locale('zh-Hant') == 'zh_TW'
			assert canonicalize_locale('zh-Hans-SG') == 'zh_SG'
			assert canonicalize_locale('zh-Hant-HK') == 'zh_HK'
		} else {
			assert canonicalize_locale('zh-Hans') == 'zh-Hans'
			assert canonicalize_locale('en_US.UTF-8') == 'en_US.UTF-8'
		}
	}
	mut small := []u8{len: 3}
	canonicalize_locale_into(mut small, 'en-US') or {
		assert err.msg() == 'NoSpaceLeft'
		return
	}
	assert false, 'the source bounded wrapper must reject short storage'
}
