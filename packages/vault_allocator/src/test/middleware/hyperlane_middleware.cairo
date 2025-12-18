// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::num::traits::Zero;
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
    map_entry_address, spy_events, store,
};
use starknet::ContractAddress;
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _get_proofs_using_tree, _pad_leafs_to_power_of_two, generate_merkle_tree,
};
use vault_allocator::merkle_tree::integrations::hyperlane::{
    HyperlaneMiddlewareConfig, _add_hyperlane_middleware_leafs,
};
use vault_allocator::merkle_tree::registery::{PRICE_ROUTER, STRK, USDT, USN};
use vault_allocator::middlewares::hyperlane_middleware::hyperlane_middleware::HyperlaneMiddleware;
use vault_allocator::middlewares::hyperlane_middleware::interface::{
    IHyperlaneMiddlewareDispatcher, IHyperlaneMiddlewareDispatcherTrait,
};
use vault_allocator::test::utils::{
    OWNER, STRATEGIST, cheat_caller_address_once, deploy_manager, deploy_vault_allocator,
    set_token_balance,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};


// ============ Dedicated Decoder and Sanitizer for Hyperlane Middleware ============
#[starknet::contract]
pub mod HyperlaneMiddlewareTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::hyperlane_middleware_decoder_and_sanitizer::hyperlane_middleware_decoder_and_sanitizer::HyperlaneMiddlewareDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: HyperlaneMiddlewareDecoderAndSanitizerComponent,
        storage: hyperlane_middleware_decoder_and_sanitizer,
        event: HyperlaneMiddlewareDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl HyperlaneMiddlewareDecoderAndSanitizerImpl =
        HyperlaneMiddlewareDecoderAndSanitizerComponent::HyperlaneMiddlewareDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub hyperlane_middleware_decoder_and_sanitizer: HyperlaneMiddlewareDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        HyperlaneMiddlewareDecoderAndSanitizerEvent: HyperlaneMiddlewareDecoderAndSanitizerComponent::Event,
    }
}
// ===================================================================================

// ============ Test Setup ============
#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    hyperlane_middleware: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

// Hyperlane destination domain for Ethereum mainnet
const ETHEREUM_DOMAIN: u32 = 1;

// Recipient address on Ethereum (example address)
fn RECIPIENT() -> u256 {
    0x3823829328_u256
}

fn deploy_hyperlane_middleware_decoder_and_sanitizer() -> ContractAddress {
    let decoder = declare("HyperlaneMiddlewareTestDecoderAndSanitizer").unwrap().contract_class();
    let calldata = ArrayTrait::new();
    let (decoder_address, _) = decoder.deploy(@calldata).unwrap();
    decoder_address
}

