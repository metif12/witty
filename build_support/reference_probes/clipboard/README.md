The runner extracts the original MIME initializer, opinionated pasteboard reader,
clipboard-content C conversion, request discriminator, app read/write/confirmation/completion callbacks,
and controller confirmation completion from Ghostty's unchanged Swift source.
The runner checks the pinned source revision `6c0e02d1138d5376e4ac2f5e311b225494514a97`.
Each source file is byte-compared with the pinned Git object before extraction.
The original shell escape implementation is compiled unchanged. Small namespace,
surface, notification, and sheet state fixtures provide those methods' dependencies.

Run the native consumer fixture using the repository's managed native test flags,
with `WITTY_CLIPBOARD_MODEL_OUTPUT=/tmp/witty-clipboard.json`, then:

```sh
python3 build_support/reference_probes/clipboard/run.py \
  /Users/alex/code/3rd/ghostty /tmp/witty-clipboard.json
```

Both programs use unique named pasteboards and release them after the run. The V
fixture redirects only the app selection pasteboard lookup; neither program reads
or changes the system general or public selection pasteboard. Native alert results
are injected without showing a modal dialog. The source fixture completes the
notification through the original controller method without presenting a sheet.

Records cover empty/plain/URL content, URL priority and shell quoting, MIME UTIs
(including dynamic types for unknown, empty, and malformed MIME names), first-NUL and malformed UTF-8 conversion,
read completion, denied/approved writes, approved plain-text-only publication,
and malformed read-confirmation/invalid-request early returns. The source's raw
MIME fallback on a failed UTType lookup is translated; these host fixtures all
produce UTTypes, so they do not exercise that fallback. This validates content and callback
policy; it does not claim source SwiftUI sheet rendering or asynchronous timing.
