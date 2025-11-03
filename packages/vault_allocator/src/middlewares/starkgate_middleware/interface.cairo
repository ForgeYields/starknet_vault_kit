// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::{ContractAddress, EthAddress};
#[starknet::interface]
pub trait IStarkgateMiddleware<T> {
    fn initiate_token_withdraw(
        ref self: T, l1_token: EthAddress, l1_recipient: ContractAddress, amount: u256,
    );
    fn claim_token_bridged_back(ref self: T);
}
