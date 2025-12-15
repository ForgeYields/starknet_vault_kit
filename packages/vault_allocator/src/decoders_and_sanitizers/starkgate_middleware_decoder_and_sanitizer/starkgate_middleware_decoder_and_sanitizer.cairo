// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod StarkgateMiddlewareDecoderAndSanitizerComponent {
    use starknet::{ContractAddress, EthAddress};
    use vault_allocator::decoders_and_sanitizers::starkgate_middleware_decoder_and_sanitizer::interface::IStarkgateMiddlewareDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(StarkgateMiddlewareDecoderAndSanitizerImpl)]
    impl StarkgateMiddlewareDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IStarkgateMiddlewareDecoderAndSanitizer<ComponentState<TContractState>> {
        fn initiate_token_withdraw(
            self: @ComponentState<TContractState>,
            starkgate_token_bridge: ContractAddress,
            l1_token: EthAddress,
            l1_recipient: EthAddress,
            amount: u256,
            token_to_claim: ContractAddress,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            starkgate_token_bridge.serialize(ref serialized_struct);
            l1_token.serialize(ref serialized_struct);
            l1_recipient.serialize(ref serialized_struct);
            token_to_claim.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