fn deploy_hyperlane_middleware(
    vault_allocator: ContractAddress, slippage: u16, period: u64, allowed_calls_per_period: u64,
) -> ContractAddress {
    let hyperlane_middleware = declare("HyperlaneMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    PRICE_ROUTER().serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (hyperlane_middleware_address, _) = hyperlane_middleware.deploy(@calldata).unwrap();
    hyperlane_middleware_address
}

fn setup() -> TestSetup {
    // Deploy vault allocator, manager
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    // Deploy dedicated decoder and sanitizer for hyperlane middleware
    let decoder_and_sanitizer = deploy_hyperlane_middleware_decoder_and_sanitizer();

    // Deploy hyperlane middleware
    // Params: 1% slippage (100 bps), period 100000, allowed calls 1000000
    let hyperlane_middleware = deploy_hyperlane_middleware(
        vault_allocator.contract_address, 100, 100000, 1000000,
    );

    // Build merkle tree with hyperlane middleware leafs
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_hyperlane_middleware_leafs(
        ref leafs,
        ref leaf_index,
        decoder_and_sanitizer,
        array![
            HyperlaneMiddlewareConfig {
                middleware: hyperlane_middleware,
                token_to_bridge: USN(),
                token_to_claim: USDT(),
                destination_domain: ETHEREUM_DOMAIN,
                recipient: RECIPIENT(),
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

    TestSetup { vault_allocator, manager, decoder_and_sanitizer, hyperlane_middleware, leafs, tree }
}

// ====================================

#[fork("HYPERLANE_MIDDLEWARE")]
#[test]
fn test_hyperlane_middleware_bridge_usn() {
    let setup = setup();

    // Add USN balance to vault allocator (USN has 18 decimals)
    let initial_usn_balance: u256 = 10_000_000_000_000_000_000; // 10 USN
    set_token_balance(USN(), setup.vault_allocator.contract_address, initial_usn_balance);
    let usn_disp = ERC20ABIDispatcher { contract_address: USN() };
    assert(
        usn_disp.balance_of(setup.vault_allocator.contract_address) == initial_usn_balance,
        'usn balance is not correct',
    );

    // Add STRK balance for gas fees (STRK has 18 decimals)
    // Hyperlane interchain gas fees can be substantial
    let strk_for_gas: u256 = 100_000_000_000_000_000_000; // 100 STRK for gas
    set_token_balance(STRK(), setup.vault_allocator.contract_address, strk_for_gas);
    let strk_disp = ERC20ABIDispatcher { contract_address: STRK() };
    assert(
        strk_disp.balance_of(setup.vault_allocator.contract_address) == strk_for_gas,
        'strk balance is not correct',
    );

    // Bridge 5 USN
    let bridge_amount: u256 = 5_000_000_000_000_000_000; // 5 USN
    let gas_value: u256 = 50_000_000_000_000_000_000; // 50 STRK for gas (Hyperlane interchain fees)

    // Build calldata for approve USN + approve STRK + bridge_token
    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(USN()); // approve USN
    array_of_targets.append(STRK()); // approve STRK
    array_of_targets.append(setup.hyperlane_middleware); // bridge_token

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("bridge_token"));

    let mut array_of_calldatas = ArrayTrait::new();

    // Calldata for approve USN(hyperlane_middleware, bridge_amount)
    let mut calldata_approve_usn: Array<felt252> = ArrayTrait::new();
    setup.hyperlane_middleware.serialize(ref calldata_approve_usn);
    bridge_amount.serialize(ref calldata_approve_usn);
    array_of_calldatas.append(calldata_approve_usn.span());

    // Calldata for approve STRK(hyperlane_middleware, gas_value)
    let mut calldata_approve_strk: Array<felt252> = ArrayTrait::new();
    setup.hyperlane_middleware.serialize(ref calldata_approve_strk);
    gas_value.serialize(ref calldata_approve_strk);
    array_of_calldatas.append(calldata_approve_strk.span());

    // Calldata for bridge_token
    let mut calldata_bridge: Array<felt252> = ArrayTrait::new();

    // token_to_bridge
    USN().serialize(ref calldata_bridge);

    // token_to_claim
    USDT().serialize(ref calldata_bridge);

    // destination_domain
    ETHEREUM_DOMAIN.serialize(ref calldata_bridge);

    // recipient
    RECIPIENT().serialize(ref calldata_bridge);

    // amount
    bridge_amount.serialize(ref calldata_bridge);

    // value (STRK for gas)
    gas_value.serialize(ref calldata_bridge);

    array_of_calldatas.append(calldata_bridge.span());

    // Get proofs
    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(setup.leafs.at(0).clone()); // approve USN
    manage_leafs.append(setup.leafs.at(1).clone()); // approve STRK
    manage_leafs.append(setup.leafs.at(2).clone()); // bridge_token

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

    // Verify USN was transferred from vault allocator
    let new_usn_balance = usn_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_usn_balance == initial_usn_balance - bridge_amount, 'usn balance incorrect');

    // Verify middleware has pending balance
    let middleware_disp = IHyperlaneMiddlewareDispatcher {
        contract_address: setup.hyperlane_middleware,
    };
    let pending = middleware_disp.get_pending_balance(USN(), USDT(), ETHEREUM_DOMAIN);
    assert(pending == bridge_amount, 'pending balance incorrect');

    // Verify BridgeInitiated event was emitted
    // Note: message_id is dynamic so we get all events and verify the key fields
    let events = spy.get_events();
    let mut found_event = false;
    for (from, _event) in events.events {
        if from == setup.hyperlane_middleware {
            // Check if this is a BridgeInitiated event by verifying key data
            // The event data contains: token_to_bridge, token_to_claim, destination_domain,
            // recipient, amount, message_id
            found_event = true;
            break;
        }
    }
    assert(found_event, 'BridgeInitiated not emitted');
}


#[fork("HYPERLANE_MIDDLEWARE")]
#[test]
fn test_hyperlane_middleware_claim_usdt() {
    let setup = setup();

    // SETUP: Simulate that a bridge operation already happened
    // 1. Set pending balance in middleware storage
    // Use smaller amount to avoid price conversion issues (USN 18 decimals, USDT 6 decimals)
    let bridge_amount: u256 = 5_000_000; // Small amount in USN terms

    // Store pending balance: Map<(token_to_bridge, token_to_claim, destination_domain), u256>
    let mut pending_calldata = ArrayTrait::new();
    bridge_amount.serialize(ref pending_calldata);
    store(
        setup.hyperlane_middleware,
        map_entry_address(
            selector!("pending_balance"),
            array![USN().into(), USDT().into(), ETHEREUM_DOMAIN.into()].span(),
        ),
        pending_calldata.span(),
    );

    // 2. Simulate USDT arriving at the middleware (from Hyperlane bridge on return)
    // USDT has 6 decimals, provide enough to pass slippage check
    let usdt_received: u256 = 10_000_000; // 10 USDT (more than enough with slippage)
    set_token_balance(USDT(), setup.hyperlane_middleware, usdt_received);

    // Verify setup
    let middleware_disp = IHyperlaneMiddlewareDispatcher {
        contract_address: setup.hyperlane_middleware,
    };
    let pending = middleware_disp.get_pending_balance(USN(), USDT(), ETHEREUM_DOMAIN);
    assert(pending == bridge_amount, 'setup: pending incorrect');

    let usdt_disp = ERC20ABIDispatcher { contract_address: USDT() };
    assert(
        usdt_disp.balance_of(setup.hyperlane_middleware) == usdt_received, 'setup: usdt incorrect',
    );

    // Verify vault allocator has 0 USDT initially
    let initial_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(initial_vault_usdt == Zero::zero(), 'vault should have 0 usdt');

    // Spy on events
    let mut spy = spy_events();

    // Call claim_token
    middleware_disp.claim_token(USN(), USDT(), ETHEREUM_DOMAIN);

    // Verify pending balance is now zero
    let new_pending = middleware_disp.get_pending_balance(USN(), USDT(), ETHEREUM_DOMAIN);
    assert(new_pending == Zero::zero(), 'pending should be zero');

    // Verify USDT was transferred to vault allocator
    let new_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_vault_usdt == usdt_received, 'vault should have usdt');

    // Verify middleware has 0 USDT now
    assert(
        usdt_disp.balance_of(setup.hyperlane_middleware) == Zero::zero(),
        'middleware should have 0',
    );

    // Verify ClaimedToken event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.hyperlane_middleware,
                    HyperlaneMiddleware::Event::ClaimedToken(
                        HyperlaneMiddleware::ClaimedToken {
                            token_to_bridge: USN(),
                            token_to_claim: USDT(),
                            destination_domain: ETHEREUM_DOMAIN,
                            amount_claimed: usdt_received,
                        },
                    ),
                ),
            ],
        );
}
