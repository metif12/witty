module openurl

// Kind identifies the type of data at a URL. Ghostty declares this as
// apprt.action.OpenUrl.Kind with c_int backing; this cycle-free leaf lets the
// translated OS opener consume that exact type through the V module boundary.
pub enum Kind as i32 {
	unknown
	text
	html
}
