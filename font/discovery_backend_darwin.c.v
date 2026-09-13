module font

// Ghostty selects its discovery implementation from the build-time font
// backend. The Witty macOS build uses CoreText.
pub type Discover = CoreTextDiscovery

pub type DiscoverIterator = CtDiscoverIterator
