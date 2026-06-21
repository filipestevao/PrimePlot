// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

#[derive(Clone, Debug)]
pub struct Point2D {
    pub x: f64,
    pub y: f64,
}

/// Generates a complex dataset mimicking scientific data (e.g., XRD, Spectroscopy)
/// combining multiple Gaussian peaks and random noise.
pub fn generate_scientific_dataset(num_points: usize) -> Vec<Point2D> {
    let mut data = Vec::with_capacity(num_points);
    let x_start = 10.0;
    let x_end = 90.0;
    let step = (x_end - x_start) / (num_points as f64);

    // Mock peaks: (center, amplitude, width)
    let peaks: [(f64, f64, f64); 5] = [
        (30.0, 80.0, 2.0),
        (31.5, 40.0, 1.5),
        (45.0, 20.0, 5.0),
        (60.0, 60.0, 3.0),
        (75.0, 15.0, 4.0),
    ];

    let mut x = x_start;
    for i in 0..num_points {
        let mut y = 5.0; // Baseline

        for &(center, amp, width) in &peaks {
            let exponent = -((x - center).powi(2)) / (2.0 * width.powi(2));
            y += amp * exponent.exp();
        }

        // Add some high-frequency pseudo-random noise
        // A simple deterministic pseudo-random generator based on index
        let noise = ((i as f64 * 13.0).sin() + (i as f64 * 29.0).cos()) * 1.5;
        y += noise;

        data.push(Point2D { x, y });
        x += step;
    }

    data
}
