module shaper

import font

// Runtime representation of the source's font.shape.Shaper compile-time
// switch. Each branch owns the existing translated backend implementation.
pub struct NativeShaper {
pub:
	backend font.Backend
mut:
	harfbuzz   HbShaper
	coretext   voidptr = unsafe { nil }
	noop       NoopShaper
	web_canvas WebCanvasShaper
}

pub fn NativeShaper.init(opts font.ShaperOptions) !NativeShaper {
	return NativeShaper.init_backend(font.Backend.selected_(), opts)
}

pub fn NativeShaper.init_backend(backend font.Backend, opts font.ShaperOptions) !NativeShaper {
	mut result := NativeShaper{
		backend: backend
	}
	match backend {
		.coretext {
			$if macos {
				native := Shaper.init(opts)!
				result.coretext = &Shaper{
					...native
				}
			} $else {
				return error('CoreText shaping requires macOS')
			}
		}
		.coretext_noshape {
			result.noop = NoopShaper.init(opts)!
		}
		.web_canvas {
			result.web_canvas = WebCanvasShaper.init(opts)!
		}
		else {
			result.harfbuzz = HbShaper.init(opts)!
		}
	}

	return result
}

pub fn (mut self NativeShaper) deinit() {
	match self.backend {
		.coretext {
			$if macos {
				if !isnil(self.coretext) {
					mut native := unsafe { &Shaper(self.coretext) }
					native.deinit()
					self.coretext = unsafe { nil }
				}
			}
		}
		.coretext_noshape {
			self.noop.deinit()
		}
		.web_canvas {
			self.web_canvas.deinit()
		}
		else {
			self.harfbuzz.deinit()
		}
	}
}

pub fn (mut self NativeShaper) end_frame() {
	match self.backend {
		.coretext {
			$if macos {
				mut native := unsafe { &Shaper(self.coretext) }
				native.end_frame()
			}
		}
		.coretext_noshape {
			self.noop.end_frame()
		}
		.web_canvas {
			self.web_canvas.end_frame()
		}
		else {
			self.harfbuzz.end_frame()
		}
	}
}

pub fn (mut self NativeShaper) run_iterator(opts font.RunOptions) font.RunIterator {
	match self.backend {
		.coretext {
			$if macos {
				mut native := unsafe { &Shaper(self.coretext) }
				return native.run_iterator(opts)
			} $else {
				panic('CoreText shaping requires macOS')
			}
		}
		.coretext_noshape {
			return self.noop.run_iterator(opts)
		}
		.web_canvas {
			return self.web_canvas.run_iterator(opts)
		}
		else {
			return self.harfbuzz.run_iterator(opts)
		}
	}
}

pub fn (mut self NativeShaper) shape(run font.TextRun) ![]font.ShapeCell {
	match self.backend {
		.coretext {
			$if macos {
				mut native := unsafe { &Shaper(self.coretext) }
				return native.shape(run)
			} $else {
				return error('CoreText shaping requires macOS')
			}
		}
		.coretext_noshape {
			return self.noop.shape(run)
		}
		.web_canvas {
			return self.web_canvas.shape(run)
		}
		else {
			return self.harfbuzz.shape(run)
		}
	}
}
