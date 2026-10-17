// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! User-level palettes and recent custom colors.
//!
//! Stored in `palettes.json` next to `prefs.json` (config dir), so customs
//! survive across projects and can be shared as single `.json` files. Rust
//! is SSOT and validates everything: hex format, 2–12 colors, unique names.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

pub const MIN_PALETTE_COLORS: usize = 2;
pub const MAX_PALETTE_COLORS: usize = 12;
pub const MAX_RECENT_COLORS: usize = 8;

/// One named user palette (also the on-disk schema for shared files).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct UserPalette {
    pub name: String,
    pub colors: Vec<String>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[flutter_rust_bridge::frb(ignore)]
struct PaletteStore {
    #[serde(default)]
    recents: Vec<String>,
    #[serde(default)]
    customs: Vec<UserPalette>,
}

fn get_palettes_path() -> PathBuf {
    crate::api::prefs::get_config_dir().join("palettes.json")
}

fn load_store() -> PaletteStore {
    let path = get_palettes_path();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(store) = serde_json::from_str::<PaletteStore>(&content) {
                return store;
            }
        }
    }
    PaletteStore::default()
}

fn save_store(store: &PaletteStore) -> Result<(), String> {
    let path = get_palettes_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("cannot create config dir: {e}"))?;
    }
    let json =
        serde_json::to_string_pretty(store).map_err(|e| format!("serialize failed: {e}"))?;
    fs::write(&path, json).map_err(|e| format!("cannot write {}: {e}", path.display()))
}

/// Normalizes `#RRGGBB` / `#AARRGGBB` (leading `#` optional) to uppercase
/// `#`-prefixed hex. `None` for anything else.
fn normalize_hex(raw: &str) -> Option<String> {
    let trimmed = raw.trim();
    let body = trimmed.strip_prefix('#').unwrap_or(trimmed);
    if (body.len() == 6 || body.len() == 8) && body.chars().all(|c| c.is_ascii_hexdigit()) {
        return Some(format!("#{}", body.to_ascii_uppercase()));
    }
    None
}

fn validate_name(name: &str, customs: &[UserPalette]) -> Result<String, String> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return Err("palette name cannot be empty".to_string());
    }
    if trimmed.chars().count() > 40 {
        return Err("palette name is too long (max 40 characters)".to_string());
    }
    let lower = trimmed.to_ascii_lowercase();
    if crate::api::palettes::is_builtin_name(&lower) {
        return Err(format!("'{trimmed}' is a built-in palette name"));
    }
    if customs.iter().any(|p| p.name.to_ascii_lowercase() == lower) {
        return Err(format!("a palette named '{trimmed}' already exists"));
    }
    Ok(trimmed.to_string())
}

fn validate_colors(colors: &[String]) -> Result<Vec<String>, String> {
    if colors.len() < MIN_PALETTE_COLORS || colors.len() > MAX_PALETTE_COLORS {
        return Err(format!(
            "a palette needs {MIN_PALETTE_COLORS}-{MAX_PALETTE_COLORS} colors (got {})",
            colors.len()
        ));
    }
    let mut out = Vec::with_capacity(colors.len());
    for c in colors {
        match normalize_hex(c) {
            Some(hex) => out.push(hex),
            None => return Err(format!("'{c}' is not a valid hex color")),
        }
    }
    Ok(out)
}

/// All custom palettes in creation order.
pub(crate) fn load_custom_palettes() -> Vec<UserPalette> {
    load_store().customs
}

/// Case-insensitive custom lookup.
pub(crate) fn find_custom_palette(name: &str) -> Option<UserPalette> {
    let lower = name.trim().to_ascii_lowercase();
    load_custom_palettes()
        .into_iter()
        .find(|p| p.name.to_ascii_lowercase() == lower)
}

/// Recent custom color picks, newest first (capped at [MAX_RECENT_COLORS]).
#[flutter_rust_bridge::frb(sync)]
pub fn list_recent_colors() -> Vec<String> {
    load_store().recents
}

