// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use alexandria_bytes::Bytes;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IHyperlaneTokenRouter<TContractState> {

    /// Initiates a token transfer to a remote domain.
    ///
    /// This function dispatches a token transfer to the specified recipient on a remote domain, transferring
    /// either an amount of tokens or a token ID. It supports optional hooks and metadata for additional
    /// processing during the transfer. The function emits a `SentTransferRemote` event once the transfer is initiated.
    ///
    /// # Arguments
    ///
    /// * `destination` - A `u32` representing the destination domain.
    /// * `recipient` - A `u256` representing the recipient's address.
    /// * `amount_or_id` - A `u256` representing the amount of tokens or token ID to transfer.
    /// * `value` - A `u256` representing the value of the transfer.
    /// * `hook_metadata` - An optional `Bytes` object representing metadata for the hook.
    /// * `hook` - An optional `ContractAddress` representing the contract hook to invoke during the transfer.
    ///
    /// # Returns
    ///
    /// A `u256` representing the message ID of the dispatched transfer.
    /// 
    /// # Reference
    /// 
    /// https://github.com/astraly-labs/hyperlane_starknet/blob/bf6504847be148714ba9b622924dd3c5ae7fbee1/cairo/crates/token/src/components/token_router.cairo#L15
    fn transfer_remote(
        ref self: TContractState,
        destination: u32,
        recipient: u256,
        amount_or_id: u256,
        value: u256,
        hook_metadata: Option<Bytes>,
        hook: Option<ContractAddress>
    ) -> u256;
}
