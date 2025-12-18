// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod StarkgateMiddleware {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    };
    use starknet::{ContractAddress, EthAddress, get_caller_address, get_contract_address};
    use vault_allocator::integration_interfaces::starkgate::{
        IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait,
    };
    use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;
    use vault_allocator::middlewares::starkgate_middleware::errors::Errors;
    use vault_allocator::middlewares::starkgate_middleware::interface::IStarkgateMiddleware;

    // --- Component Integrations ---
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: BaseMiddlewareComponent, storage: base_middleware, event: BaseMiddlewareEvent);

    // --- Component Implementations ---
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl BaseMiddlewareInternalImpl = BaseMiddlewareComponent::InternalImpl<ContractState>;

    // --- Embedded Component Implementations ---
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
        pub pending_balance: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        BaseMiddlewareEvent: BaseMiddlewareComponent::Event,
        WithdrawInitiated: WithdrawInitiated,
        ClaimedToken: ClaimedToken,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct WithdrawInitiated {
        pub token_to_bridge: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub l1_token: EthAddress,
        pub l1_recipient: EthAddress,
        pub amount: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ClaimedToken {
        pub token_to_bridge: ContractAddress,
        pub token_to_claim: ContractAddress,
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
        self
            .base_middleware
            .initialize_base_middleware(
                vault_allocator, price_router, slippage, period, allowed_calls_per_period, owner,
            );
    }

    #[abi(embed_v0)]
    impl StarkgateMiddlewareImpl of IStarkgateMiddleware<ContractState> {
        fn initiate_token_withdraw(
            ref self: ContractState,
            starkgate_token_bridge: ContractAddress,
            l1_token: EthAddress,
            l1_recipient: EthAddress,
            amount: u256,
            token_to_claim: ContractAddress,
        ) {
            let caller = get_caller_address();
            self.base_middleware.enforce_rate_limit(caller);

            let bridge = IStarkgateABIDispatcher { contract_address: starkgate_token_bridge };
            let token_to_bridge = bridge.get_l2_token(l1_token);

            // Check that pending balance is zero for this token pair
            let current_pending = self.pending_balance.read((token_to_bridge, token_to_claim));
            if (current_pending != Zero::zero()) {
                Errors::pending_value_not_zero();
            }

            // Check that the middleware's balance of token_to_claim is zero
            let token_to_claim_balance = ERC20ABIDispatcher { contract_address: token_to_claim }
                .balance_of(get_contract_address());
            if (token_to_claim_balance != Zero::zero()) {
                Errors::claimable_value_not_zero();
            }

            // Track pending balance
            self.pending_balance.write((token_to_bridge, token_to_claim), amount);

            // Transfer token from caller to this contract
            ERC20ABIDispatcher { contract_address: token_to_bridge }
                .transfer_from(caller, get_contract_address(), amount);

            // Initiate the withdrawal
            bridge.initiate_token_withdraw(l1_token, l1_recipient, amount);

            self
                .emit(
                    WithdrawInitiated {
                        token_to_bridge, token_to_claim, l1_token, l1_recipient, amount,
                    },
                );
        }

        fn claim_token(
            ref self: ContractState,
            token_to_bridge: ContractAddress,
            token_to_claim: ContractAddress,
        ) {
            let pending = self.pending_balance.read((token_to_bridge, token_to_claim));
            if (pending == Zero::zero()) {
                Errors::pending_balance_zero();
            }
            let min_new_value = self
                .base_middleware
                .get_computed_min(token_to_bridge, pending, token_to_claim);
            let token_balance = ERC20ABIDispatcher { contract_address: token_to_claim }
                .balance_of(get_contract_address());

            if (token_balance < min_new_value) {
                Errors::insufficient_output(token_balance, min_new_value);
            }

            self.pending_balance.write((token_to_bridge, token_to_claim), Zero::zero());

            ERC20ABIDispatcher { contract_address: token_to_claim }
                .transfer(self.base_middleware.vault_allocator.read(), token_balance);

            self
                .emit(
                    ClaimedToken {
                        token_to_bridge, token_to_claim, amount_claimed: token_balance,
                    },
                );
        }

        // View functions
        fn get_pending_balance(
            self: @ContractState,
            token_to_bridge: ContractAddress,
            token_to_claim: ContractAddress,
        ) -> u256 {
            self.pending_balance.read((token_to_bridge, token_to_claim))
        }
    }
}
