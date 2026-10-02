module build_support

import crypto.sha256
import os

// macos/.../swiftpm/Package.resolved pins Sparkle 2.8.0 at this revision.
// Its Package.swift is a binary target with this URL and SHA-256 checksum.
// This is the same native framework dependency used by the source updater.
pub const sparkle_revision = '9a1d2a19d3595fcf8d9c447173f9a1687b3dcadb'
pub const sparkle_checksum = 'dfb69c5b4d040a162c8076817e96ef635f5627f3af606222376c870e03b9f8ca'

pub fn (d Driver) build_sparkle() !string {
	archive := d.cache_path('downloads', 'Sparkle-2.8.0.zip')
	if !os.exists(archive) {
		os.mkdir_all(os.dir(archive))!
		checked_process(d.cfg.root, ['curl', '--fail', '--location', '--silent', '--show-error',
			'--output', archive, 'https://github.com/sparkle-project/Sparkle/releases/download/2.8.0/Sparkle-for-Swift-Package-Manager.zip'])!
	}
	data := os.read_bytes(archive)!
	if sha256.sum(data).hex() != sparkle_checksum { return error('Sparkle binary target checksum mismatch') }
	path := d.cache_path('native', 'Sparkle.xcframework')
	if !os.exists(path) {
		os.mkdir_all(os.dir(path))!
		checked_process(d.cfg.root, ['unzip', '-q', archive, 'Sparkle.xcframework/*', '-d', os.dir(path)])!
	}
	// The pinned package has one universal macOS slice. The bundle contains
	// symlinks and XPC services; keep it intact when installing or linking.
	return os.join_path(path, 'macos-arm64_x86_64', 'Sparkle.framework')
}
