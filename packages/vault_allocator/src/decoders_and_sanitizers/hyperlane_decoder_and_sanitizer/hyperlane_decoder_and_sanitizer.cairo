// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod HyperlaneDecoderAndSanitizerComponent {
    use alexandria_bytes::Bytes;
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::hyperlane_decoder_and_sanitizer::interface::IHyperlaneDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(HyperlaneDecoderAndSanitizerImpl)]
    impl HyperlaneDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IHyperlaneDecoderAndSanitizer<ComponentState<TContractState>> {
        fn transfer_remote(
            self: @ComponentState<TContractState>,
            destination: u32,
            recipient: u256,
            amount_or_id: u256,
            value: u256,
            hook_metadata: Option<Bytes>,
            hook: Option<ContractAddress>,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            destination.serialize(ref serialized_struct);
            recipient.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
