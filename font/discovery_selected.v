module font

// V representation of discovery.zig's compile-time backend switch. FreeType
// and WebCanvas deliberately have no discovery backend in the source.
pub struct Discover {
pub:
	backend Backend
mut:
	fontconfig FontconfigDiscovery
}

pub fn Discover.init() Discover {
	return Discover.init_backend(Backend.selected_())
}

pub fn Discover.init_backend(backend Backend) Discover {
	if backend.has_fontconfig() {
		return Discover{
			backend:    backend
			fontconfig: FontconfigDiscovery.init()
		}
	}
	return Discover{
		backend: backend
	}
}

pub fn (mut self Discover) deinit() {
	if self.backend.has_fontconfig() { self.fontconfig.deinit() }
	// CoreText's source discovery object owns no persistent native state.
}

pub fn (self &Discover) discover(desc Descriptor) !DiscoverIterator {
	if self.backend.has_fontconfig() {
		return DiscoverIterator{
			backend:    self.backend
			fontconfig: self.fontconfig.discover(desc)!
		}
	}
	if self.backend.has_coretext() {
		$if macos {
			native := CoreTextDiscovery.init()
			iterator := native.discover(desc)!
			return DiscoverIterator{
				backend:  self.backend
				coretext: &CtDiscoverIterator{
					...iterator
				}
			}
		} $else {
			return error('CoreText discovery requires macOS')
		}
	}
	return DiscoverIterator{
		backend: self.backend
	}
}

pub fn (self &Discover) discover_fallback(mut collection Collection, desc Descriptor) !DiscoverIterator {
	if self.backend.has_fontconfig() {
		return DiscoverIterator{
			backend:    self.backend
			fontconfig: self.fontconfig.discover_fallback(mut collection, desc)!
		}
	}
	if self.backend.has_coretext() {
		$if macos {
			native := CoreTextDiscovery.init()
			iterator := native.discover_fallback(mut collection, desc)!
			return DiscoverIterator{
				backend:  self.backend
				coretext: &CtDiscoverIterator{
					...iterator
				}
			}
		} $else {
			return error('CoreText discovery requires macOS')
		}
	}
	return DiscoverIterator{
		backend: self.backend
	}
}

pub struct DiscoverIterator {
mut:
	backend    Backend
	fontconfig FcDiscoverIterator
	coretext   voidptr = unsafe { nil }
}

pub fn (mut self DiscoverIterator) next() !DeferredFaceValue {
	if self.backend.has_fontconfig() { return self.fontconfig.next() }
	if self.backend.has_coretext() {
		$if macos {
			mut native := unsafe { &CtDiscoverIterator(self.coretext) }
			return native.next()
		} $else {
			return error('CoreText discovery requires macOS')
		}
	}
	return DeferredFaceValue{}
}

pub fn (mut self DiscoverIterator) deinit() {
	if self.backend.has_fontconfig() { self.fontconfig.deinit() }
	if self.backend.has_coretext() {
		$if macos {
			if !isnil(self.coretext) {
				mut native := unsafe { &CtDiscoverIterator(self.coretext) }
				native.deinit()
				self.coretext = unsafe { nil }
			}
		}
	}
}
