// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use ekubo::types::position::Position as EkuboPosition;
use starknet::ContractAddress;
use vault_allocator::integration_interfaces::ekubo::{Bounds, PoolKey, PositionKey};

#[starknet::interface]
pub trait IEkuboAdapter<T> {
    fn get_position_key(self: @T) -> PositionKey;
    fn get_position(self: @T) -> EkuboPosition;
    fn get_ekubo_positions_contract(self: @T) -> ContractAddress;
    fn get_bounds_settings(self: @T) -> Bounds;
    fn get_pool_key(self: @T) -> PoolKey;
    fn get_ekubo_positions_nft(self: @T) -> ContractAddress;
    fn get_contract_nft_id(self: @T) -> u64;
    fn get_ekubo_core(self: @T) -> ContractAddress;
    fn get_vault_allocator(self: @T) -> ContractAddress;
    fn total_liquidity(self: @T) -> u256;
    fn deposit_liquidity(ref self: T, amount0: u256, amount1: u256);
    fn withdraw_liquidity(ref self: T, ratioWad: u256, min_token0: u128, min_token1: u128);
    fn underlying_balance(self: @T) -> (u256, u256);
    fn pending_fees(self: @T) -> (u256, u256);
    fn collect_fees(ref self: T);
    /// @notice Returns the deposit ratio of token0 and token1 based on bounds and current pool
    /// price @dev Calculates how much of each token is needed for a balanced deposit given the
    /// position bounds @return sqrt_ratio_lower The sqrt price ratio at the lower bound
    /// @return sqrt_ratio_upper The sqrt price ratio at the upper bound
    /// @return sqrt_ratio_current The current pool sqrt price ratio
    /// @return token0_ratio_wad The percentage of token0 to deposit in WAD (0 to 1e18)
    /// @return token1_ratio_wad The percentage of token1 to deposit in WAD (0 to 1e18)
    fn get_deposit_ratio(self: @T) -> (u256, u256);
    /// @notice Sets new bounds settings for the position
    /// @dev Only callable by owner and only when no position exists (contract_nft_id is zero)
    /// @param bounds The new bounds settings to set
    fn set_bounds_settings(ref self: T, bounds: Bounds);
    /// @notice Claims rewards from a reward contract and sends them to vault allocator
    /// @param reward_contract The contract to claim rewards from
    /// @param amount The amount to claim
    /// @param proof The merkle proof for claiming
    /// @param reward_token The token address of the reward
    fn harvest(
        ref self: T,
        reward_contract: ContractAddress,
        amount: u128,
        proof: Span<felt252>,
        reward_token: ContractAddress,
    );
}

#[starknet::interface]
pub trait IRewardContract<T> {
    fn claim(ref self: T, amount: u128, proof: Span<felt252>);
}
