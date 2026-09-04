module internal_os

import macos

fn macos_system_locale() ?macos.SystemLocale {
	return macos.system_locale()
}

fn macos_preferred_languages() []string {
	return macos.preferred_languages()
}
