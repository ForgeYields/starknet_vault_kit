// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use alexandria_math::i257::I257Impl;
use core::num::traits::Zero;
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{map_entry_address, store};
use starknet::ContractAddress;
use vault_allocator::decoders_and_sanitizers::decoder_custom_types::Route;
use vault_allocator::manager::interface::IManagerDispatcherTrait;
use vault_allocator::middlewares::avnu_middleware::interface::{
    IAvnuMiddlewareDispatcher, IAvnuMiddlewareDispatcherTrait,
};
use vault_allocator::test::register::{ETH, wstETH};
use vault_allocator::test::utils::{
    ManageLeaf, OWNER, STRATEGIST, WAD, _add_avnu_leafs, _get_proofs_using_tree,
    _pad_leafs_to_power_of_two, cheat_caller_address_once, deploy_avnu_middleware, deploy_manager,
    deploy_price_router, deploy_simple_decoder_and_sanitizer, deploy_vault_allocator,
    generate_merkle_tree, initialize_price_router,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcherTrait;

#[fork("AVNU")]
#[test]
fn test_manage_vault_with_merkle_verification_avnu() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();
    let price_router = deploy_price_router();
    initialize_price_router(price_router);
    let avnu_middleware = deploy_avnu_middleware(price_router);

    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_avnu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        avnu_middleware,
        array![(wstETH(), ETH())],
    );

    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);

    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);
    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), root);

    // add wsteth balance to vault allocator
    let initial_wsteth_balance: u256 = 10 * WAD;
    let mut cheat_calldata = ArrayTrait::new();
    initial_wsteth_balance.serialize(ref cheat_calldata);
    store(
        wstETH(),
        map_entry_address(
            selector!("ERC20_balances"), array![vault_allocator.contract_address.into()].span(),
        ),
        cheat_calldata.span(),
    );
    let underlying_disp = ERC20ABIDispatcher { contract_address: wstETH() };
    assert(
        underlying_disp.balance_of(vault_allocator.contract_address) == initial_wsteth_balance,
        'wsteth balance is not correct',
    );

    // sell 1 wsteth for eth
    let sell_amount: u256 = WAD;

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(wstETH());
    array_of_targets.append(avnu_middleware);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("multi_route_swap"));

    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    avnu_middleware.serialize(ref array_of_calldata_approve);
    sell_amount.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    let mut array_of_calldata_multi_route_swap: Array<felt252> = ArrayTrait::new();
    wstETH().serialize(ref array_of_calldata_multi_route_swap);
    sell_amount.serialize(ref array_of_calldata_multi_route_swap);
    ETH().serialize(ref array_of_calldata_multi_route_swap);
    // buy token amount is 0 because we are selling
    let buy_token_amount: u256 = Zero::zero();
    buy_token_amount.serialize(ref array_of_calldata_multi_route_swap);
    // buy_token_min_amount is set to 0 because we are protected by price router whatever
    let buy_token_min_amount: u256 = Zero::zero();
    buy_token_min_amount.serialize(ref array_of_calldata_multi_route_swap);
    vault_allocator.contract_address.serialize(ref array_of_calldata_multi_route_swap);
    let integrator_fee_amount_bps: u128 = Zero::zero();
    integrator_fee_amount_bps.serialize(ref array_of_calldata_multi_route_swap);
    let integrator_fee_recipient: ContractAddress = Zero::zero();
    integrator_fee_recipient.serialize(ref array_of_calldata_multi_route_swap);

    let mut routes: Array<Route> = ArrayTrait::new();
    // hardcode rout to ekubo wsteth/eth

    let mut additional_swap_params: Array<felt252> = ArrayTrait::new();
    let token0: ContractAddress = wstETH();
    token0.serialize(ref additional_swap_params);
    let token1: ContractAddress = ETH();
    token1.serialize(ref additional_swap_params);
    let fee: u128 = 0x68db8bac710cb4000000000000000;
    fee.serialize(ref additional_swap_params);
    let tick_spacing: u128 = 0xc8;
    tick_spacing.serialize(ref additional_swap_params);
    let extension: ContractAddress = Zero::zero();
    extension.serialize(ref additional_swap_params);
    let sqrt_ratio_distance: felt252 = 13317268759177810398769652994932736;
    sqrt_ratio_distance.serialize(ref additional_swap_params);

    routes
        .append(
            Route {
                sell_token: wstETH(),
                buy_token: ETH(),
                exchange_address: 0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b
                    .try_into()
                    .unwrap(), // ekubo
                percent: 1000000000000,
                additional_swap_params,
            },
        );
    routes.serialize(ref array_of_calldata_multi_route_swap);
    array_of_calldatas.append(array_of_calldata_multi_route_swap.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(0).clone());
    manage_leafs.append(leafs.at(1).clone());

    cheat_caller_address_once(avnu_middleware, OWNER());
    IAvnuMiddlewareDispatcher { contract_address: avnu_middleware }
        .set_slippage_tolerance_bps(100); // 1% slippage

    let manage_proofs = _get_proofs_using_tree(manage_leafs, tree.clone());

    cheat_caller_address_once(manager.contract_address, STRATEGIST());
    manager
        .manage_vault_with_merkle_verification(
            manage_proofs.span(),
            array_of_decoders_and_sanitizers.span(),
            array_of_targets.span(),
            array_of_selectors.span(),
            array_of_calldatas.span(),
        );

    let new_wsteth_balance_vault_allocator = ERC20ABIDispatcher { contract_address: wstETH() }
        .balance_of(vault_allocator.contract_address);
    assert(
        new_wsteth_balance_vault_allocator == initial_wsteth_balance - sell_amount,
        'incorrect sell amount',
    );

    let new_eth_balance_vault_allocator = ERC20ABIDispatcher { contract_address: ETH() }
        .balance_of(vault_allocator.contract_address);
    assert(new_eth_balance_vault_allocator > Zero::zero(), 'incorrect');
}
