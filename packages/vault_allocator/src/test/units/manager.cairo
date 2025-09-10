// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::interfaces::security::pausable::{IPausableDispatcher, IPausableDispatcherTrait};
use openzeppelin::interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::manager::manager::Manager::{OWNER_ROLE, PAUSER_ROLE};
use vault_allocator::mocks::counter::{ICounterDispatcher, ICounterDispatcherTrait};
use vault_allocator::test::utils::{
    DUMMY_ADDRESS, ManageLeaf, OWNER, STRATEGIST, WAD, _add_erc4626_leafs, _get_proofs_using_tree,
    _pad_leafs_to_power_of_two, cheat_caller_address_once, deploy_counter, deploy_erc20_mock,
    deploy_erc4626_mock, deploy_manager, deploy_simple_decoder_and_sanitizer,
    deploy_vault_allocator, generate_merkle_tree,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcherTrait;

#[test]
fn test_constructor() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: manager.contract_address,
    };
    let role_admin = access_control_dispatcher.get_role_admin(OWNER_ROLE);
    assert(role_admin == OWNER_ROLE, 'Owner is not set correctly');
    let role_admin = access_control_dispatcher.get_role_admin(PAUSER_ROLE);
    assert(role_admin == OWNER_ROLE, 'Owner is not set correctly');
    let has_role = access_control_dispatcher.has_role(OWNER_ROLE, OWNER());
    assert(has_role, 'Owner is not set correctly');
    let has_role = access_control_dispatcher.has_role(PAUSER_ROLE, OWNER());
    assert(has_role, 'Pauser is not set correctly');

    assert(
        manager.vault_allocator() == vault_allocator.contract_address,
        'allocator is not set correctly',
    );
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_upgrade_not_owner() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let (_, counter_class_hash) = deploy_counter();
    IUpgradeableDispatcher { contract_address: manager.contract_address }
        .upgrade(counter_class_hash);
}

#[test]
fn test_upgrade() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let (_, counter_class_hash) = deploy_counter();
    cheat_caller_address_once(manager.contract_address, OWNER());
    IUpgradeableDispatcher { contract_address: manager.contract_address }
        .upgrade(counter_class_hash);
    ICounterDispatcher { contract_address: manager.contract_address }.get_value();
}

#[test]
fn test_set_manage_root() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    let target = 0x123.try_into().unwrap();
    let root = 0x456;

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(target, root);

    let stored_root = manager.manage_root(target);
    assert(stored_root == root, 'Root not set correctly');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_manage_root_not_owner() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    let target = 0x123.try_into().unwrap();
    let root = 0x456;

    manager.set_manage_root(target, root);
}

#[test]
fn test_pause() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let manager_dispatcher = IManagerDispatcher { contract_address: manager.contract_address };
    let pausable_dispatcher = IPausableDispatcher { contract_address: manager.contract_address };

    assert(!pausable_dispatcher.is_paused(), 'Should not be paused initially');

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager_dispatcher.pause();

    assert(pausable_dispatcher.is_paused(), 'Should be paused after pause()');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_pause_not_pauser() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    manager.pause();
}

#[test]
fn test_unpause() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let manager_dispatcher = IManagerDispatcher { contract_address: manager.contract_address };
    let pausable_dispatcher = IPausableDispatcher { contract_address: manager.contract_address };

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager_dispatcher.pause();
    assert(pausable_dispatcher.is_paused(), 'Should be paused');

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager_dispatcher.unpause();

    assert(!pausable_dispatcher.is_paused(), ' not be paused after unpause()');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_unpause_not_owner() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.pause();
    manager.unpause();
}

#[test]
#[should_panic(expected: "Inconsistent lengths")]
fn test_manage_vault_with_merkle_verification_inconsistent_lengths_1() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    manager
        .manage_vault_with_merkle_verification(
            array![array![].span()].span(),
            array![].span(),
            array![].span(),
            array![].span(),
            array![].span(),
        );
}

#[test]
#[should_panic(expected: "Inconsistent lengths")]
fn test_manage_vault_with_merkle_verification_inconsistent_lengths_2() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    manager
        .manage_vault_with_merkle_verification(
            array![array![].span()].span(),
            array![DUMMY_ADDRESS()].span(),
            array![].span(),
            array![].span(),
            array![].span(),
        );
}

