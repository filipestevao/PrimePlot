// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ColumnRole {
    X,
    Y,
    XError,
    YError,
    Text,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DataColumn {
    pub name: String,
    pub role: ColumnRole,
    pub data: Vec<f64>, // Keeping it simple with f64 for now, could use an enum for Text later
}

#[derive(Clone, Debug, Serialize, Deserialize)]
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

    pub fn row_count(&self) -> usize {
        self.columns.iter().map(|c| c.data.len()).max().unwrap_or(0)
    }

    pub fn remove_column(&mut self, index: usize) -> Result<(), String> {
        if index >= self.columns.len() {
            return Err(format!("column index {index} out of range"));
        }
        // Never strand a table without its last X or Y column.
        let role = &self.columns[index].role;
        let is_last_of_kind = matches!(
            role,
            ColumnRole::X | ColumnRole::Y
        ) && self
            .columns
            .iter()
            .filter(|c| std::mem::discriminant(&c.role) == std::mem::discriminant(role))
            .count()
            <= 1;
        if is_last_of_kind {
            return Err("cannot remove the last X or Y column".to_string());
        }
        self.columns.remove(index);
        Ok(())
    }

    pub fn rename_column(&mut self, index: usize, new_name: &str) -> Result<(), String> {
        let name = new_name.trim();
        if name.is_empty() {
            return Err("column name must not be empty".to_string());
        }
        match self.columns.get_mut(index) {
            Some(col) => {
                col.name = name.to_string();
                Ok(())
            }
            None => Err(format!("column index {index} out of range")),
        }
    }

    pub fn set_column_role(&mut self, index: usize, role: ColumnRole) -> Result<(), String> {
        match self.columns.get_mut(index) {
            Some(col) => {
                col.role = role;
                Ok(())
            }
            None => Err(format!("column index {index} out of range")),
        }
    }

    pub fn move_column(&mut self, from: usize, to: usize) -> Result<(), String> {
        let len = self.columns.len();
        if from >= len || to >= len {
            return Err(format!("column move {from} -> {to} out of range"));
        }
        if from == to {
            return Ok(());
        }
        let col = self.columns.remove(from);
        self.columns.insert(to, col);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn two_col_table() -> DataTable {
        let mut t = DataTable::new("t1", "Sample");
        t.add_column(DataColumn {
            name: "X".to_string(),
            role: ColumnRole::X,
            data: vec![1.0, 2.0],
        });
        t.add_column(DataColumn {
            name: "Y".to_string(),
            role: ColumnRole::Y,
            data: vec![3.0, 4.0],
        });
        t
    }

    #[test]
    fn guards_last_x_and_y() {
        let mut t = two_col_table();
        assert!(t.remove_column(0).is_err());
        assert!(t.remove_column(1).is_err());
        t.add_column(DataColumn {
            name: "Y2".to_string(),
            role: ColumnRole::Y,
            data: vec![5.0, 6.0],
        });
        assert!(t.remove_column(2).is_ok());
        assert_eq!(t.columns.len(), 2);
    }

    #[test]
    fn rename_move_role_round_trip() {
        let mut t = two_col_table();
        assert!(t.rename_column(0, "  ").is_err());
        t.rename_column(0, "Pos").unwrap();
        assert_eq!(t.columns[0].name, "Pos");
        t.set_column_role(1, ColumnRole::YError).unwrap();
        assert!(matches!(t.columns[1].role, ColumnRole::YError));
        t.move_column(0, 1).unwrap();
        assert_eq!(t.columns[0].name, "Y");
        assert!(t.move_column(0, 9).is_err());
    }
}
