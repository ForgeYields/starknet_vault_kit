// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IDefiSpringSNFStyleDecoderAndSanitizer<T> {
    fn claim(
        self: @T,
        amount: u128,
        proof: Span<felt252>,
    ) -> Span<felt252>;
}