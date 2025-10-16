// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod ExtendedDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::extended_decoder_and_sanitizer::interface::IExtendedDecoderAndSanitizer;
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(StarkgateDecoderAndSanitizerImpl)]
    impl ExtendedDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IExtendedDecoderAndSanitizer<ComponentState<TContractState>> {
        fn deposit(
            self: @ComponentState<TContractState>,
            vault_number: felt252,
            amount: felt252,
            nonce: felt252,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            vault_number.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
