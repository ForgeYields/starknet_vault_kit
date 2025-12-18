// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod HyperlaneMiddlewareDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::hyperlane_middleware_decoder_and_sanitizer::interface::IHyperlaneMiddlewareDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(HyperlaneMiddlewareDecoderAndSanitizerImpl)]
    impl HyperlaneMiddlewareDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IHyperlaneMiddlewareDecoderAndSanitizer<ComponentState<TContractState>> {
        fn bridge_token(
            self: @ComponentState<TContractState>,
            token_to_bridge: ContractAddress,
            token_to_claim: ContractAddress,
            destination_domain: u32,
            recipient: u256,
            amount: u256,
            value: u256,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            token_to_bridge.serialize(ref serialized_struct);
            token_to_claim.serialize(ref serialized_struct);
            destination_domain.serialize(ref serialized_struct);
            recipient.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
