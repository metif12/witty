// Generated build options are supplied by the translated build driver.
// Unconfigured compiler invocations use the source's unknown-development
// fallback. GitVersion detection runs in the build driver, including worktrees.
module build_meta

pub const version_string = $d('app_version_string', '1.3.0-dev+0000000')

// Release channel of the pinned Ghostty source translated by this tree.
pub const release_channel = $d('release_channel', 'tip')

pub const commit_hash = $d('commit_hash', '0000000')
pub const git_branch = $d('git_branch', 'dev')
pub const git_changes = $d('git_changes', false)

// Provenance of the translated original is separate from the V build identity.
pub const reference_commit = '6c0e02d1138d5376e4ac2f5e311b225494514a97'
