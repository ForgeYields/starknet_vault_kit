// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::num::traits::Zero;
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, map_entry_address,
    spy_events, store,
};
use starknet::{ContractAddress, EthAddress};
use vault_allocator::integration_interfaces::starkgate::{
    IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait,
};
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _get_proofs_using_tree, _pad_leafs_to_power_of_two, generate_merkle_tree,
};
use vault_allocator::merkle_tree::integrations::starkgate::{
    StarkgateMiddlewareConfig, _add_starkgate_middleware_leafs,
};
use vault_allocator::merkle_tree::registery::{PRICE_ROUTER, STARKGATE_USDC_BRIDGE, USDC, USDT};
use vault_allocator::middlewares::starkgate_middleware::interface::{
    IStarkgateMiddlewareDispatcher, IStarkgateMiddlewareDispatcherTrait,
};
use vault_allocator::middlewares::starkgate_middleware::starkgate_middleware::StarkgateMiddleware;
use vault_allocator::test::utils::{
    OWNER, STRATEGIST, cheat_caller_address_once, deploy_manager, deploy_vault_allocator,
    set_token_balance,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};


// ============ Dedicated Decoder and Sanitizer for Starkgate Middleware ============
#[starknet::contract]
pub mod StarkgateMiddlewareTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starkgate_middleware_decoder_and_sanitizer::starkgate_middleware_decoder_and_sanitizer::StarkgateMiddlewareDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: StarkgateMiddlewareDecoderAndSanitizerComponent,
        storage: starkgate_middleware_decoder_and_sanitizer,
        event: StarkgateMiddlewareDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl StarkgateMiddlewareDecoderAndSanitizerImpl =
        StarkgateMiddlewareDecoderAndSanitizerComponent::StarkgateMiddlewareDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starkgate_middleware_decoder_and_sanitizer: StarkgateMiddlewareDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        StarkgateMiddlewareDecoderAndSanitizerEvent: StarkgateMiddlewareDecoderAndSanitizerComponent::Event,
    }
}
// ===================================================================================

// ============ Test Setup ============
#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    starkgate_middleware: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

fn L1_RECIPIENT() -> EthAddress {
    0x3823829328.try_into().unwrap()
}

fn deploy_starkgate_middleware_decoder_and_sanitizer() -> ContractAddress {
    let decoder = declare("StarkgateMiddlewareTestDecoderAndSanitizer").unwrap().contract_class();
    let calldata = ArrayTrait::new();
    let (decoder_address, _) = decoder.deploy(@calldata).unwrap();
    decoder_address
}

fn deploy_starkgate_middleware(
    vault_allocator: ContractAddress, slippage: u16, period: u64, allowed_calls_per_period: u64,
) -> ContractAddress {
    let starkgate_middleware = declare("StarkgateMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    PRICE_ROUTER().serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (starkgate_middleware_address, _) = starkgate_middleware.deploy(@calldata).unwrap();
    starkgate_middleware_address
}

fn setup() -> TestSetup {
    // Deploy vault allocator, manager
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    // Deploy dedicated decoder and sanitizer for starkgate middleware
    let decoder_and_sanitizer = deploy_starkgate_middleware_decoder_and_sanitizer();

    // Deploy starkgate middleware
    // Params: 1% slippage (100 bps), period 100000, allowed calls 1000000
    let starkgate_middleware = deploy_starkgate_middleware(
        vault_allocator.contract_address, 100, 100000, 1000000,
    );

    // Build merkle tree with starkgate middleware leafs
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_starkgate_middleware_leafs(
        ref leafs,
        ref leaf_index,
        decoder_and_sanitizer,
        array![
            StarkgateMiddlewareConfig {
                middleware: starkgate_middleware,
                l2_bridge: STARKGATE_USDC_BRIDGE(),
                l2_token: USDC(),
                l1_recipient: L1_RECIPIENT(),
                token_to_claim: USDT(),
            },
        ]
            .span(),
    );

    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);

    // Set manager on vault allocator
    cheat_caller_address_once(vault_allocator.contract_address, OWNER());
    vault_allocator.set_manager(manager.contract_address);

    // Set manage root for strategist
    cheat_caller_address_once(manager.contract_address, OWNER());
    manager.set_manage_root(STRATEGIST(), root);

    TestSetup { vault_allocator, manager, decoder_and_sanitizer, starkgate_middleware, leafs, tree }
}

// ====================================

