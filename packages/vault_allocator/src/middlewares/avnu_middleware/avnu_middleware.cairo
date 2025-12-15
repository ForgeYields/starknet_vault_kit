// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod AvnuMiddleware {
    const BPS_SCALE: u16 = 10_000;
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use vault_allocator::decoders_and_sanitizers::decoder_custom_types::Route;
    use vault_allocator::integration_interfaces::avnu::{
        IAvnuExchangeDispatcher, IAvnuExchangeDispatcherTrait,
    };
    use vault_allocator::merkle_tree::registery::AVNU_ROUTER;
    use vault_allocator::middlewares::avnu_middleware::errors::Errors;
    use vault_allocator::middlewares::avnu_middleware::interface::IAvnuMiddleware;
    use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: BaseMiddlewareComponent, storage: base_middleware, event: BaseMiddlewareEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl BaseMiddlewareImpl =
        BaseMiddlewareComponent::BaseMiddlewareImpl<ContractState>;
    impl BaseMiddlewareInternalImpl = BaseMiddlewareComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        base_middleware: BaseMiddlewareComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        BaseMiddlewareEvent: BaseMiddlewareComponent::Event,
        ConfigUpdated: ConfigUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ConfigUpdated {
        pub slippage: u16,
        period: u64,
        allowed_calls_per_period: u64,
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
        self.ownable.initializer(owner);
        self
            .base_middleware
            .initialize_base_middleware(
                vault_allocator, price_router, slippage, period, allowed_calls_per_period, owner,
            );
    }


    #[abi(embed_v0)]
    impl AvnuMiddlewareViewImpl of IAvnuMiddleware<ContractState> {
        fn avnu_router(self: @ContractState) -> ContractAddress {
            AVNU_ROUTER()
        }

        fn multi_route_swap(
            ref self: ContractState,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_amount: u256,
            buy_token_min_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            routes: Array<Route>,
        ) -> u256 {
            let caller = get_caller_address();
            self.base_middleware.enforce_rate_limit(caller);
            let this = get_contract_address();

            if (sell_token_amount == Zero::zero()) {
                return Zero::zero();
            }

            if sell_token_address == buy_token_address {
                ERC20ABIDispatcher { contract_address: sell_token_address }
                    .transfer_from(caller, beneficiary, sell_token_amount);
                return sell_token_amount;
            }
            let sell = ERC20ABIDispatcher { contract_address: sell_token_address };
            let buy = ERC20ABIDispatcher { contract_address: buy_token_address };
            let avnu = IAvnuExchangeDispatcher { contract_address: AVNU_ROUTER() };
            sell.transfer_from(caller, this, sell_token_amount);
            sell.approve(avnu.contract_address, sell_token_amount);

            let computed_min = self
                .base_middleware
                .get_computed_min(sell_token_address, sell_token_amount, buy_token_address);

            let min_out = if buy_token_min_amount < computed_min {
                computed_min
            } else {
                buy_token_min_amount
            };
            let buy_bal_0 = buy.balance_of(this);

            avnu
                .multi_route_swap(
                    sell_token_address,
                    sell_token_amount,
                    buy_token_address,
                    Zero::zero(),
                    min_out,
                    this,
                    Zero::zero(),
                    Zero::zero(),
                    routes,
                );
            let buy_bal_1 = buy.balance_of(this);
            let out = buy_bal_1 - buy_bal_0;
            if (out < min_out) {
                Errors::insufficient_output(out, min_out);
            }
            buy.transfer(beneficiary, out);
            out
        }
    }
}
