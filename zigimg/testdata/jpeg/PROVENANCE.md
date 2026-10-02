These regression images were generated for this translation audit using Pillow
11.3.0/libjpeg from deterministic synthetic pixel values. They contain no
external photographs. The generator and unchanged-source differential runner
are in `zigimg/verify_jpeg_reference.py`.

- `grayscale-baseline.jpg`: 8×8 grayscale, baseline, quality 90.
- `rgb-baseline.jpg`: 17×3 RGB, baseline, 4:2:2, quality 90.
- `rgb-progressive-restart.jpg`: 32×32 RGB, progressive, 4:2:2, one-block restart
  intervals, quality 90.

Expected pixel hashes are produced by the JPEG implementation in the locked
zigimg dependency `d7b7ab0ba0899643831ef042bd73289510b39906`, not Pillow's decoder.
The production implementation is translated V; the Zig probe is validation only.
