// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use alexandria_math::i257::{I257Impl, I257Trait};
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use snforge_std::{map_entry_address, store};
use vault_allocator::decoders_and_sanitizers::decoder_custom_types::{
    Amount, AmountDenomination, AmountType,
};
use vault_allocator::integration_interfaces::vesu::{
    IDefaultExtensionPOV2Dispatcher, IDefaultExtensionPOV2DispatcherTrait, ISingletonV2Dispatcher,
    ISingletonV2DispatcherTrait,
};
use vault_allocator::manager::interface::IManagerDispatcherTrait;
use vault_allocator::test::register::{ETH, GENESIS_POOL_ID, VESU_SINGLETON, wstETH};
use vault_allocator::test::utils::{
    ManageLeaf, OWNER, STRATEGIST, WAD, _add_vesu_leafs, _get_proofs_using_tree,
    _pad_leafs_to_power_of_two, cheat_caller_address_once, deploy_manager,
    deploy_simple_decoder_and_sanitizer, deploy_vault_allocator, generate_merkle_tree,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcherTrait;

#[fork("MAINNET")]
#[test]
fn test_manage_vault_with_merkle_verification_earn_mode() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();

    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_vesu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        GENESIS_POOL_ID,
        array![wstETH()].span(),
        array![array![ETH()].span()].span(),
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

    // first scenario is depositing wsteth to vesu genesis pool
    let deposit_amount: u256 = WAD;

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(wstETH());
    let v_token = IDefaultExtensionPOV2Dispatcher {
        contract_address: ISingletonV2Dispatcher { contract_address: VESU_SINGLETON() }
            .extension(GENESIS_POOL_ID),
    }
        .v_token_for_collateral_asset(GENESIS_POOL_ID, wstETH());
    array_of_targets.append(v_token);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("deposit"));

    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    v_token.serialize(ref array_of_calldata_approve);
    deposit_amount.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    let mut array_of_calldata_deposit: Array<felt252> = ArrayTrait::new();
    deposit_amount.serialize(ref array_of_calldata_deposit);
    vault_allocator.contract_address.serialize(ref array_of_calldata_deposit);
    array_of_calldatas.append(array_of_calldata_deposit.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(0).clone());
    manage_leafs.append(leafs.at(1).clone());

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

    let new_underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    assert(new_underlying_balance == initial_wsteth_balance - deposit_amount, 'incorrect');

    let v_token_erc4626_disp = IERC4626Dispatcher { contract_address: v_token };
    let exptected_shares_obtained = v_token_erc4626_disp.preview_deposit(deposit_amount);

    let v_token_erc20_disp = ERC20ABIDispatcher { contract_address: v_token };
    let vault_shares_balance = v_token_erc20_disp.balance_of(vault_allocator.contract_address);
    assert(vault_shares_balance == exptected_shares_obtained, 'incorrect');

    // second scenario is redeeming full v-token obtained from deposit

    let shares_to_redeem: u256 = vault_shares_balance;

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(v_token);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("redeem"));

    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_redeem: Array<felt252> = ArrayTrait::new();
    shares_to_redeem.serialize(ref array_of_calldata_redeem);
    vault_allocator.contract_address.serialize(ref array_of_calldata_redeem);
    vault_allocator.contract_address.serialize(ref array_of_calldata_redeem);
    array_of_calldatas.append(array_of_calldata_redeem.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(4).clone());

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

    let new_vault_shares_balance = v_token_erc20_disp.balance_of(vault_allocator.contract_address);
    assert(new_vault_shares_balance == 0, 'incorrect');

    let expected_received_assets = v_token_erc4626_disp.preview_redeem(shares_to_redeem);

    let new_underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    let current_expected_balance = initial_wsteth_balance
        - deposit_amount
        + expected_received_assets;
    assert(new_underlying_balance == current_expected_balance, 'incorrect');

    // third scenario is minting v-token wsteth

    let shares_to_mint: u256 = 2 * WAD;

    let assets_required_to_mint = v_token_erc4626_disp.preview_mint(shares_to_mint);

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(wstETH());
    array_of_targets.append(v_token);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("mint"));

    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    v_token.serialize(ref array_of_calldata_approve);
    assets_required_to_mint.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    let mut array_of_calldata_mint: Array<felt252> = ArrayTrait::new();
    shares_to_mint.serialize(ref array_of_calldata_mint);
    vault_allocator.contract_address.serialize(ref array_of_calldata_mint);
    array_of_calldatas.append(array_of_calldata_mint.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(0).clone());
    manage_leafs.append(leafs.at(3).clone());

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

    let new_underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    let current_expected_balance = current_expected_balance - assets_required_to_mint;
    assert(new_underlying_balance == current_expected_balance, 'incorrect');

    let new_vault_shares_balance = v_token_erc20_disp.balance_of(vault_allocator.contract_address);
    assert(new_vault_shares_balance == shares_to_mint, 'incorrect');

    // fourth scenario is withdraw v-token wsteth
    let assets_to_withdraw: u256 = WAD;

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(v_token);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("withdraw"));

    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_withdraw: Array<felt252> = ArrayTrait::new();
    assets_to_withdraw.serialize(ref array_of_calldata_withdraw);
    vault_allocator.contract_address.serialize(ref array_of_calldata_withdraw);
    vault_allocator.contract_address.serialize(ref array_of_calldata_withdraw);
    array_of_calldatas.append(array_of_calldata_withdraw.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(2).clone());

    let manage_proofs = _get_proofs_using_tree(manage_leafs, tree.clone());

    let shares_balance_before_withdraw = v_token_erc20_disp
        .balance_of(vault_allocator.contract_address);
    cheat_caller_address_once(manager.contract_address, STRATEGIST());
    manager
        .manage_vault_with_merkle_verification(
            manage_proofs.span(),
            array_of_decoders_and_sanitizers.span(),
            array_of_targets.span(),
            array_of_selectors.span(),
            array_of_calldatas.span(),
        );

    let expected_shares_burn = v_token_erc4626_disp.preview_withdraw(assets_to_withdraw);
    let new_vault_shares_balance = v_token_erc20_disp.balance_of(vault_allocator.contract_address);

    assert(
        new_vault_shares_balance <= shares_balance_before_withdraw - expected_shares_burn,
        'incorrect',
    );

    let new_underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    let current_expected_balance = current_expected_balance + assets_to_withdraw;
    assert(new_underlying_balance == current_expected_balance, 'incorrect');
}

