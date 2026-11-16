// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

/// NEAR Omni Bridge on Starknet, the bridge backing NEAR Intents deposits.
/// `init_transfer` pulls `amount` of `token_address` and `native_fee` of STRK from the caller.
/// For a NEAR Intents deposit, `recipient` is "near:intents.near" and `message` is the
/// NEAR Intents account to credit.
#[starknet::interface]
pub trait INearOmniBridge<T> {
    fn init_transfer(
        ref self: T,
        token_address: ContractAddress,
        amount: u128,
        fee: u128,
        native_fee: u128,
        recipient: ByteArray,
        message: ByteArray,
    );
    fn is_bridge_token(self: @T, token_address: ContractAddress) -> bool;
}
