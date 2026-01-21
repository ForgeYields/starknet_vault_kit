// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::integration_interfaces::lz::{MessagingFee, SendParam};

#[starknet::interface]
pub trait ILzMiddlewareDecoderAndSanitizer<T> {
    fn send(
        self: @T,
        oft: ContractAddress,
        underlying_token: ContractAddress,
        token_to_claim: ContractAddress,
        send_param: SendParam,
        fee: MessagingFee,
        refund_address: ContractAddress,
    ) -> Span<felt252>;
}
