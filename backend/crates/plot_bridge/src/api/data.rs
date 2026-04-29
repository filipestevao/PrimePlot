use core_math::{generate_scientific_dataset, Point2D as CorePoint2D};
use flutter_rust_bridge::frb;

/// A simple DTO for passing 2D points to Flutter.
/// Using #[frb(dart_metadata=...)] if we needed specific Dart names, but simple structs map cleanly.
#[derive(Clone, Debug)]
pub struct Point2D {
    pub x: f64,
    pub y: f64,
}

impl From<CorePoint2D> for Point2D {
    fn from(core_point: CorePoint2D) -> Self {
        Self {
            x: core_point.x,
            y: core_point.y,
        }
    }
}

/// Fetches a high-performance mock scientific dataset from the core math engine.
#[frb(sync)]
pub fn get_mock_scientific_data(num_points: usize) -> Vec<Point2D> {
    let core_data = generate_scientific_dataset(num_points);
    core_data.into_iter().map(|p| p.into()).collect()
}
