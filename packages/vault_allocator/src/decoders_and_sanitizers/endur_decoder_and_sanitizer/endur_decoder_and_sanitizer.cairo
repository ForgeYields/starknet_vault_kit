// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod EndurDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::endur_decoder_and_sanitizer::interface::IEndurDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(EndurDecoderAndSanitizerImpl)]
    impl EndurDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IEndurDecoderAndSanitizer<ComponentState<TContractState>> {
        fn deposit_with_referral(
            self: @ComponentState<TContractState>,
            assets: u256,
            receiver: ContractAddress,
            referral: ByteArray,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            receiver.serialize(ref serialized_struct);
            serialized_struct.span()
        }

        fn claim_withdrawal(
            self: @ComponentState<TContractState>, request_id: u128,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
