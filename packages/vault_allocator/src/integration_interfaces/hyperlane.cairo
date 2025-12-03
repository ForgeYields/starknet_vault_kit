// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use alexandria_bytes::Bytes;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IHyperlaneTokenRouter<TContractState> {
    fn transfer_remote(
        ref self: TContractState,
        destination: u32,
        recipient: u256,
        amount_or_id: u256,
        hook_metadata: Option<Bytes>,
        hook: Option<ContractAddress>,
    ) -> u256;
}
