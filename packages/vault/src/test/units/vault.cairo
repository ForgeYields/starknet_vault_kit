// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::num::traits::{Bounded, Zero};
use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc20::{
    ERC20ABIDispatcher, ERC20ABIDispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use openzeppelin::interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::interfaces::security::pausable::{IPausableDispatcher, IPausableDispatcherTrait};
use openzeppelin::interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin::utils::math;
use openzeppelin::utils::math::Rounding;
use snforge_std::{
    EventSpyAssertionsTrait, map_entry_address, spy_events, start_cheat_block_timestamp_global,
    store, test_address,
};
use starknet::{ContractAddress, get_block_timestamp};
use vault::redeem_request::interface::{IRedeemRequestDispatcher, IRedeemRequestDispatcherTrait};
use vault::test::utils::{
    DUMMY_ADDRESS, FEES_RECIPIENT, MANAGEMENT_FEES, MAX_DELTA, ORACLE, OTHER_DUMMY_ADDRESS, OWNER,
    PERFORMANCE_FEES, REDEEM_FEES, REPORT_DELAY, VAULT_ALLOCATOR, VAULT_NAME, VAULT_SYMBOL, between,
    cheat_caller_address_once, deploy_counter, deploy_erc20_mock, deploy_redeem_request,
    deploy_vault,
};
use vault::vault::interface::{IVaultDispatcher, IVaultDispatcherTrait};
use vault::vault::vault::Vault;
use vault::vault::vault::Vault::{InternalFunctions, VaultImpl};
use vault_allocator::mocks::counter::{ICounterDispatcher, ICounterDispatcherTrait};

fn set_up() -> (ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher) {
    let underlying_assets = deploy_erc20_mock();
    let vault = deploy_vault(underlying_assets);
    let redeem_request = deploy_redeem_request(vault.contract_address);
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.register_redeem_request(redeem_request.contract_address);
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.register_vault_allocator(VAULT_ALLOCATOR());
    (underlying_assets, vault, redeem_request)
}

#[test]
fn test_constructor() {
    let (underlying_assets, vault, redeem_request) = set_up();

    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    let role_admin = access_control_dispatcher.get_role_admin(Vault::OWNER_ROLE);
    assert(role_admin == Vault::OWNER_ROLE, 'invalid role admin');
    let role_admin = access_control_dispatcher.get_role_admin(Vault::PAUSER_ROLE);
    assert(role_admin == Vault::OWNER_ROLE, 'invalid role admin');
    let role_admin = access_control_dispatcher.get_role_admin(Vault::ORACLE_ROLE);
    assert(role_admin == Vault::OWNER_ROLE, 'invalid role admin');

    let has_role = access_control_dispatcher.has_role(Vault::OWNER_ROLE, OWNER());
    assert(has_role, 'Owner is not set correctly');
    let has_role = access_control_dispatcher.has_role(Vault::PAUSER_ROLE, OWNER());
    assert(has_role, 'Pauser is not set correctly');
    let has_role = access_control_dispatcher.has_role(Vault::ORACLE_ROLE, OWNER());
    assert(has_role, 'Oracle is not set correctly');

    let erc20_metadata_dispatcher = IERC20MetadataDispatcher {
        contract_address: vault.contract_address,
    };
    assert(erc20_metadata_dispatcher.name() == VAULT_NAME(), 'Name is not set correctly');
    assert(erc20_metadata_dispatcher.symbol() == VAULT_SYMBOL(), 'Symbol is not set correctly');
    assert(erc20_metadata_dispatcher.decimals() == 18, 'Decimals are not set correctly');

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    assert(erc4626_dispatcher.asset() == underlying_assets, 'Underlying asset ');
    assert(vault.fees_recipient() == FEES_RECIPIENT(), 'Fees recipient');
    assert(vault.redeem_fees() == REDEEM_FEES(), 'Redeem fees');
    assert(vault.management_fees() == MANAGEMENT_FEES(), 'Management fees');
    assert(vault.performance_fees() == PERFORMANCE_FEES(), 'Performance fees');
    assert(vault.report_delay() == REPORT_DELAY(), 'Report delay');
    assert(vault.max_delta() == MAX_DELTA(), 'Max delta');
    assert(vault.redeem_request() == redeem_request.contract_address, 'Redeem request');
    assert(vault.vault_allocator() == VAULT_ALLOCATOR(), 'Vault allocator');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_upgrade_not_owner() {
    let (_, vault, _) = set_up();
    let (_, counter_class_hash) = deploy_counter();
    IUpgradeableDispatcher { contract_address: vault.contract_address }.upgrade(counter_class_hash);
}

#[test]
fn test_upgrade() {
    let (_, vault, _) = set_up();
    let (_, counter_class_hash) = deploy_counter();
    cheat_caller_address_once(vault.contract_address, OWNER());
    IUpgradeableDispatcher { contract_address: vault.contract_address }.upgrade(counter_class_hash);
    ICounterDispatcher { contract_address: vault.contract_address }.get_value();
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_register_redeem_not_owner() {
    let (_, vault, _) = set_up();
    vault.register_redeem_request(DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Redeem request already registered")]
fn test_register_redeem_already_registered() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.register_redeem_request(DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_register_vault_allocator_not_owner() {
    let (_, vault, _) = set_up();
    vault.register_vault_allocator(DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Vault allocator already registered")]
fn test_register_vault_allocator_already_registered() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.register_vault_allocator(DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_max_delta_not_owner() {
    let (_, vault, _) = set_up();
    vault.set_max_delta(MAX_DELTA() + 1);
}

#[test]
fn test_set_max_delta_success() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_max_delta(MAX_DELTA() + 1);
    assert(vault.max_delta() == MAX_DELTA() + 1, 'Max delta not updated');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_fees_config_not_owner() {
    let (_, vault, _) = set_up();
    vault.set_fees_config(FEES_RECIPIENT(), REDEEM_FEES(), MANAGEMENT_FEES(), PERFORMANCE_FEES());
}

#[test]
#[should_panic(expected: "Invalid redeem fees")]
fn test_set_fees_config_invalid_redeem_fees() {
    let (_, vault, _) = set_up();
    let invalid_redeem_fees = Vault::MAX_REDEEM_FEE + 1;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault
        .set_fees_config(
            FEES_RECIPIENT(), invalid_redeem_fees, MANAGEMENT_FEES(), PERFORMANCE_FEES(),
        );
}

#[test]
#[should_panic(expected: "Invalid management fees")]
fn test_set_fees_config_invalid_management_fees() {
    let (_, vault, _) = set_up();
    let invalid_management_fees = Vault::MAX_MANAGEMENT_FEE + 1;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault
        .set_fees_config(
            FEES_RECIPIENT(), REDEEM_FEES(), invalid_management_fees, PERFORMANCE_FEES(),
        );
}

#[test]
#[should_panic(expected: "Invalid performance fees")]
fn test_set_fees_config_invalid_performance_fees() {
    let (_, vault, _) = set_up();
    let invalid_performance_fees = Vault::MAX_PERFORMANCE_FEE + 1;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault
        .set_fees_config(
            FEES_RECIPIENT(), REDEEM_FEES(), MANAGEMENT_FEES(), invalid_performance_fees,
        );
}

#[test]
fn test_set_fees_config_success() {
    let (_, vault, _) = set_up();
    let new_fees_recipient = DUMMY_ADDRESS();
    let new_redeem_fees = Vault::MAX_REDEEM_FEE;
    let new_management_fees = Vault::MAX_MANAGEMENT_FEE;
    let new_performance_fees = Vault::MAX_PERFORMANCE_FEE;

    cheat_caller_address_once(vault.contract_address, OWNER());
    vault
        .set_fees_config(
            new_fees_recipient, new_redeem_fees, new_management_fees, new_performance_fees,
        );

    assert(vault.fees_recipient() == new_fees_recipient, 'Fees recipient not updated');
    assert(vault.redeem_fees() == new_redeem_fees, 'Redeem fees not updated');
    assert(vault.management_fees() == new_management_fees, 'Management fees not updated');
    assert(vault.performance_fees() == new_performance_fees, 'Performance fees not updated');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_report_delay_not_owner() {
    let (_, vault, _) = set_up();
    vault.set_report_delay(Vault::MIN_REPORT_DELAY);
}

#[test]
#[should_panic(expected: "Invalid report delay")]
fn test_set_report_delay_invalid_delay() {
    let (_, vault, _) = set_up();
    let invalid_delay = Vault::MIN_REPORT_DELAY - 1;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_report_delay(invalid_delay);
}

#[test]
fn test_set_report_delay_success() {
    let (_, vault, _) = set_up();
    let new_delay = Vault::MIN_REPORT_DELAY + 100;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_report_delay(new_delay);
    assert(vault.report_delay() == new_delay, 'Report delay not updated');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_pause_not_pauser() {
    let (_, vault, _) = set_up();
    vault.pause();
}

#[test]
fn test_pause_success() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();
    let pausable_dispatcher = IPausableDispatcher { contract_address: vault.contract_address };
    assert(pausable_dispatcher.is_paused(), 'Vault is not unpaused');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_unpause_not_owner() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();
    vault.unpause();
}

#[test]
fn test_unpause_success() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.unpause();
    let pausable_dispatcher = IPausableDispatcher { contract_address: vault.contract_address };
    assert(!pausable_dispatcher.is_paused(), 'Vault is not unpaused');
}

#[test]
#[should_panic(expected: "Not implemented")]
fn test_redeem_not_implemented() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;
    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };

    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    cheat_caller_address_once(vault.contract_address, OWNER());
    erc4626_dispatcher.redeem(shares, OWNER(), OWNER());
}

#[test]
#[should_panic(expected: "Not implemented")]
fn test_withdraw_not_implemented() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;
    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };

    cheat_caller_address_once(vault.contract_address, OWNER());
    erc4626_dispatcher.deposit(deposit_amount, OWNER());

    cheat_caller_address_once(vault.contract_address, OWNER());
    erc4626_dispatcher.withdraw(deposit_amount, OWNER(), OWNER());
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_deposit_when_paused() {
    let (underlying, vault, _) = set_up();

    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();

    let deposit_amount = Vault::WAD;
    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    erc4626_dispatcher.deposit(deposit_amount, OWNER());
}

#[test]
#[fuzzer]
fn test_deposit_success_buffer_increase(x: u256) {
    let (underlying, vault, _) = set_up();

    let deposit_amount = between(1, Vault::WAD * 100, x);
    let buffer_before = vault.buffer();

    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    let buffer_after = vault.buffer();
    assert(buffer_after == buffer_before + deposit_amount, 'Buffer did not increase');
    assert(shares > 0, 'No shares minted');

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    assert(erc20_dispatcher.balance_of(OWNER()) == shares, 'Shares not minted to owner');
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_request_redeem_paused() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();
    vault.request_redeem(Vault::WAD, DUMMY_ADDRESS(), DUMMY_ADDRESS());
}

#[test]
#[fuzzer]
#[should_panic(expected: "Exceeded max redeem")]
fn test_request_redeem_exceeds_max_redeem(x: u256) {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_to_redeem = between(shares + 1, shares * 100, x);

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    vault.request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());
}

#[test]
#[fuzzer]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_request_redeem_exceeds_max_allowance(x: u256) {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_to_redeem = between(1, shares, x);

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    vault.request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Zero assets")]
fn test_request_redeem_exceeds_zero_assets() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_to_redeem = 1;

    let erc20_dispatcher_vault = ERC20ABIDispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc20_dispatcher_vault.approve(OTHER_DUMMY_ADDRESS(), shares_to_redeem);

    let mut cheat_calldata = ArrayTrait::new();
    (deposit_amount - 1).serialize(ref cheat_calldata);

    store(vault.contract_address, selector!("buffer"), cheat_calldata.span());

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    vault.request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());
}

#[test]
#[fuzzer]
fn test_request_redeem_success(x: u256) {
    let (underlying, vault, redeem_request) = set_up();

    let deposit_amount = Vault::WAD;

    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_to_redeem = between(1, shares, x);

    let erc20_dispatcher_vault = ERC20ABIDispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc20_dispatcher_vault.approve(OTHER_DUMMY_ADDRESS(), shares_to_redeem);

    let mut cheat_calldata_buffer = ArrayTrait::new();
    (deposit_amount * 10).serialize(ref cheat_calldata_buffer); // make share price 10x higher
    store(vault.contract_address, selector!("buffer"), cheat_calldata_buffer.span());

    let mut cheat_calldata_epoch = ArrayTrait::new();
    let epoch: u256 = 7;
    epoch.serialize(ref cheat_calldata_epoch);
    store(vault.contract_address, selector!("epoch"), cheat_calldata_epoch.span());

    let mut cheat_calldata_redeem_nominal = ArrayTrait::new();
    (2 * Vault::WAD).serialize(ref cheat_calldata_redeem_nominal);

    let mut map_entry = map_entry_address(selector!("redeem_nominal"), cheat_calldata_epoch.span());
    store(vault.contract_address, map_entry, cheat_calldata_redeem_nominal.span());

    assert(vault.buffer() == deposit_amount * 10, 'Buffer not updated');
    assert(vault.epoch() == epoch, 'Epoch not updated');
    assert(vault.redeem_nominal(epoch) == 2 * Vault::WAD, 'Redeem nominal not updated');

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let id = vault.request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());
    assert(id == 0, 'Id not minted');

    assert(
        erc20_dispatcher_vault.balance_of(DUMMY_ADDRESS()) == shares - shares_to_redeem,
        'Shares not burned',
    );

    let expected_shares_fee_recipient = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares = shares_to_redeem - expected_shares_fee_recipient;
    let expected_assets = math::u256_mul_div(
        remaining_shares, deposit_amount * 10 + 1, deposit_amount + 1, Rounding::Floor,
    );

    let expected_redeem_nominal = 2 * Vault::WAD + expected_assets;

    assert(vault.redeem_nominal(epoch) == expected_redeem_nominal, 'Redeem nominal not updated');

    let id_info = redeem_request.id_to_info(id);
    assert(id_info.epoch == epoch, 'Epoch not set correctly');
    assert(id_info.nominal == expected_assets, 'Nominal not set correctly');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id) == OTHER_DUMMY_ADDRESS(), 'Owner not set correctly');

    assert(
        erc20_dispatcher_vault.balance_of(FEES_RECIPIENT()) == expected_shares_fee_recipient,
        'Fees recipient balance',
    );

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemRequested(
                        Vault::RedeemRequested {
                            owner: DUMMY_ADDRESS(),
                            receiver: OTHER_DUMMY_ADDRESS(),
                            shares: shares_to_redeem,
                            assets: expected_assets,
                            id,
                            epoch,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_request_redeem_over_multiple_calls_same_epoch() {
    let (underlying, vault, redeem_request) = set_up();

    let deposit_amount = Vault::WAD * 2;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_a = shares / 3;
    let shares_b = shares / 4;

    let erc20_dispatcher_vault = ERC20ABIDispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc20_dispatcher_vault.approve(OTHER_DUMMY_ADDRESS(), shares_a + shares_b);

    let mut cheat_calldata_buffer = ArrayTrait::new();
    (deposit_amount * 10).serialize(ref cheat_calldata_buffer);
    store(vault.contract_address, selector!("buffer"), cheat_calldata_buffer.span());

    let mut cheat_calldata_epoch = ArrayTrait::new();
    let epoch: u256 = 7;
    epoch.serialize(ref cheat_calldata_epoch);
    store(vault.contract_address, selector!("epoch"), cheat_calldata_epoch.span());

    assert(vault.buffer() == deposit_amount * 10, 'Buffer not updated');
    assert(vault.epoch() == epoch, 'Epoch not updated');

    let mut spy = spy_events();

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let id_a = vault.request_redeem(shares_a, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_shares_fee_recipient_a = shares_a * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_a = shares_a - expected_shares_fee_recipient_a;
    let expected_assets_a = math::u256_mul_div(
        remaining_shares_a, deposit_amount * 10 + 1, deposit_amount + 1, Rounding::Floor,
    );
    assert(vault.redeem_nominal(epoch) == expected_assets_a, 'Redeem nominal 1');
    assert(id_a == 0, 'First NFT id incorrect');
    assert(
        erc20_dispatcher_vault.balance_of(FEES_RECIPIENT()) == expected_shares_fee_recipient_a,
        'fees 1',
    );
    assert(erc20_dispatcher_vault.balance_of(DUMMY_ADDRESS()) == shares - shares_a, 'shares 1');

    let id_info_a = redeem_request.id_to_info(id_a);
    assert(id_info_a.epoch == epoch, 'First epoch not set correctly');
    assert(id_info_a.nominal == expected_assets_a, 'First nominal not set correctly');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id_a) == DUMMY_ADDRESS(), 'First NFT owner incorrect');

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemRequested(
                        Vault::RedeemRequested {
                            owner: DUMMY_ADDRESS(),
                            receiver: DUMMY_ADDRESS(),
                            shares: shares_a,
                            assets: expected_assets_a,
                            id: id_a,
                            epoch,
                        },
                    ),
                ),
            ],
        );

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let id_b = vault.request_redeem(shares_b, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_shares_fee_recipient_b = shares_b * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_b = shares_b - expected_shares_fee_recipient_b;
    let expected_assets_b = math::u256_mul_div(
        remaining_shares_b,
        (deposit_amount * 10 - expected_assets_a) + 1,
        (deposit_amount - remaining_shares_a) + 1,
        Rounding::Floor,
    );

    let expected_redeem_nominal = expected_assets_a + expected_assets_b;

    assert(vault.redeem_nominal(epoch) == expected_redeem_nominal, 'Redeem nominal 2');

    assert(
        erc20_dispatcher_vault.balance_of(FEES_RECIPIENT()) == expected_shares_fee_recipient_a
            + expected_shares_fee_recipient_b,
        'fees 2',
    );
    assert(
        erc20_dispatcher_vault.balance_of(DUMMY_ADDRESS()) == shares - (shares_a + shares_b),
        'shares 1',
    );
    assert(id_b == 1, 'Second NFT id incorrect');
    let id_info_b = redeem_request.id_to_info(id_b);
    assert(id_info_b.epoch == epoch, 'Second epoch not set correctly');
    assert(id_info_b.nominal == expected_assets_b, 'Second nominal not');
    assert(
        erc721_dispatcher.owner_of(id_b) == OTHER_DUMMY_ADDRESS(), 'Second NFT owner
    incorrect',
    );

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemRequested(
                        Vault::RedeemRequested {
                            owner: DUMMY_ADDRESS(),
                            receiver: OTHER_DUMMY_ADDRESS(),
                            shares: shares_b,
                            assets: expected_assets_b,
                            id: id_b,
                            epoch,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_request_redeem_exact_max_ok() {
    let (underlying, vault, redeem_request) = set_up();

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    let total_supply_before = ERC20ABIDispatcher { contract_address: vault.contract_address }
        .total_supply();
    let fees_recipient_balance_before = ERC20ABIDispatcher {
        contract_address: vault.contract_address,
    }
        .balance_of(FEES_RECIPIENT());

    let epoch = vault.epoch();
    let redeem_nominal_before = vault.redeem_nominal(epoch);

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let id = vault.request_redeem(shares, DUMMY_ADDRESS(), OWNER());

    let fee_shares = shares * REDEEM_FEES() / Vault::WAD;
    let remaining_shares = shares - fee_shares;
    let expected_assets = remaining_shares;

    let total_supply_after = ERC20ABIDispatcher { contract_address: vault.contract_address }
        .total_supply();
    let owner_balance_after = ERC20ABIDispatcher { contract_address: vault.contract_address }
        .balance_of(OWNER());
    let fees_recipient_balance_after = ERC20ABIDispatcher {
        contract_address: vault.contract_address,
    }
        .balance_of(FEES_RECIPIENT());

    assert(
        total_supply_after == total_supply_before - (shares - fee_shares),
        'TotalSupply
    incorrect',
    );
    assert(owner_balance_after == 0, 'Owner balance incorrect');
    assert(
        fees_recipient_balance_after == fees_recipient_balance_before + fee_shares,
        'Fees recipient incorrect',
    );
    assert(
        vault.redeem_nominal(epoch) == redeem_nominal_before + expected_assets,
        'Redeem nominal incorrect',
    );
    assert(id == 0, 'NFT id incorrect');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id) == DUMMY_ADDRESS(), 'NFT owner incorrect');

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemRequested(
                        Vault::RedeemRequested {
                            owner: OWNER(),
                            receiver: DUMMY_ADDRESS(),
                            shares,
                            assets: expected_assets,
                            id,
                            epoch,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_request_redeem_fee_exempt_when_owner_is_fees_recipient() {
    let (underlying, vault, redeem_request) = set_up();

    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_fees_config(FEES_RECIPIENT(), REDEEM_FEES(), MANAGEMENT_FEES(), PERFORMANCE_FEES());

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(FEES_RECIPIENT(), deposit_amount);

    cheat_caller_address_once(underlying, FEES_RECIPIENT());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, FEES_RECIPIENT());
    let shares = erc4626_dispatcher.deposit(deposit_amount, FEES_RECIPIENT());

    let total_supply_before = ERC20ABIDispatcher { contract_address: vault.contract_address }
        .total_supply();
    let epoch = vault.epoch();
    let redeem_nominal_before = vault.redeem_nominal(epoch);

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, FEES_RECIPIENT());
    let id = vault.request_redeem(shares, DUMMY_ADDRESS(), FEES_RECIPIENT());

    let expected_assets = shares;
    let total_supply_after = ERC20ABIDispatcher { contract_address: vault.contract_address }
        .total_supply();

    assert(total_supply_after == total_supply_before - shares, 'TotalSupply incorrect');
    assert(
        vault.redeem_nominal(epoch) == redeem_nominal_before + expected_assets,
        'Redeem
    nominal incorrect',
    );
    assert(
        ERC20ABIDispatcher { contract_address: vault.contract_address }
            .balance_of(FEES_RECIPIENT()) == 0,
        'Fees recipient balance',
    );

    let id_info = redeem_request.id_to_info(id);
    assert(id_info.epoch == epoch, 'Epoch not set correctly');
    assert(id_info.nominal == expected_assets, 'Nominal not set correctly');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id) == DUMMY_ADDRESS(), 'Owner not set correctly');

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemRequested(
                        Vault::RedeemRequested {
                            owner: FEES_RECIPIENT(),
                            receiver: DUMMY_ADDRESS(),
                            shares,
                            assets: expected_assets,
                            id,
                            epoch,
                        },
                    ),
                ),
            ],
        );
}
#[test]
fn test_request_redeem_third_party_spender_uses_allowance_and_decreases_it() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    erc20_vault_dispatcher.approve(DUMMY_ADDRESS(), shares);

    let shares_to_redeem = shares / 2;
    let allowance_before = erc20_vault_dispatcher.allowance(OWNER(), DUMMY_ADDRESS());
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    vault.request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), OWNER());
    let allowance_after = erc20_vault_dispatcher.allowance(OWNER(), DUMMY_ADDRESS());
    assert(allowance_after == allowance_before - shares_to_redeem, 'Allowance not decreased');
}

