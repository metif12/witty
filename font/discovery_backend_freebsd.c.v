module font

// Ghostty selects its discovery implementation from the build-time font
// backend. The Witty FreeBSD build uses Fontconfig.
pub type Discover = FontconfigDiscovery

pub type DiscoverIterator = FcDiscoverIterator
