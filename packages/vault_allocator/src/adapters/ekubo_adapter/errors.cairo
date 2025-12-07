// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

pub mod Errors {
    pub fn only_vault_allocator() {
        panic!("Only vault allocator can call this function");
    }

    pub fn zero_amount() {
        panic!("Zero amount");
    }

    pub fn invalid_liquidity_added() {
        panic!("Invalid liquidity added");
    }

    pub fn invalid_liquidity_removed() {
        panic!("Invalid liquidity removed");
    }

    pub fn position_exists() {
        panic!("Cannot modify bounds when position exists");
    }
}
