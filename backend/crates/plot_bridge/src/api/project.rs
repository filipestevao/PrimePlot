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
    let mut root = EngineProjectNode::new("root_1", "Main Project", EngineNodeType::Folder);
    
    let mut data_folder = EngineProjectNode::new("folder_1", "Data", EngineNodeType::Folder);
    data_folder.add_child(EngineProjectNode::new("ds_1", "Sample XRD Data", EngineNodeType::Dataset));
    data_folder.add_child(EngineProjectNode::new("ds_2", "Calibration Data", EngineNodeType::Dataset));

    let mut plots_folder = EngineProjectNode::new("folder_2", "Plots", EngineNodeType::Folder);
    plots_folder.add_child(EngineProjectNode::new("plot_1", "Intensity vs 2Theta", EngineNodeType::Plot));

    root.add_child(data_folder);
    root.add_child(plots_folder);

    root.into()
}
