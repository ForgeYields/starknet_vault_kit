// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IBaseDecoderAndSanitizer<T> {
    fn approve(self: @T, spender: ContractAddress, amount: u256) -> Span<felt252>;
    fn bring_liquidity(self: @T, amount: u256) -> Span<felt252>;
}
