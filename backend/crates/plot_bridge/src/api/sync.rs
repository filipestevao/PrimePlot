// Copyright (C) 2026 Filipe Estevão
// This program is licensed under the GPLv3. See LICENSE for details.

//! Poison-tolerant mutex locking for the FFI layer. A panic in one sync
//! call poisons the mutex; recovering (instead of `unwrap()`-crashing)
//! keeps subsequent UI operations alive.

use std::sync::{Mutex, MutexGuard};

pub(crate) fn lock_or_recover<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}
