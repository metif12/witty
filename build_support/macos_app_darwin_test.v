module build_support

import os

fn test_source_project_plist_metadata_and_services() ! {
	directory := os.join_path(os.temp_dir(), 'witty-macos-plist-${os.getpid()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	for mode in [Mode.debug, .release_safe] {
		driver := Driver{cfg: Config{root: @VMODROOT, mode: mode}}
		path := os.join_path(directory, '${mode}.plist')
		driver.write_macos_plist(path)!
		checked_process(@VMODROOT, ['plutil', '-lint', path])!
		text := checked_process(@VMODROOT, ['plutil', '-convert', 'json', '-o', '-', path])!
		identifier := checked_process(@VMODROOT, ['plutil', '-extract', 'CFBundleIdentifier', 'raw', '-o', '-', path])!.trim_space()
		assert identifier == if mode == .debug { 'com.mitchellh.ghostty.debug' } else { 'com.mitchellh.ghostty' }
		assert text.contains('"CFBundleExecutable":"ghostty"')
		assert text.contains('"CFBundlePackageType":"APPL"')
		public_key := checked_process(@VMODROOT, ['plutil', '-extract', 'SUPublicEDKey', 'raw', '-o', '-', path])!.trim_space()
		assert public_key == 'wsNcGf5hirwtdXMVnYoxRIX/SqZQLMOsYlD3q3imeok='
		assert !text.contains('\x24(INFOPLIST_KEY_CFBundleDisplayName)')
		assert text.contains('New Ghostty${if mode == .debug { '[DEBUG]' } else { '' }} Tab Here')
		assert text.contains('public.unix-executable')
	}
}
