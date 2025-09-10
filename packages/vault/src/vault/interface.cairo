// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// Standard library imports
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVault<TContractState> {
    fn register_redeem_request(ref self: TContractState, redeem_request: ContractAddress);
    fn register_vault_allocator(ref self: TContractState, vault_allocator: ContractAddress);
    fn request_redeem(
        ref self: TContractState, shares: u256, receiver: ContractAddress, owner: ContractAddress,
    ) -> u256;
    fn claim_redeem(ref self: TContractState, id: u256) -> u256;

    fn set_fees_config(
        ref self: TContractState,
        fees_recipient: ContractAddress,
        redeem_fees: u256,
        management_fees: u256,
        performance_fees: u256,
    );
    fn set_report_delay(ref self: TContractState, report_delay: u64);
    fn set_max_delta(ref self: TContractState, max_delta: u256);
    fn report(ref self: TContractState, new_aum: u256);
    fn bring_liquidity(ref self: TContractState, amount: u256);

    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);

    fn epoch(self: @TContractState) -> u256;
    fn handled_epoch_len(self: @TContractState) -> u256;
    fn buffer(self: @TContractState) -> u256;
    fn aum(self: @TContractState) -> u256;
    fn redeem_assets(self: @TContractState, epoch: u256) -> u256;
    fn redeem_nominal(self: @TContractState, epoch: u256) -> u256;
    fn fees_recipient(self: @TContractState) -> ContractAddress;
    fn redeem_fees(self: @TContractState) -> u256;
    fn management_fees(self: @TContractState) -> u256;
    fn performance_fees(self: @TContractState) -> u256;
    fn redeem_request(self: @TContractState) -> ContractAddress;
    fn report_delay(self: @TContractState) -> u64;
    fn vault_allocator(self: @TContractState) -> ContractAddress;
    fn last_report_timestamp(self: @TContractState) -> u64;
    fn max_delta(self: @TContractState) -> u256;
    fn due_assets_from_id(self: @TContractState, id: u256) -> u256;
}