fn test_custom_total_assets_and_shares() {
    let (_, vault, _) = set_up();

    // cheat buffer
    let mut cheat_calldata_buffer = ArrayTrait::new();
    (Vault::WAD * 10).serialize(ref cheat_calldata_buffer);
    store(vault.contract_address, selector!("buffer"), cheat_calldata_buffer.span());
    assert(vault.buffer() == Vault::WAD * 10, 'Buffer not updated');

    // cheat aum
    let mut cheat_calldata_aum = ArrayTrait::new();
    (Vault::WAD * 100).serialize(ref cheat_calldata_aum);
    store(vault.contract_address, selector!("aum"), cheat_calldata_aum.span());
    assert(vault.aum() == Vault::WAD * 100, 'AUM not updated');

    // cheat epoch
    let mut cheat_calldata_epoch = ArrayTrait::new();
    let epoch: u256 = 7;
    epoch.serialize(ref cheat_calldata_epoch);
    store(vault.contract_address, selector!("epoch"), cheat_calldata_epoch.span());
    assert(vault.epoch() == epoch, 'Epoch not updated');

    // cheat handled_epoch_len
    let mut cheat_calldata_handled_epoch_len = ArrayTrait::new();
    (epoch - 1).serialize(ref cheat_calldata_handled_epoch_len);
    store(
        vault.contract_address,
        selector!("handled_epoch_len"),
        cheat_calldata_handled_epoch_len.span(),
    );
    assert(vault.handled_epoch_len() == epoch, 'Handled epoch len not updated');

    // cheat redeem_nominal epoch 6
    let mut cheat_calldata_redeem_nominal = ArrayTrait::new();
    (Vault::WAD * 12).serialize(ref cheat_calldata_redeem_nominal);
    store(
        vault.contract_address,
        map_entry_address(selector!("redeem_nominal"), cheat_calldata_handled_epoch_len.span()),
        cheat_calldata_redeem_nominal.span(),
    );
    assert(vault.redeem_nominal(epoch - 1) == Vault::WAD * 12, 'Redeem nominal not updated');

    // cheat redeem_assets epoch 7
    let mut cheat_calldata_redeem_assets = ArrayTrait::new();
    (Vault::WAD * 15).serialize(ref cheat_calldata_redeem_assets);
    store(
        vault.contract_address,
        map_entry_address(selector!("redeem_assets"), cheat_calldata_epoch.span()),
        cheat_calldata_redeem_assets.span(),
    );
    assert(vault.redeem_assets(epoch) == Vault::WAD * 15, 'Redeem assets not updated');

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    let expected_total_assets = Vault::WAD * 100
        + Vault::WAD * 10
        - (Vault::WAD * 12 + Vault::WAD * 15);
    assert(
        erc4626_dispatcher.total_assets() == expected_total_assets, 'Total assets not
    updated',
    );
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_claim_redeem_when_paused() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();

    vault.claim_redeem(0);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_claim_redeem_when_invalid_id() {
    let (_, vault, _) = set_up();
    vault.claim_redeem(0);
}

#[test]
#[should_panic(expected: "Redeem assets not claimable")]
fn test_claim_redeem_epoch_not_processed() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    cheat_caller_address_once(vault.contract_address, OWNER());
    let id = vault.request_redeem(shares, OWNER(), OWNER());

    vault.claim_redeem(id);
}

