// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Column calculations & data transforms (Step C). Every endpoint mutates
//! `TABLE_STORE` in place and returns the updated table DTO; the Flutter
//! wrapper refreshes state + dirty flag. NaN cells propagate (stay NaN).

use crate::api::data::DTODataTable;

/// Per-column summary statistics (finite values only, except `nan_count`).
#[derive(Clone, Debug)]
pub struct ColumnStatistics {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub std_dev: f64,
    pub count: usize,
    pub nan_count: usize,
}

fn table_not_found(table_id: &str) -> String {
    format!("table '{table_id}' not found")
}

fn column_mut(
    table_id: &str,
    col_index: usize,
) -> Result<
    (
        std::sync::MutexGuard<'static, std::collections::HashMap<String, data_engine::table::DataTable>>,
        usize,
    ),
    String,
> {
    let store = crate::api::project::lock_table_store();
    if !store.contains_key(table_id) {
        return Err(table_not_found(table_id));
    }
    let len = store
        .get(table_id)
        .map(|t| t.columns.len())
        .unwrap_or(0);
    if col_index >= len {
        return Err(format!("column index {col_index} out of range"));
    }
    Ok((store, col_index))
}

fn stats_of(data: &[f64]) -> ColumnStatistics {
    let finite: Vec<f64> = data.iter().copied().filter(|v| v.is_finite()).collect();
    let nan_count = data.len() - finite.len();
    if finite.is_empty() {
        return ColumnStatistics {
            min: f64::NAN,
            max: f64::NAN,
            mean: f64::NAN,
            std_dev: f64::NAN,
            count: 0,
            nan_count,
        };
    }
    let count = finite.len();
    let min = finite.iter().copied().fold(f64::INFINITY, f64::min);
    let max = finite.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    let mean = finite.iter().sum::<f64>() / count as f64;
    let var = finite.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / count as f64;
    ColumnStatistics {
        min,
        max,
        mean,
        std_dev: var.sqrt(),
        count,
        nan_count,
    }
}

fn map_column(
    table_id: &str,
    col_index: usize,
    f: impl Fn(f64, usize) -> f64,
) -> Result<DTODataTable, String> {
    let (mut store, idx) = column_mut(table_id, col_index)?;
    let table = store.get_mut(table_id).unwrap();
    let col = &mut table.columns[idx];
    for (i, v) in col.data.iter_mut().enumerate() {
        // NaN stays NaN (f(NaN) would be NaN anyway; skip keeps intent clear).
        if v.is_nan() {
            continue;
        }
        let y = f(*v, i);
        *v = if y.is_finite() { y } else { f64::NAN };
    }
    Ok(table.clone().into())
}

/// `y_i = y_i + value`.
#[flutter_rust_bridge::frb(sync)]
pub fn column_add_scalar(
    table_id: String,
    col_index: usize,
    value: f64,
) -> Result<DTODataTable, String> {
    if !value.is_finite() {
        return Err("scalar must be finite".to_string());
    }
    map_column(&table_id, col_index, |y, _| y + value)
}

/// `y_i = y_i * value`.
#[flutter_rust_bridge::frb(sync)]
pub fn column_multiply_scalar(
    table_id: String,
    col_index: usize,
    value: f64,
) -> Result<DTODataTable, String> {
    if !value.is_finite() {
        return Err("scalar must be finite".to_string());
    }
    map_column(&table_id, col_index, |y, _| y * value)
}

/// Maps finite values to [0, 1]. Errors on empty/constant columns.
#[flutter_rust_bridge::frb(sync)]
pub fn column_normalize(
    table_id: String,
    col_index: usize,
) -> Result<DTODataTable, String> {
    let (store, idx) = column_mut(&table_id, col_index)?;
    let data = store.get(&table_id).unwrap().columns[idx].data.clone();
    drop(store);
    let s = stats_of(&data);
    if s.count == 0 {
        return Err("column has no finite values".to_string());
    }
    if (s.max - s.min).abs() < f64::EPSILON {
        return Err("column is constant; cannot normalize".to_string());
    }
    map_column(&table_id, col_index, |y, _| (y - s.min) / (s.max - s.min))
}

/// Evaluates a `meval` expression per cell with `y` = current value and
/// `i` = row index (e.g. `"y / 1000"`, `"y - 273.15"`, `"log10(y)"`).
#[flutter_rust_bridge::frb(sync)]
pub fn column_apply_expression(
    table_id: String,
    col_index: usize,
    expr: String,
) -> Result<DTODataTable, String> {
    let parsed: meval::Expr = expr
        .trim()
        .parse()
        .map_err(|e| format!("parse error: {e}"))?;
    let func = parsed
        .bind2("y", "i")
        .map_err(|e| format!("bind error (use 'y' and 'i'): {e}"))?;
    map_column(&table_id, col_index, |y, i| func(y, i as f64))
}

