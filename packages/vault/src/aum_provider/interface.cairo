// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IBaseAumProvider<T> {
    fn aum(self: @T) -> u256;
    fn report(ref self: T);
}
