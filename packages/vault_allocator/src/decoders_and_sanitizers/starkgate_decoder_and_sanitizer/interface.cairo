// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::EthAddress;

#[starknet::interface]
pub trait IStarkgateDecoderAndSanitizer<T> {
    fn initiate_token_withdraw(
        self: @T, l1_token: EthAddress, l1_recipient: EthAddress, amount: u256,
    ) -> Span<felt252>;
}