#[test]
#[should_panic(expected: "Inconsistent lengths")]
fn test_manage_vault_with_merkle_verification_inconsistent_lengths_3() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    manager
        .manage_vault_with_merkle_verification(
            array![array![].span()].span(),
            array![DUMMY_ADDRESS()].span(),
            array![DUMMY_ADDRESS()].span(),
            array![].span(),
            array![].span(),
        );
}

#[test]
#[should_panic(expected: "Inconsistent lengths")]
fn test_manage_vault_with_merkle_verification_inconsistent_lengths_4() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    manager
        .manage_vault_with_merkle_verification(
            array![array![].span()].span(),
            array![DUMMY_ADDRESS()].span(),
            array![DUMMY_ADDRESS()].span(),
            array![3].span(),
            array![].span(),
        );
}

#[test]
#[should_panic(expected: "Invalid manage proof")]
fn test_manage_vault_with_merkle_verification_invalid_proof() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();
    let underlying = deploy_erc20_mock();
    let erc4626 = deploy_erc4626_mock(underlying);
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;
    _add_erc4626_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        erc4626,
    );
    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree = generate_merkle_tree(leafs.span());

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(underlying);
    array_of_targets.append(erc4626);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("deposit"));
    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    vault_allocator.contract_address.serialize(ref array_of_calldata_approve);
    let amount: u256 = WAD;
    amount.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    let mut array_of_calldata_deposit: Array<felt252> = ArrayTrait::new();
    amount.serialize(ref array_of_calldata_deposit);
    vault_allocator.contract_address.serialize(ref array_of_calldata_deposit);
    array_of_calldatas.append(array_of_calldata_deposit.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(0).clone());
    manage_leafs.append(leafs.at(1).clone());

    let proofs = _get_proofs_using_tree(manage_leafs, tree);
    manager
        .manage_vault_with_merkle_verification(
            proofs.span(),
            array_of_decoders_and_sanitizers.span(),
            array_of_targets.span(),
            array_of_selectors.span(),
            array_of_calldatas.span(),
        );
}

#[test]
fn test_manage_vault_with_merkle_verification_valid_proof() {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let simple_decoder_and_sanitizer = deploy_simple_decoder_and_sanitizer();
    let underlying = deploy_erc20_mock();
    let erc4626 = deploy_erc4626_mock(underlying);
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;
    _add_erc4626_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        simple_decoder_and_sanitizer,
        erc4626,
    );
    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree = generate_merkle_tree(leafs.span());

    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(simple_decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(underlying);
    array_of_targets.append(erc4626);

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("deposit"));
    let mut array_of_calldatas = ArrayTrait::new();
    let mut array_of_calldata_approve: Array<felt252> = ArrayTrait::new();
    erc4626.serialize(ref array_of_calldata_approve);
    let amount: u256 = WAD;
    amount.serialize(ref array_of_calldata_approve);
    array_of_calldatas.append(array_of_calldata_approve.span());

    let mut array_of_calldata_deposit: Array<felt252> = ArrayTrait::new();
    amount.serialize(ref array_of_calldata_deposit);
    vault_allocator.contract_address.serialize(ref array_of_calldata_deposit);
    array_of_calldatas.append(array_of_calldata_deposit.span());

    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(leafs.at(0).clone());
    manage_leafs.append(leafs.at(1).clone());

    let proofs = _get_proofs_using_tree(manage_leafs, tree.clone());

    let manager_root = *tree.at(tree.len() - 1).at(0);

    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), manager_root);
    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);
    cheat_caller_address_once(manager.contract_address, OWNER());

    let underlying_disp = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    underlying_disp.transfer(vault_allocator.contract_address, WAD * 10);

    let balance = underlying_disp.balance_of(vault_allocator.contract_address);
    assert(balance == WAD * 10, 'Balance wrong');

    cheat_caller_address_once(manager.contract_address, STRATEGIST());
    manager
        .manage_vault_with_merkle_verification(
            proofs.span(),
            array_of_decoders_and_sanitizers.span(),
            array_of_targets.span(),
            array_of_selectors.span(),
            array_of_calldatas.span(),
        );

    let strategy_balance = ERC20ABIDispatcher { contract_address: erc4626 }
        .balance_of(vault_allocator.contract_address);
    assert(strategy_balance == WAD, 'Balance wrong');

    let underlying_balance = underlying_disp.balance_of(vault_allocator.contract_address);
    assert(underlying_balance == WAD * 9, 'Balance wrong');
}

