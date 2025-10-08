// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::accesscontrol::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::interfaces::upgrades::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use starknet::ContractAddress;
use vault::redeem_request::interface::{
    IRedeemRequestDispatcher, IRedeemRequestDispatcherTrait, RedeemRequestInfo,
};
use vault::test::utils::{
    DUMMY_ADDRESS, OTHER_DUMMY_ADDRESS, OWNER, cheat_caller_address_once, deploy_counter,
    deploy_erc20_mock, deploy_erc721_receiver_at, deploy_redeem_request, deploy_vault,
};
use vault::vault::vault::Vault;
use vault_allocator::mocks::counter::{ICounterDispatcher, ICounterDispatcherTrait};

fn set_up() -> (ContractAddress, IRedeemRequestDispatcher) {
    let underlying_assets = deploy_erc20_mock();
    let vault = deploy_vault(underlying_assets);
    let redeem_request = deploy_redeem_request(vault.contract_address);
    deploy_erc721_receiver_at(DUMMY_ADDRESS());
    deploy_erc721_receiver_at(OTHER_DUMMY_ADDRESS());
    (vault.contract_address, redeem_request)
}

#[test]
fn test_constructor() {
    let (vault_address, redeem_request) = set_up();

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };

    assert(erc721_dispatcher.name() == "redeem_request", 'Name incorrect');
    assert(erc721_dispatcher.symbol() == "rr", 'Symbol incorrect');
    assert(redeem_request.vault() == vault_address, 'Vault address incorrect');
    assert(redeem_request.id_len() == 0, 'Initial ID length should be 0');
}

#[test]
fn test_vault_getter() {
    let (vault_address, redeem_request) = set_up();
    assert(redeem_request.vault() == vault_address, 'Vault getter incorrect');
}

#[test]
fn test_id_len_initial_value() {
    let (_, redeem_request) = set_up();
    assert(redeem_request.id_len() == 0, 'Initial ID length should be 0');
}

#[test]
fn test_id_to_info_nonexistent() {
    let (_, redeem_request) = set_up();
    let info = redeem_request.id_to_info(0);
    assert(info.epoch == 0, 'Non-existent epoch ');
    assert(info.nominal == 0, 'Non-existent nominal ');
}

#[test]
#[should_panic(expected: "Caller is not vault")]
fn test_mint_not_vault() {
    let (_, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 1, nominal: 100 };
    redeem_request.mint(DUMMY_ADDRESS(), redeem_info);
}

#[test]
fn test_mint_success() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 5, nominal: 1000 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    assert(id == 0, 'First ID should be 0');
    assert(redeem_request.id_len() == 1, 'ID length should be 1');

    let info = redeem_request.id_to_info(id);
    assert(info.epoch == 5, 'Epoch should be 5');
    assert(info.nominal == 1000, 'Nominal should be 1000');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id) == DUMMY_ADDRESS(), 'Owner incorrect');
    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 1, 'Balance should be 1');
}

#[test]
fn test_mint_multiple() {
    let (vault_address, redeem_request) = set_up();

    let redeem_info_1 = RedeemRequestInfo { epoch: 1, nominal: 100 };
    let redeem_info_2 = RedeemRequestInfo { epoch: 2, nominal: 200 };
    let redeem_info_3 = RedeemRequestInfo { epoch: 3, nominal: 300 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_1 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_1);

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_2 = redeem_request.mint(OTHER_DUMMY_ADDRESS(), redeem_info_2);

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_3 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_3);

    assert(id_1 == 0, 'First ID should be 0');
    assert(id_2 == 1, 'Second ID should be 1');
    assert(id_3 == 2, 'Third ID should be 2');
    assert(redeem_request.id_len() == 3, 'ID length should be 3');

    let info_1 = redeem_request.id_to_info(id_1);
    let info_2 = redeem_request.id_to_info(id_2);
    let info_3 = redeem_request.id_to_info(id_3);

    assert(info_1.epoch == 1 && info_1.nominal == 100, 'Info 1 incorrect');
    assert(info_2.epoch == 2 && info_2.nominal == 200, 'Info 2 incorrect');
    assert(info_3.epoch == 3 && info_3.nominal == 300, 'Info 3 incorrect');

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.owner_of(id_1) == DUMMY_ADDRESS(), 'Owner 1 incorrect');
    assert(erc721_dispatcher.owner_of(id_2) == OTHER_DUMMY_ADDRESS(), 'Owner 2 incorrect');
    assert(erc721_dispatcher.owner_of(id_3) == DUMMY_ADDRESS(), 'Owner 3 incorrect');

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 2, 'Dummy balance incorrect');
    assert(
        erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'Other dummy balance incorrect',
    );
}

