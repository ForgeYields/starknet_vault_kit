// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IExtendedDecoderAndSanitizer<T> {
    fn deposit(self: @T, vault_number: felt252, amount: felt252, nonce: felt252) -> Span<felt252>;
}

