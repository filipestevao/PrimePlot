// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Plain-text data export (Step F). CSV/TSV written by Rust so file I/O
//! stays in the core. Headers reuse the bundle `Name[Role]` convention;
//! NaN cells become empty strings. Figure (PNG) export is Flutter-side.

use std::collections::HashMap;
use std::fs::File;
use std::io::Write;

use data_engine::table::{ColumnRole as EngineColumnRole, DataTable as EngineDataTable};

fn check_delimiter(delimiter: &str) -> Result<char, String> {
    match delimiter {
        "," => Ok(','),
        "\t" | "\\t" => Ok('\t'),
        other => Err(format!(
            "unsupported delimiter '{other}' (expected ',' or tab)"
        )),
    }
}

fn write_text(path: &str, text: &str) -> Result<(), String> {
    let mut file = File::create(path).map_err(|e| format!("create '{path}': {e}"))?;
    file.write_all(text.as_bytes())
        .map_err(|e| format!("write '{path}': {e}"))?;
    Ok(())
}

fn without_header(csv: &str) -> String {
    let mut lines = csv.lines();
    lines.next();
    let rest: Vec<&str> = lines.collect();
    if rest.is_empty() {
        String::new()
    } else {
        format!("{}\n", rest.join("\n"))
    }
}

/// Exports one dataset. Delimiter `","` (CSV) or tab (TSV).
#[flutter_rust_bridge::frb(sync)]
pub fn export_table_csv(
    table_id: String,
    path: String,
    delimiter: String,
    include_header: bool,
) -> Result<(), String> {
    let tables = crate::api::project::snapshot_tables_engine();
    let table = tables
        .get(&table_id)
        .ok_or_else(|| format!("table '{table_id}' not found"))?;
    let delim = check_delimiter(&delimiter)?;
    let text = table_to_delimited(table, delim, include_header);
    write_text(&path, &text)
}

/// Serializes one table with `Name[Role]` headers and empty-string NaNs.
fn table_to_delimited(
    table: &EngineDataTable,
    delim: char,
    include_header: bool,
) -> String {
    let sep = delim.to_string();
    let mut out = String::new();
    if include_header {
        let heads: Vec<String> = table
            .columns
            .iter()
            .map(|c| {
                escape_field(&format!(
                    "{}[{}]",
                    c.name,
                    match c.role {
                        EngineColumnRole::X => "X",
                        EngineColumnRole::Y => "Y",
                        EngineColumnRole::XError => "XError",
                        EngineColumnRole::YError => "YError",
                        EngineColumnRole::Text => "Text",
                    }
                ))
            })
            .collect();
        out.push_str(&heads.join(&sep));
        out.push('\n');
    }
    let row_count = table.columns.iter().map(|c| c.data.len()).max().unwrap_or(0);
    for r in 0..row_count {
        let cells: Vec<String> = table
            .columns
            .iter()
            .map(|c| format_cell(c.data.get(r).copied().unwrap_or(f64::NAN)))
            .collect();
        out.push_str(&cells.join(&sep));
        out.push('\n');
    }
    out
}

fn pick_xy(table: &EngineDataTable) -> Option<(&[f64], &[f64])> {
    if table.columns.is_empty() {
        return None;
    }
    let xcol = table
        .columns
        .iter()
        .find(|c| matches!(c.role, EngineColumnRole::X))
        .or(table.columns.first())?;
    let ycol = table
        .columns
        .iter()
        .find(|c| matches!(c.role, EngineColumnRole::Y))
        .or(table.columns.get(1).or(table.columns.first()))?;
    Some((&xcol.data, &ycol.data))
}

fn format_cell(v: f64) -> String {
    if v.is_nan() {
        String::new()
    } else if v.is_infinite() {
        if v.is_sign_positive() {
            "inf".to_string()
        } else {
            "-inf".to_string()
        }
    } else {
        format!("{v}")
    }
}

