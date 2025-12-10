// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// Standard library imports
use starknet::ContractAddress;

#[starknet::interface]
pub trait IAssetTransferPod<TContractState> {
    fn set_authorized_caller(ref self: TContractState, authorized_caller: ContractAddress);
    fn set_vault_allocator(ref self: TContractState, vault_allocator: ContractAddress);
    fn transfer_assets(ref self: TContractState, asset: ContractAddress, amount: u256);
    fn upgrade(ref self: TContractState, new_class_hash: starknet::ClassHash);
    fn get_vault_allocator(self: @TContractState) -> ContractAddress;
    fn get_authorized_caller(self: @TContractState) -> ContractAddress;
}
