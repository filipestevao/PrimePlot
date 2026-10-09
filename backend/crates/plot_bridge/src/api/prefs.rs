// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppPreferences {
    #[serde(default = "default_theme")]
    pub theme: String, // "primeplot", "dark", "light"
    /// Decimal separator for display/export: "." or ",".
    #[serde(default = "default_decimal_separator")]
    pub decimal_separator: String,
    /// Thousands grouping in display (`,` for dot-decimals, `.` for comma).
    #[serde(default)]
    pub thousands_separator: bool,
}

fn default_theme() -> String {
    "primeplot".to_string()
}

fn default_decimal_separator() -> String {
    ".".to_string()
}

/// Validated decimal separator (anything else falls back to dot).
pub fn validated_decimal_separator(prefs: &AppPreferences) -> char {
    if prefs.decimal_separator == "," {
        ','
    } else {
        '.'
    }
}

impl Default for AppPreferences {
    fn default() -> Self {
        Self {
            theme: default_theme(),
            decimal_separator: default_decimal_separator(),
            thousands_separator: false,
        }
    }
}

pub(crate) fn get_config_dir() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("primeplot");
        }
    }
    if let Ok(appdata) = std::env::var("APPDATA") {
        if !appdata.is_empty() {
            return PathBuf::from(appdata).join("primeplot");
        }
    }
    if let Ok(home) = std::env::var("HOME") {
        if !home.is_empty() {
            return PathBuf::from(home).join(".config").join("primeplot");
        }
    }
    PathBuf::from(".primeplot")
}

pub(crate) fn get_prefs_path() -> PathBuf {
    get_config_dir().join("prefs.json")
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_preferences() -> AppPreferences {
    let path = get_prefs_path();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(prefs) = serde_json::from_str::<AppPreferences>(&content) {
                return prefs;
            }
        }
    }
    AppPreferences::default()
}

#[flutter_rust_bridge::frb(sync)]
pub fn set_preferences(prefs: AppPreferences) {
    let path = get_prefs_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(&prefs) {
        let _ = fs::write(&path, json);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_preferences() {
        let prefs = AppPreferences::default();
        assert_eq!(prefs.theme, "primeplot");
    }

    #[test]
    fn test_prefs_file_round_trip() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        let dir = std::env::temp_dir().join(format!("primeplot_prefs_{}", std::process::id()));
        let old = std::env::var("XDG_CONFIG_HOME").ok();
        // SAFETY: TEST_MUTEX serializes all store-backed tests in this binary,
        // and no other test reads XDG_CONFIG_HOME.
        unsafe { std::env::set_var("XDG_CONFIG_HOME", &dir) };
        set_preferences(AppPreferences {
            theme: "dark".to_string(),
            decimal_separator: ".".to_string(),
            thousands_separator: false,
        });
        assert_eq!(get_preferences().theme, "dark");
        // Corrupt file falls back to defaults instead of crashing.
        let _ = fs::write(get_prefs_path(), "{not json");
        assert_eq!(get_preferences().theme, "primeplot");
        let _ = fs::remove_dir_all(&dir);
        unsafe {
            match old {
                Some(v) => std::env::set_var("XDG_CONFIG_HOME", v),
                None => std::env::remove_var("XDG_CONFIG_HOME"),
            }
        }
    }

    #[test]
    fn test_serde_preferences() {
        let prefs = AppPreferences {
            theme: "light".to_string(),
            decimal_separator: ".".to_string(),
            thousands_separator: false,
        };
        let json = serde_json::to_string(&prefs).unwrap();
        let loaded: AppPreferences = serde_json::from_str(&json).unwrap();
        assert_eq!(loaded.theme, "light");

        // Test fallback on empty json object
        let empty_loaded: AppPreferences = serde_json::from_str("{}").unwrap();
        assert_eq!(empty_loaded.theme, "primeplot");
        assert_eq!(empty_loaded.decimal_separator, ".");
        assert!(!empty_loaded.thousands_separator);
    }

    #[test]
    fn test_decimal_separator_validation() {
        let weird: AppPreferences = serde_json::from_str(r#"{"decimal_separator":";"}"#).unwrap();
        assert_eq!(validated_decimal_separator(&weird), '.');
        let comma = AppPreferences {
            theme: "dark".to_string(),
            decimal_separator: ",".to_string(),
            thousands_separator: true,
        };
        assert_eq!(validated_decimal_separator(&comma), ',');
    }
}
