The input table was emitted by the unchanged pinned uucode dependency `31655fba3c638229989cc524363ef5e3c7b580c1` (Zig package hash `uucode-0.1.0-ZZjBPicPTQDlG6OClzn2bPu7ICkkkyWrTB6aRsBr-A1E`) using Ghostty `6c0e02d1138d5376e4ac2f5e311b225494514a97` `src/build/uucode_config.zig`.

This is the dependency's **two-stage buildtime input**, not Ghostty's finished three-stage props/symbol tables. It retains 4352 u16 indices and 31744 records. Each little-endian u16 record stores width in bits 0–1, GraphemeBreakNoControl in bits 2–6, emoji variation-sequence base in bit 7, and symbol in bit 8. The V generators visit the full u21 domain and run the translated original LUT generator against these inputs.

SHA-256: `756ffe2c8f8778509a3a37706f7767f9c8cfdcf02d436bb90f46f29136cc9f40`.

The accompanying reference probe compiles the unchanged dependency generator, dumps its stage1/stage2 data, and can regenerate this file independently of Witty's runtime tables.