#[test]
fn test_claim_redeem_success() {
    let (underlying, vault, _) = set_up();

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    cheat_caller_address_once(vault.contract_address, OWNER());
    let id = vault.request_redeem(shares, OWNER(), OWNER());

    let epoch = vault.epoch();
    let redeem_nominal = vault.redeem_nominal(epoch);

    let mut cheat_calldata_handled_epoch = ArrayTrait::new();
    (epoch + 1).serialize(ref cheat_calldata_handled_epoch);
    store(
        vault.contract_address, selector!("handled_epoch_len"), cheat_calldata_handled_epoch.span(),
    );

    let redeem_assets = redeem_nominal;
    let mut cheat_calldata_redeem_assets = ArrayTrait::new();
    redeem_assets.serialize(ref cheat_calldata_redeem_assets);

    let owner_balance_before = erc20_dispatcher.balance_of(OWNER());

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let assets_received = vault.claim_redeem(id);

    assert(assets_received == redeem_assets, 'Incorrect assets received');
    assert(
        erc20_dispatcher.balance_of(OWNER()) == owner_balance_before + assets_received,
        'Balance not updated',
    );
    assert(vault.redeem_nominal(epoch) == 0, 'Redeem nominal not updated');
    assert(vault.redeem_assets(epoch) == 0, 'Redeem assets not updated');

    let expected_redeem_nominal = shares - (shares * REDEEM_FEES() / Vault::WAD);
    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::RedeemClaimed(
                        Vault::RedeemClaimed {
                            receiver: OWNER(),
                            redeem_request_nominal: expected_redeem_nominal,
                            assets: assets_received,
                            id,
                            epoch,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_claim_redeem_proportional_distribution() {
    let (underlying, vault, redeem_request) = set_up();

    let deposit_amount = Vault::WAD * 2;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.transfer(DUMMY_ADDRESS(), deposit_amount);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(deposit_amount, DUMMY_ADDRESS());

    let shares_to_redeem_1 = shares / 3;
    let shares_to_redeem_2 = shares / 4;

    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc20_vault_dispatcher.approve(OTHER_DUMMY_ADDRESS(), shares_to_redeem_1 + shares_to_redeem_2);

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let id1 = vault.request_redeem(shares_to_redeem_1, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let id2 = vault.request_redeem(shares_to_redeem_2, OTHER_DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let epoch = vault.epoch();
    let redeem_nominal = vault.redeem_nominal(epoch);

    let mut cheat_calldata_handled_epoch = ArrayTrait::new();
    (epoch + 1).serialize(ref cheat_calldata_handled_epoch);
    store(
        vault.contract_address, selector!("handled_epoch_len"), cheat_calldata_handled_epoch.span(),
    );

    let available_assets = redeem_nominal * 9 / 10;
    let mut cheat_calldata_redeem_assets = ArrayTrait::new();
    available_assets.serialize(ref cheat_calldata_redeem_assets);

    let mut cheat_calldata_epoch_key = ArrayTrait::new();
    epoch.serialize(ref cheat_calldata_epoch_key);
    let map_entry = map_entry_address(selector!("redeem_assets"), cheat_calldata_epoch_key.span());
    store(vault.contract_address, map_entry, cheat_calldata_redeem_assets.span());

    let redeem_request_1_info = redeem_request.id_to_info(id1);
    let redeem_request_2_info = redeem_request.id_to_info(id2);

    let expected_assets_1 = (redeem_request_1_info.nominal * available_assets) / redeem_nominal;
    let expected_assets_2 = (redeem_request_2_info.nominal * available_assets) / redeem_nominal;

    let balance_1_before = erc20_dispatcher.balance_of(DUMMY_ADDRESS());
    let balance_2_before = erc20_dispatcher.balance_of(OTHER_DUMMY_ADDRESS());

    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let assets_1 = vault.claim_redeem(id1);

    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let assets_2 = vault.claim_redeem(id2);

    assert(assets_1 == expected_assets_1, 'Incorrect assets 1');
    assert(assets_2 == expected_assets_2, 'Incorrect assets 2');
    assert(
        erc20_dispatcher.balance_of(DUMMY_ADDRESS()) == balance_1_before + assets_1,
        'Balance 1 not updated',
    );
    assert(
        erc20_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == balance_2_before + assets_2,
        'Balance 2 not updated',
    );
    assert(
        vault.redeem_assets(epoch) == available_assets - assets_1 - assets_2,
        'Redeem assets incorrect',
    );
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_claim_redeem_nft_burned() {
    let (underlying, vault, redeem_request) = set_up();

    let deposit_amount = Vault::WAD;
    let erc20_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    erc20_dispatcher.approve(vault.contract_address, deposit_amount);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OWNER());
    let shares = erc4626_dispatcher.deposit(deposit_amount, OWNER());

    cheat_caller_address_once(vault.contract_address, OWNER());
    let id = vault.request_redeem(shares, OWNER(), OWNER());

    let epoch = vault.epoch();
    let redeem_nominal = vault.redeem_nominal(epoch);

    let mut cheat_calldata_handled_epoch = ArrayTrait::new();
    (epoch + 1).serialize(ref cheat_calldata_handled_epoch);
    store(
        vault.contract_address, selector!("handled_epoch_len"), cheat_calldata_handled_epoch.span(),
    );

    let mut cheat_calldata_redeem_assets = ArrayTrait::new();
    redeem_nominal.serialize(ref cheat_calldata_redeem_assets);

    let mut cheat_calldata_epoch_key = ArrayTrait::new();
    epoch.serialize(ref cheat_calldata_epoch_key);
    let map_entry = map_entry_address(selector!("redeem_assets"), cheat_calldata_epoch_key.span());
    store(vault.contract_address, map_entry, cheat_calldata_redeem_assets.span());

    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.claim_redeem(id);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    erc721_dispatcher.owner_of(id);
}

fn test_internal_apply_loss_on_redeems() {
    let address_vault = test_address();
    let mut state = Vault::contract_state_for_testing();

    let loss_amount = 100;
    let base = 1000;

    let handled_epoch_len: u256 = 0;
    let new_epoch: u256 = 1;

    let mut redeem_assets = ArrayTrait::new();
    redeem_assets.append(500);

    let mut i = handled_epoch_len;
    while (i < new_epoch) {
        let elem = *redeem_assets.at(i.try_into().unwrap());
        let mut epoch_entry = ArrayTrait::new();
        i.serialize(ref epoch_entry);

        let mut cheat_store_redeem_assets_at_epoch = ArrayTrait::new();
        elem.serialize(ref cheat_store_redeem_assets_at_epoch);

        store(
            address_vault,
            map_entry_address(selector!("redeem_assets"), epoch_entry.span()),
            cheat_store_redeem_assets_at_epoch.span(),
        );
        assert(state.redeem_assets(i) == elem, 'Redeem assets at epoch');
        i += 1;
    }

    let total_redeem_assets_after_loss = state
        ._apply_loss_on_redeems(loss_amount, base, new_epoch, handled_epoch_len);

    assert(total_redeem_assets_after_loss == 450, 'Total redeem assets after loss');
    assert(state.redeem_assets(0) == 450, 'Redeem assets at epoch 0');
}

#[test]
fn test_internal_apply_loss_on_redeems_multiple_epochs() {
    let address_vault = test_address();
    let mut state = Vault::contract_state_for_testing();

    let loss_amount = 300;
    let base = 2000;

    let handled_epoch_len: u256 = 1;
    let new_epoch: u256 = 4;

    let mut redeem_assets = ArrayTrait::new();
    redeem_assets.append(600); // epoch 1
    redeem_assets.append(800); // epoch 2
    redeem_assets.append(400); // epoch 3

    let mut i = handled_epoch_len;
    while (i < new_epoch) {
        let elem = *redeem_assets.at((i - handled_epoch_len).try_into().unwrap());
        let mut epoch_entry = ArrayTrait::new();
        i.serialize(ref epoch_entry);

        let mut cheat_store_redeem_assets_at_epoch = ArrayTrait::new();
        elem.serialize(ref cheat_store_redeem_assets_at_epoch);

        store(
            address_vault,
            map_entry_address(selector!("redeem_assets"), epoch_entry.span()),
            cheat_store_redeem_assets_at_epoch.span(),
        );
        assert(state.redeem_assets(i) == elem, 'Redeem assets at epoch');
        i += 1;
    }

    let total_redeem_assets_after_loss = state
        ._apply_loss_on_redeems(loss_amount, base, new_epoch, handled_epoch_len);

    // Expected losses:
    // epoch 1: 600 * 300 / 2000 = 90 -> 600 - 90 = 510
    // epoch 2: 800 * 300 / 2000 = 120 -> 800 - 120 = 680
    // epoch 3: 400 * 300 / 2000 = 60 -> 400 - 60 = 340
    // Total: 510 + 680 + 340 = 1530

    assert(total_redeem_assets_after_loss == 1530, 'Total after loss incorrect');
    assert(state.redeem_assets(1) == 510, 'Epoch 1 assets incorrect');
    assert(state.redeem_assets(2) == 680, 'Epoch 2 assets incorrect');
    assert(state.redeem_assets(3) == 340, 'Epoch 3 assets incorrect');
}

#[test]
fn test_internal_apply_loss_on_redeems_rounding_up() {
    let address_vault = test_address();
    let mut state = Vault::contract_state_for_testing();

    let loss_amount = 7;
    let base = 100;

    let handled_epoch_len: u256 = 0;
    let new_epoch: u256 = 3;

    let mut redeem_assets = ArrayTrait::new();
    redeem_assets.append(15); // epoch 0: 15 * 7 / 100 = 1.05 -> rounds up to 2
    redeem_assets.append(20); // epoch 1: 20 * 7 / 100 = 1.4 -> rounds up to 2
    redeem_assets
        .append(50); // epoch 2: 50 * 7 / 100 = 3.5 -> rounds up to 4, but limited by remaining =3

    let mut i = handled_epoch_len;
    while (i < new_epoch) {
        let elem = *redeem_assets.at(i.try_into().unwrap());
        let mut epoch_entry = ArrayTrait::new();
        i.serialize(ref epoch_entry);

        let mut cheat_store_redeem_assets_at_epoch = ArrayTrait::new();
        elem.serialize(ref cheat_store_redeem_assets_at_epoch);

        store(
            address_vault,
            map_entry_address(selector!("redeem_assets"), epoch_entry.span()),
            cheat_store_redeem_assets_at_epoch.span(),
        );
        i += 1;
    }

    let total_redeem_assets_after_loss = state
        ._apply_loss_on_redeems(loss_amount, base, new_epoch, handled_epoch_len);

    // Expected:
    // epoch 0: 15 - 2 = 13 (cut = 2, remaining = 5)
    // epoch 1: 20 - 2 = 18 (cut = 2, remaining = 3)
    // epoch 2: 50 - 3 = 47 (cut = 3, remaining = 0)
    // Total: 13 + 18 + 47 = 78

    assert(total_redeem_assets_after_loss == 78, 'Total rounding test failed');
    assert(state.redeem_assets(0) == 13, 'Epoch 0 rounding incorrect');
    assert(state.redeem_assets(1) == 18, 'Epoch 1 rounding incorrect');
    assert(state.redeem_assets(2) == 47, 'Epoch 2 rounding incorrect');
}

#[test]
fn test_internal_apply_loss_on_redeems_zero_loss() {
    let address_vault = test_address();
    let mut state = Vault::contract_state_for_testing();

    let loss_amount = 0;
    let base = 1000;

    let handled_epoch_len: u256 = 0;
    let new_epoch: u256 = 2;

    let mut redeem_assets = ArrayTrait::new();
    redeem_assets.append(300);
    redeem_assets.append(500);

    let mut i = handled_epoch_len;
    while (i < new_epoch) {
        let elem = *redeem_assets.at(i.try_into().unwrap());
        let mut epoch_entry = ArrayTrait::new();
        i.serialize(ref epoch_entry);

        let mut cheat_store_redeem_assets_at_epoch = ArrayTrait::new();
        elem.serialize(ref cheat_store_redeem_assets_at_epoch);

        store(
            address_vault,
            map_entry_address(selector!("redeem_assets"), epoch_entry.span()),
            cheat_store_redeem_assets_at_epoch.span(),
        );
        i += 1;
    }

    let total_redeem_assets_after_loss = state
        ._apply_loss_on_redeems(loss_amount, base, new_epoch, handled_epoch_len);

    // No loss should be applied
    assert(total_redeem_assets_after_loss == 800, 'Zero loss test failed');
    assert(state.redeem_assets(0) == 300, 'Epoch 0 unchanged');
    assert(state.redeem_assets(1) == 500, 'Epoch 1 unchanged');
}

#[test]
#[should_panic(expected: ('Pausable: paused',))]
fn test_report_when_paused() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.pause();
    vault.report(Vault::WAD);
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_report_when_not_oracle() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    vault.report(Vault::WAD);
}

#[test]
#[should_panic(expected: "Report too early - redeem delay not elapsed")]
fn test_report_too_early() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(Vault::WAD);
}

#[test]
#[should_panic(expected: "Invalid new AUM: 1000000000000000000")]
fn test_report_when_new_aum_is_zero() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    let current_timestamp = get_block_timestamp();

    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(Vault::WAD);
}

#[test]
#[should_panic(expected: "Liquidity is zero")]
fn test_report_when_liquidity_is_zero() {
    let (_, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    let current_timestamp = get_block_timestamp();

    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(Zero::zero());
}

#[test]
#[should_panic(expected: "Vault allocator not set")]
fn test_report_when_vault_allocator_is_not_set() {
    let (underlying, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    let current_timestamp = get_block_timestamp();

    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let er20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    er20_underlying_dispatcher.transfer(DUMMY_ADDRESS(), Vault::WAD);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    er20_underlying_dispatcher.approve(vault.contract_address, Vault::WAD);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(Vault::WAD, DUMMY_ADDRESS());

    let mut cheat_calldata_vault_allocator = ArrayTrait::new();
    cheat_calldata_vault_allocator.append(0);
    store(
        vault.contract_address, selector!("vault_allocator"), cheat_calldata_vault_allocator.span(),
    );
    assert(vault.vault_allocator() == Zero::zero(), 'Vault allocator not set');
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(Zero::zero());
}

#[test]
#[should_panic(expected: "Fees recipient not set")]
fn test_report_when_fees_recipient_is_not_set() {
    let (underlying, vault, _) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    let current_timestamp = get_block_timestamp();

    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let er20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    er20_underlying_dispatcher.transfer(DUMMY_ADDRESS(), Vault::WAD);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    er20_underlying_dispatcher.approve(vault.contract_address, Vault::WAD);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(Vault::WAD, DUMMY_ADDRESS());

    let mut cheat_calldata_fees_recipient = ArrayTrait::new();
    cheat_calldata_fees_recipient.append(0);
    store(
        vault.contract_address, selector!("fees_recipient"), cheat_calldata_fees_recipient.span(),
    );
    assert(vault.fees_recipient() == Zero::zero(), 'Fees recipient not set');
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(Zero::zero());
}

fn check_vault_state(
    vault: IVaultDispatcher,
    expected_epoch: u256,
    expected_handled_epoch_len: u256,
    expected_total_supply: u256,
    expected_aum: u256,
    expected_buffer: u256,
    expected_pending_redeem_nominal_and_redeem_assets: Array<(u256, u256)>,
) {
    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };

    assert(vault.epoch() == expected_epoch, 'Epoch not updated');
    assert(vault.handled_epoch_len() == expected_handled_epoch_len, 'Invalid handled epoch len');
    assert(erc20_vault_dispatcher.total_supply() == expected_total_supply, 'Invalid total supply');

    assert(vault.aum() == expected_aum, 'Invalid aum');
    assert(vault.buffer() == expected_buffer, 'Invalid buffer');

    assert(
        expected_pending_redeem_nominal_and_redeem_assets
            .len()
            .into() == (expected_epoch - expected_handled_epoch_len)
            + 1,
        ' nominal and  assets',
    );

    let mut total_redeem_assets = Zero::zero();
    let mut i = expected_handled_epoch_len;
    while i <= expected_epoch {
        let (nominal, assets) = *expected_pending_redeem_nominal_and_redeem_assets
            .at(i.try_into().unwrap() - expected_handled_epoch_len.try_into().unwrap());
        total_redeem_assets += assets;
        assert(vault.redeem_assets(i) == assets, 'Invalid redeem assets');
        assert(vault.redeem_nominal(i) == nominal, 'Invalid redeem nominal');
        i += 1;
    }

    let expected_total_assets = expected_aum + expected_buffer - total_redeem_assets;
    assert(erc4626_dispatcher.total_assets() == expected_total_assets, 'Invalid total assets');
}

fn setup_report_simple_deposit_epoch_0() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = set_up();
    cheat_caller_address_once(vault.contract_address, OWNER());
    let access_controler_dispatcher = IAccessControlDispatcher {
        contract_address: vault.contract_address,
    };
    access_controler_dispatcher.grant_role(Vault::ORACLE_ROLE, ORACLE());

    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let er20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    cheat_caller_address_once(underlying, OWNER());
    er20_underlying_dispatcher.transfer(DUMMY_ADDRESS(), Vault::WAD);

    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    er20_underlying_dispatcher.approve(vault.contract_address, Vault::WAD);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let shares = erc4626_dispatcher.deposit(Vault::WAD, DUMMY_ADDRESS());

    // Epoch 0, pre-report state
    let mut expected_epoch = 0;
    let mut expected_handled_epoch_len = 0;
    let mut expected_total_supply = shares;
    let mut expected_aum = Zero::zero();
    let mut expected_buffer = Vault::WAD;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 1, post-report state
    let new_aum = Zero::zero();

    let mut expected_management_fees_assets = (Vault::WAD
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());
    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_buffer + expected_aum - (expected_management_fees_assets + 0) + 1,
        Rounding::Floor,
    );

    let performance_fee_shares = 0;
    expected_total_supply = expected_total_supply + management_fee_shares;
    expected_buffer = Zero::zero();
    expected_epoch = 1;
    expected_handled_epoch_len = 1;
    expected_aum = Vault::WAD;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);
    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_aum,
                            management_fee_shares,
                            performance_fee_shares: performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_deposit() {
    setup_report_simple_deposit_epoch_0();
}

fn setup_report_simple_deposit_with_profit_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let er20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };

    let new_assets_to_deposit = 3 * Vault::WAD;

    cheat_caller_address_once(underlying, OWNER());
    er20_underlying_dispatcher.transfer(OTHER_DUMMY_ADDRESS(), new_assets_to_deposit);

    cheat_caller_address_once(underlying, OTHER_DUMMY_ADDRESS());
    er20_underlying_dispatcher.approve(vault.contract_address, new_assets_to_deposit);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let new_shares = erc4626_dispatcher.deposit(new_assets_to_deposit, OTHER_DUMMY_ADDRESS());

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply + new_shares;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = new_assets_to_deposit;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let profit_amount = current_aum / 100;
    let new_aum = current_aum + profit_amount;

    let expected_total_assets = new_aum + expected_buffer;

    let mut expected_management_fees_assets = (expected_total_assets
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());
    let net_profit_after_mgmt = profit_amount - expected_management_fees_assets;
    let expected_performance_fee_assets = PERFORMANCE_FEES() * net_profit_after_mgmt / Vault::WAD;
    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;
    let performance_fee_shares = math::u256_mul_div(
        expected_performance_fee_assets,
        expected_total_supply + 1,
        expected_total_assets - (expected_performance_fee_assets) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + performance_fee_shares;

    expected_buffer = Zero::zero();
    expected_epoch = 2;
    expected_handled_epoch_len = 2;
    expected_aum = new_aum + expected_buffer;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    // Check that Report event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_deposit_with_profit() {
    setup_report_simple_deposit_with_profit_epoch_1();
}

