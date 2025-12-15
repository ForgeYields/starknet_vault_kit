// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::num::traits::Zero;
use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, map_entry_address,
    spy_events, store,
};
use starknet::ContractAddress;
use vault_allocator::manager::interface::{IManagerDispatcher, IManagerDispatcherTrait};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _get_proofs_using_tree, _pad_leafs_to_power_of_two, generate_merkle_tree,
};
use vault_allocator::merkle_tree::integrations::cctp::{
    CctpMiddlewareConfig, _add_cctp_middleware_leafs,
};
use vault_allocator::merkle_tree::registery::{CCTP_USDC_BRIDGE, PRICE_ROUTER, USDC_CCTP, USDT};
use vault_allocator::middlewares::cctp_middleware::cctp_middleware::CctpMiddleware;
use vault_allocator::middlewares::cctp_middleware::interface::{
    ICctpMiddlewareDispatcher, ICctpMiddlewareDispatcherTrait,
};
use vault_allocator::test::utils::{
    OWNER, STRATEGIST, cheat_caller_address_once, deploy_manager, deploy_vault_allocator,
    set_token_balance, set_token_balance_circle,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};


// ============ Dedicated Decoder and Sanitizer for CCTP Middleware ============
#[starknet::contract]
pub mod CctpMiddlewareTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::cctp_middleware_decoder_and_sanitizer::cctp_middleware_decoder_and_sanitizer::CctpMiddlewareDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: CctpMiddlewareDecoderAndSanitizerComponent,
        storage: cctp_middleware_decoder_and_sanitizer,
        event: CctpMiddlewareDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl CctpMiddlewareDecoderAndSanitizerImpl =
        CctpMiddlewareDecoderAndSanitizerComponent::CctpMiddlewareDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub cctp_middleware_decoder_and_sanitizer: CctpMiddlewareDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        CctpMiddlewareDecoderAndSanitizerEvent: CctpMiddlewareDecoderAndSanitizerComponent::Event,
    }
}
// ===================================================================================

// ============ Test Setup ============
#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    cctp_middleware: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

// CCTP destination domain for Ethereum mainnet
const ETHEREUM_DOMAIN: u32 = 0;

// Mint recipient address on Ethereum (example address)
fn MINT_RECIPIENT() -> u256 {
    0x3823829328_u256
}

// Destination caller (0 means anyone can call)
fn DESTINATION_CALLER() -> u256 {
    0_u256
}

fn deploy_cctp_middleware_decoder_and_sanitizer() -> ContractAddress {
    let decoder = declare("CctpMiddlewareTestDecoderAndSanitizer").unwrap().contract_class();
    let calldata = ArrayTrait::new();
    let (decoder_address, _) = decoder.deploy(@calldata).unwrap();
    decoder_address
}

fn deploy_cctp_middleware(
    vault_allocator: ContractAddress,
    cctp_token_bridge: ContractAddress,
    slippage: u16,
    period: u64,
    allowed_calls_per_period: u64,
) -> ContractAddress {
    let cctp_middleware = declare("CctpMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    PRICE_ROUTER().serialize(ref calldata);
    cctp_token_bridge.serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (cctp_middleware_address, _) = cctp_middleware.deploy(@calldata).unwrap();
    cctp_middleware_address
}

fn setup() -> TestSetup {
    // Deploy vault allocator, manager
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    // Deploy dedicated decoder and sanitizer for cctp middleware
    let decoder_and_sanitizer = deploy_cctp_middleware_decoder_and_sanitizer();

    // Deploy cctp middleware
    // Params: 1% slippage (100 bps), period 100000, allowed calls 1000000
    let cctp_middleware = deploy_cctp_middleware(
        vault_allocator.contract_address, CCTP_USDC_BRIDGE(), 100, 100000, 1000000,
    );

    // Build merkle tree with cctp middleware leafs
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_cctp_middleware_leafs(
        ref leafs,
        ref leaf_index,
        decoder_and_sanitizer,
        array![
            CctpMiddlewareConfig {
                middleware: cctp_middleware,
                burn_token: USDC_CCTP(),
                token_to_claim: USDT(),
                destination_domain: ETHEREUM_DOMAIN,
                mint_recipient: MINT_RECIPIENT(),
                destination_caller: DESTINATION_CALLER(),
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

    TestSetup { vault_allocator, manager, decoder_and_sanitizer, cctp_middleware, leafs, tree }
}

// ====================================

#[fork("CCTP_MIDDLEWARE")]
#[test]
fn test_cctp_middleware_deposit_for_burn() {
    let setup = setup();

    // Add USDC_CCTP balance to vault allocator (USDC has 6 decimals)
    // Circle USDC uses 'balances' storage selector instead of 'ERC20_balances'
    let initial_usdc_balance: u256 = 10_000_000; // 10 USDC
    set_token_balance_circle(
        USDC_CCTP(), setup.vault_allocator.contract_address, initial_usdc_balance,
    );
    let usdc_disp = ERC20ABIDispatcher { contract_address: USDC_CCTP() };
    assert(
        usdc_disp.balance_of(setup.vault_allocator.contract_address) == initial_usdc_balance,
        'usdc balance is not correct',
    );

    // Bridge 5 USDC
    let bridge_amount: u256 = 5_000_000; // 5 USDC

    // Build calldata for approve + deposit_for_burn
    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(USDC_CCTP()); // approve
    array_of_targets.append(setup.cctp_middleware); // deposit_for_burn

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("deposit_for_burn"));

    let mut array_of_calldatas = ArrayTrait::new();

    // Calldata for approve(cctp_middleware, bridge_amount)
    let mut calldata_approve: Array<felt252> = ArrayTrait::new();
    setup.cctp_middleware.serialize(ref calldata_approve);
    bridge_amount.serialize(ref calldata_approve);
    array_of_calldatas.append(calldata_approve.span());

    // Calldata for deposit_for_burn
    let mut calldata_deposit: Array<felt252> = ArrayTrait::new();

    // amount
    bridge_amount.serialize(ref calldata_deposit);

    // destination_domain
    ETHEREUM_DOMAIN.serialize(ref calldata_deposit);

    // mint_recipient
    MINT_RECIPIENT().serialize(ref calldata_deposit);

    // burn_token
    USDC_CCTP().serialize(ref calldata_deposit);

    // token_to_claim
    USDT().serialize(ref calldata_deposit);

    // destination_caller
    DESTINATION_CALLER().serialize(ref calldata_deposit);

    // max_fee (0 for no fee limit)
    let max_fee: u256 = 0;
    max_fee.serialize(ref calldata_deposit);

    // min_finality_threshold (2000 for standard finality)
    let min_finality_threshold: u32 = 2000;
    min_finality_threshold.serialize(ref calldata_deposit);

    array_of_calldatas.append(calldata_deposit.span());

    // Get proofs
    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(setup.leafs.at(0).clone()); // approve
    manage_leafs.append(setup.leafs.at(1).clone()); // deposit_for_burn

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

    // Verify USDC_CCTP was transferred from vault allocator
    let new_usdc_balance = usdc_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_usdc_balance == initial_usdc_balance - bridge_amount, 'usdc balance incorrect');

    // Verify middleware has pending balance
    let middleware_disp = ICctpMiddlewareDispatcher { contract_address: setup.cctp_middleware };
    let pending = middleware_disp.get_pending_balance(USDC_CCTP(), USDT(), ETHEREUM_DOMAIN);
    assert(pending == bridge_amount, 'pending balance incorrect');

    // Verify DepositForBurnInitiated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.cctp_middleware,
                    CctpMiddleware::Event::DepositForBurnInitiated(
                        CctpMiddleware::DepositForBurnInitiated {
                            burn_token: USDC_CCTP(),
                            token_to_claim: USDT(),
                            destination_domain: ETHEREUM_DOMAIN,
                            mint_recipient: MINT_RECIPIENT(),
                            amount: bridge_amount,
                        },
                    ),
                ),
            ],
        );
}


