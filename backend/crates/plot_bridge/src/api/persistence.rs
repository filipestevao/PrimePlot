// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Zipped `.primeplot` project bundle persistence.
//!
//! Layout inside the ZIP archive:
//! ```text
//! manifest.json
//! project_tree.json
//! properties/folder_properties.json
//! properties/graph_properties.json
//! properties/table_properties.json
//! properties/function_properties.json
//! properties/shape_properties.json
//! data/<table_id>.csv          # header: `Name[Role]`, empty cell = ""
//! ```

use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Write};

use data_engine::table::{
    ColumnRole as EngineColumnRole, DataColumn as EngineDataColumn,
    DataTable as EngineDataTable,
};
use data_engine::ProjectNode as EngineProjectNode;
use serde::{Deserialize, Serialize};

// ---------------------------------------------------------------------------
// Manifest
// ---------------------------------------------------------------------------

const BUNDLE_FORMAT_VERSION: u32 = 1;
const APP_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProjectManifest {
    pub format_version: u32,
    pub app_version: String,
    pub creation_date: String,
}

impl ProjectManifest {
    fn new_now() -> Self {
        Self {
            format_version: BUNDLE_FORMAT_VERSION,
            app_version: APP_VERSION.to_string(),
            creation_date: chrono::Utc::now().to_rfc3339(),
        }
    }
}

// ---------------------------------------------------------------------------
// CSV helpers (header-suffix format: `Name[Role]`)
// ---------------------------------------------------------------------------

fn role_to_tag(role: &EngineColumnRole) -> &'static str {
    match role {
        EngineColumnRole::X => "X",
        EngineColumnRole::Y => "Y",
        EngineColumnRole::XError => "XError",
        EngineColumnRole::YError => "YError",
        EngineColumnRole::Text => "Text",
    }
}

fn tag_to_role(tag: &str) -> Option<EngineColumnRole> {
    match tag {
        "X" => Some(EngineColumnRole::X),
        "Y" => Some(EngineColumnRole::Y),
        "XError" => Some(EngineColumnRole::XError),
        "YError" => Some(EngineColumnRole::YError),
        "Text" => Some(EngineColumnRole::Text),
        _ => None,
    }
}

fn escape_csv_field(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

/// Splits one CSV line respecting RFC-4180 double-quoted fields.
fn split_csv_line(line: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut cur = String::new();
    let mut chars = line.chars().peekable();
    let mut in_quotes = false;
    while let Some(c) = chars.next() {
        if in_quotes {
            if c == '"' {
                if chars.peek() == Some(&'"') {
                    cur.push('"');
                    chars.next();
                } else {
                    in_quotes = false;
                }
            } else {
                cur.push(c);
            }
        } else if c == '"' {
            in_quotes = true;
        } else if c == ',' {
            fields.push(cur);
            cur = String::new();
        } else {
            cur.push(c);
        }
    }
    fields.push(cur);
    fields
}

/// Splits a header cell `Name[Role]` into (name, role).
/// Parses only the *last* bracket pair so names containing brackets
/// (e.g. `Foo[X]`) round-trip correctly as `Foo[X][Y]`.
fn parse_header_cell(cell: &str, fallback_role: EngineColumnRole) -> (String, EngineColumnRole) {
    let trimmed = cell.trim();
    if let Some(open) = trimmed.rfind('[') {
        if trimmed.ends_with(']') && open + 1 < trimmed.len() - 1 {
            let tag = &trimmed[open + 1..trimmed.len() - 1];
            if let Some(role) = tag_to_role(tag) {
                return (trimmed[..open].to_string(), role);
            }
        }
    }
    (trimmed.to_string(), fallback_role)
}

fn default_role_for_index(i: usize) -> EngineColumnRole {
    if i == 0 {
        EngineColumnRole::X
    } else {
        EngineColumnRole::Y
    }
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
        // `{}` prints the shortest round-trip representation.
        format!("{v}")
    }
}

fn parse_cell(s: &str) -> f64 {
    let t = s.trim();
    if t.is_empty() {
        return f64::NAN;
    }
    match t {
        "inf" | "+inf" | "Infinity" | "+Infinity" => f64::INFINITY,
        "-inf" | "-Infinity" => f64::NEG_INFINITY,
        "NaN" | "nan" | "-nan" => f64::NAN,
        _ => t.parse::<f64>().unwrap_or(f64::NAN),
    }
}

