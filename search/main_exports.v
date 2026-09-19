module search

// Public search namespace exported by terminal/search.zig. V modules flatten
// source files, so these aliases restore the short names from that namespace
// while retaining the descriptive implementation type names.
pub type Active = ActiveSearch

pub type PageList = PageListSearch

pub type Screen = ScreenSearch

pub type Viewport = ViewportSearch

pub type Thread = SearchThread