fn setup_report_simple_deposit_with_loss_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    // Dépôt additionnel pour créer du buffer à déployer à l’epoch 2
    let erc20_underlying = ERC20ABIDispatcher { contract_address: underlying };
    let new_assets_to_deposit = 3 * Vault::WAD;

    cheat_caller_address_once(underlying, OWNER());
    erc20_underlying.transfer(OTHER_DUMMY_ADDRESS(), new_assets_to_deposit);

    cheat_caller_address_once(underlying, OTHER_DUMMY_ADDRESS());
    erc20_underlying.approve(vault.contract_address, new_assets_to_deposit);

    let erc4626 = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let new_shares = erc4626.deposit(new_assets_to_deposit, OTHER_DUMMY_ADDRESS());

    // Epoch 1, état pré-report
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply + new_shares;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = new_assets_to_deposit;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, état post-report avec perte
    let current_aum = vault.aum();
    let loss_amount = current_aum / 100; // 1% de perte
    let new_aum = current_aum - loss_amount; // AUM après perte

    let expected_total_assets = new_aum + expected_buffer; // avant déploiement du buffer

    // Management fees sur total_assets (aucun redeem en attente)
    let expected_management_fees_assets = (expected_total_assets
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        (expected_total_assets - (expected_management_fees_assets + 0)) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;

    // Pas de perf fee si pas de profit net
    let performance_fee_shares = 0;

    // Après report: tout le buffer est déployé car aucun redeem en attente
    expected_buffer = Zero::zero();
    expected_epoch = 2;
    expected_handled_epoch_len = 2;
    expected_aum = new_aum + (3 * Vault::WAD); // new_aum + buffer déployé
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_deposit_with_loss() {
    setup_report_simple_deposit_with_loss_epoch_1();
}

fn setup_report_simple_redeem_unhandled_with_profit_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees, Vault::WAD + 1, current_supply + 1, Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = Zero::zero();
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let profit_amount = current_aum / 100;
    let new_aum = current_aum + profit_amount;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_nominal * expected_management_fees_assets / liqudity_after;
    if (expected_nominal * expected_management_fees_assets % liqudity_after).is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_nominal - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;

    let management_fee_assets_for_shareholders = expected_management_fees_assets
        - (expected_nominal - expected_redeem_assets_after_cut_epoch_1);

    let net_profit_after_mgmt = profit_amount - management_fee_assets_for_shareholders;
    let expected_performance_fee_assets = PERFORMANCE_FEES() * net_profit_after_mgmt / Vault::WAD;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;
    let performance_fee_shares = math::u256_mul_div(
        expected_performance_fee_assets,
        expected_total_supply + 1,
        expected_total_assets - (expected_performance_fee_assets) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + performance_fee_shares;

    expected_buffer = Zero::zero();
    expected_epoch = 2;
    expected_handled_epoch_len = 1;
    expected_aum = new_aum + expected_buffer;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((expected_nominal, expected_redeem_assets_after_cut_epoch_1));
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_redeem_unhandled_with_profit() {
    setup_report_simple_redeem_unhandled_with_profit_epoch_1();
}

fn setup_report_simple_redeem_matched_with_profit_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let other_dummy_deposit = 2 * Vault::WAD;

    let erc20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };
    cheat_caller_address_once(underlying, OWNER());
    erc20_underlying_dispatcher.transfer(OTHER_DUMMY_ADDRESS(), other_dummy_deposit);

    cheat_caller_address_once(underlying, OTHER_DUMMY_ADDRESS());
    erc20_underlying_dispatcher.approve(vault.contract_address, other_dummy_deposit);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let new_shares_minted_by_other_dummy = erc4626_dispatcher
        .deposit(other_dummy_deposit, OTHER_DUMMY_ADDRESS());

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees,
        (Vault::WAD + other_dummy_deposit) + 1,
        (current_supply + new_shares_minted_by_other_dummy) + 1,
        Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply
        + new_shares_minted_by_other_dummy
        - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = other_dummy_deposit;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let profit_amount = current_aum / 100;
    let new_aum = current_aum + profit_amount;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_nominal * expected_management_fees_assets / liqudity_after;
    if (expected_nominal * expected_management_fees_assets % liqudity_after).is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_nominal - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;

    let management_fee_assets_for_shareholders = expected_management_fees_assets
        - (expected_nominal - expected_redeem_assets_after_cut_epoch_1);

    let net_profit_after_mgmt = profit_amount - management_fee_assets_for_shareholders;
    let expected_performance_fee_assets = PERFORMANCE_FEES() * net_profit_after_mgmt / Vault::WAD;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;
    let performance_fee_shares = math::u256_mul_div(
        expected_performance_fee_assets,
        expected_total_supply + 1,
        expected_total_assets - (expected_performance_fee_assets) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + performance_fee_shares;

    expected_epoch = 2;
    expected_handled_epoch_len = 2;
    expected_aum = new_aum + expected_buffer - expected_redeem_assets_after_cut_epoch_1;
    expected_buffer = Zero::zero();

    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    assert(
        vault.redeem_assets(1) == expected_redeem_assets_after_cut_epoch_1,
        'Invalid redeem
        assets',
    );

    // Epoch 2, post-rep
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_redeem_matched_with_profit() {
    setup_report_simple_redeem_matched_with_profit_epoch_1();
}

fn setup_report_simple_redeem_handled_with_bring_liquidity_with_profit_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let vault_allocator_refund = Vault::WAD / 2;
    cheat_caller_address_once(underlying, VAULT_ALLOCATOR());
    let erc20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };
    erc20_underlying_dispatcher.approve(vault.contract_address, vault_allocator_refund);

    cheat_caller_address_once(vault.contract_address, VAULT_ALLOCATOR());
    vault.bring_liquidity(vault_allocator_refund);

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees, (Vault::WAD) + 1, (current_supply) + 1, Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD / 2;
    let mut expected_buffer = Vault::WAD / 2;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let profit_amount = current_aum / 100;
    let new_aum = current_aum + profit_amount;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_nominal * expected_management_fees_assets / liqudity_after;
    if (expected_nominal * expected_management_fees_assets % liqudity_after).is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_nominal - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;

    let management_fee_assets_for_shareholders = expected_management_fees_assets
        - (expected_nominal - expected_redeem_assets_after_cut_epoch_1);

    let net_profit_after_mgmt = profit_amount - management_fee_assets_for_shareholders;
    let expected_performance_fee_assets = PERFORMANCE_FEES() * net_profit_after_mgmt / Vault::WAD;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;
    let performance_fee_shares = math::u256_mul_div(
        expected_performance_fee_assets,
        expected_total_supply + 1,
        expected_total_assets - (expected_performance_fee_assets) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + performance_fee_shares;

    expected_epoch = 2;
    expected_handled_epoch_len = 2;
    expected_aum = new_aum + expected_buffer - expected_redeem_assets_after_cut_epoch_1;
    expected_buffer = Zero::zero();

    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    assert(
        vault.redeem_assets(1) == expected_redeem_assets_after_cut_epoch_1,
        'Invalid redeem
        assets',
    );

    // Epoch 2, post-rep
    (underlying, vault, redeem_request)
}

#[test]
fn test_setup_report_simple_redeem_handled_with_bring_liquidity_with_profit_epoch_1() {
    setup_report_simple_redeem_handled_with_bring_liquidity_with_profit_epoch_1();
}

fn setup_report_simple_redeem_not_handled_with_bring_liquidity_with_profit_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let vault_allocator_refund = Vault::WAD / 10;
    cheat_caller_address_once(underlying, VAULT_ALLOCATOR());
    let erc20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };
    erc20_underlying_dispatcher.approve(vault.contract_address, vault_allocator_refund);

    cheat_caller_address_once(vault.contract_address, VAULT_ALLOCATOR());
    vault.bring_liquidity(vault_allocator_refund);

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees, (Vault::WAD) + 1, (current_supply) + 1, Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD - vault_allocator_refund;
    let mut expected_buffer = vault_allocator_refund;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let profit_amount = current_aum / 100;
    let new_aum = current_aum + profit_amount;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_nominal * expected_management_fees_assets / liqudity_after;
    if (expected_nominal * expected_management_fees_assets % liqudity_after).is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_nominal - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;

    let management_fee_assets_for_shareholders = expected_management_fees_assets
        - (expected_nominal - expected_redeem_assets_after_cut_epoch_1);

    let net_profit_after_mgmt = profit_amount - management_fee_assets_for_shareholders;
    let expected_performance_fee_assets = PERFORMANCE_FEES() * net_profit_after_mgmt / Vault::WAD;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;
    let performance_fee_shares = math::u256_mul_div(
        expected_performance_fee_assets,
        expected_total_supply + 1,
        expected_total_assets - (expected_performance_fee_assets) + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + performance_fee_shares;

    expected_epoch = 2;
    expected_handled_epoch_len = 1;
    expected_aum = new_aum;
    expected_buffer = expected_buffer;

    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((expected_nominal, expected_redeem_assets_after_cut_epoch_1));
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares,
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    assert(
        vault.redeem_assets(1) == expected_redeem_assets_after_cut_epoch_1,
        'Invalid redeem
        assets',
    );

    // Epoch 2, post-rep
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_redeem_not_handled_with_bring_liquidity_with_profit() {
    setup_report_simple_redeem_not_handled_with_bring_liquidity_with_profit_epoch_1();
}

fn setup_report_simple_redeem_unhandled_with_loss_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees, Vault::WAD + 1, current_supply + 1, Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = Zero::zero();
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let loss_amount = current_aum / 100;
    let new_aum = current_aum - loss_amount;

    let liquidity_before = current_aum + expected_buffer;
    let mut market_loss_cut = expected_nominal * loss_amount / liquidity_before;
    if (expected_nominal * loss_amount % liquidity_before).is_non_zero() {
        market_loss_cut += 1;
    }
    let expected_redeem_assets_after_market_loss_cut = expected_nominal - market_loss_cut;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_redeem_assets_after_market_loss_cut
        * expected_management_fees_assets
        / liqudity_after;
    if (expected_redeem_assets_after_market_loss_cut
        * expected_management_fees_assets % liqudity_after)
        .is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_redeem_assets_after_market_loss_cut
        - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;
    let expected_performance_fee_assets = 0;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;

    expected_buffer = Zero::zero();
    expected_epoch = 2;
    expected_handled_epoch_len = 1;
    expected_aum = new_aum + expected_buffer;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((expected_nominal, expected_redeem_assets_after_cut_epoch_1));
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares: Zero::zero(),
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
}

