// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

#[flutter_rust_bridge::frb(sync)] // Synchronous execution for simple greeting
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(sync)]
pub fn shutdown() {
    crate::api::properties::clear_all_property_stores();
    crate::api::history::clear_all_history();
    crate::api::project::clear_all_project_stores();
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shutdown_clears_stores() {
        let _lock = crate::api::properties::TEST_MUTEX.lock().unwrap();
        crate::api::history::checkpoint();
        shutdown();
        assert!(!crate::api::history::history_status().can_undo);
    }
}
