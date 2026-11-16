// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

/// Endur specific entrypoints only. The ERC-4626 entrypoints of the LST (deposit, withdraw,
/// redeem) are sanitized by the ERC-4626 decoder and sanitizer.
#[starknet::interface]
pub trait IEndurDecoderAndSanitizer<T> {
    fn deposit_with_referral(
        self: @T, assets: u256, receiver: ContractAddress, referral: ByteArray,
    ) -> Span<felt252>;
    fn claim_withdrawal(self: @T, request_id: u128) -> Span<felt252>;
}