#[test]
fn test_report_simple_redeem_unhandled_with_loss() {
    setup_report_simple_redeem_unhandled_with_loss_epoch_1();
}

fn setup_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) = setup_report_simple_deposit_epoch_0();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let current_timestamp = get_block_timestamp();
    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let other_dummy_deposit = Vault::WAD / 8;

    let erc20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };
    cheat_caller_address_once(underlying, OWNER());
    erc20_underlying_dispatcher.transfer(OTHER_DUMMY_ADDRESS(), other_dummy_deposit);

    cheat_caller_address_once(underlying, OTHER_DUMMY_ADDRESS());
    erc20_underlying_dispatcher.approve(vault.contract_address, other_dummy_deposit);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let new_shares_minted_by_other_dummy = erc4626_dispatcher
        .deposit(other_dummy_deposit, OTHER_DUMMY_ADDRESS());

    let shares_to_redeem = Vault::WAD / 4;
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, DUMMY_ADDRESS(), DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees,
        Vault::WAD + other_dummy_deposit + 1,
        current_supply + new_shares_minted_by_other_dummy + 1,
        Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 1, 'Epoch mismatch');

    // Epoch 1, pre-report state
    let mut expected_epoch = 1;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply
        + new_shares_minted_by_other_dummy
        - remaining_shares_after_reem_fees;
    let mut expected_aum = Vault::WAD;
    let mut expected_buffer = other_dummy_deposit;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));
    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 2, post-report state
    let current_aum = vault.aum();
    let loss_amount = current_aum / 100;
    let new_aum = current_aum - loss_amount;

    let liquidity_before = current_aum + expected_buffer;
    let mut market_loss_cut = expected_nominal * loss_amount / liquidity_before;
    if (expected_nominal * loss_amount % liquidity_before).is_non_zero() {
        market_loss_cut += 1;
    }
    let expected_redeem_assets_after_market_loss_cut = expected_nominal - market_loss_cut;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut = expected_redeem_assets_after_market_loss_cut
        * expected_management_fees_assets
        / liqudity_after;
    if (expected_redeem_assets_after_market_loss_cut
        * expected_management_fees_assets % liqudity_after)
        .is_non_zero() {
        cut += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 = expected_redeem_assets_after_market_loss_cut
        - cut;

    let expected_total_assets = liqudity_after - expected_redeem_assets_after_cut_epoch_1;
    let expected_performance_fee_assets = 0;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;

    expected_buffer = expected_buffer;
    expected_epoch = 2;
    expected_handled_epoch_len = 1;
    expected_aum = new_aum;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((expected_nominal, expected_redeem_assets_after_cut_epoch_1));
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares: Zero::zero(),
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
    //
}

