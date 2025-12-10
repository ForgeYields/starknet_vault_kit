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
    fn set_config(ref self: T, slippage: u16, period: u64, allowed_calls_per_period: u64);
    fn set_vault_allocator(ref self: T, vault_allocator: ContractAddress);

    // View functions
    fn get_cctp_token_bridge(self: @T) -> ContractAddress;
    fn get_vault_allocator(self: @T) -> ContractAddress;
    fn get_price_router(self: @T) -> ContractAddress;
    fn get_slippage(self: @T) -> u16;
    fn get_period(self: @T) -> u64;
    fn get_allowed_calls_per_period(self: @T) -> u64;
    fn get_current_window_id(self: @T) -> u64;
    fn get_window_call_count(self: @T) -> u64;
    fn get_pending_balance(self: @T, burn_token: ContractAddress, token_to_claim: ContractAddress, destination_domain: u32) -> u256;
}