#[test]
#[should_panic(expected: "Caller is not vault")]
fn test_burn_not_vault() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 1, nominal: 100 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    redeem_request.burn(id);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_burn_nonexistent_token() {
    let (vault_address, redeem_request) = set_up();
    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    redeem_request.burn(999);
}

#[test]
fn test_burn_success() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 5, nominal: 1000 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };
    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 1, 'Balance should be 1 before burn');

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    redeem_request.burn(id);

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 0, 'Balance should be 0 after burn');
    assert(redeem_request.id_len() == 1, 'ID length should remain 1');

    let info = redeem_request.id_to_info(id);
    assert(info.epoch == 5, 'Info should remain after burn');
    assert(info.nominal == 1000, 'should remain after burn');
}

#[test]
fn test_burn_one_of_multiple() {
    let (vault_address, redeem_request) = set_up();

    let redeem_info_1 = RedeemRequestInfo { epoch: 1, nominal: 100 };
    let redeem_info_2 = RedeemRequestInfo { epoch: 2, nominal: 200 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_1 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_1);

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_2 = redeem_request.mint(OTHER_DUMMY_ADDRESS(), redeem_info_2);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 1, 'Dummy balance before burn');
    assert(
        erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'Other dummy balance before burn',
    );

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    redeem_request.burn(id_1);

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 0, 'Dummy balance after burn');
    assert(
        erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'Other dummy balance after burn',
    );
    assert(erc721_dispatcher.owner_of(id_2) == OTHER_DUMMY_ADDRESS(), 'ID 2 owner should remain');
}

#[test]
#[should_panic(expected: "Caller is not vault owner")]
fn test_upgrade_not_vault_owner() {
    let (_, redeem_request) = set_up();
    let (_, counter_class_hash) = deploy_counter();

    IUpgradeableDispatcher { contract_address: redeem_request.contract_address }
        .upgrade(counter_class_hash);
}

#[test]
fn test_upgrade_success() {
    let (_, redeem_request) = set_up();
    let (_, counter_class_hash) = deploy_counter();

    cheat_caller_address_once(redeem_request.contract_address, OWNER());
    IUpgradeableDispatcher { contract_address: redeem_request.contract_address }
        .upgrade(counter_class_hash);

    ICounterDispatcher { contract_address: redeem_request.contract_address }.get_value();
}

#[test]
fn test_upgrade_with_vault_owner() {
    let (vault_address, redeem_request) = set_up();
    let (_, counter_class_hash) = deploy_counter();

    let vault_access_control = IAccessControlDispatcher { contract_address: vault_address };

    cheat_caller_address_once(vault_address, OWNER());
    vault_access_control.grant_role(Vault::OWNER_ROLE, DUMMY_ADDRESS());

    cheat_caller_address_once(redeem_request.contract_address, DUMMY_ADDRESS());
    IUpgradeableDispatcher { contract_address: redeem_request.contract_address }
        .upgrade(counter_class_hash);

    ICounterDispatcher { contract_address: redeem_request.contract_address }.get_value();
}

#[test]
fn test_erc721_functionality() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 5, nominal: 1000 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };

    assert(erc721_dispatcher.owner_of(id) == DUMMY_ADDRESS(), 'Owner incorrect');
    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 1, 'Balance incorrect');

    cheat_caller_address_once(redeem_request.contract_address, DUMMY_ADDRESS());
    erc721_dispatcher.approve(OTHER_DUMMY_ADDRESS(), id);
    assert(erc721_dispatcher.get_approved(id) == OTHER_DUMMY_ADDRESS(), 'Approved incorrect');

    cheat_caller_address_once(redeem_request.contract_address, OTHER_DUMMY_ADDRESS());
    erc721_dispatcher
        .safe_transfer_from(DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS(), id, array![].span());

    assert(erc721_dispatcher.owner_of(id) == OTHER_DUMMY_ADDRESS(), 'Owner after transfer');
    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 0, 'Balance after transfer');
    assert(erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'New owner balance');
}

