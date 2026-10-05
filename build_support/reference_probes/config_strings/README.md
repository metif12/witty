This probe extracts the unchanged `title` and `windowTitleFontFamily` getters from
Ghostty's `macos/Sources/Ghostty/Ghostty.Config.swift`, compiles them with Swift,
and compares their results against Witty's actual native configuration projection.
The C lookup fixture supplies borrowed nullable strings; it does not replace the
two Swift getter bodies. The unchanged `Ghostty.Command` initializer also checks
the command palette title and description projections.

```sh
VEXE=/path/to/v WITTY_CONFIG_STRING_MODEL_OUTPUT=/tmp/witty-config-strings.json \
  /path/to/v -path "$PWD|@vlib|@vmodules" run tools/build test \
  -Dtest-filter=native_config_string_getters -Dsentry=false -Drenderer=opengl
python3 build_support/reference_probes/config_strings/run.py \
  /path/to/ghostty /tmp/witty-config-strings.json
```

Twenty nullable, valid, malformed UTF-8 and embedded-NUL inputs exercise both
getters, with all nineteen non-null inputs checking command palette strings.
`native_config_strings_darwin_test.v` also verifies that the projected
values reach a real AppKit window title and attributed title font. The managed
build driver runs that consumer case with `-Dtest-filter=native_config_strings`.
