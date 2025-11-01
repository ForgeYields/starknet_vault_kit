// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod ParadexGigavaultDecoderAndSanitizerComponent {
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::paradex_gigavault_decoder_and_sanitizer::interface::IParadexGigavaultDecoderAndSanitizer;
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(ParadexGigavaultDecoderAndSanitizerImpl)]
    impl ParadexGigavaultDecoderAndSanitizer<
        TContractState,
        +HasComponent<TContractState>,
        +Erc4626DecoderAndSanitizerComponent::HasComponent<TContractState>,
    > of IParadexGigavaultDecoderAndSanitizer<ComponentState<TContractState>> {
        fn request_withdrawal(
            self: @ComponentState<TContractState>, shares: u256,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
