// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};
use vault_allocator::merkle_tree::registery::STRK;

/// Relayer fee taken from the bridged amount. NEAR Intents deposits use no token fee.
pub const NEAR_INTENTS_TOKEN_FEE: u128 = 0;

/// Omni Bridge recipient of every NEAR Intents deposit.
pub fn NEAR_INTENTS_RECIPIENT() -> ByteArray {
    "near:intents.near"
}

#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct NearIntentsConfig {
    pub omni_bridge: ContractAddress,
    pub token: ContractAddress,
    /// NEAR Intents account credited with the deposit (named or 64-hex implicit account).
    pub intents_account: ByteArray,
}

/// Adds the leafs to deposit `token` into a fixed NEAR Intents account through the NEAR Omni
/// Bridge. The bridge pulls the bridged amount and a native fee paid in STRK.
pub fn _add_near_intents_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    near_intents_configs: Span<NearIntentsConfig>,
) {
    for i in 0..near_intents_configs.len() {
        let config = near_intents_configs.at(i);
        let omni_bridge = *config.omni_bridge;
        let token = *config.token;
        let intents_account = config.intents_account.clone();
        let token_symbol = get_symbol(token);

        // Approval for the bridged token
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: token,
                    selector: selector!("approve"),
                    argument_addresses: array![omni_bridge.into()].span(),
                    description: "Approve near_omni_bridge to spend " + token_symbol.clone(),
                },
            );
        leaf_index += 1;

        // Approval for the native fee (STRK)
        if token != STRK() {
            leafs
                .append(
                    ManageLeaf {
                        decoder_and_sanitizer,
                        target: STRK(),
                        selector: selector!("approve"),
                        argument_addresses: array![omni_bridge.into()].span(),
                        description: "Approve near_omni_bridge to spend " + get_symbol(STRK()),
                    },
                );
            leaf_index += 1;
        }

        // Deposit into NEAR Intents
        let mut argument_addresses = ArrayTrait::new();
        token.serialize(ref argument_addresses);
        NEAR_INTENTS_TOKEN_FEE.serialize(ref argument_addresses);
        NEAR_INTENTS_RECIPIENT().serialize(ref argument_addresses);
        intents_account.serialize(ref argument_addresses);
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: omni_bridge,
                    selector: selector!("init_transfer"),
                    argument_addresses: argument_addresses.span(),
                    description: "NEAR Intents: deposit "
                        + token_symbol
                        + " to account "
                        + intents_account,
                },
            );
        leaf_index += 1;
    }
}
