// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::interfaces::erc721::{IERC721Dispatcher, IERC721DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
};
use starknet::{ContractAddress, get_block_timestamp};
use vault_allocator::integration_interfaces::endur::{
    EndurWithdrawRequest, IEndurLstDispatcher, IEndurLstDispatcherTrait,
    IEndurWithdrawQueueDispatcher, IEndurWithdrawQueueDispatcherTrait,
};
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _get_proofs_using_tree, _pad_leafs_to_power_of_two, generate_merkle_tree,
};
use vault_allocator::merkle_tree::integrations::endur::_add_endur_leafs;
use vault_allocator::merkle_tree::registery::{ENDUR_XSTRK, STRK};
use vault_allocator::test::utils::{
    DUMMY_ADDRESS, OWNER, STRATEGIST, WAD, cheat_caller_address_once, deploy_manager,
    deploy_vault_allocator, set_token_balance,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};

const LEAF_APPROVE: u32 = 0;
const LEAF_DEPOSIT: u32 = 1;
const LEAF_DEPOSIT_WITH_REFERRAL: u32 = 2;
const LEAF_WITHDRAW: u32 = 3;
const LEAF_REDEEM: u32 = 4;
const LEAF_CLAIM_WITHDRAWAL: u32 = 5;
const INITIAL_STRK_BALANCE: u256 = 1_000 * WAD;
const DEPOSIT_AMOUNT: u256 = 100 * WAD;
const CLAIM_DELAY: u64 = 30 * 86_400;

// ============ Dedicated Decoder and Sanitizer for Endur ============
#[starknet::contract]
pub mod EndurTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::endur_decoder_and_sanitizer::endur_decoder_and_sanitizer::EndurDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );
    component!(
        path: Erc4626DecoderAndSanitizerComponent,
        storage: erc4626_decoder_and_sanitizer,
        event: Erc4626DecoderAndSanitizerEvent,
    );
    component!(
        path: EndurDecoderAndSanitizerComponent,
        storage: endur_decoder_and_sanitizer,
        event: EndurDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl Erc4626DecoderAndSanitizerImpl =
        Erc4626DecoderAndSanitizerComponent::Erc4626DecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl EndurDecoderAndSanitizerImpl =
        EndurDecoderAndSanitizerComponent::EndurDecoderAndSanitizerImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub erc4626_decoder_and_sanitizer: Erc4626DecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub endur_decoder_and_sanitizer: EndurDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        Erc4626DecoderAndSanitizerEvent: Erc4626DecoderAndSanitizerComponent::Event,
        #[flat]
        EndurDecoderAndSanitizerEvent: EndurDecoderAndSanitizerComponent::Event,
    }
}
// ====================================================================

#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    withdraw_queue: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

#[derive(Drop)]
struct ManageCall {
    leaf: u32,
    target: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>,
}

fn setup() -> TestSetup {
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);
    let decoder = declare("EndurTestDecoderAndSanitizer").unwrap().contract_class();
    let (decoder_and_sanitizer, _) = decoder.deploy(@ArrayTrait::new()).unwrap();
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;
    _add_endur_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator.contract_address,
        decoder_and_sanitizer,
        ENDUR_XSTRK(),
    );
    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);
    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);
    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), root);
    set_token_balance(STRK(), vault_allocator.contract_address, INITIAL_STRK_BALANCE);
    let withdraw_queue = IEndurLstDispatcher { contract_address: ENDUR_XSTRK() }
        .get_config()
        .withdraw_queue;
    TestSetup { vault_allocator, manager, decoder_and_sanitizer, withdraw_queue, leafs, tree }
}

fn execute_manage_calls(setup: @TestSetup, calls: Array<ManageCall>) {
    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut decoders_and_sanitizers = ArrayTrait::new();
    let mut targets = ArrayTrait::new();
    let mut selectors = ArrayTrait::new();
    let mut calldatas = ArrayTrait::new();
    for call in calls {
        manage_leafs.append(setup.leafs.at(call.leaf).clone());
        decoders_and_sanitizers.append(*setup.decoder_and_sanitizer);
        targets.append(call.target);
        selectors.append(call.selector);
        calldatas.append(call.calldata.span());
    }
    let proofs = _get_proofs_using_tree(manage_leafs, setup.tree.clone());
    cheat_caller_address_once(*setup.manager.contract_address, STRATEGIST());
    (*setup.manager)
        .manage_vault_with_merkle_verification(
            proofs.span(),
            decoders_and_sanitizers.span(),
            targets.span(),
            selectors.span(),
            calldatas.span(),
        );
}

fn build_approve_call(amount: u256) -> ManageCall {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    ENDUR_XSTRK().serialize(ref calldata);
    amount.serialize(ref calldata);
    ManageCall { leaf: LEAF_APPROVE, target: STRK(), selector: selector!("approve"), calldata }
}

fn build_deposit_call(amount: u256, receiver: ContractAddress) -> ManageCall {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    amount.serialize(ref calldata);
    receiver.serialize(ref calldata);
    ManageCall {
        leaf: LEAF_DEPOSIT, target: ENDUR_XSTRK(), selector: selector!("deposit"), calldata,
    }
}

fn build_exit_call(
    leaf: u32, selector: felt252, amount: u256, receiver: ContractAddress,
) -> ManageCall {
    let mut calldata: Array<felt252> = ArrayTrait::new();
    amount.serialize(ref calldata);
    receiver.serialize(ref calldata);
    receiver.serialize(ref calldata);
    ManageCall { leaf, target: ENDUR_XSTRK(), selector, calldata }
}

