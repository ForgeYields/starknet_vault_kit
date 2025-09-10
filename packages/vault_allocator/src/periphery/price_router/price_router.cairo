// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod PriceRouter {
    use core::num::traits::{Pow, Zero};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::utils::math;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use vault_allocator::integration_interfaces::pragma::{
        DataType, IPragmaABIDispatcher, IPragmaABIDispatcherTrait, PragmaPricesResponse,
    };
    use vault_allocator::periphery::price_router::errors::Errors;
    use vault_allocator::periphery::price_router::interface::IPriceRouter;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        pragma: IPragmaABIDispatcher,
        asset_to_id: Map<ContractAddress, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, pragma: ContractAddress) {
        self.ownable.initializer(owner);
        self.pragma.write(IPragmaABIDispatcher { contract_address: pragma });
    }


    #[abi(embed_v0)]
    impl PriceRouterImpl of IPriceRouter<ContractState> {
        fn get_value(
            self: @ContractState,
            base_asset: ContractAddress,
            amount: u256,
            quote_asset: ContractAddress,
        ) -> u256 {
            if base_asset == quote_asset {
                return amount;
            }

            let base_id: felt252 = self.asset_to_id.read(base_asset);
            if base_id.is_zero() {
                Errors::asset_not_found(base_asset);
            }
            let quote_id: felt252 = self.asset_to_id.read(quote_asset);
            if quote_id.is_zero() {
                Errors::asset_not_found(quote_asset);
            }

            let base_resp = self.get_asset_price(base_id); // USD price with its own decimals
            let quote_resp = self.get_asset_price(quote_id);

            let base_price: u256 = base_resp.price.into();
            let quote_price: u256 = quote_resp.price.into();

            let pragma_decimals_base: u32 = base_resp.decimals;
            let pragma_decimals_quote: u32 = quote_resp.decimals;

            let asset_decimals_base: u8 = ERC20ABIDispatcher { contract_address: base_asset }
                .decimals();
            let asset_decimals_quote: u8 = ERC20ABIDispatcher { contract_address: quote_asset }
                .decimals();

            let scale_base: u256 = 10_u256.pow(pragma_decimals_base + asset_decimals_base.into());
            let scale_quote: u256 = 10_u256
                .pow(pragma_decimals_quote + asset_decimals_quote.into());

            let num: u256 = amount * base_price * scale_quote;
            let den: u256 = quote_price * scale_base;
            math::u256_mul_div(num, 1, den, math::Rounding::Ceil)
        }
        fn asset_to_id(self: @ContractState, asset: ContractAddress) -> felt252 {
            self.asset_to_id.read(asset)
        }

        fn set_asset_to_id(ref self: ContractState, asset: ContractAddress, id: felt252) {
            self.ownable.assert_only_owner();
            self.asset_to_id.write(asset, id);
        }

        fn get_asset_price(self: @ContractState, asset_id: felt252) -> PragmaPricesResponse {
            self.pragma.read().get_data_median(DataType::SpotEntry(asset_id))
        }
    }
}
