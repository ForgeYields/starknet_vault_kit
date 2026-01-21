// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod LzMiddleware {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use vault_allocator::integration_interfaces::lz::{
        IOFTDispatcher, IOFTDispatcherTrait, MessagingFee, SendParam,
    };
    use vault_allocator::merkle_tree::registery::STRK;
    use vault_allocator::middlewares::base_middleware::base_middleware::BaseMiddlewareComponent;
    use vault_allocator::middlewares::lz_middleware::errors::Errors;
    use vault_allocator::middlewares::lz_middleware::interface::ILzMiddleware;

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
        BridgeInitiated: BridgeInitiated,
        ClaimedToken: ClaimedToken,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct BridgeInitiated {
        pub underlying_token: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub dst_eid: u32,
        pub to: u256,
        pub amount: u256,
        pub guid: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct ClaimedToken {
        pub underlying_token: ContractAddress,
        pub token_to_claim: ContractAddress,
        pub dst_eid: u32,
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
    impl ILzMiddlewareImpl of ILzMiddleware<ContractState> {
        fn send(
            ref self: ContractState,
            oft: ContractAddress,
            underlying_token: ContractAddress,
            token_to_claim: ContractAddress,
            send_param: SendParam,
            fee: MessagingFee,
            refund_address: ContractAddress,
        ) {
            let caller = get_caller_address();
            self.base_middleware.enforce_rate_limit(caller);

            let dst_eid = send_param.dst_eid;
            let amount = send_param.amount_ld;
            let to = send_param.to;

            // Check that pending balance is zero for this underlying_token/token_to_claim/dst_eid combination
            let current_pending = self
                .pending_balance
                .read((underlying_token, token_to_claim, dst_eid));
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
            self.pending_balance.write((underlying_token, token_to_claim, dst_eid), amount);

            // Transfer STRK from caller to this contract for bridge fees (native_fee)
            let native_fee = fee.native_fee;
            if native_fee > Zero::zero() {
                ERC20ABIDispatcher { contract_address: STRK() }
                    .transfer_from(caller, get_contract_address(), native_fee);

                // Approve OFT contract to pull STRK for fees
                ERC20ABIDispatcher { contract_address: STRK() }.approve(oft, native_fee);
            }

            // Transfer underlying token from caller to this contract
            ERC20ABIDispatcher { contract_address: underlying_token }
                .transfer_from(caller, get_contract_address(), amount);

            // For adapter OFT (oft != underlying_token), approve OFT to pull underlying token
            if oft != underlying_token {
                ERC20ABIDispatcher { contract_address: underlying_token }.approve(oft, amount);
            }

            // Call send on the OFT contract
            let result = IOFTDispatcher { contract_address: oft }
                .send(send_param, fee, refund_address);

            let guid = result.message_receipt.guid;

            self
                .emit(
                    BridgeInitiated { underlying_token, token_to_claim, dst_eid, to, amount, guid },
                );
        }

        fn claim_token(
            ref self: ContractState,
            underlying_token: ContractAddress,
            token_to_claim: ContractAddress,
            dst_eid: u32,
        ) {
            let pending = self.pending_balance.read((underlying_token, token_to_claim, dst_eid));
            if (pending == Zero::zero()) {
                Errors::pending_balance_zero();
            }

            let min_new_value = self
                .base_middleware
                .get_computed_min(underlying_token, pending, token_to_claim);
            let token_balance = ERC20ABIDispatcher { contract_address: token_to_claim }
                .balance_of(get_contract_address());
            if (token_balance < min_new_value) {
                Errors::insufficient_output(token_balance, min_new_value);
            }

            self.pending_balance.write((underlying_token, token_to_claim, dst_eid), Zero::zero());

            ERC20ABIDispatcher { contract_address: token_to_claim }
                .transfer(self.base_middleware.vault_allocator.read(), token_balance);

            self
                .emit(
                    ClaimedToken {
                        underlying_token, token_to_claim, dst_eid, amount_claimed: token_balance,
                    },
                );
        }

        fn get_pending_balance(
            self: @ContractState,
            underlying_token: ContractAddress,
            token_to_claim: ContractAddress,
            dst_eid: u32,
        ) -> u256 {
            self.pending_balance.read((underlying_token, token_to_claim, dst_eid))
        }
    }
}
