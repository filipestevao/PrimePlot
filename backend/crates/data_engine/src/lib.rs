pub mod table;

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

impl ProjectNode {
    pub fn new(id: &str, name: &str, node_type: NodeType) -> Self {
        Self {
            id: id.to_string(),
            name: name.to_string(),
            node_type,
            children: Vec::new(),
        }
    }

    pub fn add_child(&mut self, child: ProjectNode) {
        self.children.push(child);
    }
}
