module gtk

fn test_semver_order_and_format() {
	version := SemVer{
		major: 4
		minor: 16
		patch: 2
	}
	assert version.str() == '4.16.2'
	assert version.order(SemVer{ major: 4, minor: 16, patch: 2 }) == 0
	assert version.order(SemVer{ major: 4, minor: 16, patch: 3 }) == -1
	assert version.order(SemVer{ major: 4, minor: 15, patch: 99 }) == 1
}

fn test_adwaita_capability_helpers_match_their_version_boundaries() {
	assert supports_dialogs() == adw_at_least(1, 5, 0)
	assert supports_tab_overview() == adw_at_least(1, 4, 0)
	assert supports_switch_row() == adw_at_least(1, 4, 0)
	assert supports_toolbar_view() == adw_at_least(1, 4, 0)
	assert supports_banner() == adw_at_least(1, 3, 0)
}
