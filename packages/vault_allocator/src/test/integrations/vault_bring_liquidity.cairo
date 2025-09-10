// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::interfaces::erc4626::IERC4626Dispatcher;
use snforge_std::{map_entry_address, store};
use vault_allocator::manager::interface::IManagerDispatcherTrait;
use vault_allocator::mocks::vault::MockVault::MockVaultTraitDispatcherTrait;
use vault_allocator::test::utils::{
    ManageLeaf, OWNER, STRATEGIST, WAD, _add_vault_allocator_leafs, _get_proofs_using_tree,
    _pad_leafs_to_power_of_two, cheat_caller_address_once, deploy_erc20_mock, deploy_manager,
    deploy_mock_vault, deploy_simple_decoder_and_sanitizer, deploy_vault_allocator,
    generate_merkle_tree,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcherTrait;

#[test]
fn test_manage_vault_with_merkle_verification_bring_liquidity() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();

    let underlying_token = deploy_erc20_mock();
    let mock_vault = deploy_mock_vault(underlying_token);

    let mock_vault_erc4626 = IERC4626Dispatcher { contract_address: mock_vault.contract_address };

    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_vault_allocator_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        mock_vault_erc4626,
    );

    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);

    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);

    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), root);

    // Set initial balance and liquidity for mock vault
    let initial_liquidity: u256 = 10 * WAD;
    let initial_buffer: u256 = 5 * WAD;

    // Add underlying token balance to vault allocator
    let mut cheat_calldata = ArrayTrait::new();
    initial_liquidity.serialize(ref cheat_calldata);
    store(
        underlying_token,
        map_entry_address(
            selector!("ERC20_balances"), array![vault_allocator.contract_address.into()].span(),
        ),
        cheat_calldata.span(),
    );

    // Set initial buffer and liquidity in mock vault
    cheat_caller_address_once(mock_vault.contract_address, OWNER());
    mock_vault.set_buffer(initial_buffer);

    cheat_caller_address_once(mock_vault.contract_address, OWNER());
    mock_vault.set_aum(initial_liquidity);

    let underlying_disp = ERC20ABIDispatcher { contract_address: underlying_token };
    assert(
        underlying_disp.balance_of(vault_allocator.contract_address) == initial_liquidity,
        'underlying balance incorrect',
    );

    // Prepare to call bring_liquidity
    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(underlying_token);
    array_of_targets.append(mock_vault.contract_address);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("bring_liquidity"));

    let mut array_of_calldatas = ArrayTrait::new();

    let bring_liquidity_amount: u256 = 2 * WAD;

    // Approval calldata
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    mock_vault.contract_address.serialize(ref array_of_calldata_approve);
    bring_liquidity_amount.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    // Bring liquidity calldata (empty for this function)
    let mut array_of_calldata_bring_liquidity: Array<felt252> = ArrayTrait::new();
    bring_liquidity_amount.serialize(ref array_of_calldata_bring_liquidity);
    array_of_calldatas.append(array_of_calldata_bring_liquidity.span());

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

    // Verify that bring_liquidity was called successfully
    // The mock vault should have received some underlying tokens and updated its state
    let new_liquidity = underlying_disp.balance_of(vault_allocator.contract_address);
    assert(
        new_liquidity == initial_liquidity - bring_liquidity_amount, 'tokens should be transferred',
    );

    // Check that the vault has increased liquidity
    let new_buffer = mock_vault.buffer();
    let new_aum = mock_vault.aum();

    assert(new_buffer == initial_buffer + bring_liquidity_amount, 'buffer should increase');
    assert(new_aum == initial_liquidity - bring_liquidity_amount, 'aum should decrease');
}
