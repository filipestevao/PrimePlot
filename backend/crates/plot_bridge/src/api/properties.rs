// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

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
            marker_visible: true,
            line_color: "#1F77B4".to_string(),
            marker_color: "#FFFFFF".to_string(),
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FunctionProperties {
    pub equation: String,
}

impl Default for FunctionProperties {
    fn default() -> Self {
        Self {
            equation: "f(x) = x".to_string(),
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
    let mut store = get_folder_store().lock().unwrap();
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_folder_properties(node_id: String, props: FolderProperties) {
    get_folder_store().lock().unwrap().insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_graph_properties(node_id: String) -> GraphProperties {
    let mut store = get_graph_store().lock().unwrap();
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_graph_properties(node_id: String, props: GraphProperties) {
    get_graph_store().lock().unwrap().insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_table_properties(node_id: String) -> TableProperties {
    let mut store = get_table_store().lock().unwrap();
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_table_properties(node_id: String, props: TableProperties) {
    get_table_store().lock().unwrap().insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_function_properties(node_id: String) -> FunctionProperties {
    let mut store = get_function_store().lock().unwrap();
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_function_properties(node_id: String, props: FunctionProperties) {
    get_function_store().lock().unwrap().insert(node_id, props);
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_shape_properties(node_id: String) -> ShapeProperties {
    let mut store = get_shape_store().lock().unwrap();
    store.entry(node_id).or_default().clone()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_shape_properties(node_id: String, props: ShapeProperties) {
    get_shape_store().lock().unwrap().insert(node_id, props);
}

// ---------------------------------------------------------------------------
// Persistence helpers (crate-internal): snapshot / restore / clear all stores.
// Used by `persistence.rs` to pack/unpack the `.primeplot` bundle.
// ---------------------------------------------------------------------------

pub(crate) fn snapshot_folder_props() -> HashMap<String, FolderProperties> {
    get_folder_store().lock().unwrap().clone()
}

pub(crate) fn snapshot_graph_props() -> HashMap<String, GraphProperties> {
    get_graph_store().lock().unwrap().clone()
}

pub(crate) fn snapshot_table_props() -> HashMap<String, TableProperties> {
    get_table_store().lock().unwrap().clone()
}

pub(crate) fn snapshot_function_props() -> HashMap<String, FunctionProperties> {
    get_function_store().lock().unwrap().clone()
}

pub(crate) fn snapshot_shape_props() -> HashMap<String, ShapeProperties> {
    get_shape_store().lock().unwrap().clone()
}

pub(crate) fn restore_folder_props(map: HashMap<String, FolderProperties>) {
    *get_folder_store().lock().unwrap() = map;
}

pub(crate) fn restore_graph_props(map: HashMap<String, GraphProperties>) {
    *get_graph_store().lock().unwrap() = map;
}

pub(crate) fn restore_table_props(map: HashMap<String, TableProperties>) {
    *get_table_store().lock().unwrap() = map;
}

pub(crate) fn restore_function_props(map: HashMap<String, FunctionProperties>) {
    *get_function_store().lock().unwrap() = map;
}

pub(crate) fn restore_shape_props(map: HashMap<String, ShapeProperties>) {
    *get_shape_store().lock().unwrap() = map;
}

pub(crate) fn clear_all_property_stores() {
    get_folder_store().lock().unwrap().clear();
    get_graph_store().lock().unwrap().clear();
    get_table_store().lock().unwrap().clear();
    get_function_store().lock().unwrap().clear();
    get_shape_store().lock().unwrap().clear();
}

/// Serializes tests that mutate global stores (Rust runs tests in parallel
/// threads; without this, store-backed tests flake against each other).
#[cfg(test)]
pub(crate) static TEST_MUTEX: std::sync::Mutex<()> = std::sync::Mutex::new(());
