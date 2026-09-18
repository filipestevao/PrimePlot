// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Academic color palettes and automatic series-color assignment.
//!
//! Rust is SSOT for curve colors (`TableProperties.line_color`); when a new
//! dataset node is created under a graph, the next unused Tab10 color is
//! assigned so imported curves are immediately visually distinct.

/// Matplotlib Tab10 — the default series cycle.
pub const TAB10: [&str; 10] = [
    "#1F77B4", "#FF7F0E", "#2CA02C", "#D62728", "#9467BD", "#8C564B", "#E377C2",
    "#7F7F7F", "#BCBD22", "#17BECF",
];

/// ColorBrewer Set1 (qualitative, colorblind-friendlier subset order).
pub const SET1: [&str; 8] = [
    "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#FFFF33", "#A65628",
    "#F781BF",
];

/// First unused Tab10 color among `sibling_dataset_ids` (compared
/// case-insensitively against stored `line_color` values). Falls back to
/// cycling by sibling count once the palette is exhausted.
pub(crate) fn next_color_for_siblings(sibling_dataset_ids: &[String]) -> String {
    let props = crate::api::properties::snapshot_table_props();
    let mut used: Vec<String> = Vec::with_capacity(sibling_dataset_ids.len());
    for id in sibling_dataset_ids {
        if let Some(p) = props.get(id) {
            used.push(p.line_color.to_ascii_uppercase());
        }
    }
    for candidate in TAB10 {
        if !used.iter().any(|u| u == candidate) {
            return candidate.to_string();
        }
    }
    TAB10[sibling_dataset_ids.len() % TAB10.len()].to_string()
}

/// Assigns the next palette color to `table_id`, preserving any other
/// already-stored properties for that node.
pub(crate) fn assign_next_color(sibling_dataset_ids: &[String], table_id: &str) {
    let color = next_color_for_siblings(sibling_dataset_ids);
    let mut props = crate::api::properties::get_table_properties(table_id.to_string());
    props.line_color = color;
    crate::api::properties::set_table_properties(table_id.to_string(), props);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn test_props(color: &str) -> crate::api::properties::TableProperties {
        crate::api::properties::TableProperties {
            line_color: color.to_string(),
            ..Default::default()
        }
    }

    #[test]
    fn first_curve_gets_tab10_blue() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        let color = next_color_for_siblings(&["table_1".to_string()]);
        assert_eq!(color, "#1F77B4");
    }

    #[test]
    fn skips_used_colors_case_insensitively() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::restore_table_props(HashMap::from([
            ("table_1".to_string(), test_props("#1f77b4")),
            ("table_2".to_string(), test_props("#FF7F0E")),
        ]));
        let color =
            next_color_for_siblings(&["table_1".to_string(), "table_2".to_string()]);
        assert_eq!(color, "#2CA02C");
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn cycles_when_palette_exhausted() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        let mut map = HashMap::new();
        let mut ids = Vec::new();
        for (i, c) in TAB10.iter().enumerate() {
            let id = format!("table_{i}");
            map.insert(id.clone(), test_props(c));
            ids.push(id);
        }
        crate::api::properties::restore_table_props(map);
        let color = next_color_for_siblings(&ids);
        assert_eq!(color, TAB10[ids.len() % TAB10.len()]);
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn assign_preserves_other_properties() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::restore_table_props(HashMap::from([(
            "table_9".to_string(),
            crate::api::properties::TableProperties {
                legend_display_name: "Custom".to_string(),
                line_thickness: 5.0,
                line_color: "#FF7F0E".to_string(),
                ..Default::default()
            },
        )]));
        assign_next_color(&["table_9".to_string()], "table_9");
        let back = crate::api::properties::get_table_properties("table_9".to_string());
        assert_eq!(back.line_color, "#1F77B4");
        assert_eq!(back.legend_display_name, "Custom");
        assert_eq!(back.line_thickness, 5.0);
        crate::api::properties::clear_all_property_stores();
    }
}
