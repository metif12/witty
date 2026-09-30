module main

import zigimg

fn main() {
	mut stream := zigimg.ReadStream.init_memory('#define w 8\n'.bytes())
	zigimg.XBM.format_detect(mut stream) or { panic(err) }
	panic('XBM detection unexpectedly returned')
}
