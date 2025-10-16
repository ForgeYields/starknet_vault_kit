// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IStarkgateDecoderAndSanitizer<T> {
    fn initiate_token_withdraw(
        self: @T, l1_token: ContractAddress, l1_recipient: ContractAddress, amount: u256,
    ) -> Span<felt252>;
}

