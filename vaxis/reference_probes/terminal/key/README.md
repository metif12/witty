# Terminal key encoding

```sh
python3 vaxis/verify_terminal_key_reference.py /path/to/vaxis /path/to/zig /path/to/v
python3 vaxis/verify_terminal_key_reference.py /path/to/vaxis /path/to/zig /path/to/v --v-prod --zig-mode ReleaseSafe
```

The runner verifies the complete unchanged vaxis `src` hash
`bc71386c999b4ba88faf0096c55f8b7af2bdb0c02cdb98ab9bf9455633c514ed`
and the exact locked uucode package using the shared classic-widget build helper.
The native consumer is added as a new file inside the copied source package;
it calls the public `encode` function from the internally imported `key.zig`.
Pinned dependency bodies stay unchanged. The default macOS 14 target avoids
Zig 0.15.2's newer-host libc boundary; `--target` and `--uucode` can override it.

The 59,072 returning cases compare emitted bytes, pending writer length, and
`WriteFailed` results. They cover all ASCII codepoints, ordinary/keypad/function
key ranges, all 256 modifier masks, generated text including empty/NUL/malformed
UTF-8 bytes, fixed buffers of 0–10 bytes, preexisting buffered bytes, ignored
shifted/base-layout fields, and releases with every Kitty flag mask. Thirty-one
isolated nonzero-mask Kitty presses must retain the source unreachable trap,
including in V production builds. Returning paths, domain errors, and an
unexpected marker are rejected explicitly. The returning output SHA256 is
`fef07475371a26194ffa5a396745016d36ef5eb33b005ef1a47f115888a96d6a`.

`terminal_key_encode(mut zigimg.WriteStream, Key, bool, KittyFlags)` preserves
source write ordering and partial output on errors. The writer representation
uses the repository's translated stream adapter. V's optional `string` retains
the source byte-slice content, including NUL and invalid UTF-8. Inputs remain
within the source `u21` codepoint and packed `u5` flag domains.

This source encoder implements legacy presses only. Nonzero Kitty masks on a
press are inherited traps; releases emit nothing. Unsupported keys emit
nothing. CTRL+ALT lowercase letters produce ESC plus the **decimal digits** of
the control value (`j` produces `1b3130`), then continue to the unsupported-key
return. The comparison preserves these source behaviors rather than filling
its protocol TODOs.
