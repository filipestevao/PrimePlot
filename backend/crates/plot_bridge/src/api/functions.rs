// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Analytical function curves: validation + viewport sampling for `f(x)` nodes.

use crate::api::data::Point2D;

/// Cheap syntax check for inspector feedback (no sampling).
#[flutter_rust_bridge::frb(sync)]
pub fn validate_function_expression(expr: String) -> Result<(), String> {
    core_math::validate_function(&expr)
}

/// Samples the function node over its local domain override if set,
/// else over the visible viewport. Parse/domain errors propagate to Dart
/// (inspector shows them; the canvas skips the curve).
#[flutter_rust_bridge::frb(sync)]
pub fn get_function_curve_data(
    node_id: String,
    viewport_x_min: f64,
    viewport_x_max: f64,
) -> Result<Vec<Point2D>, String> {
    let props = crate::api::properties::get_function_properties(node_id);
    let lo = props.x_min.unwrap_or(viewport_x_min);
    let hi = props.x_max.unwrap_or(viewport_x_max);
    if !lo.is_finite() || !hi.is_finite() {
        return Err("function domain is not finite".to_string());
    }
    if hi <= lo {
        return Err("function domain is empty (x_max must exceed x_min)".to_string());
    }
    let n = props.num_samples.clamp(2, 100_000);
    let xs = core_math::sample_domain(lo, hi, n);
    let ys = core_math::evaluate_function(&props.equation, &xs)?;
    Ok(xs
        .into_iter()
        .zip(ys)
        .map(|(x, y)| Point2D { x, y })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn samples_default_function_over_viewport() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        let pts = get_function_curve_data("fn_1".to_string(), 0.0, 20.0).unwrap();
        assert_eq!(pts.len(), 1000); // default num_samples
        assert!((pts[0].x - 0.0).abs() < 1e-12);
        assert!((pts[0].y - 0.0).abs() < 1e-12); // f(x) = x
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn bad_equation_and_domain_are_errors() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::set_function_properties(
            "fn_bad".to_string(),
            crate::api::properties::FunctionProperties {
                equation: "sin(".to_string(),
                ..Default::default()
            },
        );
        assert!(get_function_curve_data("fn_bad".to_string(), 0.0, 1.0).is_err());
        assert!(validate_function_expression("sin(".to_string()).is_err());
        assert!(validate_function_expression("sin(x)".to_string()).is_ok());
        assert!(get_function_curve_data("fn_1".to_string(), 5.0, 5.0).is_err());
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn local_domain_overrides_viewport() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::set_function_properties(
            "fn_dom".to_string(),
            crate::api::properties::FunctionProperties {
                equation: "x".to_string(),
                x_min: Some(2.0),
                x_max: Some(4.0),
                num_samples: 3,
                ..Default::default()
            },
        );
        let pts = get_function_curve_data("fn_dom".to_string(), 0.0, 20.0).unwrap();
        assert_eq!(pts.len(), 3);
        assert!((pts[0].x - 2.0).abs() < 1e-12);
        assert!((pts[2].x - 4.0).abs() < 1e-12);
        crate::api::properties::clear_all_property_stores();
    }
}
