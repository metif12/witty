module gtk

// version_linux.v - GTK and libadwaita runtime version detection.
//
// Translated from ghostty/src/apprt/gtk/gtk_version.zig and adw_version.zig.
//
// The Zig originals split their version checks into a `comptime` variant
// (checking header macros, `atLeast`) and a `runtime` variant (querying the
// linked library, `runtimeAtLeast`). Because V does not have Zig's
// comptime-vs-runtime `@inComptime()` distinction we express both against the
// actual runtime version reported by the library. The header-macro constants
// are still exposed as `comptime_version` for parity/logging.

// --- SemanticVersion ------------------------------------------------------

// SemVer is a simple major.minor.patch version triple, mirroring Zig's
// std.SemanticVersion for the pieces used by the version checks.
pub struct SemVer {
pub:
	major u16
	minor u16
	patch u16
}

// order returns -1, 0, or 1 comparing `a` to `b` (like Zig's `.order`).
pub fn (a SemVer) order(b SemVer) int {
	if a.major != b.major {
		return if a.major < b.major { -1 } else { 1 }
	}
	if a.minor != b.minor {
		return if a.minor < b.minor { -1 } else { 1 }
	}
	if a.patch != b.patch {
		return if a.patch < b.patch { -1 } else { 1 }
	}
	return 0
}

// str formats the version as "major.minor.patch".
pub fn (v SemVer) str() string {
	return '${v.major}.${v.minor}.${v.patch}'
}

// --- GTK version C bindings -----------------------------------------------

fn C.gtk_get_major_version() u32

fn C.gtk_get_minor_version() u32

fn C.gtk_get_micro_version() u32

// --- GTK version API ------------------------------------------------------

// gtk_comptime_version is the version of GTK the headers were built against.
pub const gtk_comptime_version = SemVer{
	major: u16(C.GTK_MAJOR_VERSION)
	minor: u16(C.GTK_MINOR_VERSION)
	patch: u16(C.GTK_MICRO_VERSION)
}

// gtk_runtime_version returns the version of the GTK library we are linked
// against at runtime.
pub fn gtk_runtime_version() SemVer {
	return SemVer{
		major: u16(C.gtk_get_major_version())
		minor: u16(C.gtk_get_minor_version())
		patch: u16(C.gtk_get_micro_version())
	}
}

// gtk_log_version reports the build and runtime versions during application
// construction. Mirrors `gtk_version.logVersion`.
pub fn gtk_log_version() {
	eprintln('[info] gtk: GTK version build=${gtk_comptime_version} runtime=${gtk_runtime_version()}')
}

// gtk_at_least verifies that the GTK version is at least the given version.
//
// Faithful to `gtk_version.atLeast`: because in V we cannot disable code
// generation based on the header version the way Zig's inline comptime check
// does, this always consults the runtime version.
pub fn gtk_at_least(major u16, minor u16, patch u16) bool {
	return gtk_runtime_at_least(major, minor, patch)
}

// gtk_runtime_at_least verifies that the runtime GTK version is at least the
// given version. Mirrors `gtk_version.runtimeAtLeast`.
pub fn gtk_runtime_at_least(major u16, minor u16, patch u16) bool {
	rt := gtk_runtime_version()
	return rt.order(SemVer{ major: major, minor: minor, patch: patch }) != -1
}

// gtk_runtime_until returns true if the runtime GTK version is *older* than
// the given version. Mirrors `gtk_version.runtimeUntil`.
pub fn gtk_runtime_until(major u16, minor u16, patch u16) bool {
	rt := gtk_runtime_version()
	return rt.order(SemVer{ major: major, minor: minor, patch: patch }) == -1
}

// --- libadwaita version C bindings ----------------------------------------

fn C.adw_get_major_version() u32

fn C.adw_get_minor_version() u32

fn C.adw_get_micro_version() u32

// adw_comptime_version is the libadwaita version the headers were built
// against.
pub const adw_comptime_version = SemVer{
	major: u16(C.ADW_MAJOR_VERSION)
	minor: u16(C.ADW_MINOR_VERSION)
	patch: u16(C.ADW_MICRO_VERSION)
}

// adw_runtime_version returns the version of libadwaita we are linked against.
pub fn adw_runtime_version() SemVer {
	return SemVer{
		major: u16(C.adw_get_major_version())
		minor: u16(C.adw_get_minor_version())
		patch: u16(C.adw_get_micro_version())
	}
}

// adw_log_version reports the build and runtime versions during application
// construction. Mirrors `adw_version.logVersion`.
pub fn adw_log_version() {
	eprintln('[info] gtk: libadwaita version build=${adw_comptime_version} runtime=${adw_runtime_version()}')
}

// adw_at_least verifies that the running libadwaita version is at least the
// given version. Mirrors `adw_version.atLeast`.
pub fn adw_at_least(major u16, minor u16, patch u16) bool {
	return adw_runtime_at_least(major, minor, patch)
}

// adw_runtime_at_least verifies that the runtime libadwaita version is at
// least the given version. Mirrors `adw_version.runtimeAtLeast`.
pub fn adw_runtime_at_least(major u16, minor u16, patch u16) bool {
	rt := adw_runtime_version()
	return rt.order(SemVer{ major: major, minor: minor, patch: patch }) != -1
}

// --- libadwaita feature detection helpers ---------------------------------
// Translated from the `supports*` helpers in adw_version.zig.

// adw_supports_dialogs reports whether AdwDialog/AdwAlertDialog are available
// (libadwaita 1.5+).
pub fn adw_supports_dialogs() bool {
	return adw_at_least(1, 5, 0)
}

// adw_supports_tab_overview reports whether AdwTabOverview is available (1.4+).
pub fn adw_supports_tab_overview() bool {
	return adw_at_least(1, 4, 0)
}

// adw_supports_switch_row reports whether AdwSwitchRow is available (1.4+).
pub fn adw_supports_switch_row() bool {
	return adw_at_least(1, 4, 0)
}

// adw_supports_toolbar_view reports whether AdwToolbarView is available (1.4+).
pub fn adw_supports_toolbar_view() bool {
	return adw_at_least(1, 4, 0)
}

// adw_supports_banner reports whether AdwBanner is available (1.3+).
pub fn adw_supports_banner() bool {
	return adw_at_least(1, 3, 0)
}
