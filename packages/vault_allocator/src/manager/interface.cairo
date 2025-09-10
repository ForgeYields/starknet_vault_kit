// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IManager<T> {
    fn vault_allocator(self: @T) -> ContractAddress;
    fn set_manage_root(ref self: T, target: ContractAddress, root: felt252);
    fn manage_root(self: @T, target: ContractAddress) -> felt252;
    fn pause(ref self: T);
    fn unpause(ref self: T);
    fn manage_vault_with_merkle_verification(
        ref self: T,
        proofs: Span<Span<felt252>>,
        decoder_and_sanitizers: Span<ContractAddress>,
        targets: Span<ContractAddress>,
        selectors: Span<felt252>,
        calldatas: Span<Span<felt252>>,
    );
}