#[test]
fn test_report_simple_redeem_unhandled_not_enough_buffer_with_loss() {
    setup_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_1();
}

fn setup_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_2_handled_epoch_1() -> (
    ContractAddress, IVaultDispatcher, IRedeemRequestDispatcher,
) {
    let (underlying, vault, redeem_request) =
        setup_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_1();
    let erc20_vault_dispatcher = ERC20ABIDispatcher { contract_address: vault.contract_address };
    let current_supply = erc20_vault_dispatcher.total_supply();
    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    let current_total_assets = erc4626_dispatcher.total_assets();
    let current_timestamp = get_block_timestamp();
    let current_aum = vault.aum();

    start_cheat_block_timestamp_global(current_timestamp + REPORT_DELAY());

    let current_nominal_epoch_1 = vault.redeem_nominal(1);
    let current_assets_epoch_1 = vault.redeem_assets(1);
    let current_buffer = vault.buffer();

    let other_dummy_deposit = Vault::WAD;

    let erc20_underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying };
    cheat_caller_address_once(underlying, OWNER());
    erc20_underlying_dispatcher.transfer(OTHER_DUMMY_ADDRESS(), other_dummy_deposit);

    cheat_caller_address_once(underlying, OTHER_DUMMY_ADDRESS());
    erc20_underlying_dispatcher.approve(vault.contract_address, other_dummy_deposit);

    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let new_shares_minted_by_other_dummy = erc4626_dispatcher
        .deposit(other_dummy_deposit, OTHER_DUMMY_ADDRESS());

    let shares_to_redeem = new_shares_minted_by_other_dummy;
    cheat_caller_address_once(vault.contract_address, OTHER_DUMMY_ADDRESS());
    let redeem_request_id = vault
        .request_redeem(shares_to_redeem, OTHER_DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS());

    let expected_redeem_fee_shares = shares_to_redeem * REDEEM_FEES() / Vault::WAD;
    let remaining_shares_after_reem_fees = shares_to_redeem - expected_redeem_fee_shares;
    let expected_nominal = math::u256_mul_div(
        remaining_shares_after_reem_fees,
        current_total_assets + other_dummy_deposit + 1,
        current_supply + new_shares_minted_by_other_dummy + 1,
        Rounding::Floor,
    );

    let info = redeem_request.id_to_info(redeem_request_id);
    assert(info.nominal == expected_nominal, 'Nominal mismatch');
    assert(info.epoch == 2, 'Epoch mismatch');

    // Epoch 2, pre-report state
    let mut expected_epoch = 2;
    let mut expected_handled_epoch_len = 1;
    let mut expected_total_supply = current_supply
        + new_shares_minted_by_other_dummy
        - remaining_shares_after_reem_fees;
    let mut expected_aum = current_aum;
    let mut expected_buffer = other_dummy_deposit + current_buffer;
    let mut expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((current_nominal_epoch_1, current_assets_epoch_1));
    expected_redeem_nominal_and_redeem_assets.append((expected_nominal, expected_nominal));

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );

    // Epoch 3, post-report state
    let current_aum = vault.aum();
    let loss_amount = current_aum / 100;
    let new_aum = current_aum - loss_amount;

    let liquidity_before = current_aum + expected_buffer;

    let mut market_loss_cut_epoch_1 = current_assets_epoch_1 * loss_amount / liquidity_before;
    if (current_assets_epoch_1 * loss_amount % liquidity_before).is_non_zero() {
        market_loss_cut_epoch_1 += 1;
    }
    let expected_redeem_assets_after_market_loss_cut_epoch_1 = current_assets_epoch_1
        - market_loss_cut_epoch_1;

    let mut market_loss_cut_epoch_2 = expected_nominal * loss_amount / liquidity_before;
    if (expected_nominal * loss_amount % liquidity_before).is_non_zero() {
        market_loss_cut_epoch_2 += 1;
    }
    let expected_redeem_assets_after_market_loss_cut_epoch_2 = expected_nominal
        - market_loss_cut_epoch_2;

    let liqudity_after = new_aum + expected_buffer;
    let mut expected_management_fees_assets = (liqudity_after
        * MANAGEMENT_FEES()
        * REPORT_DELAY().into())
        / (Vault::WAD * Vault::YEAR.into());

    let mut cut_epoch_1 = expected_redeem_assets_after_market_loss_cut_epoch_1
        * expected_management_fees_assets
        / liqudity_after;
    if (expected_redeem_assets_after_market_loss_cut_epoch_1
        * expected_management_fees_assets % liqudity_after)
        .is_non_zero() {
        cut_epoch_1 += 1;
    }
    let expected_redeem_assets_after_cut_epoch_1 =
        expected_redeem_assets_after_market_loss_cut_epoch_1
        - cut_epoch_1;

    let mut cut_epoch_2 = expected_redeem_assets_after_market_loss_cut_epoch_2
        * expected_management_fees_assets
        / liqudity_after;
    if (expected_redeem_assets_after_market_loss_cut_epoch_2
        * expected_management_fees_assets % liqudity_after)
        .is_non_zero() {
        cut_epoch_2 += 1;
    }
    let expected_redeem_assets_after_cut_epoch_2 =
        expected_redeem_assets_after_market_loss_cut_epoch_2
        - cut_epoch_2;

    let expected_total_assets = liqudity_after
        - (expected_redeem_assets_after_cut_epoch_1 + expected_redeem_assets_after_cut_epoch_2);
    let expected_performance_fee_assets = 0;

    let management_fee_shares = math::u256_mul_div(
        expected_management_fees_assets,
        expected_total_supply + 1,
        expected_total_assets
            - (expected_management_fees_assets + expected_performance_fee_assets)
            + 1,
        Rounding::Floor,
    );
    expected_total_supply = expected_total_supply + management_fee_shares;

    expected_buffer = expected_buffer - expected_redeem_assets_after_cut_epoch_1;
    expected_epoch = 3;
    expected_handled_epoch_len = 2;
    expected_aum = new_aum;
    expected_redeem_nominal_and_redeem_assets = ArrayTrait::new();
    expected_redeem_nominal_and_redeem_assets
        .append((expected_nominal, expected_redeem_assets_after_cut_epoch_2));
    expected_redeem_nominal_and_redeem_assets.append((Zero::zero(), Zero::zero()));

    let mut spy = spy_events();
    cheat_caller_address_once(vault.contract_address, ORACLE());
    vault.report(new_aum);

    spy
        .assert_emitted(
            @array![
                (
                    vault.contract_address,
                    Vault::Event::Report(
                        Vault::Report {
                            new_epoch: expected_epoch,
                            new_handled_epoch_len: expected_handled_epoch_len,
                            total_supply: expected_total_supply,
                            total_assets: expected_total_assets,
                            management_fee_shares,
                            performance_fee_shares: Zero::zero(),
                        },
                    ),
                ),
            ],
        );

    check_vault_state(
        vault,
        expected_epoch,
        expected_handled_epoch_len,
        expected_total_supply,
        expected_aum,
        expected_buffer,
        expected_redeem_nominal_and_redeem_assets,
    );
    (underlying, vault, redeem_request)
}


