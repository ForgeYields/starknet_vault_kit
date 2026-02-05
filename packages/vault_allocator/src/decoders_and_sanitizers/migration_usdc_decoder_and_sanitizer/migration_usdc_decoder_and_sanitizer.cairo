// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod MigrationUsdcDecoderAndSanitizerComponent {
    use vault_allocator::decoders_and_sanitizers::migration_usdc_decoder_and_sanitizer::interface::IMigrationUsdcDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(MigrationUsdcDecoderAndSanitizerImpl)]
    impl MigrationUsdcDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IMigrationUsdcDecoderAndSanitizer<ComponentState<TContractState>> {
        fn swap_to_new(self: @ComponentState<TContractState>, amount: u256) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }

        fn swap_to_legacy(self: @ComponentState<TContractState>, amount: u256) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
