// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.
use alexandria_math::i257::I257Impl;
use core::num::traits::Zero;
use ekubo::types::i129::i129;
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{map_entry_address, store};
use starknet::ContractAddress;
use vault_allocator::adapters::ekubo_adapter::interface::{
    IEkuboAdapterDispatcher, IEkuboAdapterDispatcherTrait,
};
use vault_allocator::integration_interfaces::ekubo::{
    Bounds, IMathLibDispatcherTrait, PoolKey, dispatcher as ekuboLibDispatcher,
};
use vault_allocator::test::utils::{cheat_caller_address_once, deploy_ekubo_adapter};
fn _tick_to_sqrt_ratio(tick: i129) -> u256 {
    ekuboLibDispatcher().tick_to_sqrt_ratio(tick)
}

fn sqrt_ratio_to_tick(sqrt_ratio: u256) -> i129 {
    ekuboLibDispatcher().sqrt_ratio_to_tick(sqrt_ratio)
}

#[fork("EKUBO")]
#[test]
fn test_ekubo_adapter() {
    let owner: ContractAddress = 0x0399EB3460EB885B5E1F5f2aeBF63DAdb7493F4Cbf34868434366BBB55422C4E
        .try_into()
        .unwrap();

    let ekubo_core: ContractAddress =
        0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b
        .try_into()
        .unwrap();
    let ekubo_positions_contract =
        0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067
        .try_into()
        .unwrap();
    let ekubo_positions_nft: ContractAddress =
        0x07b696af58c967c1b14c9dde0ace001720635a660a8e90c565ea459345318b30
        .try_into()
        .unwrap();

    let solvBtc: ContractAddress =
        0x0593e034DdA23eea82d2bA9a30960ED42CF4A01502Cc2351Dc9B9881F9931a68
        .try_into()
        .unwrap();
    let wBtc = 0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC
        .try_into()
        .unwrap();

    let lower_bound = i129 { mag: 23025400, sign: false };
    let upper_bound = i129 { mag: 23026200, sign: false };
    let bounds_settings = Bounds { lower: lower_bound, upper: upper_bound };
    let pool_key = PoolKey {
        token0: wBtc, token1: solvBtc, fee: 0, tick_spacing: 100, extension: Zero::zero(),
    };

    let ekubo_adapter = deploy_ekubo_adapter(
        owner,
        owner,
        ekubo_positions_contract,
        bounds_settings,
        pool_key,
        ekubo_positions_nft,
        ekubo_core,
    );

    // add wsteth balance to vault allocator
    let initial_wbtc_balance: u256 = 1_00_000_000; // 1 wbtc
    let initial_solv_balance: u256 = 1_000_000_000_000_000_000; // 1 solv

    let mut cheat_calldata_wbtc = ArrayTrait::new();
    initial_wbtc_balance.serialize(ref cheat_calldata_wbtc);
    let mut cheat_calldata_solv = ArrayTrait::new();
    initial_solv_balance.serialize(ref cheat_calldata_solv);
    store(
        wBtc,
        map_entry_address(selector!("ERC20_balances"), array![owner.into()].span()),
        cheat_calldata_wbtc.span(),
    );
    store(
        solvBtc,
        map_entry_address(selector!("ERC20_balances"), array![owner.into()].span()),
        cheat_calldata_solv.span(),
    );
    let underlying_disp_wbtc = ERC20ABIDispatcher { contract_address: wBtc };
    assert(
        underlying_disp_wbtc.balance_of(owner) == initial_wbtc_balance,
        'wbtc balance is not correct',
    );
    let underlying_disp_solv = ERC20ABIDispatcher { contract_address: solvBtc };
    assert(
        underlying_disp_solv.balance_of(owner) == initial_solv_balance,
        'solv balance is not correct',
    );

    cheat_caller_address_once(wBtc, owner);
    ERC20ABIDispatcher { contract_address: wBtc }
        .approve(ekubo_adapter.contract_address, initial_wbtc_balance);
    cheat_caller_address_once(solvBtc, owner);
    ERC20ABIDispatcher { contract_address: solvBtc }
        .approve(ekubo_adapter.contract_address, initial_solv_balance);
    cheat_caller_address_once(ekubo_adapter.contract_address, owner);
    ekubo_adapter.deposit_liquidity(initial_wbtc_balance, initial_solv_balance);

    // check res and position

    let new_btc_balance = underlying_disp_wbtc.balance_of(owner);
    let new_solv_balance = underlying_disp_solv.balance_of(owner);
    println!("new_btc_balance: {}", new_btc_balance);
    println!("new_solv_balance: {}", new_solv_balance);

    let position = IEkuboAdapterDispatcher { contract_address: ekubo_adapter.contract_address }
        .get_position();
    println!("position liquidity: {}", position.liquidity);

    let (amount0, amount1) = IEkuboAdapterDispatcher {
        contract_address: ekubo_adapter.contract_address,
    }
        .underlying_balance();
    println!("underlying balance 0: {}", amount0);
    println!("underlying balance 1: {}", amount1);

    // withdraw 50% of the position
    let ratioWad = 500000000000000000; // 50%
    let min_token0 = 0;
    let min_token1 = 0;

    cheat_caller_address_once(ekubo_adapter.contract_address, owner);
    ekubo_adapter.withdraw_liquidity(ratioWad, min_token0, min_token1);

    let (amount0, amount1) = IEkuboAdapterDispatcher {
        contract_address: ekubo_adapter.contract_address,
    }
        .underlying_balance();
    println!("underlying balance 0: {}", amount0);
    println!("underlying balance 1: {}", amount1);

    let (token0_ratio_wad, token1_ratio_wad) = IEkuboAdapterDispatcher {
        contract_address: ekubo_adapter.contract_address,
    }
        .get_deposit_ratio();
    println!("token0_ratio_wad: {}", token0_ratio_wad);
    println!("token1_ratio_wad: {}", token1_ratio_wad);
}