/// Records a color pick: normalizes, dedupes case-insensitively, newest first.
#[flutter_rust_bridge::frb(sync)]
pub fn push_recent_color(color: String) -> Result<(), String> {
    let hex =
        normalize_hex(&color).ok_or_else(|| format!("'{color}' is not a valid hex color"))?;
    let mut store = load_store();
    store.recents.retain(|c| !c.eq_ignore_ascii_case(&hex));
    store.recents.insert(0, hex);
    store.recents.truncate(MAX_RECENT_COLORS);
    save_store(&store)
}

/// Creates a named custom palette. Rejects invalid hex, wrong color counts,
/// empty/duplicate names, and collisions with built-ins.
#[flutter_rust_bridge::frb(sync)]
pub fn create_user_palette(name: String, colors: Vec<String>) -> Result<(), String> {
    let mut store = load_store();
    let clean_name = validate_name(&name, &store.customs)?;
    let clean_colors = validate_colors(&colors)?;
    store.customs.push(UserPalette {
        name: clean_name,
        colors: clean_colors,
    });
    save_store(&store)
}

/// Deletes a custom palette. Built-ins and unknown names are errors.
#[flutter_rust_bridge::frb(sync)]
pub fn delete_user_palette(name: String) -> Result<(), String> {
    let mut store = load_store();
    let lower = name.trim().to_ascii_lowercase();
    if crate::api::palettes::is_builtin_name(&lower) {
        return Err(format!("'{name}' is a built-in palette"));
    }
    let before = store.customs.len();
    store.customs.retain(|p| p.name.to_ascii_lowercase() != lower);
    if store.customs.len() == before {
        return Err(format!("palette '{name}' not found"));
    }
    save_store(&store)
}

/// Writes one custom palette as a standalone `.json` file (sharing).
#[flutter_rust_bridge::frb(sync)]
pub fn export_user_palette(name: String, path: String) -> Result<(), String> {
    let palette = find_custom_palette(&name).ok_or_else(|| {
        format!("palette '{name}' not found (only custom palettes can be exported)")
    })?;
    let json =
        serde_json::to_string_pretty(&palette).map_err(|e| format!("serialize failed: {e}"))?;
    fs::write(&path, json).map_err(|e| format!("cannot write {path}: {e}"))
}

