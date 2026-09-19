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

/// Scientific Neon — PrimePlot's bright-on-dark set (mirrors the Dart
/// `AcademicPalettes.neonScientific` quick-picker).
pub const NEON: [&str; 8] = [
    "#00C3FF", "#FF5252", "#69F0AE", "#FFD740", "#E040FB", "#FFFFFF", "#90A4AE",
    "#FF6E40",
];

/// Canonical palette names in UI order.
pub const PALETTE_NAMES: [&str; 3] = ["Tab10", "Set1", "Scientific Neon"];

/// Case-insensitive lookup (`"tab10"`, `"Tab10"`, `"SET1"`, `"neon"` all work).
pub(crate) fn palette_by_name(name: &str) -> Option<&'static [&'static str]> {
    match name.to_ascii_lowercase().as_str() {
        "tab10" => Some(&TAB10),
        "set1" => Some(&SET1),
        "neon" | "scientific neon" | "scientific_neon" => Some(&NEON),
        _ => None,
    }
}

/// Palette names for building UI buttons.
#[flutter_rust_bridge::frb(sync)]
pub fn list_palettes() -> Vec<String> {
    PALETTE_NAMES.iter().map(|s| s.to_string()).collect()
}

/// Hex colors of one palette (for swatch previews). Err on unknown name.
#[flutter_rust_bridge::frb(sync)]
pub fn palette_colors(palette: String) -> Result<Vec<String>, String> {
    palette_by_name(&palette)
        .map(|p| p.iter().map(|s| s.to_string()).collect())
        .ok_or_else(|| {
            format!("unknown palette '{palette}' (expected Tab10, Set1 or Scientific Neon)")
        })
}

/// Re-aligns a graph's curves to a palette: tree order → color sequence
/// (datasets and functions share one index, so deleting/reordering is fixed
/// with one tap). Custom single-curve tweaks are overwritten; other
/// properties are preserved.
#[flutter_rust_bridge::frb(sync)]
pub fn apply_palette(graph_id: String, palette: String) -> Result<(), String> {
    let colors = palette_by_name(&palette).ok_or_else(|| {
        format!("unknown palette '{palette}' (expected Tab10, Set1 or Scientific Neon)")
    })?;

    // Snapshot + release before touching property stores (lock ordering).
    let tree = crate::api::project::snapshot_tree_engine();
    let graph = find_graph(&tree, &graph_id)
        .ok_or_else(|| format!("graph '{graph_id}' not found"))?;

    let mut i = 0;
    for child in &graph.children {
        let color = colors[i % colors.len()].to_string();
        match child.node_type {
            data_engine::NodeType::Dataset => {
                let mut props =
                    crate::api::properties::get_table_properties(child.id.clone());
                props.line_color = color;
                crate::api::properties::set_table_properties(child.id.clone(), props);
                i += 1;
            }
            data_engine::NodeType::Function => {
                let mut props =
                    crate::api::properties::get_function_properties(child.id.clone());
                props.line_color = color;
                crate::api::properties::set_function_properties(child.id.clone(), props);
                i += 1;
            }
            _ => {}
        }
    }
    Ok(())
}

fn find_graph<'a>(
    tree: &'a data_engine::ProjectNode,
    graph_id: &str,
) -> Option<&'a data_engine::ProjectNode> {
    if tree.id == graph_id {
        return match tree.node_type {
            data_engine::NodeType::Plot => Some(tree),
            _ => None,
        };
    }
    for child in &tree.children {
        if let Some(n) = find_graph(child, graph_id) {
            return Some(n);
        }
    }
    None
}

/// First unused Tab10 color among `sibling_dataset_ids` (compared
/// case-insensitively against stored `line_color` values). Falls back to
/// cycling by sibling count once the palette is exhausted.
pub(crate) fn next_color_for_siblings(sibling_dataset_ids: &[String]) -> String {
    next_combined_color(Some(sibling_dataset_ids), None)
        .unwrap_or_else(|| TAB10[0].to_string())
}

/// First unused Tab10 color across dataset + function siblings of a graph.
/// `None` when the node wasn't born under a graph (caller keeps lazy default).
pub(crate) fn next_combined_color(
    dataset_ids: Option<&[String]>,
    function_ids: Option<&[String]>,
) -> Option<String> {
    if dataset_ids.is_none() && function_ids.is_none() {
        return None;
    }
    let table_props = crate::api::properties::snapshot_table_props();
    let fn_props = crate::api::properties::snapshot_function_props();
    let mut used: Vec<String> = Vec::new();
    for id in dataset_ids.unwrap_or(&[]).iter().chain(function_ids.unwrap_or(&[])) {
        let color = table_props
            .get(id)
            .map(|p| p.line_color.clone())
            .or_else(|| fn_props.get(id).map(|p| p.line_color.clone()));
        if let Some(c) = color {
            used.push(c.to_ascii_uppercase());
        }
    }
    for candidate in TAB10 {
        if !used.iter().any(|u| u == candidate) {
            return Some(candidate.to_string());
        }
    }
    let total = dataset_ids.map_or(0, |s| s.len()) + function_ids.map_or(0, |s| s.len());
    Some(TAB10[total % TAB10.len()].to_string())
}

