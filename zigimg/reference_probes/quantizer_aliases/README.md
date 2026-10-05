The alias matrix runs all eleven built-in RGB(A) inputs through quantizer add,
palette creation, quantizer/node lookup, direct node accumulation, and leaf lookup
with a level above eight. Zig aliases preserve their original type; V's one-layer
aliases must select the same built-in conversions. The matrix includes packed
channels, 16-bit low bits, alpha premultiplication, NaN, infinity, and zero alpha.

Run the source-hashed quantizer runner with the pinned V compiler to compare 2,816
records and sixteen checked failure cases:

```sh
python3 zigimg/verify_quantizer_reference.py SOURCE ZIG V
python3 zigimg/verify_quantizer_reference.py SOURCE ZIG V --v-prod --zig-mode ReleaseSafe
```

The original quantizer/color sources are copied unchanged after hash checks.
The numeric matrices retain their original hashes. `removeLeaves` additions wrap
by design; add accumulation, averages, levels, palette capacity, and repeated
reduction remain checked in both V build modes. The bound probes reject returned
domain errors, preventing an erased color-level guard from passing as a trap.
Arbitrary custom source color adapters and private source context representations
are not expanded by this alias checkpoint.
