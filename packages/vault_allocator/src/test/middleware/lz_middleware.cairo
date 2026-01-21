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
use vault_allocator::merkle_tree::integrations::lz::{LzMiddlewareConfig, _add_lz_middleware_leafs};
use vault_allocator::merkle_tree::registery::{LZ_WBTC_OFT_ADAPTER, PRICE_ROUTER, STRK, USDC, WBTC};
use vault_allocator::middlewares::lz_middleware::interface::{
    ILzMiddlewareDispatcher, ILzMiddlewareDispatcherTrait,
};
use vault_allocator::middlewares::lz_middleware::lz_middleware::LzMiddleware;
use vault_allocator::test::utils::{
    OWNER, STRATEGIST, cheat_caller_address_once, deploy_manager, deploy_vault_allocator,
    set_token_balance,
};
use vault_allocator::vault_allocator::interface::{
    IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
};


// ============ Dedicated Decoder and Sanitizer for LZ Middleware ============
#[starknet::contract]
pub mod LzMiddlewareTestDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::lz_middleware_decoder_and_sanitizer::lz_middleware_decoder_and_sanitizer::LzMiddlewareDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: LzMiddlewareDecoderAndSanitizerComponent,
        storage: lz_middleware_decoder_and_sanitizer,
        event: LzMiddlewareDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl LzMiddlewareDecoderAndSanitizerImpl =
        LzMiddlewareDecoderAndSanitizerComponent::LzMiddlewareDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub lz_middleware_decoder_and_sanitizer: LzMiddlewareDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        LzMiddlewareDecoderAndSanitizerEvent: LzMiddlewareDecoderAndSanitizerComponent::Event,
    }
}
// ===================================================================================

// ============ Test Setup ============
#[derive(Drop)]
struct TestSetup {
    vault_allocator: IVaultAllocatorDispatcher,
    manager: IManagerDispatcher,
    decoder_and_sanitizer: ContractAddress,
    lz_middleware: ContractAddress,
    leafs: Array<ManageLeaf>,
    tree: Array<Array<felt252>>,
}

// LayerZero destination endpoint ID for Ethereum mainnet
const ETH_EID: u32 = 30101;

// Recipient address on Ethereum (example address)
fn TO() -> u256 {
    0x732357e321Bf7a02CbB690fc2a629161D7722e29_u256
}

fn deploy_lz_middleware_decoder_and_sanitizer() -> ContractAddress {
    let decoder = declare("LzMiddlewareTestDecoderAndSanitizer").unwrap().contract_class();
    let calldata = ArrayTrait::new();
    let (decoder_address, _) = decoder.deploy(@calldata).unwrap();
    decoder_address
}

