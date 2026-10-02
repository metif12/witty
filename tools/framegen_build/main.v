module main

import build_support
import os

fn main() {
	root := os.real_path(os.join_path(os.dir(@FILE), '..', '..'))
	cfg := build_support.init_config(root, os.args[1..]) or {
		eprintln(err)
		exit(1)
	}
	driver := build_support.Driver{
		cfg: cfg
	}
	println(driver.generate_frame_data() or {
		eprintln(err)
		exit(1)
	})
}
