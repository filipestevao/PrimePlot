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
    /// f64::NAN encodes an empty cell. The Flutter side checks `value.isNaN`.
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

// ---------------------------------------------------------------------------
// Empty table – application startup state
// ---------------------------------------------------------------------------

/// Returns an empty two-column table (Position/X, Intensity/Y) with zero rows.
/// This is the canonical starting state of the application.
#[frb(sync)]
pub fn get_empty_table_data() -> DTODataTable {
    let mut table = EngineDataTable::new("table_001", "Untitled");
    table.add_column(DataColumn {
        name: "Position".to_string(),
        role: ColumnRole::X,
        data: Vec::new(),
    });
    table.add_column(DataColumn {
        name: "Intensity".to_string(),
        role: ColumnRole::Y,
        data: Vec::new(),
    });
    table.into()
}

/// Compat alias – kept so the existing frb_generated.rs glue compiles until
/// `flutter_rust_bridge_codegen generate` is re-run.
#[frb(sync)]
pub fn get_initial_table_data() -> DTODataTable {
    get_empty_table_data()
}

// ---------------------------------------------------------------------------
// Clipboard paste parser
// ---------------------------------------------------------------------------

/// Normalises a single cell string to f64.
///
/// Rules (in priority order):
///   1. Both ',' and '.' present → first occurrence is the thousands separator
///      (stripped), second is the decimal separator (replaced with '.').
///   2. Only ',' present → European decimal comma → replace with '.'.
///   3. Only '.' present → standard decimal point → parse as-is.
///   4. Neither → integer or empty string.
///   5. Empty string → f64::NAN (empty cell sentinel).
fn normalise_cell(raw: &str) -> f64 {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return f64::NAN;
    }

    let dot_pos = trimmed.find('.');
    let comma_pos = trimmed.find(',');

    let normalised: String = match (comma_pos, dot_pos) {
        (Some(ci), Some(di)) => {
            // Both separators present: the one that appears first is thousands.
            if ci < di {
                // e.g. "1,234.56" – comma is thousands, dot is decimal
                trimmed.replace(',', "")
            } else {
                // e.g. "1.234,56" – dot is thousands, comma is decimal
                trimmed.replace('.', "").replace(',', ".")
            }
        }
        (Some(_), None) => {
            // Only comma: European decimal → "1,5" → "1.5"
            trimmed.replace(',', ".")
        }
        _ => {
            // Only dot or neither: standard format
            trimmed.to_string()
        }
    };

    normalised.parse::<f64>().unwrap_or(f64::NAN)
}

/// Returns `true` if all cells in a row parse as non-numeric (used for header detection).
fn row_is_header(cells: &[&str]) -> bool {
    cells
        .iter()
        .all(|c| c.trim().parse::<f64>().is_err() && !c.trim().is_empty())
}

/// Detects the column delimiter from the first data row.
fn detect_delimiter(line: &str) -> char {
    // Tab is the most common clipboard delimiter (spreadsheet default).
    if line.contains('\t') {
        return '\t';
    }
    if line.contains(';') {
        return ';';
    }
    // Comma only if dots are absent or rare (avoids breaking "1,5" decimals).
    if line.contains(',') && !line.contains('.') {
        return ',';
    }
    '\t' // fallback
}

/// Parses a raw clipboard string (TSV / CSV) into a DTODataTable.
///
/// - Blank cells become f64::NAN (empty cell sentinel).
/// - Decimal normalisation handles European and US formats automatically.
/// - If the first row is all non-numeric, it is treated as column headers.
/// - Column roles: col 0 → X, col 1 → Y, rest → Y.
#[frb(sync)]
pub fn parse_clipboard_table(raw: String) -> DTODataTable {
    // Split into lines, strip trailing empty lines.
    let lines: Vec<&str> = raw
        .lines()
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .skip_while(|l| l.trim().is_empty())
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();

    if lines.is_empty() {
        return get_empty_table_data();
    }

    let delimiter = detect_delimiter(lines[0]);

    // Split all lines into cells.
    let rows: Vec<Vec<&str>> = lines
        .iter()
        .map(|l| l.split(delimiter).collect())
        .collect();

    // Determine column count (widest row).
    let col_count = rows.iter().map(|r| r.len()).max().unwrap_or(0);
    if col_count == 0 {
        return get_empty_table_data();
    }

    // Check for header row.
    let (header_row, data_rows) = if !rows.is_empty() && row_is_header(&rows[0]) {
        (Some(&rows[0]), &rows[1..])
    } else {
        (None, &rows[..])
    };

    // Build column name list.
    let col_names: Vec<String> = (0..col_count)
        .map(|i| {
            header_row
                .and_then(|h| h.get(i))
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| format!("Col {}", i + 1))
        })
        .collect();

    // Allocate column data vectors.
    let row_count = data_rows.len();
    let mut col_data: Vec<Vec<f64>> = vec![Vec::with_capacity(row_count); col_count];

    for row in data_rows {
        for ci in 0..col_count {
            let cell = row.get(ci).copied().unwrap_or("");
            col_data[ci].push(normalise_cell(cell));
        }
    }

    // Assemble DTODataTable.
    let mut table = EngineDataTable::new("table_001", "Untitled");
    for (i, name) in col_names.iter().enumerate() {
        let role = if i == 0 { ColumnRole::X } else { ColumnRole::Y };
        table.add_column(DataColumn {
            name: name.clone(),
            role,
            data: col_data[i].clone(),
        });
    }

    table.into()
}

// ---------------------------------------------------------------------------
// Scatter / Hide auto-rule
// ---------------------------------------------------------------------------

/// Returns `true` (Scatter enabled) when `row_count` ≤ 10, `false` (Hide) otherwise.
/// Rust is the single source of truth for this threshold rule.
#[frb(sync)]
pub fn apply_scatter_rule(row_count: usize) -> bool {
    row_count <= 10
}
