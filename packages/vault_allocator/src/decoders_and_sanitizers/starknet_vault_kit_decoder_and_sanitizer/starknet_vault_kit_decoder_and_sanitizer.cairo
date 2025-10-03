// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod StarknetVaultKitDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent::Erc4626DecoderAndSanitizerImpl;
    use vault_allocator::decoders_and_sanitizers::starknet_vault_kit_decoder_and_sanitizer::interface::IStarknetVaultKitDecoderAndSanitizer;
    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(VesuDecoderAndSanitizerImpl)]
    impl StarknetVaultKitDecoderAndSanitizer<
        TContractState,
        +HasComponent<TContractState>,
        +Erc4626DecoderAndSanitizerComponent::HasComponent<TContractState>,
    > of IStarknetVaultKitDecoderAndSanitizer<ComponentState<TContractState>> {
        fn request_redeem(
            self: @ComponentState<TContractState>,
            shares: u256,
            receiver: ContractAddress,
            owner: ContractAddress,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            receiver.serialize(ref serialized_struct);
            owner.serialize(ref serialized_struct);
            serialized_struct.span()
        }

        fn claim_redeem(self: @ComponentState<TContractState>, id: u256) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            serialized_struct.span()
        }
    }
}
