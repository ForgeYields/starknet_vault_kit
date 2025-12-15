// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IHyperlaneMiddleware<T> {
    fn bridge_token(
        ref self: T,
        token_to_bridge: ContractAddress,
        token_to_claim: ContractAddress,
        destination_domain: u32,
        recipient: u256,
        amount: u256,
        value: u256,
    ) -> u256;
    fn claim_token(
        ref self: T,
        token_to_bridge: ContractAddress,
        token_to_claim: ContractAddress,
        destination_domain: u32,
    );

    // View functions
    fn get_pending_balance(self: @T, token_to_bridge: ContractAddress, token_to_claim: ContractAddress, destination_domain: u32) -> u256;
}
