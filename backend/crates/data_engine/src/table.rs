// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

#[derive(Clone, Debug)]
pub enum ColumnRole {
    X,
    Y,
    XError,
    YError,
    Text,
}

#[derive(Clone, Debug)]
pub struct DataColumn {
    pub name: String,
    pub role: ColumnRole,
    pub data: Vec<f64>, // Keeping it simple with f64 for now, could use an enum for Text later
}

#[derive(Clone, Debug)]
pub struct DataTable {
    pub id: String,
    pub name: String,
    pub columns: Vec<DataColumn>,
}

impl DataTable {
    pub fn new(id: &str, name: &str) -> Self {
        Self {
            id: id.to_string(),
            name: name.to_string(),
            columns: Vec::new(),
        }
    }

    pub fn add_column(&mut self, col: DataColumn) {
        self.columns.push(col);
    }
}
