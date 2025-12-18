// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod StarkgateDecoderAndSanitizerComponent {
    use starknet::EthAddress;
    use vault_allocator::decoders_and_sanitizers::starkgate_decoder_and_sanitizer::interface::IStarkgateDecoderAndSanitizer;
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(StarkgateDecoderAndSanitizerImpl)]
    impl StarkgateDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IStarkgateDecoderAndSanitizer<ComponentState<TContractState>> {
        fn initiate_token_withdraw(
            self: @ComponentState<TContractState>,
            l1_token: EthAddress,
            l1_recipient: EthAddress,
            amount: u256,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            l1_token.serialize(ref serialized_struct);
            l1_recipient.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