#[test]
fn test_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_2_handled_epoch_1() {
    setup_report_simple_redeem_unhandled_not_enough_buffer_with_loss_epoch_2_handled_epoch_1();
}

#[test]
fn test_deposit_limit() {
    let (underlying, vault, _) = set_up();
    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };
    let deposit_cap = Vault::WAD * 100;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_deposit_limit(deposit_cap);
    assert(vault.get_deposit_limit() == deposit_cap, 'Deposit limit not set');
    assert(
        erc4626_dispatcher.max_deposit(DUMMY_ADDRESS()) == deposit_cap, 'Initial max deposit wrong',
    );
    let first_deposit = Vault::WAD * 30;
    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }.transfer(DUMMY_ADDRESS(), first_deposit);
    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, first_deposit);
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(first_deposit, DUMMY_ADDRESS());
    let expected_remaining = deposit_cap - first_deposit;
    assert(
        erc4626_dispatcher.max_deposit(DUMMY_ADDRESS()) == expected_remaining,
        'Max deposit not reduced',
    );
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_deposit_limit(Bounded::MAX);
    assert(vault.get_deposit_limit() == Bounded::MAX, 'Unlimited not set');
    assert(
        erc4626_dispatcher.max_deposit(DUMMY_ADDRESS()) == Bounded::MAX,
        'Max deposit not unlimited',
    );
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_deposit_limit_unauthorized() {
    let (_, vault, _) = set_up();

    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    vault.set_deposit_limit(Vault::WAD);
}