#[fork("MAINNET")]
#[test]
fn test_manage_vault_with_merkle_verification_debt_mode() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();

    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_vesu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        GENESIS_POOL_ID,
        array![wstETH()].span(),
        array![array![ETH()].span()].span(),
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
    // first scenario is depositing wsteth to vesu genesis pool, transfer the position and borrow
    // ETH
    let deposit_amount: u256 = WAD;

    let debt_amount: u256 = WAD / 40; // 2.5% of the deposit

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(wstETH());
    array_of_targets.append(VESU_SINGLETON());

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("modify_position"));

    let mut array_of_calldatas = ArrayTrait::new();

    let mut array_of_calldata_approve_token: Array<felt252> = ArrayTrait::new();
    VESU_SINGLETON().serialize(ref array_of_calldata_approve_token);
    deposit_amount.serialize(ref array_of_calldata_approve_token);
    array_of_calldatas.append(array_of_calldata_approve_token.span());

    let mut array_of_calldata_modify_position: Array<felt252> = ArrayTrait::new();
    // pool_id
    GENESIS_POOL_ID.serialize(ref array_of_calldata_modify_position);

    // collateral_asset
    wstETH().serialize(ref array_of_calldata_modify_position);

    // debt_asset
    ETH().serialize(ref array_of_calldata_modify_position);

    // user
    vault_allocator.contract_address.serialize(ref array_of_calldata_modify_position);

    // collateral
    let value_for_collateral_modify_position = I257Trait::new((deposit_amount), false);
    let collateral_modify_position: Amount = Amount {
        amount_type: AmountType::Delta,
        denomination: AmountDenomination::Assets,
        value: value_for_collateral_modify_position,
    };
    collateral_modify_position.serialize(ref array_of_calldata_modify_position);

    // debt
    let value_for_debt_modify_position = I257Trait::new(debt_amount, false);
    let debt_modify_position: Amount = Amount {
        amount_type: AmountType::Target,
        denomination: AmountDenomination::Assets,
        value: value_for_debt_modify_position,
    };
    debt_modify_position.serialize(ref array_of_calldata_modify_position);

    // data
    let data: Span<felt252> = array![].span();
    data.serialize(ref array_of_calldata_modify_position);

    array_of_calldatas.append(array_of_calldata_modify_position.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(5).clone());
    manage_leafs.append(leafs.at(6).clone());

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
    let new_underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    assert(new_underlying_balance == initial_wsteth_balance - deposit_amount, 'incorrect');

    let debt_asset_disp = ERC20ABIDispatcher { contract_address: ETH() };
    let debt_asset_balance = debt_asset_disp.balance_of(vault_allocator.contract_address);
    assert(debt_asset_balance == debt_amount, 'incorrect');
}

