// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod CctpDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::cctp_decoder_and_sanitizer::interface::ICctpDecoderAndSanitizer;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(CctpDecoderAndSanitizerImpl)]
    impl CctpDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of ICctpDecoderAndSanitizer<ComponentState<TContractState>> {
        fn deposit_for_burn(
            self: @ComponentState<TContractState>,
            amount: u256,
            destination_domain: u32,
            mint_recipient: u256,
            burn_token: ContractAddress,
            destination_caller: u256,
            max_fee: u256,
            min_finality_threshold: u32,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            destination_domain.serialize(ref serialized_struct);
            mint_recipient.serialize(ref serialized_struct);
            burn_token.serialize(ref serialized_struct);
            destination_caller.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