#[test]
fn test_deposit_with_limit() {
    let (underlying, vault, _) = set_up();
    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };

    let deposit_limit = Vault::WAD;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_deposit_limit(deposit_limit);

    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }.transfer(DUMMY_ADDRESS(), Vault::WAD * 2);
    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, Vault::WAD * 2);

    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(deposit_limit, DUMMY_ADDRESS());

    assert(
        ERC20ABIDispatcher { contract_address: vault.contract_address }
            .balance_of(DUMMY_ADDRESS()) > 0,
        'Deposit failed',
    );
}

#[test]
#[should_panic(expected: 'ERC4626: exceeds max deposit')]
fn test_deposit_exceeds_limit() {
    let (underlying, vault, _) = set_up();
    let erc4626_dispatcher = IERC4626Dispatcher { contract_address: vault.contract_address };

    let deposit_limit = Vault::WAD;
    cheat_caller_address_once(vault.contract_address, OWNER());
    vault.set_deposit_limit(deposit_limit);

    cheat_caller_address_once(underlying, OWNER());
    ERC20ABIDispatcher { contract_address: underlying }.transfer(DUMMY_ADDRESS(), Vault::WAD * 2);
    cheat_caller_address_once(underlying, DUMMY_ADDRESS());
    ERC20ABIDispatcher { contract_address: underlying }
        .approve(vault.contract_address, Vault::WAD * 2);

    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    erc4626_dispatcher.deposit(deposit_limit + 1, DUMMY_ADDRESS());
}

#[test]
#[should_panic(expected: "Caller is not the vault allocator")]
fn test_bring_liquidity_unauthorized() {
    let (_underlying, vault, _) = set_up();

    // Try to call bring_liquidity from unauthorized address
    cheat_caller_address_once(vault.contract_address, DUMMY_ADDRESS());
    vault.bring_liquidity(1000);
}
