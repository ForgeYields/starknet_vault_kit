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
    fn set_config(ref self: T, slippage: u16, period: u64, allowed_calls_per_period: u64);
    fn set_vault_allocator(ref self: T, vault_allocator: ContractAddress);

    // View functions
    fn get_vault_allocator(self: @T) -> ContractAddress;
    fn get_price_router(self: @T) -> ContractAddress;
    fn get_slippage(self: @T) -> u16;
    fn get_period(self: @T) -> u64;
    fn get_allowed_calls_per_period(self: @T) -> u64;
    fn get_current_window_id(self: @T) -> u64;
    fn get_window_call_count(self: @T) -> u64;
    fn get_pending_balance(self: @T, token_to_bridge: ContractAddress, token_to_claim: ContractAddress, destination_domain: u32) -> u256;
}
