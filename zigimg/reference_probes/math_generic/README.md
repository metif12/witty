# Generic matrix source comparison

`verify_math_generic_reference.py` compares the unchanged pinned
`src/math.zig` with V `Matrix[B]` in dimensions 1, 2, 3, 4, 5, and 8.
The 2/3/4 cases also exercise the existing named matrix types; the 5x5
cases exercise an independently named fixed-array alias. The corpus
covers arithmetic, signed zero, subnormals, infinities, NaNs, zero
pivots, and unchanged input values. Non-NaN bits and NaN occurrence
must match. Three invalid-shape checks also run in production mode.

The V type factory uses explicit named fixed arrays:

```v
type Rows5 = [5][5]f32
type Flat25 = [25]f32

matrix := zigimg.Matrix.from_array[Rows5, Flat25](values)
identity := zigimg.Matrix.identity[Rows5]()
product := matrix.mul(identity)
vector_result := matrix.mul_vector(vector)
// The fixed-vector adapter also infers complete matrix storage:
same_result := zigimg.matrix_mul_vector_fixed(matrix, vector)
```

Both storage and flat input aliases must directly name their inline
fixed arrays. V 0.5.2 cannot inspect another alias layer, reliably
forward these static factory calls from an enclosing generic function,
or represent zero-length fixed arrays. These are boundaries of the V
factory adaptation. V fixed-array layout also differs from the source
SIMD-vector ABI. Arithmetic retains source f32 rounding and its
elimination without pivoting.

The pinned V compiler reuses fixed-array bounds metadata across generic
specializations. The private arithmetic helpers use direct array access
only inside loops bounded by the validated dimension; each public
generic operation checks square f32 storage, and constructors/vector
operations check their input dimensions before entering those helpers.
These explicit panic checks remain active under `-prod`.

Run from the repository root, optionally adding `--v-prod`:

```sh
python3 zigimg/verify_math_generic_reference.py /path/to/locked/zigimg /path/to/zig /path/to/v
```