/// First 5 transformed values without mutating (dialog live preview).
#[flutter_rust_bridge::frb(sync)]
pub fn preview_column_expression(
    table_id: String,
    col_index: usize,
    expr: String,
) -> Result<Vec<f64>, String> {
    let (store, idx) = column_mut(&table_id, col_index)?;
    let data = store.get(&table_id).unwrap().columns[idx].data.clone();
    drop(store);
    let parsed: meval::Expr = expr
        .trim()
        .parse()
        .map_err(|e| format!("parse error: {e}"))?;
    let func = parsed
        .bind2("y", "i")
        .map_err(|e| format!("bind error (use 'y' and 'i'): {e}"))?;
    Ok(data
        .iter()
        .take(5)
        .enumerate()
        .map(|(i, &y)| {
            if y.is_nan() {
                return f64::NAN;
            }
            let r = func(y, i as f64);
            if r.is_finite() { r } else { f64::NAN }
        })
        .collect())
}

/// Fills the column with `linspace(start, end)` over the current row count.
#[flutter_rust_bridge::frb(sync)]
pub fn column_fill_linspace(
    table_id: String,
    col_index: usize,
    start: f64,
    end: f64,
) -> Result<DTODataTable, String> {
    if !start.is_finite() || !end.is_finite() {
        return Err("linspace bounds must be finite".to_string());
    }
    let (mut store, idx) = column_mut(&table_id, col_index)?;
    let table = store.get_mut(&table_id).unwrap();
    let n = table.columns[idx].data.len();
    if n == 0 {
        return Err("column has no rows".to_string());
    }
    let col = &mut table.columns[idx];
    if n == 1 {
        col.data[0] = start;
    } else {
        for (i, v) in col.data.iter_mut().enumerate() {
            *v = start + (end - start) * i as f64 / (n - 1) as f64;
        }
    }
    Ok(table.clone().into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_column_statistics(
    table_id: String,
    col_index: usize,
) -> Result<ColumnStatistics, String> {
    let (store, idx) = column_mut(&table_id, col_index)?;
    let data = store.get(&table_id).unwrap().columns[idx].data.clone();
    Ok(stats_of(&data))
}

#[cfg(test)]
mod tests {
    use super::*;
    use data_engine::table::{DataColumn, DataTable as EngineDataTable};
    use data_engine::table::ColumnRole as EngineColumnRole;

    fn seed() {
        let mut t = EngineDataTable::new("tr_1", "T");
        t.add_column(DataColumn {
            name: "X".to_string(),
            role: EngineColumnRole::X,
            data: vec![0.0, 1.0, 2.0, 3.0],
        });
        t.add_column(DataColumn {
            name: "mV".to_string(),
            role: EngineColumnRole::Y,
            data: vec![1000.0, 2000.0, f64::NAN, 4000.0],
        });
        crate::api::project::lock_table_store()
            .insert("tr_1".to_string(), t);
    }

    fn col(table: &str, idx: usize) -> Vec<f64> {
        crate::api::project::lock_table_store()[table].columns[idx]
            .data
            .clone()
    }

    #[test]
    fn scalars_expression_and_linspace() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved = crate::api::project::snapshot_tables_engine();
        seed();

        column_add_scalar("tr_1".to_string(), 1, -1000.0).unwrap();
        let v = col("tr_1", 1);
        assert_eq!((v[0], v[1], v[3]), (0.0, 1000.0, 3000.0));
        assert!(v[2].is_nan());

        column_multiply_scalar("tr_1".to_string(), 1, 0.001).unwrap();
        assert_eq!(col("tr_1", 1)[0], 0.0);
        assert!(!col("tr_1", 1)[2].is_finite()); // NaN preserved

        // mV -> V style expression with row index available
        column_apply_expression("tr_1".to_string(), 0, "y * 10 + i".to_string()).unwrap();
        assert_eq!(col("tr_1", 0), vec![0.0, 11.0, 22.0, 33.0]);
        assert!(column_apply_expression("tr_1".to_string(), 0, "y +".to_string()).is_err());
        assert!(column_apply_expression("tr_1".to_string(), 9, "y".to_string()).is_err());

        // ln(0) -> NaN gracefully, no crash
        column_apply_expression("tr_1".to_string(), 0, "ln(y)".to_string()).unwrap();
        assert!(col("tr_1", 0)[0].is_nan());

        column_fill_linspace("tr_1".to_string(), 0, 0.0, 30.0).unwrap();
        assert_eq!(col("tr_1", 0), vec![0.0, 10.0, 20.0, 30.0]);

        crate::api::project::restore_tables_engine(saved);
    }

    #[test]
    fn normalize_and_statistics() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let saved = crate::api::project::snapshot_tables_engine();
        seed();

        let s = get_column_statistics("tr_1".to_string(), 1).unwrap();
        assert_eq!((s.min, s.max, s.count, s.nan_count), (1000.0, 4000.0, 3, 1));
        assert!((s.mean - 2333.3333333333335).abs() < 1e-9);

        column_normalize("tr_1".to_string(), 1).unwrap();
        let v = col("tr_1", 1);
        assert_eq!((v[0], v[1], v[3]), (0.0, 1.0 / 3.0, 1.0));
        assert!(v[2].is_nan());

        // constant column refuses to normalize
        column_fill_linspace("tr_1".to_string(), 1, 5.0, 5.0).unwrap();
        assert!(column_normalize("tr_1".to_string(), 1).is_err());

        // preview does not mutate
        let p = preview_column_expression("tr_1".to_string(), 0, "y * 2".to_string()).unwrap();
        assert_eq!(p.len(), 4);
        assert_eq!(col("tr_1", 0)[0], 0.0);

        crate::api::project::restore_tables_engine(saved);
    }
}
