// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IMigrationUsdcDecoderAndSanitizer<T> {
    fn swap_to_new(self: @T, amount: u256) -> Span<felt252>;
    fn swap_to_legacy(self: @T, amount: u256) -> Span<felt252>;
}
