// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// Standard library imports
use starknet::ContractAddress;

#[starknet::interface]
pub trait IBaseMiddleware<TContractState> {
    fn set_config(
        ref self: TContractState, slippage: u16, period: u64, allowed_calls_per_period: u64,
    );
    fn set_vault_allocator(ref self: TContractState, vault_allocator: ContractAddress);
    fn upgrade(ref self: TContractState, new_class_hash: starknet::ClassHash);
    fn get_vault_allocator(self: @TContractState) -> ContractAddress;
    fn get_slippage(self: @TContractState) -> u16;
    fn get_period(self: @TContractState) -> u64;
    fn get_allowed_calls_per_period(self: @TContractState) -> u64;
    fn get_current_window_id(self: @TContractState) -> u64;
    fn get_window_call_count(self: @TContractState) -> u64;
    fn get_price_router(self: @TContractState) -> ContractAddress;
    fn get_computed_min(
        self: @TContractState,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
    ) -> u256;
}
