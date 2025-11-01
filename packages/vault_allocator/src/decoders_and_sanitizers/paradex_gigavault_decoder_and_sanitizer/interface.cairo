// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IParadexGigavaultDecoderAndSanitizer<T> {
    fn request_withdrawal(self: @T, shares: u256) -> Span<felt252>;
}

