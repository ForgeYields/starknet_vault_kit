// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _get_proofs_using_tree, _pad_leafs_to_power_of_two, generate_merkle_tree,
};
use vault_allocator::merkle_tree::integrations::near_intents::{
    NEAR_INTENTS_RECIPIENT, NEAR_INTENTS_TOKEN_FEE, NearIntentsConfig, _add_near_intents_leafs,
};
use vault_allocator::merkle_tree::registery::{NEAR_OMNI_BRIDGE, STRK};
use vault_allocator::test::utils::{
    OWNER, STRATEGIST, WAD, cheat_caller_address_once, deploy_manager, deploy_vault_allocator,
    set_token_balance,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};

const LEAF_APPROVE: u32 = 0;
const LEAF_INIT_TRANSFER: u32 = 1;
const INITIAL_STRK_BALANCE: u256 = 1_000 * WAD;
const DEPOSIT_AMOUNT: u128 = 100_000_000_000_000_000_000; // 100 STRK
const NATIVE_FEE: u128 = 300_000_000_000_000_000; // 0.3 STRK

fn INTENTS_ACCOUNT() -> ByteArray {
    "forge-yields.near"
}

// ============ Dedicated Decoder and Sanitizer for NEAR Intents ============
#[starknet::contract]
pub mod NearIntentsTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::near_intents_decoder_and_sanitizer::near_intents_decoder_and_sanitizer::NearIntentsDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );
    component!(
        path: NearIntentsDecoderAndSanitizerComponent,
        storage: near_intents_decoder_and_sanitizer,
        event: NearIntentsDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl NearIntentsDecoderAndSanitizerImpl =
        NearIntentsDecoderAndSanitizerComponent::NearIntentsDecoderAndSanitizerImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub near_intents_decoder_and_sanitizer: NearIntentsDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        NearIntentsDecoderAndSanitizerEvent: NearIntentsDecoderAndSanitizerComponent::Event,
    }
}
// ===========================================================================

#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

#[derive(Drop)]
struct InitTransferParams {
    amount: u128,
    fee: u128,
    native_fee: u128,
    recipient: ByteArray,
    message: ByteArray,
}

fn setup() -> TestSetup {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let decoder = declare("NearIntentsTestDecoderAndSanitizer").unwrap().contract_class();
    let (decoder_and_sanitizer, _) = decoder.deploy(@ArrayTrait::new()).unwrap();
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;
    _add_near_intents_leafs(
        ref leafs,
        ref leaf_index,
        decoder_and_sanitizer,
        array![
            NearIntentsConfig {
                omni_bridge: NEAR_OMNI_BRIDGE(), token: STRK(), intents_account: INTENTS_ACCOUNT(),
            },
        ]
            .span(),
    );
    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);
    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);
    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), root);
    set_token_balance(STRK(), vault_allocator.contract_address, INITIAL_STRK_BALANCE);
    TestSetup { vault_allocator, manager, decoder_and_sanitizer, leafs, tree }
}

fn build_default_params() -> InitTransferParams {
    InitTransferParams {
        amount: DEPOSIT_AMOUNT,
        fee: NEAR_INTENTS_TOKEN_FEE,
        native_fee: NATIVE_FEE,
        recipient: NEAR_INTENTS_RECIPIENT(),
        message: INTENTS_ACCOUNT(),
    }
}

fn execute_deposit(setup: @TestSetup, params: InitTransferParams) {
    let mut calldata_approve: Array<felt252> = ArrayTrait::new();
    NEAR_OMNI_BRIDGE().serialize(ref calldata_approve);
    let approve_amount: u256 = (params.amount + params.native_fee).into();
    approve_amount.serialize(ref calldata_approve);
    let mut calldata_init_transfer: Array<felt252> = ArrayTrait::new();
    STRK().serialize(ref calldata_init_transfer);
    params.amount.serialize(ref calldata_init_transfer);
    params.fee.serialize(ref calldata_init_transfer);
    params.native_fee.serialize(ref calldata_init_transfer);
    params.recipient.serialize(ref calldata_init_transfer);
    params.message.serialize(ref calldata_init_transfer);
    let manage_leafs: Array<ManageLeaf> = array![
        setup.leafs.at(LEAF_APPROVE).clone(), setup.leafs.at(LEAF_INIT_TRANSFER).clone(),
    ];
    let proofs = _get_proofs_using_tree(manage_leafs, setup.tree.clone());
    cheat_caller_address_once(*setup.manager.contract_address, STRATEGIST());
    (*setup.manager)
        .manage_vault_with_merkle_verification(
            proofs.span(),
            array![*setup.decoder_and_sanitizer, *setup.decoder_and_sanitizer].span(),
            array![STRK(), NEAR_OMNI_BRIDGE()].span(),
            array![selector!("approve"), selector!("init_transfer")].span(),
            array![calldata_approve.span(), calldata_init_transfer.span()].span(),
        );
}

#[fork("NEAR_INTENTS")]
#[test]
fn test_near_intents_deposit_strk() {
    let setup = setup();
    let strk = ERC20ABIDispatcher { contract_address: STRK() };
    let bridge_balance_before = strk.balance_of(NEAR_OMNI_BRIDGE());
    execute_deposit(@setup, build_default_params());
    let expected_spent: u256 = (DEPOSIT_AMOUNT + NATIVE_FEE).into();
    let actual_balance = strk.balance_of(setup.vault_allocator.contract_address);
    let actual_bridge_received = strk.balance_of(NEAR_OMNI_BRIDGE()) - bridge_balance_before;
    assert(actual_balance == INITIAL_STRK_BALANCE - expected_spent, 'strk balance incorrect');
    assert(actual_bridge_received == expected_spent, 'bridge balance incorrect');
}

#[fork("NEAR_INTENTS")]
#[test]
#[should_panic]
fn test_near_intents_deposit_to_other_account_fails() {
    let setup = setup();
    let mut params = build_default_params();
    params.message = "attacker.near";
    execute_deposit(@setup, params);
}

#[fork("NEAR_INTENTS")]
#[test]
#[should_panic]
fn test_near_intents_deposit_to_other_recipient_fails() {
    let setup = setup();
    let mut params = build_default_params();
    params.recipient = "near:attacker.near";
    execute_deposit(@setup, params);
}

#[fork("NEAR_INTENTS")]
#[test]
#[should_panic]
fn test_near_intents_deposit_with_token_fee_fails() {
    let setup = setup();
    let mut params = build_default_params();
    params.fee = 1;
    execute_deposit(@setup, params);
}