pub(crate) fn table_to_csv(table: &EngineDataTable) -> String {
    let mut out = String::new();
    // Header
    let header: Vec<String> = table
        .columns
        .iter()
        .map(|c| escape_csv_field(&format!("{}[{}]", c.name, role_to_tag(&c.role))))
        .collect();
    out.push_str(&header.join(","));
    out.push('\n');
    // Rows
    let row_count = table.columns.iter().map(|c| c.data.len()).max().unwrap_or(0);
    for r in 0..row_count {
        let row: Vec<String> = table
            .columns
            .iter()
            .map(|c| {
                if r < c.data.len() {
                    format_cell(c.data[r])
                } else {
                    String::new()
                }
            })
            .collect();
        out.push_str(&row.join(","));
        out.push('\n');
    }
    out
}

pub(crate) fn csv_to_table(
    table_id: &str,
    table_name: &str,
    csv: &str,
) -> Result<EngineDataTable, String> {
    let mut lines = csv.lines();
    let header_line = lines
        .next()
        .ok_or_else(|| format!("CSV for table '{table_id}' is empty (missing header)"))?;
    let header_cells = split_csv_line(header_line);
    if header_cells.is_empty() {
        return Err(format!("CSV for table '{table_id}' has no columns"));
    }

    let mut names_roles: Vec<(String, EngineColumnRole)> = header_cells
        .iter()
        .enumerate()
        .map(|(i, cell)| parse_header_cell(cell, default_role_for_index(i)))
        .collect();

    // Guard against duplicate column names after parsing.
    let mut seen: HashMap<String, usize> = HashMap::new();
    for (name, _) in names_roles.iter_mut() {
        if name.is_empty() {
            *name = "Column".to_string();
        }
        let count = seen.entry(name.clone()).or_insert(0);
        if *count > 0 {
            *name = format!("{name} ({})", *count + 1);
        }
        *count += 1;
    }

    let col_count = names_roles.len();
    let mut col_data: Vec<Vec<f64>> = vec![Vec::new(); col_count];
    for line in lines {
        if line.trim().is_empty() {
            continue;
        }
        let cells = split_csv_line(line);
        for ci in 0..col_count {
            let cell = cells.get(ci).map(|s| s.as_str()).unwrap_or("");
            col_data[ci].push(parse_cell(cell));
        }
    }

    let mut table = EngineDataTable::new(table_id, table_name);
    for (i, (name, role)) in names_roles.into_iter().enumerate() {
        table.add_column(EngineDataColumn {
            name,
            role,
            data: std::mem::take(&mut col_data[i]),
        });
    }
    Ok(table)
}

// ---------------------------------------------------------------------------
// Bundle save / load
// ---------------------------------------------------------------------------

fn find_node_name(tree: &EngineProjectNode, target_id: &str) -> Option<String> {
    if tree.id == target_id {
        return Some(tree.name.clone());
    }
    for child in &tree.children {
        if let Some(name) = find_node_name(child, target_id) {
            return Some(name);
        }
    }
    None
}

fn write_json_file<W: Write + std::io::Seek>(
    zip: &mut zip::ZipWriter<W>,
    name: &str,
    value: &impl Serialize,
) -> Result<(), String> {
    let options = zip::write::SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o644);
    zip.start_file(name, options)
        .map_err(|e| format!("zip start '{name}': {e}"))?;
    let json = serde_json::to_string_pretty(value)
        .map_err(|e| format!("serialize '{name}': {e}"))?;
    zip.write_all(json.as_bytes())
        .map_err(|e| format!("zip write '{name}': {e}"))?;
    Ok(())
}

fn write_text_file<W: Write + std::io::Seek>(
    zip: &mut zip::ZipWriter<W>,
    name: &str,
    text: &str,
) -> Result<(), String> {
    let options = zip::write::SimpleFileOptions::default()
        .compression_method(zip::CompressionMethod::Deflated)
        .unix_permissions(0o644);
    zip.start_file(name, options)
        .map_err(|e| format!("zip start '{name}': {e}"))?;
    zip.write_all(text.as_bytes())
        .map_err(|e| format!("zip write '{name}': {e}"))?;
    Ok(())
}