fn deploy_lz_middleware(
    vault_allocator: ContractAddress, slippage: u16, period: u64, allowed_calls_per_period: u64,
) -> ContractAddress {
    let lz_middleware = declare("LzMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    PRICE_ROUTER().serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (lz_middleware_address, _) = lz_middleware.deploy(@calldata).unwrap();
    lz_middleware_address
}

fn setup() -> TestSetup {
    // Deploy vault allocator, manager
    let vault_allocator = deploy_vault_allocator();
    let manager = deploy_manager(vault_allocator);

    // Deploy dedicated decoder and sanitizer for lz middleware
    let decoder_and_sanitizer = deploy_lz_middleware_decoder_and_sanitizer();

    // Deploy lz middleware
    // Params: 1% slippage (100 bps), period 100000, allowed calls 1000000
    let lz_middleware = deploy_lz_middleware(
        vault_allocator.contract_address, 100, 100000, 1000000,
    );

    // Build merkle tree with lz middleware leafs
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_lz_middleware_leafs(
        ref leafs,
        ref leaf_index,
        decoder_and_sanitizer,
        vault_allocator.contract_address,
        array![
            LzMiddlewareConfig {
                middleware: lz_middleware,
                oft: LZ_WBTC_OFT_ADAPTER(),
                underlying_token: WBTC(),
                token_to_claim: USDC(),
                dst_eid: ETH_EID,
                to: TO(),
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

    TestSetup { vault_allocator, manager, decoder_and_sanitizer, lz_middleware, leafs, tree }
}

// ====================================

#[fork("LZ")]
#[test]
fn test_lz_middleware_send() {
    let setup = setup();

    // Add WBTC balance to vault allocator (WBTC has 8 decimals)
    let initial_wbtc_balance: u256 = 100_000_000; // 1 WBTC
    set_token_balance(WBTC(), setup.vault_allocator.contract_address, initial_wbtc_balance);
    let wbtc_disp = ERC20ABIDispatcher { contract_address: WBTC() };
    assert(
        wbtc_disp.balance_of(setup.vault_allocator.contract_address) == initial_wbtc_balance,
        'wbtc balance is not correct',
    );

    // Add STRK balance to vault allocator for fees (STRK has 18 decimals)
    let strk_fee: u256 = 100_000_000_000_000_000; // 0.1 STRK
    set_token_balance(STRK(), setup.vault_allocator.contract_address, strk_fee);
    let strk_disp = ERC20ABIDispatcher { contract_address: STRK() };
    assert(
        strk_disp.balance_of(setup.vault_allocator.contract_address) == strk_fee,
        'strk balance is not correct',
    );

    // Bridge 0.5 WBTC
    let bridge_amount: u256 = 50_000_000; // 0.5 WBTC
    let min_amount: u256 = bridge_amount;

    // Build calldata for approve WBTC + approve STRK + send
    let mut array_of_decoders_and_sanitizers = ArrayTrait::new();
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);
    array_of_decoders_and_sanitizers.append(setup.decoder_and_sanitizer);

    let mut array_of_targets = ArrayTrait::new();
    array_of_targets.append(WBTC()); // approve WBTC
    array_of_targets.append(STRK()); // approve STRK
    array_of_targets.append(setup.lz_middleware); // send

    let mut array_of_selectors = ArrayTrait::new();
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("approve"));
    array_of_selectors.append(selector!("send"));

    let mut array_of_calldatas = ArrayTrait::new();

    // Calldata for approve WBTC(lz_middleware, bridge_amount)
    let mut calldata_approve_wbtc: Array<felt252> = ArrayTrait::new();
    setup.lz_middleware.serialize(ref calldata_approve_wbtc);
    bridge_amount.serialize(ref calldata_approve_wbtc);
    array_of_calldatas.append(calldata_approve_wbtc.span());

    // Calldata for approve STRK(lz_middleware, strk_fee)
    let mut calldata_approve_strk: Array<felt252> = ArrayTrait::new();
    setup.lz_middleware.serialize(ref calldata_approve_strk);
    strk_fee.serialize(ref calldata_approve_strk);
    array_of_calldatas.append(calldata_approve_strk.span());

    // Calldata for send
    let mut calldata_send: Array<felt252> = ArrayTrait::new();

    // oft
    LZ_WBTC_OFT_ADAPTER().serialize(ref calldata_send);

    // underlying_token
    WBTC().serialize(ref calldata_send);

    // token_to_claim
    USDC().serialize(ref calldata_send);

    // SendParam struct
    // dst_eid
    ETH_EID.serialize(ref calldata_send);

    // to
    TO().serialize(ref calldata_send);

    // amount_ld
    bridge_amount.serialize(ref calldata_send);

    // min_amount_ld
    min_amount.serialize(ref calldata_send);

    let extra_options: ByteArray = "";
    extra_options.serialize(ref calldata_send);
    let compose_msg: ByteArray = "";
    compose_msg.serialize(ref calldata_send);
    let oft_cmd: ByteArray = "";
    oft_cmd.serialize(ref calldata_send);

    // MessagingFee struct
    // native_fee
    strk_fee.serialize(ref calldata_send);

    // lz_token_fee
    let lz_token_fee: u256 = 0;
    lz_token_fee.serialize(ref calldata_send);

    // refund_address
    setup.vault_allocator.contract_address.serialize(ref calldata_send);

    array_of_calldatas.append(calldata_send.span());

    // Get proofs
    let mut manage_leafs: Array<ManageLeaf> = ArrayTrait::new();
    manage_leafs.append(setup.leafs.at(0).clone()); // approve WBTC
    manage_leafs.append(setup.leafs.at(1).clone()); // approve STRK
    manage_leafs.append(setup.leafs.at(2).clone()); // send

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

    // Verify WBTC was transferred from vault allocator
    let new_wbtc_balance = wbtc_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_wbtc_balance == initial_wbtc_balance - bridge_amount, 'wbtc balance incorrect');

    // Verify middleware has pending balance
    let middleware_disp = ILzMiddlewareDispatcher { contract_address: setup.lz_middleware };
    let pending = middleware_disp.get_pending_balance(WBTC(), USDC(), ETH_EID);
    assert(pending == bridge_amount, 'pending balance incorrect');

    // Verify BridgeInitiated event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.lz_middleware,
                    LzMiddleware::Event::BridgeInitiated(
                        LzMiddleware::BridgeInitiated {
                            underlying_token: WBTC(),
                            token_to_claim: USDC(),
                            dst_eid: ETH_EID,
                            to: TO(),
                            amount: bridge_amount,
                            guid: 0 // guid will be mocked/ignored in fork test
                        },
                    ),
                ),
            ],
        );
}


