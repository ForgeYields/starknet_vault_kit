// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct MigrationUsdcConfig {
    pub migration_contract: ContractAddress,
    pub legacy_usdc: ContractAddress,
    pub new_usdc: ContractAddress,
}


pub fn _add_migration_usdc_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    migration_usdc_config: MigrationUsdcConfig,
) {
    let migration_contract = migration_usdc_config.migration_contract;
    let legacy_usdc = migration_usdc_config.legacy_usdc;
    let new_usdc = migration_usdc_config.new_usdc;

    // Approval for migration contract to spend legacy USDC
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: legacy_usdc,
                selector: selector!("approve"),
                argument_addresses: array![migration_contract.into()].span(),
                description: "Approve migration contract to spend "
                    + get_symbol(legacy_usdc),
            },
        );
    leaf_index += 1;

    // Approval for migration contract to spend new USDC
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: new_usdc,
                selector: selector!("approve"),
                argument_addresses: array![migration_contract.into()].span(),
                description: "Approve migration contract to spend "
                    + get_symbol(new_usdc),
            },
        );
    leaf_index += 1;

    // swap_to_new: convert legacy USDC to new USDC
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: migration_contract,
                selector: selector!("swap_to_new"),
                argument_addresses: array![].span(),
                description: "Migration: swap "
                    + get_symbol(legacy_usdc)
                    + " to "
                    + get_symbol(new_usdc),
            },
        );
    leaf_index += 1;

    // swap_to_legacy: convert new USDC back to legacy USDC
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: migration_contract,
                selector: selector!("swap_to_legacy"),
                argument_addresses: array![].span(),
                description: "Migration: swap "
                    + get_symbol(new_usdc)
                    + " to "
                    + get_symbol(legacy_usdc),
            },
        );
    leaf_index += 1;
}
