// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod StarkgateMiddleware {
    const BPS_SCALE: u16 = 10_000;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::utils::math;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{
        ContractAddress, EthAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use vault_allocator::integration_interfaces::starkgate::{
        IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait, IStarkgateABIInitiateTokenWithdraw,
    };
    use vault_allocator::middlewares::starkgate_middleware::errors::Errors;
    use vault_allocator::middlewares::starkgate_middleware::interface::IStarkgateMiddleware;
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
        pub starkgate_token_bridge: IStarkgateABIDispatcher,
        pub vault_allocator: ContractAddress,
        pub price_router: IPriceRouterDispatcher,
        pub slippage: u16,
        pub period: u64,
        pub allowed_calls_per_period: u64,
        pub current_window_id: u64,
        pub window_call_count: u64,
        pub token_to_bridge: ContractAddress,
        pub token_to_receive: ContractAddress,
        pub pending_balance: u256,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        vault_allocator: ContractAddress,
        price_router: ContractAddress,
        starkgate_token_bridge: ContractAddress,
        slippage: u16,
        period: u64,
        allowed_calls_per_period: u64,
        token_to_bridge: ContractAddress,
        token_to_receive: ContractAddress,
    ) {
        self.vault_allocator.write(vault_allocator);
        self.price_router.write(IPriceRouterDispatcher { contract_address: price_router });
        self.ownable.initializer(owner);
        self
            .starkgate_token_bridge
            .write(IStarkgateABIDispatcher { contract_address: starkgate_token_bridge });
        self.token_to_bridge.write(token_to_bridge);
        self.token_to_receive.write(token_to_receive);
        self._set_config(slippage, period, allowed_calls_per_period);
    }


    #[abi(embed_v0)]
    impl IStarkgateABIMiddlewareImpl of IStarkgateABIInitiateTokenWithdraw<ContractState> {
        fn initiate_token_withdraw(
            ref self: ContractState, l1_token: EthAddress, l1_recipient: EthAddress, amount: u256,
        ) {
            let caller = get_caller_address();
            self.enforce_rate_limit(caller);
            if (self.pending_balance.read() != Zero::zero()) {
                Errors::pending_value_not_zero();
            }
            let starkgate_token_bridge = self.starkgate_token_bridge.read();
            let l2_token = starkgate_token_bridge.get_l2_token(l1_token);
            if (l2_token != self.token_to_bridge.read()) {
                Errors::invalid_l2_token(l2_token, self.token_to_bridge.read());
            }
            ERC20ABIDispatcher { contract_address: l2_token }
                .transfer_from(caller, get_contract_address(), amount);
            starkgate_token_bridge.initiate_token_withdraw(l1_token, l1_recipient, amount);
            self.pending_balance.write(amount);
        }
    }


    #[abi(embed_v0)]
    impl StarkgateMiddlewareImpl of IStarkgateMiddleware<ContractState> {
        fn claim_token_bridged_back(ref self: ContractState) {
            let token_to_receive = self.token_to_receive.read();
            let min_new_value = math::u256_mul_div(
                self.pending_balance.read(),
                (BPS_SCALE - self.slippage.read()).into(),
                BPS_SCALE.into(),
                math::Rounding::Ceil,
            );
            let token_to_receive_balance = ERC20ABIDispatcher { contract_address: token_to_receive }
                .balance_of(get_caller_address());
            let new_value = self
                .price_router
                .read()
                .get_value(token_to_receive, token_to_receive_balance, self.token_to_bridge.read());

            if (new_value < min_new_value) {
                Errors::insufficient_output(new_value, min_new_value);
            }
            ERC20ABIDispatcher { contract_address: token_to_receive }
                .transfer(self.vault_allocator.read(), token_to_receive_balance);
            self.pending_balance.write(Zero::zero());
        }

        fn set_config(ref self: ContractState, slippage: u16, period: u64, allowed_calls_per_period: u64) {
            self.ownable.assert_only_owner();
            self._set_config(slippage, period, allowed_calls_per_period);
        }

        // View functions
        fn get_starkgate_token_bridge(self: @ContractState) -> ContractAddress {
            self.starkgate_token_bridge.read().contract_address
        }

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

        fn get_token_to_bridge(self: @ContractState) -> ContractAddress {
            self.token_to_bridge.read()
        }

        fn get_token_to_receive(self: @ContractState) -> ContractAddress {
            self.token_to_receive.read()
        }

        fn get_pending_balance(self: @ContractState) -> u256 {
            self.pending_balance.read()
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
