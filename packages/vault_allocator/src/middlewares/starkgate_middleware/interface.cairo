// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IStarkgateMiddleware<T> {
    fn claim_token_bridged_back(ref self: T);
    fn set_config(ref self: T, slippage: u16, period: u64, allowed_calls_per_period: u64);
    fn set_vault_allocator(ref self: T, vault_allocator: ContractAddress);

    // View functions
    fn get_starkgate_token_bridge(self: @T) -> ContractAddress;
    fn get_vault_allocator(self: @T) -> ContractAddress;
    fn get_price_router(self: @T) -> ContractAddress;
    fn get_slippage(self: @T) -> u16;
    fn get_period(self: @T) -> u64;
    fn get_allowed_calls_per_period(self: @T) -> u64;
    fn get_current_window_id(self: @T) -> u64;
    fn get_window_call_count(self: @T) -> u64;
    fn get_token_to_bridge(self: @T) -> ContractAddress;
    fn get_token_to_receive(self: @T) -> ContractAddress;
    fn get_pending_balance(self: @T) -> u256;
    fn get_l1_recipient(self: @T) -> EthAddress;
}
