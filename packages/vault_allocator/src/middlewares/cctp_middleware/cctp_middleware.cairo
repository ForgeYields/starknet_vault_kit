// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod CctpMiddleware {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use vault_allocator::integration_interfaces::cctp::{
        ICctpTokenBridgeDispatcher, ICctpTokenBridgeDispatcherTrait,
    };
    use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;
    use vault_allocator::middlewares::cctp_middleware::errors::Errors;
    use vault_allocator::middlewares::cctp_middleware::interface::ICctpMiddleware;

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
        pub cctp_token_bridge: ICctpTokenBridgeDispatcher,
        pub pending_balance: Map<(ContractAddress, ContractAddress, u32), u256>,
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
        DepositForBurnInitiated: DepositForBurnInitiated,
        ClaimedToken: ClaimedToken,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DepositForBurnInitiated {
        pub burn_token: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub destination_domain: u32,
        pub mint_recipient: u256,
        pub amount: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ClaimedToken {
        pub burn_token: ContractAddress,
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
        cctp_token_bridge: ContractAddress,
        slippage: u16,
        period: u64,
        allowed_calls_per_period: u64,
    ) {
        self
            .base_middleware
            .initialize_base_middleware(
                vault_allocator, price_router, slippage, period, allowed_calls_per_period, owner,
            );
        self
            .cctp_token_bridge
            .write(ICctpTokenBridgeDispatcher { contract_address: cctp_token_bridge });
    }

    #[abi(embed_v0)]
    impl ICctpMiddlewareImpl of ICctpMiddleware<ContractState> {
        fn deposit_for_burn(
            ref self: ContractState,
            amount: u256,
            destination_domain: u32,
            mint_recipient: u256,
            burn_token: ContractAddress,
            token_to_claim: ContractAddress,
            destination_caller: u256,
            max_fee: u256,
            min_finality_threshold: u32,
        ) {
            let caller = get_caller_address();
            self.base_middleware.enforce_rate_limit(caller);

            // Check that pending balance is zero for this pair/domain combination
            let current_pending = self
                .pending_balance
                .read((burn_token, token_to_claim, destination_domain));
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
            self.pending_balance.write((burn_token, token_to_claim, destination_domain), amount);

            // Transfer burn_token from caller to this contract
            ERC20ABIDispatcher { contract_address: burn_token }
                .transfer_from(caller, get_contract_address(), amount);

            // Approve CCTP token bridge to pull burn_token
            ERC20ABIDispatcher { contract_address: burn_token }
                .approve(self.cctp_token_bridge.read().contract_address, amount);

            // Call deposit_for_burn on the CCTP token bridge
            self
                .cctp_token_bridge
                .read()
                .deposit_for_burn(
                    amount,
                    destination_domain,
                    mint_recipient,
                    burn_token,
                    destination_caller,
                    max_fee,
                    min_finality_threshold,
                );

            self
                .emit(
                    DepositForBurnInitiated {
                        burn_token, token_to_claim, destination_domain, mint_recipient, amount,
                    },
                );
        }

        fn claim_token(
            ref self: ContractState,
            burn_token: ContractAddress,
            token_to_claim: ContractAddress,
            destination_domain: u32,
        ) {
            let pending = self
                .pending_balance
                .read((burn_token, token_to_claim, destination_domain));
            if (pending == Zero::zero()) {
                Errors::pending_balance_zero();
            }
            let min_new_value = self
                .base_middleware
                .get_computed_min(burn_token, pending, token_to_claim);
            let token_balance = ERC20ABIDispatcher { contract_address: token_to_claim }
                .balance_of(get_contract_address());

            if (token_balance < min_new_value) {
                Errors::insufficient_output(token_balance, min_new_value);
            }

            self
                .pending_balance
                .write((burn_token, token_to_claim, destination_domain), Zero::zero());

            ERC20ABIDispatcher { contract_address: token_to_claim }
                .transfer(self.base_middleware.vault_allocator.read(), token_balance);

            self
                .emit(
                    ClaimedToken {
                        burn_token,
                        token_to_claim,
                        destination_domain,
                        amount_claimed: token_balance,
                    },
                );
        }

        fn get_cctp_token_bridge(self: @ContractState) -> ContractAddress {
            self.cctp_token_bridge.read().contract_address
        }

        fn get_pending_balance(
            self: @ContractState,
            burn_token: ContractAddress,
            token_to_claim: ContractAddress,
            destination_domain: u32,
        ) -> u256 {
            self.pending_balance.read((burn_token, token_to_claim, destination_domain))
        }
    }
}
