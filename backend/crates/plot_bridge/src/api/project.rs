// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use data_engine::{NodeType as EngineNodeType, ProjectNode as EngineProjectNode};

#[derive(Clone, Debug)]
pub enum NodeType {
    Folder,
    Dataset,
    Plot,
    Function,
    Shape,
}

#[derive(Clone, Debug)]
pub struct ProjectNode {
    pub id: String,
    pub name: String,
    pub node_type: NodeType,
    pub children: Vec<ProjectNode>,
}

impl From<EngineNodeType> for NodeType {
    fn from(engine_node_type: EngineNodeType) -> Self {
        match engine_node_type {
            EngineNodeType::Folder => NodeType::Folder,
            EngineNodeType::Dataset => NodeType::Dataset,
            EngineNodeType::Plot => NodeType::Plot,
            EngineNodeType::Function => NodeType::Function,
            EngineNodeType::Shape => NodeType::Shape,
        }
    }
}

impl From<EngineProjectNode> for ProjectNode {
    fn from(engine_node: EngineProjectNode) -> Self {
        ProjectNode {
            id: engine_node.id,
            name: engine_node.name,
            node_type: engine_node.node_type.into(),
            children: engine_node.children.into_iter().map(|c| c.into()).collect(),
        }
    }
}

use std::sync::{Mutex, OnceLock};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::collections::HashMap;
use data_engine::table::{DataTable as EngineDataTable, DataColumn as EngineDataColumn, ColumnRole as EngineColumnRole};
use crate::api::data::{DTODataTable, DTOColumnRole};

static PROJECT_STATE: OnceLock<Mutex<EngineProjectNode>> = OnceLock::new();
static NEXT_ID: AtomicUsize = AtomicUsize::new(100);

pub(crate) fn get_state() -> &'static Mutex<EngineProjectNode> {
    PROJECT_STATE.get_or_init(|| {
        let mut root = EngineProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
        let mut project = EngineProjectNode::new("project_1", "Project", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new("table_1", "Table", EngineNodeType::Dataset));
        project.add_child(graph);
        root.add_child(project);

        // Also seed TABLE_STORE with the initial empty table so get_table / update_table_from_raw work.
        let initial = crate::api::data::get_empty_table_data();
        let mut store = TABLE_STORE.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap();
        store.insert(initial.id.clone(), dto_to_engine_table(initial));

        Mutex::new(root)
    })
}

