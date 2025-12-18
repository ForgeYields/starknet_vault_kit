// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
pub trait IStarkgateMiddleware<T> {
    fn initiate_token_withdraw(
        ref self: T,
        starkgate_token_bridge: ContractAddress,
        l1_token: EthAddress,
        l1_recipient: EthAddress,
        amount: u256,
        token_to_claim: ContractAddress,
    );
    fn claim_token(
        ref self: T,
        token_to_bridge: ContractAddress,
        token_to_claim: ContractAddress,
    );

    // View functions
    fn get_pending_balance(
        self: @T, token_to_bridge: ContractAddress, token_to_claim: ContractAddress,
    ) -> u256;
}
