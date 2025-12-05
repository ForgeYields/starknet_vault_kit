// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod EkuboAdapterDecoderAndSanitizerComponent {
    use vault_allocator::decoders_and_sanitizers::ekubo_adapter_decoder_and_sanitizer::interface::IEkuboAdapterDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(EkuboAdapterDecoderAndSanitizerImpl)]
    impl EkuboAdapterDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IEkuboAdapterDecoderAndSanitizer<ComponentState<TContractState>> {
        fn deposit_liquidity(
            self: @ComponentState<TContractState>, amount0: u256, amount1: u256,
        ) -> Span<felt252> {
            // No addresses to sanitize - amounts are value parameters
            let serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }

        fn withdraw_liquidity(
            self: @ComponentState<TContractState>,
            ratioWad: u256,
            min_token0: u128,
            min_token1: u128,
        ) -> Span<felt252> {
            // No addresses to sanitize - all parameters are value types
            let serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }

        fn collect_fees(self: @ComponentState<TContractState>) -> Span<felt252> {
            // No addresses to sanitize - no parameters
            let serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