#[fork("LZ")]
#[test]
fn test_lz_middleware_claim_usdc() {
    let setup = setup();

    // SETUP: Simulate that a bridge operation already happened
    // 1. Set pending balance in middleware storage
    let bridge_amount: u256 = 50_000_000; // 0.5 WBTC

    // Store pending balance: Map<(underlying_token, token_to_claim, dst_eid), u256>
    let mut pending_calldata = ArrayTrait::new();
    bridge_amount.serialize(ref pending_calldata);
    store(
        setup.lz_middleware,
        map_entry_address(
            selector!("pending_balance"),
            array![WBTC().into(), USDC().into(), ETH_EID.into()].span(),
        ),
        pending_calldata.span(),
    );

    // 2. Simulate USDC arriving at the middleware (from bridge on return)
    // USDC has 6 decimals, simulate receiving 1000 USDC (equivalent value for 0.5 WBTC)
    let usdc_received: u256 = 1_000_000_000; // 1000 USDC
    set_token_balance(USDC(), setup.lz_middleware, usdc_received);

    // Verify setup
    let middleware_disp = ILzMiddlewareDispatcher { contract_address: setup.lz_middleware };
    let pending = middleware_disp.get_pending_balance(WBTC(), USDC(), ETH_EID);
    assert(pending == bridge_amount, 'setup: pending incorrect');

    let usdc_disp = ERC20ABIDispatcher { contract_address: USDC() };
    assert(usdc_disp.balance_of(setup.lz_middleware) == usdc_received, 'setup: usdc incorrect');

    // Verify vault allocator has 0 USDC initially
    let initial_vault_usdc = usdc_disp.balance_of(setup.vault_allocator.contract_address);
    assert(initial_vault_usdc == Zero::zero(), 'vault should have 0 usdc');

    // Spy on events
    let mut spy = spy_events();

    // Call claim_token (permissionless - anyone can call)
    middleware_disp.claim_token(WBTC(), USDC(), ETH_EID);

    // Verify pending balance is now zero
    let new_pending = middleware_disp.get_pending_balance(WBTC(), USDC(), ETH_EID);
    assert(new_pending == Zero::zero(), 'pending should be zero');

    // Verify USDC was transferred to vault allocator
    let new_vault_usdc = usdc_disp.balance_of(setup.vault_allocator.contract_address);
    assert(new_vault_usdc == usdc_received, 'vault should have usdc');

    // Verify middleware has 0 USDC now
    assert(usdc_disp.balance_of(setup.lz_middleware) == Zero::zero(), 'middleware should have 0');

    // Verify ClaimedToken event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.lz_middleware,
                    LzMiddleware::Event::ClaimedToken(
                        LzMiddleware::ClaimedToken {
                            underlying_token: WBTC(),
                            token_to_claim: USDC(),
                            dst_eid: ETH_EID,
                            amount_claimed: usdc_received,
                        },
                    ),
                ),
            ],
        );
}
