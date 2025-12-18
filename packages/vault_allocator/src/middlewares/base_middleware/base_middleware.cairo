// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod BaseMiddlewareComponent {
    const BPS_SCALE: u16 = 10_000;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent::InternalTrait as UpgradeableInternalTrait;
    use openzeppelin::utils::math;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp};
    use vault_allocator::middlewares::base_middleware::errors::Errors;
    use vault_allocator::middlewares::base_middleware::interface::IBaseMiddleware;
    use vault_allocator::periphery::price_router::interface::{
        IPriceRouterDispatcher, IPriceRouterDispatcherTrait,
    };


    #[storage]
    pub struct Storage {
        pub vault_allocator: ContractAddress,
        pub price_router: IPriceRouterDispatcher,
        pub slippage: u16,
        pub period: u64,
        pub allowed_calls_per_period: u64,
        pub current_window_id: u64,
        pub window_call_count: u64,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        ConfigSet: ConfigSet,
        VaultAllocatorSet: VaultAllocatorSet,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ConfigSet {
        pub slippage: u16,
        pub period: u64,
        pub allowed_calls_per_period: u64,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct VaultAllocatorSet {
        #[key]
        pub vault_allocator: ContractAddress,
    }


    #[embeddable_as(BaseMiddlewareImpl)]
    impl BaseMiddleware<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        impl Upgradeable: UpgradeableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IBaseMiddleware<ComponentState<TContractState>> {
        fn set_config(
            ref self: ComponentState<TContractState>,
            slippage: u16,
            period: u64,
            allowed_calls_per_period: u64,
        ) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();
            self._set_config(slippage, period, allowed_calls_per_period);
            self.emit(ConfigSet { slippage, period, allowed_calls_per_period });
        }

        fn set_vault_allocator(
            ref self: ComponentState<TContractState>, vault_allocator: ContractAddress,
        ) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();

            if vault_allocator.is_zero() {
                Errors::zero_address();
            }
            self.vault_allocator.write(vault_allocator);
            self.emit(VaultAllocatorSet { vault_allocator });
        }

        fn get_vault_allocator(self: @ComponentState<TContractState>) -> ContractAddress {
            self.vault_allocator.read()
        }


        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: starknet::ClassHash) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();

            let mut upgradeable_component = get_dep_component_mut!(ref self, Upgradeable);
            upgradeable_component.upgrade(new_class_hash);
        }

        fn get_slippage(self: @ComponentState<TContractState>) -> u16 {
            self.slippage.read()
        }

        fn get_period(self: @ComponentState<TContractState>) -> u64 {
            self.period.read()
        }

        fn get_allowed_calls_per_period(self: @ComponentState<TContractState>) -> u64 {
            self.allowed_calls_per_period.read()
        }

        fn get_current_window_id(self: @ComponentState<TContractState>) -> u64 {
            self.current_window_id.read()
        }

        fn get_window_call_count(self: @ComponentState<TContractState>) -> u64 {
            self.window_call_count.read()
        }

        fn get_price_router(self: @ComponentState<TContractState>) -> ContractAddress {
            self.price_router.read().contract_address
        }

        fn get_computed_min(
            self: @ComponentState<TContractState>,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
        ) -> u256 {
            let quote_out = self
                .price_router
                .read()
                .get_value(sell_token_address, sell_token_amount, buy_token_address);
            math::u256_mul_div(
                quote_out,
                (BPS_SCALE - self.slippage.read()).into(),
                BPS_SCALE.into(),
                math::Rounding::Ceil,
            )
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize_base_middleware(
            ref self: ComponentState<TContractState>,
            vault_allocator: ContractAddress,
            price_router: ContractAddress,
            slippage: u16,
            period: u64,
            allowed_calls_per_period: u64,
            owner: ContractAddress,
        ) {
            if vault_allocator.is_zero() {
                Errors::zero_address();
            }
            if owner.is_zero() {
                Errors::zero_address();
            }

            if price_router.is_zero() {
                Errors::zero_address();
            }

            // Initialize ownable component
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.initializer(owner);

            // Set storage values
            self.vault_allocator.write(vault_allocator);
            self.price_router.write(IPriceRouterDispatcher { contract_address: price_router });
            self._set_config(slippage, period, allowed_calls_per_period);
        }

        fn enforce_rate_limit(ref self: ComponentState<TContractState>, caller: ContractAddress) {
            if (caller != self.vault_allocator.read()) {
                Errors::caller_not_vault_allocator();
            }

            let period = self.period.read();
            let ts: u64 = get_block_timestamp();
            let window_id: u64 = ts / period;

            if (window_id != self.current_window_id.read()) {
                self.current_window_id.write(window_id);
                self.window_call_count.write(0);
            }

            let current = self.window_call_count.read();
            let next = current + 1;
            let allowed = self.allowed_calls_per_period.read();

            if (next > allowed) {
                Errors::rate_limit_exceeded(next, allowed);
            }
            self.window_call_count.write(next);
        }

        fn _set_config(
            ref self: ComponentState<TContractState>, slippage: u16, period: u64, allowed: u64,
        ) {
            if (slippage >= BPS_SCALE) {
                Errors::slippage_exceeds_max(slippage);
            }
            if (period.is_zero()) {
                Errors::period_zero();
            }
            if (allowed.is_zero()) {
                Errors::allowed_calls_per_period_zero();
            }

            self.slippage.write(slippage);
            self.period.write(period);
            self.allowed_calls_per_period.write(allowed);
            self.current_window_id.write(0);
            self.window_call_count.write(0);
        }
    }
}
