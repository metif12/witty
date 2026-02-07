module font

// Default DPI used as the base for scaling calculations.
pub const default_dpi = f32(72.0)

// Metrics holds font measurement data.
pub struct Metrics {
pub mut:
	cell_width    u32
	cell_height   u32
	cell_baseline u32
}

// DesiredSize represents the desired font size with DPI info.
pub struct DesiredSize {
pub mut:
	points f32
	xdpi   u32
	ydpi   u32
}

// SharedGridSet manages shared font grids across surfaces.
pub struct SharedGridSet {}

pub fn (s SharedGridSet) ref(config &DerivedConfig, size DesiredSize) !(GridKey, &Grid) {
	return GridKey{}, &Grid{
		metrics: Metrics{
			cell_width: 10
			cell_height: 20
			cell_baseline: 16
		}
	}
}

pub fn (s SharedGridSet) deref(key GridKey) {
	// stub: decrements reference count
	_ = key
}

pub struct GridKey {}

pub struct Grid {
pub:
	metrics Metrics
}

pub fn (g Grid) cell_size() CellSize {
	return CellSize{
		width: g.metrics.cell_width
		height: g.metrics.cell_height
	}
}

pub struct CellSize {
pub:
	width  u32
	height u32
}

pub struct DerivedConfig {}

pub fn DerivedConfig.init(config voidptr) !DerivedConfig {
	return DerivedConfig{}
}
