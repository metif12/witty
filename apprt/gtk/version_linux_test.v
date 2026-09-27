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

fn test_at_least_never_exceeds_the_build_headers() {
	assert !gtk_at_least(gtk_comptime_version.major, gtk_comptime_version.minor,
		gtk_comptime_version.patch + 1)
	assert !adw_at_least(adw_comptime_version.major, adw_comptime_version.minor,
		adw_comptime_version.patch + 1)
}

fn test_runtime_until_is_the_inverse_of_runtime_at_least() {
	assert runtime_until(4, 17, 5) == !gtk_runtime_at_least(4, 17, 5)
}
