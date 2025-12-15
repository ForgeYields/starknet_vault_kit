// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

pub mod Errors {
    pub fn pending_balance_zero() {
        panic!("Pending balance is zero");
    }

    pub fn pending_value_not_zero() {
        panic!("Pending value is not zero");
    }

    pub fn insufficient_output(out: u256, min: u256) {
        panic!("Insufficient output: {} < {}", out, min);
    }

    pub fn claimable_value_not_zero() {
        panic!("Claimable value is not zero");
    }
}