fn read_text_file(archive: &mut zip::ZipArchive<File>, name: &str) -> Result<String, String> {
    let mut file = archive
        .by_name(name)
        .map_err(|e| format!("missing '{name}': {e}"))?;
    let mut text = String::new();
    file.read_to_string(&mut text)
        .map_err(|e| format!("read '{name}': {e}"))?;
    Ok(text)
}

fn read_json_file<T>(archive: &mut zip::ZipArchive<File>, name: &str) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    let text = read_text_file(archive, name)?;
    serde_json::from_str(&text).map_err(|e| format!("parse '{name}': {e}"))
}

fn read_json_file_optional<T>(
    archive: &mut zip::ZipArchive<File>,
    name: &str,
) -> Result<HashMap<String, T>, String>
where
    T: for<'de> Deserialize<'de>,
{
    match archive.by_name(name) {
        Ok(mut file) => {
            let mut text = String::new();
            file.read_to_string(&mut text)
                .map_err(|e| format!("read '{name}': {e}"))?;
            if text.trim().is_empty() {
                return Ok(HashMap::new());
            }
            serde_json::from_str(&text).map_err(|e| format!("parse '{name}': {e}"))
        }
        Err(_) => Ok(HashMap::new()),
    }
}

/// Compresses JSON metadata, properties, and CSV tables into `.primeplot`.
pub(crate) fn save_project_to_zip(path: &str) -> Result<(), String> {
    let tree = crate::api::project::snapshot_tree_engine();
    let tables = crate::api::project::snapshot_tables_engine();
    let folder_props = crate::api::properties::snapshot_folder_props();
    let graph_props = crate::api::properties::snapshot_graph_props();
    let table_props = crate::api::properties::snapshot_table_props();
    let function_props = crate::api::properties::snapshot_function_props();
    let shape_props = crate::api::properties::snapshot_shape_props();

    let file =
        File::create(path).map_err(|e| format!("create archive '{path}': {e}"))?;
    let mut zip = zip::ZipWriter::new(file);

    write_json_file(&mut zip, "manifest.json", &ProjectManifest::new_now())?;
    write_json_file(&mut zip, "project_tree.json", &tree)?;
    write_json_file(
        &mut zip,
        "properties/folder_properties.json",
        &folder_props,
    )?;
    write_json_file(&mut zip, "properties/graph_properties.json", &graph_props)?;
    write_json_file(&mut zip, "properties/table_properties.json", &table_props)?;
    write_json_file(
        &mut zip,
        "properties/function_properties.json",
        &function_props,
    )?;
    write_json_file(&mut zip, "properties/shape_properties.json", &shape_props)?;

    // Deterministic order for reproducible archives.
    let mut ids: Vec<&String> = tables.keys().collect();
    ids.sort();
    for id in ids {
        let table = &tables[id];
        let csv = table_to_csv(table);
        write_text_file(&mut zip, &format!("data/{id}.csv"), &csv)?;
    }

    zip.finish()
        .map_err(|e| format!("finalize archive '{path}': {e}"))?;
    Ok(())
}

