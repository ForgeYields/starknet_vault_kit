// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IAumProvider4626<TContractState> {
    fn get_strategy_4626(self: @TContractState) -> ContractAddress;
}