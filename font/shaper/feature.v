module shaper

import font.feature

// Shared source parser used by every HarfBuzz/CoreText call path.
pub type Feature = feature.Feature
pub type FeatureReader = feature.FeatureReader
pub type FeatureList = feature.FeatureList
pub const default_features = feature.default_features