fn deposit_strk(setup: @TestSetup) -> u256 {
    let receiver = *setup.vault_allocator.contract_address;
    execute_manage_calls(
        setup, array![build_approve_call(DEPOSIT_AMOUNT), build_deposit_call(DEPOSIT_AMOUNT, receiver)],
    );
    ERC20ABIDispatcher { contract_address: ENDUR_XSTRK() }.balance_of(receiver)
}

fn get_last_request(setup: @TestSetup) -> (u128, EndurWithdrawRequest) {
    let queue = IEndurWithdrawQueueDispatcher { contract_address: *setup.withdraw_queue };
    let request_id = queue.get_queue_state().max_request_id;
    (request_id, queue.get_request_info(request_id))
}

#[fork("ENDUR")]
#[test]
fn test_endur_deposit() {
    let setup = setup();
    let shares = deposit_strk(@setup);
    let strk_balance = ERC20ABIDispatcher { contract_address: STRK() }
        .balance_of(setup.vault_allocator.contract_address);
    assert(shares > 0, 'no shares minted');
    assert(strk_balance == INITIAL_STRK_BALANCE - DEPOSIT_AMOUNT, 'strk balance incorrect');
}

#[fork("ENDUR")]
#[test]
fn test_endur_deposit_with_referral() {
    let setup = setup();
    let receiver = setup.vault_allocator.contract_address;
    let referral: ByteArray = "FORGE";
    let mut calldata: Array<felt252> = ArrayTrait::new();
    DEPOSIT_AMOUNT.serialize(ref calldata);
    receiver.serialize(ref calldata);
    referral.serialize(ref calldata);
    let deposit_call = ManageCall {
        leaf: LEAF_DEPOSIT_WITH_REFERRAL,
        target: ENDUR_XSTRK(),
        selector: selector!("deposit_with_referral"),
        calldata,
    };
    execute_manage_calls(@setup, array![build_approve_call(DEPOSIT_AMOUNT), deposit_call]);
    let shares = ERC20ABIDispatcher { contract_address: ENDUR_XSTRK() }.balance_of(receiver);
    assert(shares > 0, 'no shares minted');
}

#[fork("ENDUR")]
#[test]
fn test_endur_redeem_mints_request_to_vault_allocator() {
    let setup = setup();
    let receiver = setup.vault_allocator.contract_address;
    let shares = deposit_strk(@setup);
    execute_manage_calls(
        @setup, array![build_exit_call(LEAF_REDEEM, selector!("redeem"), shares, receiver)],
    );
    let (request_id, request) = get_last_request(@setup);
    let request_owner = IERC721Dispatcher { contract_address: setup.withdraw_queue }
        .owner_of(request_id.into());
    let remaining_shares = ERC20ABIDispatcher { contract_address: ENDUR_XSTRK() }
        .balance_of(receiver);
    assert(request_owner == receiver, 'request owner incorrect');
    assert(request.shares == shares, 'request shares incorrect');
    assert(remaining_shares == 0, 'shares not burned');
}

#[fork("ENDUR")]
#[test]
fn test_endur_withdraw_mints_request_to_vault_allocator() {
    let setup = setup();
    let receiver = setup.vault_allocator.contract_address;
    deposit_strk(@setup);
    let assets: u256 = DEPOSIT_AMOUNT / 2;
    execute_manage_calls(
        @setup, array![build_exit_call(LEAF_WITHDRAW, selector!("withdraw"), assets, receiver)],
    );
    let (request_id, request) = get_last_request(@setup);
    let request_owner = IERC721Dispatcher { contract_address: setup.withdraw_queue }
        .owner_of(request_id.into());
    assert(request_owner == receiver, 'request owner incorrect');
    assert(request.assets == assets, 'request assets incorrect');
}

#[fork("ENDUR")]
#[test]
fn test_endur_claim_withdrawal() {
    let setup = setup();
    let receiver = setup.vault_allocator.contract_address;
    let shares = deposit_strk(@setup);
    execute_manage_calls(
        @setup, array![build_exit_call(LEAF_REDEEM, selector!("redeem"), shares, receiver)],
    );
    let (request_id, request) = get_last_request(@setup);
    let strk = ERC20ABIDispatcher { contract_address: STRK() };
    let balance_before = strk.balance_of(receiver);
    // Simulate the queue being funded past our request and the unstake delay elapsing
    set_token_balance(
        STRK(), setup.withdraw_queue, request.cumulative_requested_amount_snapshot + request.assets,
    );
    start_cheat_block_timestamp_global(get_block_timestamp() + CLAIM_DELAY);
    let mut calldata: Array<felt252> = ArrayTrait::new();
    request_id.serialize(ref calldata);
    let claim_call = ManageCall {
        leaf: LEAF_CLAIM_WITHDRAWAL,
        target: setup.withdraw_queue,
        selector: selector!("claim_withdrawal"),
        calldata,
    };
    execute_manage_calls(@setup, array![claim_call]);
    let claimed = strk.balance_of(receiver) - balance_before;
    assert(claimed == request.assets, 'claimed amount incorrect');
}

#[fork("ENDUR")]
#[test]
#[should_panic]
fn test_endur_deposit_to_unauthorized_receiver_fails() {
    let setup = setup();
    execute_manage_calls(
        @setup,
        array![build_approve_call(DEPOSIT_AMOUNT), build_deposit_call(DEPOSIT_AMOUNT, DUMMY_ADDRESS())],
    );
}

#[fork("ENDUR")]
#[test]
#[should_panic]
fn test_endur_redeem_to_unauthorized_receiver_fails() {
    let setup = setup();
    let shares = deposit_strk(@setup);
    execute_manage_calls(
        @setup, array![build_exit_call(LEAF_REDEEM, selector!("redeem"), shares, DUMMY_ADDRESS())],
    );
}
