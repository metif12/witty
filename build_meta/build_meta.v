// Build metadata shared by the executable and translated library modules.
// The pinned Ghostty source supplies this value through its generated
// build_config module from build.zig.zon's package version.
module build_meta

pub const version_string = '1.3.0-dev'
