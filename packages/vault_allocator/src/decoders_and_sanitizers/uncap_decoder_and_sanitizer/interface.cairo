// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IUnCapDecoderAndSanitizer<T> {
    fn provide_to_sp(self: @T, top_up: u256, do_claim: bool) -> Span<felt252>;
    fn withdraw_from_sp(self: @T, amount: u256, do_claim: bool) -> Span<felt252>;
}

