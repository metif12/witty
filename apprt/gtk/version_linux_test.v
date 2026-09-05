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
