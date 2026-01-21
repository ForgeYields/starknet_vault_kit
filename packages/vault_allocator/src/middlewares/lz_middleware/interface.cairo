// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::integration_interfaces::lz::{MessagingFee, SendParam};

#[starknet::interface]
pub trait ILzMiddleware<T> {
    fn send(
        ref self: T,
        oft: ContractAddress,
        underlying_token: ContractAddress, // If oft != underlying_token, it's adapter OFT
        token_to_claim: ContractAddress,
        send_param: SendParam,
        fee: MessagingFee,
        refund_address: ContractAddress,
    );

    fn claim_token(
        ref self: T,
        underlying_token: ContractAddress,
        token_to_claim: ContractAddress,
        dst_eid: u32,
    );

    // View functions
    fn get_pending_balance(
        self: @T,
        underlying_token: ContractAddress,
        token_to_claim: ContractAddress,
        dst_eid: u32,
    ) -> u256;
}
