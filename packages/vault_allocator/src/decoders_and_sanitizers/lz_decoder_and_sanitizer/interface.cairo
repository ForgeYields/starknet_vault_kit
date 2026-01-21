// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;
use vault_allocator::integration_interfaces::lz::{SendParam, MessagingFee};

#[starknet::interface]
pub trait ILzDecoderAndSanitizer<T> {
    fn send(
        self: @T,
        send_param: SendParam,
        fee: MessagingFee,
        refund_address: ContractAddress,
    ) -> Span<felt252>;
}
