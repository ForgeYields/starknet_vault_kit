// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::num::traits::Zero;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use vault_allocator::merkle_tree::registery::PRICE_ROUTER;
use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;
use vault_allocator::middlewares::base_middleware::interface::{
    IBaseMiddlewareDispatcher, IBaseMiddlewareDispatcherTrait,
};
use vault_allocator::test::utils::OWNER;


// ============ Minimal Contract Using BaseMiddlewareComponent ============
#[starknet::interface]
pub trait ITestMiddleware<TContractState> {
    // Expose internal functions for testing
    fn test_enforce_rate_limit(ref self: TContractState, caller: ContractAddress);
}

#[starknet::contract]
pub mod TestMiddleware {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::ContractAddress;
    use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: BaseMiddlewareComponent, storage: base_middleware, event: BaseMiddlewareEvent);

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl BaseMiddlewareInternalImpl = BaseMiddlewareComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl BaseMiddlewareImpl =
        BaseMiddlewareComponent::BaseMiddlewareImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pub base_middleware: BaseMiddlewareComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        BaseMiddlewareEvent: BaseMiddlewareComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        vault_allocator: ContractAddress,
        price_router: ContractAddress,
        slippage: u16,
        period: u64,
        allowed_calls_per_period: u64,
    ) {
        self
            .base_middleware
            .initialize_base_middleware(
                vault_allocator, price_router, slippage, period, allowed_calls_per_period, owner,
            );
    }

    #[abi(embed_v0)]
    impl TestMiddlewareImpl of super::ITestMiddleware<ContractState> {
        fn test_enforce_rate_limit(ref self: ContractState, caller: ContractAddress) {
            self.base_middleware.enforce_rate_limit(caller);
        }
    }
}
// ===================================================================================

// ============ Test Setup ============
fn VAULT_ALLOCATOR() -> ContractAddress {
    'VAULT_ALLOCATOR'.try_into().unwrap()
}

fn OTHER_USER() -> ContractAddress {
    'OTHER_USER'.try_into().unwrap()
}

fn deploy_test_middleware(
    owner: ContractAddress,
    vault_allocator: ContractAddress,
    price_router: ContractAddress,
    slippage: u16,
    period: u64,
    allowed_calls_per_period: u64,
) -> ContractAddress {
    let contract = declare("TestMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    price_router.serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

// ====================================

// ============ Initialization Tests ============

#[test]
fn test_initialization() {
    let slippage: u16 = 100; // 1%
    let period: u64 = 3600; // 1 hour
    let allowed_calls: u64 = 10;

    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), slippage, period, allowed_calls,
    );

    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    // Verify all values are set correctly
    assert(middleware.get_vault_allocator() == VAULT_ALLOCATOR(), 'vault_allocator incorrect');
    assert(middleware.get_price_router() == PRICE_ROUTER(), 'price_router incorrect');
    assert(middleware.get_slippage() == slippage, 'slippage incorrect');
    assert(middleware.get_period() == period, 'period incorrect');
    assert(middleware.get_allowed_calls_per_period() == allowed_calls, 'allowed_calls incorrect');
    assert(middleware.get_current_window_id() == 0, 'window_id should be 0');
    assert(middleware.get_window_call_count() == 0, 'window_call_count should be 0');
}

#[test]
#[should_panic]
fn test_initialization_zero_vault_allocator() {
    deploy_test_middleware(OWNER(), Zero::zero(), PRICE_ROUTER(), 100, 3600, 10);
}

#[test]
#[should_panic]
fn test_initialization_zero_price_router() {
    deploy_test_middleware(OWNER(), VAULT_ALLOCATOR(), Zero::zero(), 100, 3600, 10);
}

