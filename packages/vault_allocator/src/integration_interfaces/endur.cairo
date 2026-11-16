// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct EndurLstConfig {
    pub treasury: ContractAddress,
    pub withdraw_queue: ContractAddress,
    pub validator_registry: ContractAddress,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct EndurWithdrawRequest {
    pub assets: u256,
    pub shares: u256,
    pub is_claimed: bool,
    pub timestamp: u64,
    pub claim_time: u64,
    pub cumulative_requested_amount_snapshot: u256,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct EndurQueueState {
    pub max_request_id: u128,
    pub unprocessed_withdraw_queue_amount: u256,
    pub intransit_amount: u256,
    pub cumulative_requested_amount: u256,
}

/// Endur LST specific entrypoints. The LST also exposes the standard snake_case ERC-4626
/// interface; `withdraw` and `redeem` burn shares and mint a withdraw queue NFT to `receiver`.
#[starknet::interface]
pub trait IEndurLst<T> {
    fn get_config(self: @T) -> EndurLstConfig;
    fn deposit_with_referral(
        ref self: T, assets: u256, receiver: ContractAddress, referral: ByteArray,
    ) -> u256;
}

/// Endur withdraw queue. `claim_withdrawal` is permissionless and pays the current owner of
/// the request NFT.
#[starknet::interface]
pub trait IEndurWithdrawQueue<T> {
    fn claim_withdrawal(ref self: T, request_id: u128);
    fn get_request_info(self: @T, request_id: u128) -> EndurWithdrawRequest;
    fn get_queue_state(self: @T) -> EndurQueueState;
}