/// Decompresses archive, repopulates PROJECT_STATE, TABLE_STORE and all
/// property stores. Returns the restored engine tree on success.
/// On failure the in-memory state is left untouched.
pub(crate) fn load_project_from_zip(path: &str) -> Result<EngineProjectNode, String> {
    let file = File::open(path).map_err(|e| format!("open archive '{path}': {e}"))?;
    let mut archive =
        zip::ZipArchive::new(file).map_err(|e| format!("open zip '{path}': {e}"))?;

    let manifest: ProjectManifest = read_json_file(&mut archive, "manifest.json")?;
    if manifest.format_version > BUNDLE_FORMAT_VERSION {
        return Err(format!(
            "unsupported bundle format v{} (app supports v{BUNDLE_FORMAT_VERSION})",
            manifest.format_version
        ));
    }

    let tree: EngineProjectNode = read_json_file(&mut archive, "project_tree.json")?;
    let folder_props = read_json_file_optional(&mut archive, "properties/folder_properties.json")?;
    let graph_props = read_json_file_optional(&mut archive, "properties/graph_properties.json")?;
    let table_props = read_json_file_optional(&mut archive, "properties/table_properties.json")?;
    let function_props =
        read_json_file_optional(&mut archive, "properties/function_properties.json")?;
    let shape_props = read_json_file_optional(&mut archive, "properties/shape_properties.json")?;

    // Collect data/*.csv entries first (names only), then read each.
    let mut csv_names: Vec<String> = Vec::new();
    for i in 0..archive.len() {
        let file = archive
            .by_index(i)
            .map_err(|e| format!("list archive entries: {e}"))?;
        let name = file.name().to_string();
        if name.starts_with("data/") && name.ends_with(".csv") {
            csv_names.push(name);
        }
    }
    csv_names.sort();

    let mut tables: HashMap<String, EngineDataTable> = HashMap::new();
    for entry in csv_names {
        // File stem (without `data/` prefix and `.csv` suffix) is the table id.
        let id = entry
            .strip_prefix("data/")
            .and_then(|s| s.strip_suffix(".csv"))
            .ok_or_else(|| format!("bad data entry name '{entry}'"))?;
        // Reject path traversal attempts.
        if id.contains('/') || id.contains('\\') || id.contains("..") || id.is_empty() {
            return Err(format!("unsafe data entry name '{entry}'"));
        }
        let csv = read_text_file(&mut archive, &entry)?;
        let name = find_node_name(&tree, id).unwrap_or_else(|| id.to_string());
        let table = csv_to_table(id, &name, &csv)?;
        tables.insert(id.to_string(), table);
    }

    // All parsing succeeded: commit to global state.
    crate::api::project::restore_tree_engine(tree.clone());
    crate::api::project::restore_tables_engine(tables);
    crate::api::properties::restore_folder_props(folder_props);
    crate::api::properties::restore_graph_props(graph_props);
    crate::api::properties::restore_table_props(table_props);
    crate::api::properties::restore_function_props(function_props);
    crate::api::properties::restore_shape_props(shape_props);
    crate::api::project::reset_next_id_from_tree(&tree);

    Ok(tree)
}

// ---------------------------------------------------------------------------
// FRB endpoints
// ---------------------------------------------------------------------------

/// Saves the current project to `path` (`.primeplot` zip bundle).
#[flutter_rust_bridge::frb(sync)]
pub fn save_project(path: String) -> Result<(), String> {
    save_project_to_zip(&path)
}

/// Loads a `.primeplot` bundle from `path`, replacing all in-memory state.
/// Returns the restored project tree DTO on success.
#[flutter_rust_bridge::frb(sync)]
pub fn load_project(path: String) -> Result<crate::api::project::ProjectNode, String> {
    let tree = load_project_from_zip(&path)?;
    Ok(tree.into())
}

