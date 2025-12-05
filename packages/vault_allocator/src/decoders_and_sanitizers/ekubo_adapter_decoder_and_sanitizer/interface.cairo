// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IEkuboAdapterDecoderAndSanitizer<T> {
    fn deposit_liquidity(self: @T, amount0: u256, amount1: u256) -> Span<felt252>;
    fn withdraw_liquidity(
        self: @T, ratioWad: u256, min_token0: u128, min_token1: u128,
    ) -> Span<felt252>;
    fn collect_fees(self: @T) -> Span<felt252>;
}
