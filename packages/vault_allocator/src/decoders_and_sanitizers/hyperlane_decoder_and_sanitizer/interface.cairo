// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IHyperlaneDecoderAndSanitizer<T> {
    fn bridge_token(
        self: @T,
        token_to_bridge: ContractAddress,
        token_to_claim: ContractAddress,
        destination_domain: u32,
        recipient: u256,
        amount: u256,
        value: u256,
    ) -> Span<felt252>;
}