#[fork("CCTP_MIDDLEWARE")]
#[test]
fn test_cctp_middleware_claim_usdt() {
    let setup = setup();

    // SETUP: Simulate that a bridge operation already happened
    // 1. Set pending balance in middleware storage
    let bridge_amount: u256 = 5_000_000; // 5 USDC

    // Store pending balance: Map<(burn_token, token_to_claim, destination_domain), u256>
    let mut pending_calldata = ArrayTrait::new();
    bridge_amount.serialize(ref pending_calldata);
    store(
        setup.cctp_middleware,
        map_entry_address(
            selector!("pending_balance"),
            array![USDC_CCTP().into(), USDT().into(), ETHEREUM_DOMAIN.into()].span(),
        ),
        pending_calldata.span(),
    );

    // 2. Simulate USDT arriving at the middleware (from CCTP bridge on return)
    // USDT has 6 decimals, simulate receiving 5 USDT
    let usdt_received: u256 = 5_000_000; // 5 USDT
    set_token_balance(USDT(), setup.cctp_middleware, usdt_received);

    // Verify setup
    let middleware_disp = ICctpMiddlewareDispatcher { contract_address: setup.cctp_middleware };
    let pending = middleware_disp.get_pending_balance(USDC_CCTP(), USDT(), ETHEREUM_DOMAIN);
    assert(pending == bridge_amount, 'setup: pending incorrect');

    let usdt_disp = ERC20ABIDispatcher { contract_address: USDT() };
    assert(usdt_disp.balance_of(setup.cctp_middleware) == usdt_received, 'setup: usdt incorrect');

    // Verify vault allocator has 0 USDT initially
    let initial_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(initial_vault_usdt == Zero::zero(), 'vault should have 0 usdt');

    // Spy on events
    let mut spy = spy_events();

    // Call claim_token
    middleware_disp.claim_token(USDC_CCTP(), USDT(), ETHEREUM_DOMAIN);

    // Verify pending balance is now zero
    let new_pending = middleware_disp.get_pending_balance(USDC_CCTP(), USDT(), ETHEREUM_DOMAIN);
    assert(new_pending == Zero::zero(), 'pending should be zero');

    // Verify USDT was transferred to vault allocator
    let new_vault_usdt = usdt_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_vault_usdt == usdt_received, 'vault should have usdt');

    // Verify middleware has 0 USDT now
    assert(usdt_disp.balance_of(setup.cctp_middleware) == Zero::zero(), 'middleware should have 0');

    // Verify ClaimedToken event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.cctp_middleware,
                    CctpMiddleware::Event::ClaimedToken(
                        CctpMiddleware::ClaimedToken {
                            burn_token: USDC_CCTP(),
                            token_to_claim: USDT(),
                            destination_domain: ETHEREUM_DOMAIN,
                            amount_claimed: usdt_received,
                        },
                    ),
                ),
            ],
        );
}
