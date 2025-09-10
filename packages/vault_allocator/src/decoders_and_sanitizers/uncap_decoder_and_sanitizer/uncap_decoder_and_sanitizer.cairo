// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod UnCapDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::uncap_decoder_and_sanitizer::interface::IUnCapDecoderAndSanitizer;

    #[storage]
    pub struct Storage {
        pub vault_allocator: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(UnCapDecoderAndSanitizerImpl)]
    impl UnCapDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IUnCapDecoderAndSanitizer<ComponentState<TContractState>> {
        fn provide_to_sp(
            self: @ComponentState<TContractState>, top_up: u256, do_claim: bool,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }

        fn withdraw_from_sp(
            self: @ComponentState<TContractState>, amount: u256, do_claim: bool,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
