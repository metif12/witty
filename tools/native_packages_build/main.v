module main

import build_support
import os

fn main() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	cfg := build_support.init_config(root, os.args[1..]) or {
		eprintln(err)
		exit(1)
	}
	driver := build_support.Driver{ cfg: cfg }
	cc := build_support.NativeCompileOptions{ compiler: 'clang', arguments: cfg.sdk_arguments() or {
		eprintln(err)
		exit(1)
	} }
	cxx := build_support.NativeCompileOptions{ compiler: 'clang++', arguments: cfg.sdk_arguments() or {
		eprintln(err)
		exit(1)
	} }
	for step in cfg.steps {
		path := match step {
			'cimgui' { driver.build_cimgui(cxx) or {
				eprintln(err)
				exit(1)
			} }
			'zlib' {
				driver.build_zlib(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			'libpng' {
				driver.build_png(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			'freetype' {
				driver.build_freetype(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			'libxml2' {
				driver.build_libxml2(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			'fontconfig' {
				driver.build_fontconfig(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			'harfbuzz' {
				driver.build_harfbuzz(cxx) or {
					eprintln(err)
					exit(1)
				}
			}
			'oniguruma' {
				driver.build_oniguruma(cc) or {
					eprintln(err)
					exit(1)
				}
			}
			else {
				eprintln('unknown native package ${step}')
				exit(1)
			}
		}
		println(path)
	}
}