/// Resets everything to the canonical empty project
/// (Workspace > Project > Graph > Table), clearing all property stores.
#[flutter_rust_bridge::frb(sync)]
pub fn new_project() -> crate::api::project::ProjectNode {
    use data_engine::table::{ColumnRole, DataColumn};

    let tree = crate::api::project::default_project_tree_engine();
    crate::api::project::restore_tree_engine(tree.clone());
    crate::api::properties::clear_all_property_stores();

    // Seed the canonical empty table_1 (two empty columns, zero rows).
    let mut tables: HashMap<String, EngineDataTable> = HashMap::new();
    let mut initial = EngineDataTable::new("table_1", "Table");
    initial.add_column(DataColumn {
        name: "Col 1".to_string(),
        role: ColumnRole::X,
        data: Vec::new(),
    });
    initial.add_column(DataColumn {
        name: "Col 2".to_string(),
        role: ColumnRole::Y,
        data: Vec::new(),
    });
    tables.insert("table_1".to_string(), initial);
    crate::api::project::restore_tables_engine(tables);
    crate::api::project::reset_next_id_from_tree(&tree);

    tree.into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_table() -> EngineDataTable {
        let mut t = EngineDataTable::new("table_101", "Sample");
        t.add_column(EngineDataColumn {
            name: "Position".to_string(),
            role: EngineColumnRole::X,
            data: vec![0.0, 1.5, f64::NAN],
        });
        t.add_column(EngineDataColumn {
            name: "Intensity".to_string(),
            role: EngineColumnRole::Y,
            data: vec![10.0, 20.0, 30.0],
        });
        t.add_column(EngineDataColumn {
            name: "Err".to_string(),
            role: EngineColumnRole::YError,
            data: vec![0.1, 0.2, 0.3],
        });
        t
    }

    #[test]
    fn csv_round_trip_preserves_roles_names_and_nan() {
        let t = sample_table();
        let csv = table_to_csv(&t);
        assert!(csv.contains("Position[X]"), "header must carry roles:\n{csv}");
        assert!(csv.contains("Intensity[Y]"));
        assert!(csv.contains("Err[YError]"));
        let back = csv_to_table("table_101", "Sample", &csv).unwrap();
        assert_eq!(back.columns.len(), 3);
        assert_eq!(back.columns[0].name, "Position");
        assert!(matches!(back.columns[0].role, EngineColumnRole::X));
        assert!(matches!(back.columns[2].role, EngineColumnRole::YError));
        assert_eq!(back.columns[0].data.len(), 3);
        assert!(back.columns[0].data[2].is_nan());
        assert_eq!(back.columns[1].data, vec![10.0, 20.0, 30.0]);
    }

    #[test]
    fn csv_header_with_brackets_in_name_round_trips() {
        let mut t = EngineDataTable::new("t1", "Brackets");
        t.add_column(EngineDataColumn {
            name: "Foo[X]".to_string(),
            role: EngineColumnRole::Y,
            data: vec![1.0],
        });
        let csv = table_to_csv(&t);
        assert!(csv.contains("Foo[X][Y]"), "unexpected csv:\n{csv}");
        let back = csv_to_table("t1", "Brackets", &csv).unwrap();
        assert_eq!(back.columns[0].name, "Foo[X]");
        assert!(matches!(back.columns[0].role, EngineColumnRole::Y));
    }

    #[test]
    fn csv_quoted_fields_round_trip() {
        let mut t = EngineDataTable::new("t2", "Quoted");
        t.add_column(EngineDataColumn {
            name: "A, B \"quoted\"".to_string(),
            role: EngineColumnRole::X,
            data: vec![1.0, 2.0],
        });
        t.add_column(EngineDataColumn {
            name: "Y".to_string(),
            role: EngineColumnRole::Y,
            data: vec![3.0, 4.0],
        });
        let csv = table_to_csv(&t);
        let back = csv_to_table("t2", "Quoted", &csv).unwrap();
        assert_eq!(back.columns[0].name, "A, B \"quoted\"");
        assert_eq!(back.columns[0].data, vec![1.0, 2.0]);
    }

    #[test]
    fn save_and_load_zip_round_trip() {
        use data_engine::NodeType as EngineNodeType;

        // Arrange: build a small project in global state.
        let mut root =
            EngineProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new(
            "table_101",
            "Sample",
            EngineNodeType::Dataset,
        ));
        root.add_child(graph);
        crate::api::project::restore_tree_engine(root);
        let mut tables = HashMap::new();
        tables.insert("table_101".to_string(), sample_table());
        crate::api::project::restore_tables_engine(tables);
        crate::api::properties::clear_all_property_stores();
        crate::api::properties::restore_graph_props(HashMap::from([(
            "graph_1".to_string(),
            crate::api::properties::GraphProperties {
                x_label: "Time (s)".to_string(),
                ..Default::default()
            },
        )]));

        let path = format!(
            "{}/primeplot_test_{}.primeplot",
            std::env::temp_dir().display(),
            std::process::id()
        );
        save_project_to_zip(&path).expect("save must succeed");

        // Mutate state so load must actually restore.
        crate::api::project::restore_tables_engine(HashMap::new());
        crate::api::properties::clear_all_property_stores();

        let tree = load_project_from_zip(&path).expect("load must succeed");
        assert_eq!(tree.children.len(), 1);
        let restored = crate::api::project::snapshot_tables_engine();
        let t = restored.get("table_101").expect("table must be restored");
        assert_eq!(t.columns.len(), 3);
        assert!(t.columns[0].data[2].is_nan());
        let props = crate::api::properties::snapshot_graph_props();
        assert_eq!(props["graph_1"].x_label, "Time (s)");

        std::fs::remove_file(&path).ok();
    }
}
