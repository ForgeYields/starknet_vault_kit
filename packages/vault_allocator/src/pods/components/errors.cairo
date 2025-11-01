// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

pub mod Errors {
    pub fn zero_address() {
        panic!("Zero address");
    }

    pub fn zero_amount() {
        panic!("Zero amount");
    }

    pub fn transfer_failed() {
        panic!("Transfer failed");
    }

    pub fn unauthorized() {
        panic!("Unauthorized");
    }
}