fn escape_field(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r') || s.contains('\t') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

/// Exports all curves under a graph as one interleaved file:
/// `X_<table>, Y_<table>, …` per dataset in tree order. Ragged tables are
/// padded with empty cells.
#[flutter_rust_bridge::frb(sync)]
pub fn export_graph_data_csv(
    graph_id: String,
    path: String,
    delimiter: String,
    include_header: bool,
) -> Result<(), String> {
    let delim = check_delimiter(&delimiter)?;
    let sep = delim.to_string();

    let tree = crate::api::project::snapshot_tree_engine();
    let tables: HashMap<String, EngineDataTable> =
        crate::api::project::snapshot_tables_engine();

    fn find<'a>(
        node: &'a data_engine::ProjectNode,
        target: &str,
    ) -> Option<&'a data_engine::ProjectNode> {
        if node.id == target {
            return Some(node);
        }
        for c in &node.children {
            if let Some(n) = find(c, target) {
                return Some(n);
            }
        }
        None
    }
    let graph = find(&tree, &graph_id)
        .ok_or_else(|| format!("graph '{graph_id}' not found"))?;

    // (header_x, header_y, xs, ys) per dataset, in tree order.
    let mut series: Vec<(String, String, Vec<f64>, Vec<f64>)> = Vec::new();
    for child in &graph.children {
        if !matches!(child.node_type, data_engine::NodeType::Dataset) {
            continue;
        }
        let table = match tables.get(&child.id) {
            Some(t) => t,
            None => continue,
        };
        if let Some((xs, ys)) = pick_xy(table) {
            series.push((
                format!("X_{}", table.name),
                format!("Y_{}", table.name),
                xs.to_vec(),
                ys.to_vec(),
            ));
        }
    }
    if series.is_empty() {
        return Err(format!("graph '{graph_id}' has no plottable curves"));
    }

    let row_count = series
        .iter()
        .map(|(_, _, xs, ys)| xs.len().min(ys.len()))
        .max()
        .unwrap_or(0);

    let mut out = String::new();
    if include_header {
        let heads: Vec<String> = series
            .iter()
            .flat_map(|(hx, hy, _, _)| [escape_field(hx), escape_field(hy)])
            .collect();
        out.push_str(&heads.join(&sep));
        out.push('\n');
    }
    for r in 0..row_count {
        let cells: Vec<String> = series
            .iter()
            .flat_map(|(_, _, xs, ys)| {
                let x = xs.get(r).copied().unwrap_or(f64::NAN);
                let y = ys.get(r).copied().unwrap_or(f64::NAN);
                [format_cell(x), format_cell(y)]
            })
            .collect();
        out.push_str(&cells.join(&sep));
        out.push('\n');
    }
    write_text(&path, &out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use data_engine::table::{DataColumn, DataTable as EngineDataTable};
    use data_engine::table::ColumnRole as EngineColumnRole;

    fn seed() -> (EngineDataTable, EngineDataTable) {
        let mut a = EngineDataTable::new("ex_a", "curve_a");
        a.add_column(DataColumn {
            name: "X".to_string(),
            role: EngineColumnRole::X,
            data: vec![0.0, 1.0, f64::NAN],
        });
        a.add_column(DataColumn {
            name: "Y".to_string(),
            role: EngineColumnRole::Y,
            data: vec![10.0, 20.0, 30.0],
        });
        let mut b = EngineDataTable::new("ex_b", "curve_b");
        b.add_column(DataColumn {
            name: "X".to_string(),
            role: EngineColumnRole::X,
            data: vec![5.0],
        });
        b.add_column(DataColumn {
            name: "Y".to_string(),
            role: EngineColumnRole::Y,
            data: vec![50.0],
        });
        (a, b)
    }

    fn seed_tree() {
        use data_engine::NodeType as EngineNodeType;
        use data_engine::ProjectNode as EngineProjectNode;
        let mut root = EngineProjectNode::new("root_1", "W", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("g_ex", "G", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new("ex_a", "curve_a", EngineNodeType::Dataset));
        graph.add_child(EngineProjectNode::new("ex_b", "curve_b", EngineNodeType::Dataset));
        root.add_child(graph);
        crate::api::project::restore_tree_engine(root);
    }

    fn tmp(name: &str) -> String {
        std::env::temp_dir()
            .join(format!("primeplot_{}_{}.csv", name, std::process::id()))
            .display()
            .to_string()
    }

    #[test]
    fn table_export_round_trip() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved_tables = crate::api::project::snapshot_tables_engine();
        let saved_tree = crate::api::project::snapshot_tree_engine();
        let (a, b) = seed();
        seed_tree();
        let mut map = HashMap::new();
        map.insert("ex_a".to_string(), a);
        map.insert("ex_b".to_string(), b);
        crate::api::project::restore_tables_engine(map);

        let p = tmp("single");
        export_table_csv("ex_a".to_string(), p.clone(), ",".to_string(), true).unwrap();
        let text = std::fs::read_to_string(&p).unwrap();
        let mut lines = text.lines();
        assert_eq!(lines.next().unwrap(), "X[X],Y[Y]");
        assert_eq!(lines.next().unwrap(), "0,10");
        assert_eq!(lines.next().unwrap(), "1,20");
        assert_eq!(lines.next().unwrap(), ",30"); // NaN -> empty
        std::fs::remove_file(&p).ok();

        // TSV + no header + bad delimiter + unknown table.
        let p2 = tmp("tvs");
        export_table_csv("ex_a".to_string(), p2.clone(), "\t".to_string(), false).unwrap();
        let t2 = std::fs::read_to_string(&p2).unwrap();
        assert!(t2.lines().next().unwrap().contains('\t'));
        assert!(!t2.contains("[X]"));
        std::fs::remove_file(&p2).ok();
        assert!(export_table_csv("ex_a".to_string(), tmp("x"), ";".to_string(), true).is_err());
        assert!(export_table_csv("nope".to_string(), tmp("y"), ",".to_string(), true).is_err());

        crate::api::project::restore_tree_engine(saved_tree);
        crate::api::project::restore_tables_engine(saved_tables);
    }

    #[test]
    fn graph_export_interleaves_and_pads() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved_tables = crate::api::project::snapshot_tables_engine();
        let saved_tree = crate::api::project::snapshot_tree_engine();
        let (a, b) = seed();
        seed_tree();
        let mut map = HashMap::new();
        map.insert("ex_a".to_string(), a);
        map.insert("ex_b".to_string(), b);
        crate::api::project::restore_tables_engine(map);

        let p = tmp("combined");
        export_graph_data_csv("g_ex".to_string(), p.clone(), ",".to_string(), true).unwrap();
        let text = std::fs::read_to_string(&p).unwrap();
        let mut lines = text.lines();
        assert_eq!(
            lines.next().unwrap(),
            "X_curve_a,Y_curve_a,X_curve_b,Y_curve_b"
        );
        assert_eq!(lines.next().unwrap(), "0,10,5,50");
        assert_eq!(lines.next().unwrap(), "1,20,,"); // ragged pad
        assert_eq!(lines.next().unwrap(), ",30,,");
        assert!(lines.next().is_none());
        std::fs::remove_file(&p).ok();

        assert!(export_graph_data_csv("missing".to_string(), tmp("z"), ",".to_string(), true)
            .is_err());

        crate::api::project::restore_tree_engine(saved_tree);
        crate::api::project::restore_tables_engine(saved_tables);
    }
}