fn generate_id(prefix: &str) -> String {
    let id = NEXT_ID.fetch_add(1, Ordering::SeqCst);
    format!("{}_{}", prefix, id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_project_tree() -> ProjectNode {
    let state = get_state().lock().unwrap();
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_project_node(parent_id: String, name: String, node_type: NodeType) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    
    let engine_type = match node_type {
        NodeType::Folder => EngineNodeType::Folder,
        NodeType::Dataset => EngineNodeType::Dataset,
        NodeType::Plot => EngineNodeType::Plot,
        NodeType::Function => EngineNodeType::Function,
        NodeType::Shape => EngineNodeType::Shape,
    };
    
    let prefix = match node_type {
        NodeType::Folder => "folder",
        NodeType::Dataset => "table",
        NodeType::Plot => "graph",
        NodeType::Function => "function",
        NodeType::Shape => "shape",
    };
    
    let new_id = generate_id(prefix);
    let new_node = EngineProjectNode::new(&new_id, &name, engine_type);
    let mut opt_node = Some(new_node);
    
    // Attempt to insert into specified parent.
    state.insert_node_opt(&parent_id, &mut opt_node);
    
    // If we failed to insert (parent not found or it's root but handled), append to root.
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    // Seed TABLE_STORE with an empty table for new Dataset nodes.
    if let NodeType::Dataset = node_type {
        let mut table = EngineDataTable::new(&new_id, &name);
        table.add_column(EngineDataColumn {
            name: "Col 1".to_string(),
            role: EngineColumnRole::X,
            data: Vec::new(),
        });
        table.add_column(EngineDataColumn {
            name: "Col 2".to_string(),
            role: EngineColumnRole::Y,
            data: Vec::new(),
        });
        let mut store = get_table_store().lock().unwrap();
        store.insert(new_id.clone(), table);
        drop(store);
        // Display Name follows the node name; palette color skips colors
        // already used by dataset + function siblings under the graph.
        let ds = dataset_ids_in_order(&state, &parent_id);
        let fs = function_ids_in_order(&state, &parent_id);
        let color =
            crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
        crate::api::palettes::init_curve_props(&new_id, &name, color);
    }

    // Newborn functions join the same palette cycle as datasets.
    if let NodeType::Function = node_type {
        let ds = dataset_ids_in_order(&state, &parent_id);
        let fs = function_ids_in_order(&state, &parent_id);
        let color =
            crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
        crate::api::palettes::init_function_props(&new_id, &name, color);
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn move_project_node(node_id: String, new_parent_id: String) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    
    if node_id == "root_1" {
        return state.clone().into();
    }
    
    if let Some(node) = state.remove_node(&node_id) {
        let mut opt_node = Some(node);
        state.insert_node_opt(&new_parent_id, &mut opt_node);
        // If parent not found, put it back to root
        if let Some(node) = opt_node.take() {
            state.add_child(node);
        }
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn rename_project_node(node_id: String, new_name: String) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    state.rename_node(&node_id, &new_name);
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn reorder_project_children(parent_id: String, old_index: usize, new_index: usize) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    state.reorder_children(&parent_id, old_index, new_index);
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn delete_project_node(node_id: String) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    
    if let Some(removed_node) = state.remove_node(&node_id) {
        let mut datasets_to_remove = Vec::new();
        
        // Recursive collector to find all dataset IDs in the removed subtree
        fn collect_datasets(n: &EngineProjectNode, datasets: &mut Vec<String>) {
            if let EngineNodeType::Dataset = n.node_type {
                datasets.push(n.id.clone());
            }
            for child in &n.children {
                collect_datasets(child, datasets);
            }
        }
        collect_datasets(&removed_node, &mut datasets_to_remove);
        
        let mut store = get_table_store().lock().unwrap();
        for id in datasets_to_remove {
            store.remove(&id);
        }
    }
    
    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn update_table_from_raw(table_id: String, raw: String) {
    let mut new_dto = crate::api::data::parse_clipboard_table(raw);
    
    let mut store = get_table_store().lock().unwrap();
    if let Some(existing_table) = store.get_mut(&table_id) {
        new_dto.name = existing_table.name.clone();
    }
    new_dto.id = table_id.clone();
    store.insert(table_id, dto_to_engine_table(new_dto));
}

static TABLE_STORE: OnceLock<Mutex<HashMap<String, EngineDataTable>>> = OnceLock::new();

fn get_table_store() -> &'static Mutex<HashMap<String, EngineDataTable>> {
    TABLE_STORE.get_or_init(|| Mutex::new(HashMap::new()))
}

pub(crate) fn dto_to_engine_table(dto: DTODataTable) -> EngineDataTable {
    let mut et = EngineDataTable::new(&dto.id, &dto.name);
    for col in dto.columns {
        let role = match col.role {
            DTOColumnRole::X => EngineColumnRole::X,
            DTOColumnRole::Y => EngineColumnRole::Y,
            DTOColumnRole::XError => EngineColumnRole::XError,
            DTOColumnRole::YError => EngineColumnRole::YError,
            DTOColumnRole::Text => EngineColumnRole::Text,
        };
        et.add_column(EngineDataColumn { name: col.name, role, data: col.data });
    }
    et
}

#[flutter_rust_bridge::frb(sync)]
pub fn save_table(table_id: String, columns: Vec<crate::api::data::DTODataColumn>) {
    let mut store = get_table_store().lock().unwrap();
    let name = store.get(&table_id).map(|t| t.name.clone()).unwrap_or_default();
    let mut et = EngineDataTable::new(&table_id, &name);
    for col in columns {
        let role = match col.role {
            DTOColumnRole::X => EngineColumnRole::X,
            DTOColumnRole::Y => EngineColumnRole::Y,
            DTOColumnRole::XError => EngineColumnRole::XError,
            DTOColumnRole::YError => EngineColumnRole::YError,
            DTOColumnRole::Text => EngineColumnRole::Text,
        };
        et.add_column(EngineDataColumn { name: col.name, role, data: col.data });
    }
    store.insert(table_id, et);
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_empty_table(parent_id: String, name: String, row_count: usize, col_count: usize) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    let new_id = generate_id("table");

    let mut et = EngineDataTable::new(&new_id, &name);
    for i in 0..col_count {
        let (col_name, role) = if i == 0 {
            ("Position".to_string(), EngineColumnRole::X)
        } else {
            (format!("Col {}", i + 1), EngineColumnRole::Y)
        };
        et.add_column(EngineDataColumn {
            name: col_name,
            role,
            data: vec![f64::NAN; row_count],
        });
    }

    let mut store = get_table_store().lock().unwrap();
    store.insert(new_id.clone(), et);

    let new_node = EngineProjectNode::new(&new_id, &name, EngineNodeType::Dataset);
    let mut opt_node = Some(new_node);
    state.insert_node_opt(&parent_id, &mut opt_node);
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    drop(store);
    let ds = dataset_ids_in_order(&state, &parent_id);
    let fs = function_ids_in_order(&state, &parent_id);
    let color =
        crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
    crate::api::palettes::init_curve_props(&new_id, &name, color);

    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn add_table_from_raw(parent_id: String, raw: String, display_name: String) -> ProjectNode {
    let mut state = get_state().lock().unwrap();
    // Parse using existing parser
    let mut dto = crate::api::data::parse_clipboard_table(raw);
    // assign unique id and display name
    let new_id = generate_id("table");
    dto.id = new_id.clone();
    dto.name = display_name.clone();

    // store engine table
    let engine_table = dto_to_engine_table(dto.clone());
    let mut store = get_table_store().lock().unwrap();
    store.insert(new_id.clone(), engine_table);

    // insert project node
    let new_node = EngineProjectNode::new(&new_id, &display_name, EngineNodeType::Dataset);
    let mut opt_node = Some(new_node);
    state.insert_node_opt(&parent_id, &mut opt_node);
    if let Some(node) = opt_node.take() {
        state.add_child(node);
    }

    drop(store);
    let ds = dataset_ids_in_order(&state, &parent_id);
    let fs = function_ids_in_order(&state, &parent_id);
    let color =
        crate::api::palettes::next_combined_color(ds.as_deref(), fs.as_deref());
    crate::api::palettes::init_curve_props(&new_id, &display_name, color);

    state.clone().into()
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_table(table_id: String) -> crate::api::data::DTODataTable {
    let store = get_table_store().lock().unwrap();
    if let Some(t) = store.get(&table_id) {
        t.clone().into()
    } else {
        crate::api::data::get_empty_table_data()
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_tables_for_graph(graph_id: String) -> Vec<crate::api::data::DTODataTable> {
    let state = get_state().lock().unwrap();
    let mut result = Vec::new();
    // find graph node
    fn find(node: &EngineProjectNode, target: &str, out: &mut Vec<String>) {
        if node.id == target {
            for c in &node.children {
                match c.node_type {
                    EngineNodeType::Dataset => out.push(c.id.clone()),
                    _ => (),
                }
            }
            return;
        }
        for c in &node.children {
            find(c, target, out);
        }
    }
    let mut ids = Vec::new();
    find(&state, &graph_id, &mut ids);

    let store = get_table_store().lock().unwrap();
    for id in ids {
        if let Some(t) = store.get(&id) {
            result.push(t.clone().into());
        }
    }
    result
}

// ---------------------------------------------------------------------------
// Persistence helpers (crate-internal): snapshot / restore project + tables.
// Used by `persistence.rs` to pack/unpack the `.primeplot` bundle.
// ---------------------------------------------------------------------------

/// Dataset children of `graph_id` in tree order (empty when the node is
/// missing or not a plot). Used for palette cycling / re-alignment.
/// Callers must NOT hold any store lock other than `PROJECT_STATE`
/// (palette code locks the property stores).
pub(crate) fn dataset_ids_in_order(
    state: &EngineProjectNode,
    graph_id: &str,
) -> Option<Vec<String>> {
    child_ids_of_type(state, graph_id, true)
}

/// Function children of `graph_id` in tree order. Same locking rules.
pub(crate) fn function_ids_in_order(
    state: &EngineProjectNode,
    graph_id: &str,
) -> Option<Vec<String>> {
    child_ids_of_type(state, graph_id, false)
}

fn child_ids_of_type(
    state: &EngineProjectNode,
    graph_id: &str,
    datasets: bool,
) -> Option<Vec<String>> {
    fn find<'a>(node: &'a EngineProjectNode, target: &str) -> Option<&'a EngineProjectNode> {
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
    let graph = find(state, graph_id)?;
    if !matches!(graph.node_type, EngineNodeType::Plot) {
        return None;
    }
    Some(
        graph
            .children
            .iter()
            .filter(|c| match c.node_type {
                EngineNodeType::Dataset => datasets,
                EngineNodeType::Function => !datasets,
                _ => false,
            })
            .map(|c| c.id.clone())
            .collect(),
    )
}

pub(crate) fn snapshot_tree_engine() -> EngineProjectNode {
    get_state().lock().unwrap().clone()
}

pub(crate) fn restore_tree_engine(tree: EngineProjectNode) {
    *get_state().lock().unwrap() = tree;
}

pub(crate) fn snapshot_tables_engine() -> HashMap<String, EngineDataTable> {
    get_table_store().lock().unwrap().clone()
}

pub(crate) fn restore_tables_engine(map: HashMap<String, EngineDataTable>) {
    *get_table_store().lock().unwrap() = map;
}

/// Builds the canonical empty project: Workspace > Project > Graph > Table.
pub(crate) fn default_project_tree_engine() -> EngineProjectNode {
    let mut root = EngineProjectNode::new("root_1", "Workspace", EngineNodeType::Folder);
    let mut project = EngineProjectNode::new("project_1", "Project", EngineNodeType::Folder);
    let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
    graph.add_child(EngineProjectNode::new(
        "table_1",
        "Table",
        EngineNodeType::Dataset,
    ));
    project.add_child(graph);
    root.add_child(project);
    root
}

/// After loading a bundle, bump NEXT_ID past the highest numeric suffix found
/// in the tree so newly created nodes never collide with restored IDs.
pub(crate) fn reset_next_id_from_tree(tree: &EngineProjectNode) {
    fn max_suffix(node: &EngineProjectNode, current: usize) -> usize {
        let mut best = current;
        if let Some(pos) = node.id.rfind('_') {
            if let Ok(n) = node.id[pos + 1..].parse::<usize>() {
                if n >= best {
                    best = n;
                }
            }
        }
        for child in &node.children {
            best = max_suffix(child, best);
        }
        best
    }
    let max_found = max_suffix(tree, 100);
    let desired = max_found.saturating_add(1);
    // Only move forward, never backwards (avoids reusing live IDs).
    let current = NEXT_ID.load(Ordering::SeqCst);
    if desired > current {
        NEXT_ID.store(desired, Ordering::SeqCst);
    }
}
