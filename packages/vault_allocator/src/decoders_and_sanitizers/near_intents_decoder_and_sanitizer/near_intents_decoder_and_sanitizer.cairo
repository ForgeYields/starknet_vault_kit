// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod NearIntentsDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::near_intents_decoder_and_sanitizer::interface::INearIntentsDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(NearIntentsDecoderAndSanitizerImpl)]
    impl NearIntentsDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of INearIntentsDecoderAndSanitizer<ComponentState<TContractState>> {
        /// Pins the token, the relayer `fee` taken from the bridged amount, and the full
        /// `recipient` and `message` byte arrays. `amount` and `native_fee` are left free.
        fn init_transfer(
            self: @ComponentState<TContractState>,
            token_address: ContractAddress,
            amount: u128,
            fee: u128,
            native_fee: u128,
            recipient: ByteArray,
            message: ByteArray,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            token_address.serialize(ref serialized_struct);
            fee.serialize(ref serialized_struct);
            recipient.serialize(ref serialized_struct);
            message.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
