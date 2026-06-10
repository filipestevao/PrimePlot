use data_engine::{NodeType as EngineNodeType, ProjectNode as EngineProjectNode};

#[derive(Clone, Debug)]
pub enum NodeType {
    Folder,
    Dataset,
    Plot,
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

static PROJECT_STATE: OnceLock<Mutex<EngineProjectNode>> = OnceLock::new();
static NEXT_ID: AtomicUsize = AtomicUsize::new(100);

fn get_state() -> &'static Mutex<EngineProjectNode> {
    PROJECT_STATE.get_or_init(|| {
        let mut root = EngineProjectNode::new("root_1", "Project", EngineNodeType::Folder);
        let mut graph = EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot);
        graph.add_child(EngineProjectNode::new("table_1", "Table", EngineNodeType::Dataset));
        root.add_child(graph);
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
    };
    
    let prefix = match node_type {
        NodeType::Folder => "folder",
        NodeType::Dataset => "table",
        NodeType::Plot => "graph",
    };
    
    let new_node = EngineProjectNode::new(&generate_id(prefix), &name, engine_type);
    let mut opt_node = Some(new_node);
    
    // Attempt to insert into specified parent.
    state.insert_node_opt(&parent_id, &mut opt_node);
    
    // If we failed to insert (parent not found or it's root but handled), append to root.
    if let Some(node) = opt_node.take() {
        state.add_child(node);
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
