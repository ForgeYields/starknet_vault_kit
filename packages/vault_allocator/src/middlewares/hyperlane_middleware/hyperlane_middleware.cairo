// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod HyperlaneMiddleware {
    const BPS_SCALE: u16 = 10_000;
    use core::num::traits::Zero;
    use alexandria_bytes::Bytes;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::utils::math;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use vault_allocator::integration_interfaces::hyperlane::{
        IHyperlaneTokenRouterDispatcher, IHyperlaneTokenRouterDispatcherTrait,
    };
    use vault_allocator::middlewares::hyperlane_middleware::errors::Errors;
    use vault_allocator::middlewares::hyperlane_middleware::interface::IHyperlaneMiddleware;
    use vault_allocator::periphery::price_router::interface::{
        IPriceRouterDispatcher, IPriceRouterDispatcherTrait,
    };

    // --- OpenZeppelin Component Integrations ---
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // --- Component Implementations ---
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
        pub vault_allocator: ContractAddress,
        pub price_router: IPriceRouterDispatcher,
        pub slippage: u16,
        pub period: u64,
        pub allowed_calls_per_period: u64,
        pub current_window_id: u64,
        pub window_call_count: u64,
        pub pending_balance: LegacyMap<(ContractAddress, ContractAddress, u32), u256>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        BridgeInitiated: BridgeInitiated,
        ClaimedToken: ClaimedToken,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BridgeInitiated {
        pub token_to_bridge: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub destination_domain: u32,
        pub recipient: u256,
        pub amount: u256,
        pub message_id: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ClaimedToken {
        pub token_to_bridge: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub destination_domain: u32,
        pub amount_claimed: u256,
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
        self.vault_allocator.write(vault_allocator);
        self.price_router.write(IPriceRouterDispatcher { contract_address: price_router });
        self.ownable.initializer(owner);
        self._set_config(slippage, period, allowed_calls_per_period);
    }

    #[abi(embed_v0)]
    impl IHyperlaneMiddlewareImpl of IHyperlaneMiddleware<ContractState> {
        fn bridge_token(
            ref self: ContractState,
            token_to_bridge: ContractAddress,
            token_to_claim: ContractAddress,
            destination_domain: u32,
            recipient: u256,
            amount: u256,
        ) -> u256 {
            let caller = get_caller_address();
            self.enforce_rate_limit(caller);

            // Check that pending balance is zero for this pair/domain combination
            let key = (token_to_bridge, token_to_claim, destination_domain);
            let current_pending = self.pending_balance.read(key);
            if (current_pending != Zero::zero()) {
                Errors::pending_value_not_zero();
            }

            // Track pending balance with composite key
            self.pending_balance.write(key, amount);

            // Transfer tokens from caller to this contract
            ERC20ABIDispatcher { contract_address: token_to_bridge }
                .transfer_from(caller, get_contract_address(), amount);

            // Approve the token contract (itself implementing transfer_remote) to pull tokens from this middleware
            ERC20ABIDispatcher { contract_address: token_to_bridge }
                .approve(token_to_bridge, amount);

            // Call transfer_remote on the token contract directly
            let message_id = IHyperlaneTokenRouterDispatcher { contract_address: token_to_bridge }
                .transfer_remote(destination_domain, recipient, amount, Option::None, Option::None);

            self.emit(BridgeInitiated { token_to_bridge, token_to_claim, destination_domain, recipient, amount, message_id });

            message_id
        }

        fn claim_token(
            ref self: ContractState,
            token_to_bridge: ContractAddress,
            token_to_claim: ContractAddress,
            destination_domain: u32,
        ) {
            let key = (token_to_bridge, token_to_claim, destination_domain);
            let pending = self.pending_balance.read(key);
            if (pending == Zero::zero()) {
                Errors::pending_balance_zero();
            }
            let min_new_value = math::u256_mul_div(
                pending,
                (BPS_SCALE - self.slippage.read()).into(),
                BPS_SCALE.into(),
                math::Rounding::Ceil,
            );
            let token_balance = ERC20ABIDispatcher { contract_address: token_to_claim }
                .balance_of(get_contract_address());
            let new_value = self
                .price_router
                .read()
                .get_value(token_to_claim, token_balance, token_to_bridge);

            if (new_value < min_new_value) {
                Errors::insufficient_output(new_value, min_new_value);
            }

            self.pending_balance.write(key, Zero::zero());

            ERC20ABIDispatcher { contract_address: token_to_claim }
                .transfer(self.vault_allocator.read(), token_balance);

            self.emit(ClaimedToken { token_to_bridge, token_to_claim, destination_domain, token_balance });
        }

        fn set_config(
            ref self: ContractState, slippage: u16, period: u64, allowed_calls_per_period: u64,
        ) {
            self.ownable.assert_only_owner();
            self._set_config(slippage, period, allowed_calls_per_period);
        }

        // View functions
        fn get_vault_allocator(self: @ContractState) -> ContractAddress {
            self.vault_allocator.read()
        }

        fn get_price_router(self: @ContractState) -> ContractAddress {
            self.price_router.read().contract_address
        }

        fn get_slippage(self: @ContractState) -> u16 {
            self.slippage.read()
        }

        fn get_period(self: @ContractState) -> u64 {
            self.period.read()
        }

        fn get_allowed_calls_per_period(self: @ContractState) -> u64 {
            self.allowed_calls_per_period.read()
        }

        fn get_current_window_id(self: @ContractState) -> u64 {
            self.current_window_id.read()
        }

        fn get_window_call_count(self: @ContractState) -> u64 {
            self.window_call_count.read()
        }

        fn get_pending_balance(self: @ContractState, token_to_bridge: ContractAddress, token_to_claim: ContractAddress, destination_domain: u32) -> u256 {
            self.pending_balance.read((token_to_bridge, token_to_claim, destination_domain))
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        fn enforce_rate_limit(ref self: ContractState, caller: ContractAddress) {
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

        fn _set_config(ref self: ContractState, slippage: u16, period: u64, allowed: u64) {
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
