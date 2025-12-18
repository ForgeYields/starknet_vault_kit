// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait ICctpMiddleware<T> {
    fn deposit_for_burn(
        ref self: T,
        amount: u256,
        destination_domain: u32,
        mint_recipient: u256,
        burn_token: ContractAddress,
        token_to_claim: ContractAddress,
        destination_caller: u256,
        max_fee: u256,
        min_finality_threshold: u32,
    );
    fn claim_token(
        ref self: T,
        burn_token: ContractAddress,
        token_to_claim: ContractAddress,
        destination_domain: u32,
    );

    // View functions
    fn get_cctp_token_bridge(self: @T) -> ContractAddress;
    fn get_pending_balance(self: @T, burn_token: ContractAddress, token_to_claim: ContractAddress, destination_domain: u32) -> u256;
}
