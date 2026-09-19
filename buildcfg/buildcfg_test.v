module buildcfg

fn test_release_channel_layout_and_source_ordinals() {
	assert sizeof(ReleaseChannel) == 1
	assert [ReleaseChannel.tip, .stable].map(u8(it)) == [u8(0), 1]
}

fn test_packaging_feature_flags_follow_build_defines() {
	assert flatpak == $if flatpak ? { true } $else { false }
	assert snap == $if snap ? { true } $else { false }
}

fn test_terminal_features_are_synthesized_from_oniguruma() {
	assert oniguruma == $if no_oniguruma ? { false } $else { true }
	assert kitty_graphics == oniguruma
	assert tmux_control_mode == oniguruma
}
