module build_support

fn test_source_version_tag_and_branch_rules() {
	assert version_from_git('1.3.0', GitVersion{ branch: 'main', short_hash: '1234567' })! == '1.3.0-main+1234567'
	assert version_from_git('1.3.0', GitVersion{
		branch:     'main'
		short_hash: '1234567'
		changes:    true
	})! == '1.3.0-main+1234567'
	assert version_from_git('1.3.0', GitVersion{ branch: 'main', short_hash: '1234567', tag: 'tip' })! == '1.3.0-main+1234567'
	assert version_from_git('1.3.0', GitVersion{ tag: 'v1.3.0' })! == '1.3.0'
	version_from_git('1.3.0', GitVersion{ tag: 'v1.2.3' }) or {
		assert err.msg().contains('tagged releases')
		return
	}
	assert false
}
