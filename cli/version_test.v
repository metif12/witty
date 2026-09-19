module cli

import apprt
import build_meta
import font
import renderer
import v.util.version as vversion

fn test_version_output_reports_translated_build_metadata() {
	output := version_output(false)
	assert output.starts_with('Ghostty ${build_meta.version_string}\n\nVersion\n')
	assert output.contains('  - version: ${build_meta.version_string}\n')
	assert output.contains('  - channel: ${build_meta.release_channel}\n')
	assert output.contains('  - V version     : ${vversion.v_version}\n')
	assert output.contains('  - app runtime   : ${runtime_name(apprt.Runtime.default())}\n')
	assert output.contains('  - font engine   : ${font.Backend.default_()}\n')
	assert output.contains('  - renderer      : ${renderer.Backend.default_()}\n')
	assert output.contains('  - libxev        : unavailable\n')
	assert !output.contains(@VEXE)
}

fn test_version_output_hyperlink_requires_commit_metadata() {
	assert build_meta.commit_hash == '6c0e02d'
	plain := version_output(false)
	tty := version_output(true)
	assert !plain.contains('\x1b]8;;')
	assert tty.starts_with('\x1b]8;;https://github.com/ghostty-org/ghostty/commit/6c0e02d\x1b\\Ghostty ${build_meta.version_string}\n\n')
	assert tty.contains('\x1b]8;;\x1b\\Version\n')
}