/// Initializes a newborn curve's props: Display Name follows the node name
/// (so legend label and inspector agree from the start) and, when born
/// under a graph (`color` present), the next unused Tab10 color.
pub(crate) fn init_curve_props(
    table_id: &str,
    display_name: &str,
    color: Option<String>,
) {
    let mut props = crate::api::properties::get_table_properties(table_id.to_string());
    if let Some(c) = color {
        props.line_color = c;
    }
    props.legend_display_name = display_name.to_string();
    crate::api::properties::set_table_properties(table_id.to_string(), props);
}

/// Initializes a newborn function's color (functions have no Display Name
/// field; the legend follows the node name live). No-op off-graph.
pub(crate) fn init_function_props(node_id: &str, color: Option<String>) {
    if let Some(c) = color {
        let mut props =
            crate::api::properties::get_function_properties(node_id.to_string());
        props.line_color = c;
        crate::api::properties::set_function_properties(node_id.to_string(), props);
    }
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
    fn init_sets_name_and_color_preserving_rest() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::restore_table_props(HashMap::from([(
            "table_9".to_string(),
            crate::api::properties::TableProperties {
                line_thickness: 5.0,
                line_color: "#FF7F0E".to_string(),
                ..Default::default()
            },
        )]));
        init_curve_props(
            "table_9",
            "curve_a.txt",
            next_combined_color(Some(&["table_9".to_string()]), None),
        );
        let back = crate::api::properties::get_table_properties("table_9".to_string());
        assert_eq!(back.line_color, "#1F77B4");
        assert_eq!(back.legend_display_name, "curve_a.txt");
        assert_eq!(back.line_thickness, 5.0);
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn combined_cycle_skips_function_colors() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::set_function_properties(
            "fn_1".to_string(),
            crate::api::properties::FunctionProperties {
                line_color: "#1F77B4".to_string(),
                ..Default::default()
            },
        );
        let color = next_combined_color(Some(&[]), Some(&["fn_1".to_string()]));
        assert_eq!(color, Some("#FF7F0E".to_string()));
        // Off-graph creation keeps the lazy default.
        assert_eq!(next_combined_color(None, None), None);
        crate::api::properties::clear_all_property_stores();
    }

    #[test]
    fn list_reports_all_palettes() {
        assert_eq!(
            list_palettes(),
            vec![
                "Tab10".to_string(),
                "Set1".to_string(),
                "Scientific Neon".to_string()
            ]
        );
        assert_eq!(palette_colors("Tab10".to_string()).unwrap().len(), 10);
        assert_eq!(palette_colors("neon".to_string()).unwrap()[0], "#00C3FF");
        assert!(palette_colors("Nope".to_string()).is_err());
    }

    fn mixed_curve_tree() -> data_engine::ProjectNode {
        use data_engine::NodeType as EngineNodeType;
        let mut root =
            data_engine::ProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
        let mut graph = data_engine::ProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
        graph.add_child(data_engine::ProjectNode::new(
            "table_1",
            "table_1",
            EngineNodeType::Dataset,
        ));
        graph.add_child(data_engine::ProjectNode::new(
            "fn_1",
            "fn_1",
            EngineNodeType::Function,
        ));
        graph.add_child(data_engine::ProjectNode::new(
            "table_2",
            "table_2",
            EngineNodeType::Dataset,
        ));
        root.add_child(graph);
        root
    }

    #[test]
    fn apply_realigns_order_to_palette() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved_tree = crate::api::project::snapshot_tree_engine();
        let saved_tables = crate::api::project::snapshot_tables_engine();
        crate::api::project::restore_tree_engine(mixed_curve_tree());
        crate::api::properties::clear_all_property_stores();

        // Datasets and functions share one tree-order index.
        apply_palette("graph_1".to_string(), "Set1".to_string()).unwrap();
        assert_eq!(
            crate::api::properties::get_table_properties("table_1".to_string()).line_color,
            SET1[0]
        );
        assert_eq!(
            crate::api::properties::get_function_properties("fn_1".to_string()).line_color,
            SET1[1]
        );
        assert_eq!(
            crate::api::properties::get_table_properties("table_2".to_string()).line_color,
            SET1[2]
        );

        // Unknown palette / graph are clean errors, state untouched.
        assert!(apply_palette("graph_1".to_string(), "Nope".to_string()).is_err());
        assert!(apply_palette("graph_9".to_string(), "Tab10".to_string()).is_err());

        crate::api::project::restore_tree_engine(saved_tree);
        crate::api::project::restore_tables_engine(saved_tables);
        crate::api::properties::clear_all_property_stores();
    }
}
