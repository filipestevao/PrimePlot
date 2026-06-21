// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

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

    pub fn remove_node(&mut self, target_id: &str) -> Option<ProjectNode> {
        if let Some(index) = self.children.iter().position(|c| c.id == target_id) {
            return Some(self.children.remove(index));
        }
        for child in &mut self.children {
            if let Some(removed) = child.remove_node(target_id) {
                return Some(removed);
            }
        }
        None
    }

    pub fn insert_node_opt(&mut self, target_parent_id: &str, node: &mut Option<ProjectNode>) {
        if self.id == target_parent_id {
            if let Some(n) = node.take() {
                self.children.push(n);
            }
            return;
        }
        for child in &mut self.children {
            child.insert_node_opt(target_parent_id, node);
            if node.is_none() {
                return;
            }
        }
    }

    pub fn reorder_children(&mut self, target_parent_id: &str, old_index: usize, new_index: usize) -> bool {
        if self.id == target_parent_id {
            if old_index < self.children.len() && new_index < self.children.len() {
                let child = self.children.remove(old_index);
                self.children.insert(new_index, child);
            }
            return true;
        }
        for child in &mut self.children {
            if child.reorder_children(target_parent_id, old_index, new_index) {
                return true;
            }
        }
        false
    }

    pub fn rename_node(&mut self, target_id: &str, new_name: &str) -> bool {
        if self.id == target_id {
            self.name = new_name.to_string();
            return true;
        }
        for child in &mut self.children {
            if child.rename_node(target_id, new_name) {
                return true;
            }
        }
        false
    }
}
