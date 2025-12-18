// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// work for interacting directly with the avnu router or using the avnu middleware
#[starknet::component]
pub mod AvnuExchangeDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::avnu_exchange_decoder_and_sanitizer::interface::IAvnuExchangeDecoderAndSanitizer;
    use vault_allocator::decoders_and_sanitizers::decoder_custom_types::Route;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(AvnuExchangeDecoderAndSanitizerImpl)]
    impl AvnuExchangeDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IAvnuExchangeDecoderAndSanitizer<ComponentState<TContractState>> {
        fn multi_route_swap(
            self: @ComponentState<TContractState>,
            sell_token_address: ContractAddress,
            sell_token_amount: u256,
            buy_token_address: ContractAddress,
            buy_token_amount: u256,
            buy_token_min_amount: u256,
            beneficiary: ContractAddress,
            integrator_fee_amount_bps: u128,
            integrator_fee_recipient: ContractAddress,
            routes: Array<Route>,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@sell_token_address, ref serialized_struct);
            Serde::serialize(@buy_token_address, ref serialized_struct);
            Serde::serialize(@beneficiary, ref serialized_struct);
            serialized_struct.span()
        }
    }
}
