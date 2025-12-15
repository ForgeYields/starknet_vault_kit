// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IStarkgateMiddlewareDecoderAndSanitizer<T> {
    fn initiate_token_withdraw(
        self: @T,
        starkgate_token_bridge: ContractAddress,
        l1_token: EthAddress,
        l1_recipient: EthAddress,
        amount: u256,
        token_to_claim: ContractAddress,
    ) -> Span<felt252>;
}
