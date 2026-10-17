// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use crate::api::sync::lock_or_recover;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FolderProperties {
    pub information: String,
}

impl Default for FolderProperties {
    fn default() -> Self {
        Self {
            information: String::new(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GraphProperties {
    pub x_min: Option<f64>,
    pub x_max: Option<f64>,
    pub y_min: Option<f64>,
    pub y_max: Option<f64>,
    pub x_visible: bool,
    pub y_visible: bool,
    pub x_scale: String,
    pub y_scale: String,
    pub x_label: String,
    pub y_label: String,
    pub aspect_ratio: Option<f64>,
    pub show_grid: bool,
    pub show_legend: bool,
    pub legend_position: String,
    /// Axis title font size in logical pixels.
    #[serde(default = "default_title_font_size")]
    pub title_font_size: f64,
    /// Axis tick-number font size in logical pixels.
    #[serde(default = "default_tick_font_size")]
    pub tick_font_size: f64,
    /// Gap between the X axis title and the X axis, in logical pixels.
    #[serde(default = "default_title_padding")]
    pub title_padding: f64,
    /// Gap between the Y axis title and the Y axis, in logical pixels.
    #[serde(default = "default_title_padding")]
    pub title_padding_y: f64,
    /// Full-spine frame (no ticks/titles of its own).
    #[serde(default)]
    pub show_border: bool,
    /// Per-project overrides (`None` follows the active theme tokens).
    #[serde(default)]
    pub grid_color: Option<String>,
    #[serde(default)]
    pub axis_color: Option<String>,
}

fn default_title_font_size() -> f64 {
    12.0
}

fn default_tick_font_size() -> f64 {
    10.0
}

fn default_title_padding() -> f64 {
    20.0
}

impl Default for GraphProperties {
    fn default() -> Self {
        Self {
            x_min: None,
            x_max: None,
            y_min: None,
            y_max: None,
            x_visible: true,
            y_visible: true,
            x_scale: "Linear".to_string(),
            y_scale: "Linear".to_string(),
            x_label: "X".to_string(),
            y_label: "Y".to_string(),
            aspect_ratio: None,
            show_grid: true,
            show_legend: true,
            legend_position: "Top Right".to_string(),
            title_font_size: default_title_font_size(),
            tick_font_size: default_tick_font_size(),
            title_padding: default_title_padding(),
            title_padding_y: default_title_padding(),
            show_border: false,
            grid_color: None,
            axis_color: None,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TableProperties {
    pub legend_display_name: String,
    pub line_style: String,
    pub line_thickness: f64,
    pub line_visible: bool,
    pub marker_type: String,
    pub marker_visible: bool,
    pub line_color: String,
    pub marker_color: String,
}

impl Default for TableProperties {
    fn default() -> Self {
        Self {
            legend_display_name: "Series".to_string(),
            line_style: "Full".to_string(),
            line_thickness: 2.5,
            line_visible: true,
            marker_type: "Circle".to_string(),
            marker_visible: false,
            line_color: "#1F77B4".to_string(),
            marker_color: "#FFFFFF".to_string(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FunctionProperties {
    pub equation: String,
    /// Display Name shown in the legend (falls back to the node name when
    /// empty or `"Series"`, mirroring `TableProperties`).
    #[serde(default = "default_legend_name")]
    pub legend_display_name: String,
    /// Optional local domain override (falls back to the graph viewport).
    /// `#[serde(default)]` keeps pre-Step-4 bundles loadable.
    #[serde(default = "default_function_xmin")]
    pub x_min: Option<f64>,
    #[serde(default = "default_function_xmax")]
    pub x_max: Option<f64>,
    #[serde(default = "default_num_samples")]
    pub num_samples: usize,
    #[serde(default = "default_function_color")]
    pub line_color: String,
    #[serde(default = "default_line_thickness")]
    pub line_thickness: f64,
    #[serde(default = "default_line_style")]
    pub line_style: String,
}

fn default_legend_name() -> String {
    "Series".to_string()
}

fn default_function_xmin() -> Option<f64> {
    Some(-10.0)
}

fn default_function_xmax() -> Option<f64> {
    Some(10.0)
}

fn default_num_samples() -> usize {
    1000
}

fn default_function_color() -> String {
    "#FF7F0E".to_string()
}

fn default_line_thickness() -> f64 {
    2.5
}

fn default_line_style() -> String {
    "Solid".to_string()
}

impl Default for FunctionProperties {
    fn default() -> Self {
        Self {
            equation: "f(x) = x".to_string(),
            legend_display_name: default_legend_name(),
            x_min: default_function_xmin(),
            x_max: default_function_xmax(),
            num_samples: default_num_samples(),
            line_color: default_function_color(),
            line_thickness: default_line_thickness(),
            line_style: default_line_style(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ShapeProperties {
    pub shape_type: String,
}

impl Default for ShapeProperties {
    fn default() -> Self {
        Self {
            shape_type: "Rectangle".to_string(),
        }
    }
}

// Stores
static FOLDER_PROPS: OnceLock<Mutex<HashMap<String, FolderProperties>>> = OnceLock::new();
static GRAPH_PROPS: OnceLock<Mutex<HashMap<String, GraphProperties>>> = OnceLock::new();
static TABLE_PROPS: OnceLock<Mutex<HashMap<String, TableProperties>>> = OnceLock::new();
static FUNCTION_PROPS: OnceLock<Mutex<HashMap<String, FunctionProperties>>> = OnceLock::new();
static SHAPE_PROPS: OnceLock<Mutex<HashMap<String, ShapeProperties>>> = OnceLock::new();

fn get_folder_store() -> &'static Mutex<HashMap<String, FolderProperties>> {
    FOLDER_PROPS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn get_graph_store() -> &'static Mutex<HashMap<String, GraphProperties>> {
    GRAPH_PROPS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn get_table_store() -> &'static Mutex<HashMap<String, TableProperties>> {
    TABLE_PROPS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn get_function_store() -> &'static Mutex<HashMap<String, FunctionProperties>> {
    FUNCTION_PROPS.get_or_init(|| Mutex::new(HashMap::new()))
}
fn get_shape_store() -> &'static Mutex<HashMap<String, ShapeProperties>> {
    SHAPE_PROPS.get_or_init(|| Mutex::new(HashMap::new()))
}

// APIs
#[flutter_rust_bridge::frb(sync)]
pub fn get_folder_properties(node_id: String) -> FolderProperties {
    let mut store = lock_or_recover(get_folder_store());
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_folder_properties(node_id: String, props: FolderProperties) {
    lock_or_recover(get_folder_store()).insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_graph_properties(node_id: String) -> GraphProperties {
    let mut store = lock_or_recover(get_graph_store());
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_graph_properties(node_id: String, props: GraphProperties) {
    lock_or_recover(get_graph_store()).insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_table_properties(node_id: String) -> TableProperties {
    let mut store = lock_or_recover(get_table_store());
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_table_properties(node_id: String, props: TableProperties) {
    lock_or_recover(get_table_store()).insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_function_properties(node_id: String) -> FunctionProperties {
    let mut store = lock_or_recover(get_function_store());
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_function_properties(node_id: String, props: FunctionProperties) {
    lock_or_recover(get_function_store()).insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_shape_properties(node_id: String) -> ShapeProperties {
    let mut store = lock_or_recover(get_shape_store());
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_shape_properties(node_id: String, props: ShapeProperties) {
    lock_or_recover(get_shape_store()).insert(node_id, props);
}

// ---------------------------------------------------------------------------
// Persistence helpers (crate-internal): snapshot / restore / clear all stores.
// Used by `persistence.rs` to pack/unpack the `.primeplot` bundle.
// ---------------------------------------------------------------------------

pub(crate) fn snapshot_folder_props() -> HashMap<String, FolderProperties> {
    lock_or_recover(get_folder_store()).clone()
}

pub(crate) fn snapshot_graph_props() -> HashMap<String, GraphProperties> {
    lock_or_recover(get_graph_store()).clone()
}

pub(crate) fn snapshot_table_props() -> HashMap<String, TableProperties> {
    lock_or_recover(get_table_store()).clone()
}

pub(crate) fn snapshot_function_props() -> HashMap<String, FunctionProperties> {
    lock_or_recover(get_function_store()).clone()
}

pub(crate) fn snapshot_shape_props() -> HashMap<String, ShapeProperties> {
    lock_or_recover(get_shape_store()).clone()
}

pub(crate) fn restore_folder_props(map: HashMap<String, FolderProperties>) {
    *lock_or_recover(get_folder_store()) = map;
}

pub(crate) fn restore_graph_props(map: HashMap<String, GraphProperties>) {
    *lock_or_recover(get_graph_store()) = map;
}

pub(crate) fn restore_table_props(map: HashMap<String, TableProperties>) {
    *lock_or_recover(get_table_store()) = map;
}

pub(crate) fn restore_function_props(map: HashMap<String, FunctionProperties>) {
    *lock_or_recover(get_function_store()) = map;
}

pub(crate) fn restore_shape_props(map: HashMap<String, ShapeProperties>) {
    *lock_or_recover(get_shape_store()) = map;
}

pub(crate) fn clear_all_property_stores() {
    lock_or_recover(get_folder_store()).clear();
    lock_or_recover(get_graph_store()).clear();
    lock_or_recover(get_table_store()).clear();
    lock_or_recover(get_function_store()).clear();
    lock_or_recover(get_shape_store()).clear();
}

/// Single-entry inserts for node duplication (deep copy under fresh IDs).
pub(crate) fn restore_single_folder(id: String, props: FolderProperties) {
    lock_or_recover(get_folder_store()).insert(id, props);
}

pub(crate) fn restore_single_graph(id: String, props: GraphProperties) {
    lock_or_recover(get_graph_store()).insert(id, props);
}

pub(crate) fn restore_single_table(id: String, props: TableProperties) {
    lock_or_recover(get_table_store()).insert(id, props);
}

pub(crate) fn restore_single_function(id: String, props: FunctionProperties) {
    lock_or_recover(get_function_store()).insert(id, props);
}

pub(crate) fn restore_single_shape(id: String, props: ShapeProperties) {
    lock_or_recover(get_shape_store()).insert(id, props);
}

/// Serializes tests that mutate global stores (Rust runs tests in parallel
/// threads; without this, store-backed tests flake against each other).
#[cfg(test)]
pub(crate) static TEST_MUTEX: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_graph_props_migrate_with_defaults() {
        // Pre-Step-K bundles have all legacy fields but none of the newer ones.
        let legacy: GraphProperties = serde_json::from_str(
            r#"{"x_min":null,"x_max":null,"y_min":null,"y_max":null,"x_visible":true,"y_visible":true,"x_scale":"Linear","y_scale":"Linear","x_label":"T","y_label":"Y","aspect_ratio":null,"show_grid":false,"show_legend":true,"legend_position":"Top Right"}"#,
        )
        .unwrap();
        assert_eq!(legacy.x_label, "T");
        assert!(!legacy.show_grid);
        assert_eq!(legacy.title_font_size, 12.0);
        assert_eq!(legacy.tick_font_size, 10.0);
        assert_eq!(legacy.title_padding, 20.0);
        assert_eq!(legacy.title_padding_y, 20.0);
        assert!(!legacy.show_border);
        assert_eq!(legacy.grid_color, None);
        assert_eq!(legacy.axis_color, None);
    }

    #[test]
    fn legacy_function_props_migrate_with_defaults() {
        // Pre-Step-4 bundles stored only {"equation": ...}.
        let legacy: FunctionProperties = serde_json::from_str(r#"{"equation":"x"}"#).unwrap();
        assert_eq!(legacy.equation, "x");
        assert_eq!(legacy.legend_display_name, "Series");
        assert_eq!(legacy.x_min, Some(-10.0));
        assert_eq!(legacy.x_max, Some(10.0));
        assert_eq!(legacy.num_samples, 1000);
        assert_eq!(legacy.line_color, "#FF7F0E");
    }
}