/// Imports a shared palette `.json` file (same schema as storage). The
/// palette is validated like a new one, so duplicate names are rejected.
/// Returns the imported name.
#[flutter_rust_bridge::frb(sync)]
pub fn import_user_palette(path: String) -> Result<String, String> {
    let content = fs::read_to_string(&path).map_err(|e| format!("cannot read {path}: {e}"))?;
    let palette: UserPalette = serde_json::from_str(&content)
        .map_err(|_| format!("'{path}' is not a valid palette file"))?;
    create_user_palette(palette.name.clone(), palette.colors.clone())?;
    Ok(palette.name.trim().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Serializes store-backed tests and points the config dir at a temp
    /// folder for the test's lifetime (restored on drop).
    struct ConfigGuard {
        _lock: std::sync::MutexGuard<'static, ()>,
        dir: PathBuf,
        old: Option<String>,
    }

    impl ConfigGuard {
        fn new(tag: &str) -> Self {
            let lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
            let dir = std::env::temp_dir()
                .join(format!("primeplot_palettes_{tag}_{}", std::process::id()));
            let _ = fs::remove_dir_all(&dir);
            let old = std::env::var("XDG_CONFIG_HOME").ok();
            // SAFETY: TEST_MUTEX serializes all store-backed tests in this
            // binary, and no other test reads XDG_CONFIG_HOME.
            unsafe { std::env::set_var("XDG_CONFIG_HOME", &dir) };
            ConfigGuard {
                _lock: lock,
                dir,
                old,
            }
        }
    }

    impl Drop for ConfigGuard {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
            unsafe {
                match &self.old {
                    Some(v) => std::env::set_var("XDG_CONFIG_HOME", v),
                    None => std::env::remove_var("XDG_CONFIG_HOME"),
                }
            }
        }
    }

    #[test]
    fn crud_round_trip() {
        let _cfg = ConfigGuard::new("crud");
        create_user_palette(
            "Mine".to_string(),
            vec![
                "#ff0000".to_string(),
                "#00FF00".to_string(),
                "#0000ff".to_string(),
            ],
        )
        .unwrap();
        let customs = load_custom_palettes();
        assert_eq!(customs.len(), 1);
        assert_eq!(customs[0].name, "Mine");
        assert_eq!(customs[0].colors[0], "#FF0000");
        assert!(get_palettes_path().exists());

        // Case-insensitive duplicate and built-in collisions are rejected.
        assert!(
            create_user_palette(
                "mine".to_string(),
                vec!["#111111".to_string(), "#222222".to_string()]
            )
            .is_err()
        );
        assert!(
            create_user_palette(
                "tab10".to_string(),
                vec!["#111111".to_string(), "#222222".to_string()]
            )
            .is_err()
        );

        delete_user_palette("mine".to_string()).unwrap();
        assert!(load_custom_palettes().is_empty());
        assert!(delete_user_palette("Mine".to_string()).is_err());
        assert!(delete_user_palette("Tab10".to_string()).is_err());
    }

    #[test]
    fn validation_rejects_bad_payloads() {
        let _cfg = ConfigGuard::new("validation");
        assert!(
            create_user_palette(String::new(), vec!["#111111".to_string(), "#222222".to_string()])
                .is_err()
        );
        let too_long = "x".repeat(41);
        assert!(
            create_user_palette(too_long, vec!["#111111".to_string(), "#222222".to_string()])
                .is_err()
        );
        assert!(create_user_palette("X".to_string(), vec!["#111111".to_string()]).is_err());
        assert!(
            create_user_palette("X".to_string(), vec!["#111111".to_string(); 13]).is_err()
        );
        assert!(
            create_user_palette(
                "X".to_string(),
                vec!["#111111".to_string(), "red".to_string()]
            )
            .is_err()
        );
    }

    #[test]
    fn recents_dedupe_cap_and_persist() {
        let _cfg = ConfigGuard::new("recents");
        for i in 0..10u32 {
            push_recent_color(format!("#0000{i:02X}")).unwrap();
        }
        let recents = list_recent_colors();
        assert_eq!(recents.len(), MAX_RECENT_COLORS);
        assert_eq!(recents[0], "#000009");

        push_recent_color("#000003".to_string()).unwrap();
        let recents = list_recent_colors();
        assert_eq!(recents[0], "#000003");
        assert_eq!(recents.len(), MAX_RECENT_COLORS);
        assert_eq!(recents.iter().filter(|c| *c == "#000003").count(), 1);
        assert!(push_recent_color("nope".to_string()).is_err());
    }

    #[test]
    fn export_import_round_trip() {
        let _cfg = ConfigGuard::new("export");
        create_user_palette(
            "Share Me".to_string(),
            vec!["#abcdef".to_string(), "#123456".to_string()],
        )
        .unwrap();
        let file =
            std::env::temp_dir().join(format!("primeplot_palette_{}.json", std::process::id()));
        export_user_palette("share me".to_string(), file.to_string_lossy().to_string()).unwrap();
        delete_user_palette("Share Me".to_string()).unwrap();

        let imported = import_user_palette(file.to_string_lossy().to_string()).unwrap();
        assert_eq!(imported, "Share Me");
        assert_eq!(
            load_custom_palettes()[0].colors,
            vec!["#ABCDEF".to_string(), "#123456".to_string()]
        );
        // Duplicate name on import and unknown exports are errors.
        assert!(import_user_palette(file.to_string_lossy().to_string()).is_err());
        assert!(export_user_palette("Nope".to_string(), file.to_string_lossy().to_string()).is_err());

        let bad = std::env::temp_dir().join(format!("primeplot_bad_{}.json", std::process::id()));
        fs::write(&bad, "{oops").unwrap();
        assert!(import_user_palette(bad.to_string_lossy().to_string()).is_err());
        assert!(import_user_palette("/definitely/missing.json".to_string()).is_err());
        let _ = fs::remove_file(&file);
        let _ = fs::remove_file(&bad);
    }
}
