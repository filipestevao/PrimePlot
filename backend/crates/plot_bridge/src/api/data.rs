use core_math::{generate_scientific_dataset, Point2D as CorePoint2D};
use data_engine::table::{ColumnRole, DataColumn, DataTable as EngineDataTable};
use flutter_rust_bridge::frb;

/// A simple DTO for passing 2D points to Flutter.
/// Using #[frb(dart_metadata=...)] if we needed specific Dart names, but simple structs map cleanly.
#[derive(Clone, Debug)]
pub struct Point2D {
    pub x: f64,
    pub y: f64,
}

impl From<CorePoint2D> for Point2D {
    fn from(core_point: CorePoint2D) -> Self {
        Self {
            x: core_point.x,
            y: core_point.y,
        }
    }
}

/// DTOs for Table Data
#[derive(Clone, Debug)]
pub enum DTOColumnRole {
    X,
    Y,
    XError,
    YError,
    Text,
}

impl From<ColumnRole> for DTOColumnRole {
    fn from(role: ColumnRole) -> Self {
        match role {
            ColumnRole::X => DTOColumnRole::X,
            ColumnRole::Y => DTOColumnRole::Y,
            ColumnRole::XError => DTOColumnRole::XError,
            ColumnRole::YError => DTOColumnRole::YError,
            ColumnRole::Text => DTOColumnRole::Text,
        }
    }
}

#[derive(Clone, Debug)]
pub struct DTODataColumn {
    pub name: String,
    pub role: DTOColumnRole,
    pub data: Vec<f64>,
}

impl From<DataColumn> for DTODataColumn {
    fn from(col: DataColumn) -> Self {
        Self {
            name: col.name,
            role: col.role.into(),
            data: col.data,
        }
    }
}

#[derive(Clone, Debug)]
pub struct DTODataTable {
    pub id: String,
    pub name: String,
    pub columns: Vec<DTODataColumn>,
}

impl From<EngineDataTable> for DTODataTable {
    fn from(table: EngineDataTable) -> Self {
        Self {
            id: table.id,
            name: table.name,
            columns: table.columns.into_iter().map(|c| c.into()).collect(),
        }
    }
}

/// Fetches a high-performance mock scientific dataset from the core math engine.
#[frb(sync)]
pub fn get_mock_scientific_data(num_points: usize) -> Vec<Point2D> {
    let core_data = generate_scientific_dataset(num_points);
    core_data.into_iter().map(|p| p.into()).collect()
}

/// Fetches an initial table structure populated with the mock scientific dataset.
#[frb(sync)]
pub fn get_initial_table_data() -> DTODataTable {
    let core_data = generate_scientific_dataset(2000);
    
    let mut x_col = Vec::with_capacity(2000);
    let mut y_col = Vec::with_capacity(2000);
    
    for pt in core_data {
        x_col.push(pt.x);
        y_col.push(pt.y);
    }
    
    let mut table = EngineDataTable::new("table_001", "Exp101.csv");
    table.add_column(DataColumn {
        name: "Position".to_string(),
        role: ColumnRole::X,
        data: x_col,
    });
    table.add_column(DataColumn {
        name: "Intensity".to_string(),
        role: ColumnRole::Y,
        data: y_col,
    });
    
    table.into()
}
