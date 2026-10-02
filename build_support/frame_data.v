module build_support

import os

// GhosttyFrameData.distResources always schedules the source's C generator
// for the host, independently of the application target.
pub fn (d Driver) generate_frame_data() !string {
	host := Driver{
		cfg: Config{
			...d.cfg
			target: host_target()
			mode:   .release_fast
		}
	}
	mut command := [os.getenv_opt('CC') or { 'clang' }]
	command << host.cfg.sdk_arguments()!
	exe := d.cache_path('host', 'framegen')
	os.mkdir_all(os.dir(exe))!
	command << [os.join_path(d.cfg.root, 'build_assets', 'framegen', 'main.c')]
	if d.cfg.system_libraries['zlib'] {
		command << '-lz'
	} else {
		command << '-I' + d.native_package('zlib')!
		command << host.build_zlib(NativeCompileOptions{
			compiler:  os.getenv_opt('CC') or { 'clang' }
			arguments: host.cfg.sdk_arguments()!
		})!
	}
	command << ['-o', exe]
	checked_process(d.cfg.root, command)!
	output := d.cache_path('generated', 'framedata.compressed')
	os.mkdir_all(os.dir(output))!
	checked_process(d.cfg.root, [exe, os.join_path(d.cfg.root, 'build_assets', 'framegen', 'frames'),
		output])!
	return output
}

// The original dist-resource path is used only outside Git checkouts.
pub fn (d Driver) frame_data() !string {
	distributed := os.join_path(d.cfg.root, 'build_assets', 'framegen', 'framedata.compressed')
	if os.exists(distributed) && !os.exists(os.join_path(d.cfg.root, '.git')) { return distributed }
	return d.generate_frame_data()
}
