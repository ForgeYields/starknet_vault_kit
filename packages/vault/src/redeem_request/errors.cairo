// SPDX-License-Identifier: BUSL-1.1
// Licensed under the Business Source License 1.1
// See LICENSE file for details

pub mod Errors {
    pub fn not_vault() {
        panic!("Caller is not vault");
    }

    pub fn not_vault_owner() {
        panic!("Caller is not vault owner");
    }

    pub fn not_implemented() {
        panic!("Not implemented");
    }
}
