module shaper

import font

// The concrete run iterator lives beside font.Shaper because V modules cannot
// express Ghostty's nested `font.Shaper.RunIteratorHook` type without creating
// an import cycle. Re-exporting it here keeps the source-module API while all
// callers share the production implementation.
pub type RunIterator2 = font.RunIterator
