// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod BaseDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::interface::IBaseDecoderAndSanitizer;

    #[storage]
    pub struct Storage {
        pub vault_allocator: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(BaseDecoderAndSanitizerImpl)]
    impl BaseDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of IBaseDecoderAndSanitizer<ComponentState<TContractState>> {
        fn approve(
            self: @ComponentState<TContractState>, spender: ContractAddress, amount: u256,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            spender.serialize(ref serialized_struct);
            serialized_struct.span()
        }


        fn bring_liquidity(self: @ComponentState<TContractState>, amount: u256) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
