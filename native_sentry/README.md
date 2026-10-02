# Native crash capture dependencies

`build(repo_root, Options)![]string` translates Ghostty's
`pkg/sentry/build.zig`, `pkg/breakpad/build.zig`, and `SharedDeps` selection of
Breakpad with the SDK's none transport. The V callback is the source local
envelope transport; no network transport is linked.

The returned archives, in link order, are
`.witty-build/native/libsentry.a` and `.witty-build/native/libbreakpad.a`.
Options select the C and C++ compiler, target OS, and compiler arguments.
The production build passes target, SDK, minimum-version, and optimization
arguments before compilation. Existing archives are replaced on each build.

macOS and iOS linkage needs libc++, Objective-C, and Foundation; Linux needs
libstdc++. Sentry is enabled by default on macOS/iOS, can be enabled with
`-d sentry` on Linux, and disabled with `-d no_sentry`. Windows is disabled
as in the original runtime.