#[test]
#[should_panic]
fn test_initialization_zero_owner() {
    deploy_test_middleware(Zero::zero(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10);
}

#[test]
#[should_panic]
fn test_initialization_zero_period() {
    deploy_test_middleware(OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 0, 10);
}

#[test]
#[should_panic]
fn test_initialization_zero_allowed_calls() {
    deploy_test_middleware(OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 0);
}

#[test]
#[should_panic]
fn test_initialization_slippage_exceeds_max() {
    deploy_test_middleware(OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 10000, 3600, 10);
}

// ============ set_config Tests ============

#[test]
fn test_set_config_as_owner() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    let mut spy = spy_events();

    // Set new config as owner
    let new_slippage: u16 = 200; // 2%
    let new_period: u64 = 7200; // 2 hours
    let new_allowed_calls: u64 = 20;

    start_cheat_caller_address(middleware_address, OWNER());
    middleware.set_config(new_slippage, new_period, new_allowed_calls);
    stop_cheat_caller_address(middleware_address);

    // Verify new values
    assert(middleware.get_slippage() == new_slippage, 'slippage not updated');
    assert(middleware.get_period() == new_period, 'period not updated');
    assert(
        middleware.get_allowed_calls_per_period() == new_allowed_calls, 'allowed_calls not updated',
    );

    // Verify event emitted
    spy
        .assert_emitted(
            @array![
                (
                    middleware_address,
                    BaseMiddlewareComponent::Event::ConfigSet(
                        BaseMiddlewareComponent::ConfigSet {
                            slippage: new_slippage,
                            period: new_period,
                            allowed_calls_per_period: new_allowed_calls,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_config_not_owner() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_caller_address(middleware_address, OTHER_USER());
    middleware.set_config(200, 7200, 20);
    stop_cheat_caller_address(middleware_address);
}

#[test]
#[should_panic]
fn test_set_config_slippage_exceeds_max() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_caller_address(middleware_address, OWNER());
    middleware.set_config(10001, 3600, 10);
    stop_cheat_caller_address(middleware_address);
}

// ============ set_vault_allocator Tests ============

#[test]
fn test_set_vault_allocator_as_owner() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    let mut spy = spy_events();

    let new_vault_allocator: ContractAddress = 'NEW_VAULT'.try_into().unwrap();

    start_cheat_caller_address(middleware_address, OWNER());
    middleware.set_vault_allocator(new_vault_allocator);
    stop_cheat_caller_address(middleware_address);

    // Verify new value
    assert(middleware.get_vault_allocator() == new_vault_allocator, 'vault_allocator not updated');

    // Verify event emitted
    spy
        .assert_emitted(
            @array![
                (
                    middleware_address,
                    BaseMiddlewareComponent::Event::VaultAllocatorSet(
                        BaseMiddlewareComponent::VaultAllocatorSet {
                            vault_allocator: new_vault_allocator,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_vault_allocator_not_owner() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    let new_vault_allocator: ContractAddress = 'NEW_VAULT'.try_into().unwrap();

    start_cheat_caller_address(middleware_address, OTHER_USER());
    middleware.set_vault_allocator(new_vault_allocator);
    stop_cheat_caller_address(middleware_address);
}

#[test]
#[should_panic]
fn test_set_vault_allocator_zero_address() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_caller_address(middleware_address, OWNER());
    middleware.set_vault_allocator(Zero::zero());
    stop_cheat_caller_address(middleware_address);
}

// ============ enforce_rate_limit Tests ============

#[test]
fn test_enforce_rate_limit_valid_caller() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );

    let test_middleware = ITestMiddlewareDispatcher { contract_address: middleware_address };
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    // Set timestamp to a known value
    start_cheat_block_timestamp_global(3600); // timestamp = 3600

    // Call enforce_rate_limit with vault_allocator as caller
    test_middleware.test_enforce_rate_limit(VAULT_ALLOCATOR());

    // Verify call count incremented
    assert(middleware.get_window_call_count() == 1, 'call count should be 1');
    assert(middleware.get_current_window_id() == 1, 'window_id should be 1');
}

#[test]
fn test_enforce_rate_limit_multiple_calls() {
    let allowed_calls: u64 = 5;
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, allowed_calls,
    );

    let test_middleware = ITestMiddlewareDispatcher { contract_address: middleware_address };
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_block_timestamp_global(3600);

    // Make 5 calls (the maximum allowed)
    let mut i: u64 = 0;
    while i < allowed_calls {
        test_middleware.test_enforce_rate_limit(VAULT_ALLOCATOR());
        i += 1;
    }

    // Verify all calls were counted
    assert(middleware.get_window_call_count() == allowed_calls, 'call count incorrect');
}

#[test]
#[should_panic]
fn test_enforce_rate_limit_invalid_caller() {
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, 10,
    );

    let test_middleware = ITestMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_block_timestamp_global(3600);

    // Call with wrong caller
    test_middleware.test_enforce_rate_limit(OTHER_USER());
}

#[test]
#[should_panic]
fn test_enforce_rate_limit_exceeded() {
    let allowed_calls: u64 = 5;
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, 3600, allowed_calls,
    );

    let test_middleware = ITestMiddlewareDispatcher { contract_address: middleware_address };

    start_cheat_block_timestamp_global(3600);

    // Make 6 calls (one more than allowed)
    let mut i: u64 = 0;
    while i < allowed_calls + 1 {
        test_middleware.test_enforce_rate_limit(VAULT_ALLOCATOR());
        i += 1;
    };
}

#[test]
fn test_enforce_rate_limit_window_reset() {
    let allowed_calls: u64 = 5;
    let period: u64 = 3600;
    let middleware_address = deploy_test_middleware(
        OWNER(), VAULT_ALLOCATOR(), PRICE_ROUTER(), 100, period, allowed_calls,
    );

    let test_middleware = ITestMiddlewareDispatcher { contract_address: middleware_address };
    let middleware = IBaseMiddlewareDispatcher { contract_address: middleware_address };

    // First window
    start_cheat_block_timestamp_global(period);

    // Use all allowed calls in first window
    let mut i: u64 = 0;
    while i < allowed_calls {
        test_middleware.test_enforce_rate_limit(VAULT_ALLOCATOR());
        i += 1;
    }

    assert(middleware.get_window_call_count() == allowed_calls, 'call count should be max');
    assert(middleware.get_current_window_id() == 1, 'window_id should be 1');

    // Move to next window
    start_cheat_block_timestamp_global(period * 2);

    // Should be able to make calls again
    test_middleware.test_enforce_rate_limit(VAULT_ALLOCATOR());

    // Verify window reset
    assert(middleware.get_window_call_count() == 1, 'call count should reset to 1');
    assert(middleware.get_current_window_id() == 2, 'window_id should be 2');
}

