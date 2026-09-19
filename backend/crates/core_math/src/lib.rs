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

// ---------------------------------------------------------------------------
// Analytical function evaluation (meval backend)
// ---------------------------------------------------------------------------

/// Strips an optional `f(x) = ` / `y = ` prefix; callers may store the raw
/// inspector text including the prefix.
pub fn strip_equation_prefix(expr: &str) -> &str {
    match expr.find('=') {
        Some(pos) => expr[pos + 1..].trim(),
        None => expr.trim(),
    }
}

/// Parses `expr` once; Err carries a human-readable message for the UI.
pub fn parse_function(expr: &str) -> Result<meval::Expr, String> {
    let body = strip_equation_prefix(expr);
    if body.is_empty() {
        return Err("empty expression".to_string());
    }
    body.parse::<meval::Expr>()
        .map_err(|e| format!("parse error: {e}"))
}

/// Validates syntax without sampling (cheap; for inspector feedback).
pub fn validate_function(expr: &str) -> Result<(), String> {
    parse_function(expr).map(|_| ())
}

/// Evaluates `expr` over `x_values`. Invalid points (domain errors,
/// division by zero, overflow) become `f64::NAN`, which the canvas skips.
pub fn evaluate_function(expr: &str, x_values: &[f64]) -> Result<Vec<f64>, String> {
    let parsed = parse_function(expr)?;
    let func = parsed
        .bind("x")
        .map_err(|e| format!("unbound variable (use 'x'): {e}"))?;
    Ok(x_values
        .iter()
        .map(|&x| {
            if !x.is_finite() {
                return f64::NAN;
            }
            let y = func(x);
            if y.is_finite() { y } else { f64::NAN }
        })
        .collect())
}

/// Evenly spaced samples across `[x_min, x_max]` (`num` clamped ≥ 2).
pub fn sample_domain(x_min: f64, x_max: f64, num: usize) -> Vec<f64> {
    let n = num.clamp(2, 100_000);
    if !x_min.is_finite() || !x_max.is_finite() || x_max <= x_min {
        return Vec::new();
    }
    let step = (x_max - x_min) / (n - 1) as f64;
    (0..n).map(|i| x_min + step * i as f64).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn evaluates_damped_sine() {
        let xs = sample_domain(0.0, 20.0, 1001);
        let ys = evaluate_function("2.5 * sin(3.0 * x) * exp(-0.2 * x)", &xs).unwrap();
        assert_eq!(ys.len(), 1001);
        assert!((ys[0] - 0.0).abs() < 1e-12);
        assert!(ys.iter().any(|&y| y > 1.0));
        assert!(ys.iter().any(|&y| y < -0.1));
    }

    #[test]
    fn strips_prefix_and_rejects_garbage() {
        let xs = sample_domain(0.0, 1.0, 3);
        let a = evaluate_function("f(x) = x", &xs).unwrap();
        let b = evaluate_function("x", &xs).unwrap();
        assert_eq!(a, b);
        assert!(evaluate_function("sin(", &xs).is_err());
        assert!(evaluate_function("", &xs).is_err());
        assert!(validate_function("ln(x)").is_ok());
    }

    #[test]
    fn domain_errors_become_nan() {
        let ys = evaluate_function("ln(x) / (x - 1.0)", &[0.5, -1.0, 1.0]).unwrap();
        assert!(ys[0].is_finite());
        assert!(ys[1].is_nan()); // ln(-1)
        assert!(ys[2].is_nan()); // 0/0
    }
}
