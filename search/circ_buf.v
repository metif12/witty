module search

// Concrete instantiations of Ghostty's datastruct.CircBuf for the search
// sliding window. DataBuf uses a zero byte as its default and MetaBuf uses an
// empty Meta. All circular-buffer behavior lives in the shared translation of
// src/datastruct/circ_buf.zig.

import datastruct
import highlight
import terminal

// Meta stores the page identity and the byte-to-cell map for one page in the
// sliding search window.
struct Meta {
mut:
	node     &terminal.PageNode = unsafe { nil }
	serial   u64
	cell_map []highlight.Coordinate
}

type DataBuf = datastruct.CircBuf[u8]

type MetaBuf = datastruct.CircBuf[Meta]

fn DataBuf.new() DataBuf {
	return datastruct.new_circ_buf[u8](0, 0)
}

fn MetaBuf.new() MetaBuf {
	return datastruct.new_circ_buf[Meta](0, Meta{})
}
