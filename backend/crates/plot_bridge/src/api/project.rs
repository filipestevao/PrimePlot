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

#[flutter_rust_bridge::frb(sync)]
pub fn get_project_tree() -> ProjectNode {
    let mut root = EngineProjectNode::new("root_1", "Project", EngineNodeType::Folder);
    
    root.add_child(EngineProjectNode::new("table_1", "Table", EngineNodeType::Dataset));
    root.add_child(EngineProjectNode::new("graph_1", "Graph", EngineNodeType::Plot));

    root.into()
}
