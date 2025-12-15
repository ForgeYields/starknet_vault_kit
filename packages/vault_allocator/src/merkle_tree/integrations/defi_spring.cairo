// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct DefiSpringConfig {
    pub claim_contract: ContractAddress,
    pub reward_token: ContractAddress,
}


pub fn _add_defi_spring_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    defi_spring_configs: Span<DefiSpringConfig>,
) {
    for i in 0..defi_spring_configs.len() {
        let config = defi_spring_configs.at(i);
        let claim_contract = *config.claim_contract;
        let reward_token = *config.reward_token;

        let claim_contract_felt: felt252 = claim_contract.into();
        let claim_contract_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @claim_contract_felt, 16,
        );

        // Claim rewards
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: claim_contract,
                    selector: selector!("claim"),
                    argument_addresses: array![].span(),
                    description: "DefiSpring: claim"
                        + " "
                        + get_symbol(reward_token)
                        + " "
                        + "from"
                        + " "
                        + claim_contract_str,
                },
            );
        leaf_index += 1;
    }
}
