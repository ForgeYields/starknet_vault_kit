// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IParadexGigaVaultMiddleware<T> {
    fn request_withdrawal(ref self: T, shares: u256);
}
