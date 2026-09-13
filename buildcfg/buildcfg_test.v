module buildcfg

fn test_release_channel_layout_and_source_ordinals() {
	assert sizeof(ReleaseChannel) == 1
	assert [ReleaseChannel.tip, .stable].map(u8(it)) == [u8(0), 1]
}
