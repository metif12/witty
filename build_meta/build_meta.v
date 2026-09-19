// Build metadata shared by the executable and translated library modules.
// The pinned Ghostty source supplies this through its generated build_config
// module. GitVersion detects the main branch and seven-character commit hash,
// producing this semantic version at the reference commit.
module build_meta

pub const version_string = '1.3.0-main+6c0e02d'

// Release channel of the pinned Ghostty source translated by this tree.
pub const release_channel = 'tip'

// GitVersion's short_hash at the pinned Ghostty reference commit.
pub const commit_hash = '6c0e02d'