#[test]
fn test_set_approval_for_all() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info_1 = RedeemRequestInfo { epoch: 1, nominal: 100 };
    let redeem_info_2 = RedeemRequestInfo { epoch: 2, nominal: 200 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_1 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_1);

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_2 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_2);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };

    cheat_caller_address_once(redeem_request.contract_address, DUMMY_ADDRESS());
    erc721_dispatcher.set_approval_for_all(OTHER_DUMMY_ADDRESS(), true);

    assert(
        erc721_dispatcher.is_approved_for_all(DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS()),
        'Approval for all not set',
    );

    cheat_caller_address_once(redeem_request.contract_address, OTHER_DUMMY_ADDRESS());
    erc721_dispatcher
        .safe_transfer_from(DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS(), id_1, array![].span());

    cheat_caller_address_once(redeem_request.contract_address, OTHER_DUMMY_ADDRESS());
    erc721_dispatcher
        .safe_transfer_from(DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS(), id_2, array![].span());

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 0, 'Original owner balance');
    assert(erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 2, 'New owner balance');
}

#[test]
fn test_complex_scenario_mint_burn_transfer() {
    let (vault_address, redeem_request) = set_up();

    let redeem_info_1 = RedeemRequestInfo { epoch: 10, nominal: 500 };
    let redeem_info_2 = RedeemRequestInfo { epoch: 11, nominal: 750 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_1 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_1);

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id_2 = redeem_request.mint(DUMMY_ADDRESS(), redeem_info_2);

    let erc721_dispatcher = ERC721ABIDispatcher {
        contract_address: redeem_request.contract_address,
    };

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 2, 'Initial balance');
    assert(redeem_request.id_len() == 2, 'Initial ID length');

    cheat_caller_address_once(redeem_request.contract_address, DUMMY_ADDRESS());
    erc721_dispatcher
        .safe_transfer_from(DUMMY_ADDRESS(), OTHER_DUMMY_ADDRESS(), id_1, array![].span());

    assert(erc721_dispatcher.owner_of(id_1) == OTHER_DUMMY_ADDRESS(), 'ID 1 new owner');
    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 1, 'Balance after transfer');
    assert(erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'New owner balance');

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    redeem_request.burn(id_2);

    assert(erc721_dispatcher.balance_of(DUMMY_ADDRESS()) == 0, 'Balance after burn');
    assert(erc721_dispatcher.balance_of(OTHER_DUMMY_ADDRESS()) == 1, 'Other balance after burn');

    let info_1 = redeem_request.id_to_info(id_1);
    let info_2 = redeem_request.id_to_info(id_2);
    assert(info_1.epoch == 10 && info_1.nominal == 500, 'Info 1 preserved');
    assert(info_2.epoch == 11 && info_2.nominal == 750, 'Info 2 preserved');
    assert(redeem_request.id_len() == 2, 'ID length preserved');
}

#[test]
fn test_edge_case_zero_values() {
    let (vault_address, redeem_request) = set_up();
    let redeem_info = RedeemRequestInfo { epoch: 0, nominal: 0 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    let info = redeem_request.id_to_info(id);
    assert(info.epoch == 0, 'Zero epoch should work');
    assert(info.nominal == 0, 'Zero nominal should work');
}

#[test]
fn test_edge_case_max_values() {
    let (vault_address, redeem_request) = set_up();
    let max_u256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    let redeem_info = RedeemRequestInfo { epoch: max_u256, nominal: max_u256 };

    cheat_caller_address_once(redeem_request.contract_address, vault_address);
    let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

    let info = redeem_request.id_to_info(id);
    assert(info.epoch == max_u256, 'Max epoch should work');
    assert(info.nominal == max_u256, 'Max nominal should work');
}

#[test]
fn test_sequential_id_generation() {
    let (vault_address, redeem_request) = set_up();

    let mut expected_id = 0;
    let mut i = 0;
    while i < 10 {
        let redeem_info = RedeemRequestInfo { epoch: i, nominal: i * 100 };
        cheat_caller_address_once(redeem_request.contract_address, vault_address);
        let id = redeem_request.mint(DUMMY_ADDRESS(), redeem_info);

        assert(id == expected_id, 'Sequential ID incorrect');
        expected_id += 1;
        i += 1;
    }

    assert(redeem_request.id_len() == 10, 'Final ID length incorrect');

    let info_5 = redeem_request.id_to_info(5);
    assert(info_5.epoch == 5 && info_5.nominal == 500, 'Info 5 incorrect');
}