#[fork("STARKGATE_MIDDLEWARE")]
#[test]
fn test_starkgate_middleware_bridge_usdc() {
    let setup = setup();

    // Add USDC balance to vault allocator (USDC has 6 decimals)
    let initial_usdc_balance: u256 = 10_000_000; // 10 USDC
    set_token_balance(USDC(), setup.vault_allocator.contract_address, initial_usdc_balance);
    let usdc_disp = ERC20ABIDispatcher { contract_address: USDC() };
    assert(
        usdc_disp.balance_of(setup.vault_allocator.contract_address) == initial_usdc_balance,
        'usdc balance is not correct',
    );

    // Bridge 5 USDC
    let bridge_amount: u256 = 5_000_000; // 5 USDC

    // Build calldata for approve + initiate_token_withdraw
    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(USDC()); // approve
    array_of_targets.append(setup.starkgate_middleware); // initiate_token_withdraw

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("initiate_token_withdraw"));

    let mut array_of_calldatas = ArrayTrait::new();

    // Calldata for approve(starkgate_middleware, bridge_amount)
    let mut calldata_approve: Array<felt252> = ArrayTrait::new();
    setup.starkgate_middleware.serialize(ref calldata_approve);
    bridge_amount.serialize(ref calldata_approve);
    array_of_calldatas.append(calldata_approve.span());

    // Calldata for initiate_token_withdraw
    let mut calldata_initiate: Array<felt252> = ArrayTrait::new();

    // starkgate_token_bridge
    STARKGATE_USDC_BRIDGE().serialize(ref calldata_initiate);

    // l1_token - get it from the bridge
    let bridge = IStarkgateABIDispatcher { contract_address: STARKGATE_USDC_BRIDGE() };
    let l1_token = bridge.get_l1_token(USDC());
    l1_token.serialize(ref calldata_initiate);

    // l1_recipient
    L1_RECIPIENT().serialize(ref calldata_initiate);

    // amount
    bridge_amount.serialize(ref calldata_initiate);

    // token_to_claim
    USDT().serialize(ref calldata_initiate);

    array_of_calldatas.append(calldata_initiate.span());

    // Get proofs
    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(setup.leafs.at(0).clone()); // approve
    manage_leafs.append(setup.leafs.at(1).clone()); // initiate_token_withdraw

    let manage_proofs = _get_proofs_using_tree(manage_leafs, setup.tree.clone());

    // Spy on events
    let mut spy = spy_events();

    // Execute the bridge operation
    cheat_caller_address_once(setup.manager.contract_address, STRATEGIST());
    setup
        .manager
        .manage_vault_with_merkle_verification(
            manage_proofs.span(),
            array_of_decoders_and_sanitizers.span(),
            array_of_targets.span(),
            array_of_selectors.span(),
            array_of_calldatas.span(),
        );

    // Verify USDC was transferred from vault allocator
    let new_usdc_balance = usdc_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_usdc_balance == initial_usdc_balance - bridge_amount, 'usdc balance incorrect');

    // Verify middleware has pending balance
    let middleware_disp = IStarkgateMiddlewareDispatcher {
        contract_address: setup.starkgate_middleware,
    };
    let pending = middleware_disp.get_pending_balance(USDC(), USDT());
    assert(pending == bridge_amount, 'pending balance incorrect');

    // Verify WithdrawInitiated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.starkgate_middleware,
                    StarkgateMiddleware::Event::WithdrawInitiated(
                        StarkgateMiddleware::WithdrawInitiated {
                            token_to_bridge: USDC(),
                            token_to_claim: USDT(),
                            l1_token: l1_token,
                            l1_recipient: L1_RECIPIENT(),
                            amount: bridge_amount,
                        },
                    ),
                ),
            ],
        );
}


#[fork("STARKGATE_MIDDLEWARE")]
#[test]
fn test_starkgate_middleware_claim_usdt() {
    let setup = setup();

    // SETUP: Simulate that a bridge operation already happened
    // 1. Set pending balance in middleware storage
    let bridge_amount: u256 = 5_000_000; // 5 USDC

    // Store pending balance: Map<(token_to_bridge, token_to_claim), u256>
    let mut pending_calldata = ArrayTrait::new();
    bridge_amount.serialize(ref pending_calldata);
    store(
        setup.starkgate_middleware,
        map_entry_address(
            selector!("pending_balance"), array![USDC().into(), USDT().into()].span(),
        ),
        pending_calldata.span(),
    );

    // 2. Simulate USDT arriving at the middleware (from L1 bridge)
    // USDT has 6 decimals, simulate receiving 5 USDT
    let usdt_received: u256 = 5_000_000; // 5 USDT
    set_token_balance(USDT(), setup.starkgate_middleware, usdt_received);

    // Verify setup
    let middleware_disp = IStarkgateMiddlewareDispatcher {
        contract_address: setup.starkgate_middleware,
    };
    let pending = middleware_disp.get_pending_balance(USDC(), USDT());
    assert(pending == bridge_amount, 'setup: pending incorrect');

    let usdt_disp = ERC20ABIDispatcher { contract_address: USDT() };
    assert(
        usdt_disp.balance_of(setup.starkgate_middleware) == usdt_received,
        'setup: usdt
        incorrect',
    );

    // Verify vault allocator has 0 USDT initially
    let initial_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(initial_vault_usdt == Zero::zero(), 'vault should have 0 usdt');

    // Spy on events
    let mut spy = spy_events();

    // Call claim_token
    middleware_disp.claim_token(USDC(), USDT());

    // Verify pending balance is now zero
    let new_pending = middleware_disp.get_pending_balance(USDC(), USDT());
    assert(new_pending == Zero::zero(), 'pending should be zero');

    // Verify USDT was transferred to vault allocator
    let new_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_vault_usdt == usdt_received, 'vault should have usdt');

    // Verify middleware has 0 USDT now
    assert(
        usdt_disp.balance_of(setup.starkgate_middleware) == Zero::zero(),
        'middleware should have 0',
    );

    // Verify ClaimedToken event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.starkgate_middleware,
                    StarkgateMiddleware::Event::ClaimedToken(
                        StarkgateMiddleware::ClaimedToken {
                            token_to_bridge: USDC(),
                            token_to_claim: USDT(),
                            amount_claimed: usdt_received,
                        },
                    ),
                ),
            ],
        );
}

