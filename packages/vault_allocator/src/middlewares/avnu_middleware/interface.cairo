// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::decoders_and_sanitizers::decoder_custom_types::Route;

#[starknet::interface]
pub trait IAvnuMiddleware<T> {
    fn avnu_router(self: @T) -> ContractAddress;
    fn price_router(self: @T) -> ContractAddress;
    fn vault_allocator(self: @T) -> ContractAddress;
    fn config(self: @T) -> (u16, u64, u64);
    fn set_config(ref self: T, slippage: u16, period: u64, allowed_calls_per_period: u64);
    fn get_computed_min(
        self: @T,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
    ) -> u256;
    fn multi_route_swap(
        ref self: T,
        sell_token_address: ContractAddress,
        sell_token_amount: u256,
        buy_token_address: ContractAddress,
        buy_token_amount: u256,
        buy_token_min_amount: u256,
        beneficiary: ContractAddress,
        integrator_fee_amount_bps: u128,
        integrator_fee_recipient: ContractAddress,
        routes: Array<Route>,
    ) -> u256;
}
