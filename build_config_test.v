module main

fn test_build_config_source_enum_layouts_and_ordinals() {
	assert sizeof(ReleaseChannel) == 1
	assert [ReleaseChannel.tip, .stable].map(u8(it)) == [u8(0), 1]
	assert release_channel == .tip

	assert sizeof(Artifact) == 1
	assert [Artifact.exe, .lib, .wasm_module].map(u8(it)) == [u8(0), 1, 2]
	assert artifact == .exe
}
