module build_support

import os

// These target and optimization arguments configure the native compiler for
// the artifact, rather than accidentally compiling dependencies for the host.
pub fn (cfg Config) native_arguments() []string {
	mut args := []string{}
	arch := if cfg.target.arch == 'aarch64' { 'arm64' } else { cfg.target.arch }
	if cfg.target.darwin() {
		platform := if cfg.target.os == 'macos' { 'macosx' } else { 'ios' }
		args << ['-target', '${arch}-apple-${platform}${cfg.target.minimum}${if cfg.target.abi == 'simulator' {
			'-simulator'
		} else {
			''
		}}']
	} else if cfg.target.os == 'linux' {
		args << ['-target', '${cfg.target.arch}-unknown-linux-${if cfg.target.abi == '' {
			'gnu'
		} else {
			cfg.target.abi
		}}']
	} else if cfg.target.os == 'windows' {
		args << ['-target', '${cfg.target.arch}-w64-windows-${if cfg.target.abi == '' {
			'gnu'
		} else {
			cfg.target.abi
		}}']
	} else if cfg.target.os == 'freebsd' {
		args << ['-target', '${cfg.target.arch}-unknown-freebsd']
	} else if cfg.target.wasm() {
		args << ['-target', '${cfg.target.arch}-unknown-${cfg.target.os}']
	}
	args << match cfg.mode {
		.debug { ['-O0', '-g'] }
		.release_safe, .release_fast { ['-O2'] }
		.release_small { ['-Os'] }
	}
	return args
}

// Target.ptrBitWidth in Zig's native package builders. Unsupported widths
// remain an explicit build failure rather than silently assuming 32 bits.
pub fn (target Target) pointer_size() !int {
	return match target.arch {
		'aarch64', 'aarch64_be', 'x86_64', 'riscv64', 'powerpc64', 'powerpc64le', 'mips64',
		'mips64el',
		's390x', 'sparc64', 'wasm64', 'loongarch64', 'bpfel', 'bpfeb', 'nvptx64', 'amdgcn' {
			8
		}
		'x86', 'i386', 'arm', 'armeb', 'thumb', 'thumbeb', 'riscv32', 'powerpc', 'powerpcle', 'mips',
		'mipsel', 'sparc', 'wasm32', 'hexagon', 'm68k', 'csky', 'xtensa', 'nvptx' {
			4
		}
		else { return error('unsupported native package pointer width for ${target.arch}') }
	}
}

// apple-sdk adds the artifact SDK independently of the host tools' target.
pub fn (cfg Config) sdk_arguments() ![]string {
	mut args := cfg.native_arguments()
	if cfg.target.darwin() {
		sdk := if cfg.target.os == 'macos' {
			'macosx'
		} else if cfg.target.abi == 'simulator' {
			'iphonesimulator'
		} else {
			'iphoneos'
		}
		path := checked_process(cfg.root, ['xcrun', '--sdk', sdk, '--show-sdk-path'])!.trim_space()
		args << ['-isysroot', path]
	}
	if cfg.target.cpu == 'apple_a17' { args << '-mcpu=apple-a17' }
	if value := os.getenv_opt('WITTY_SYSROOT') { args << ['--sysroot', value] }
	return args
}
