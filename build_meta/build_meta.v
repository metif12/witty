// Build metadata shared by the executable and translated library modules.
// The pinned Ghostty source supplies this value through its generated
// build_config module from build.zig.zon's package version.
module build_meta

pub const version_string = '1.3.0-dev'

// Release channel of the pinned Ghostty source translated by this tree.
pub const release_channel = 'tip'

// The generated Ghostty build config supplies this when commit metadata is
// available. Witty's current build does not generate a commit value.
pub const commit_hash = ''
