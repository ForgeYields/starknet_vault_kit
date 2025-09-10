// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

pub mod Errors {
    pub fn invalid_manage_proof() {
        panic!("Invalid manage proof");
    }

    pub fn only_manager() {
        panic!("Only manager can call this function");
    }

    pub fn inconsistent_lengths() {
        panic!("Inconsistent lengths");
    }

    pub fn not_vault_allocator() {
        panic!("Not vault allocator");
    }
}
