// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod ForgeyieldsParadexDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::paradex_gigavault_decoder_and_sanitizer::paradex_gigavault_decoder_and_sanitizer::ParadexGigavaultDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starkgate_decoder_and_sanitizer::starkgate_decoder_and_sanitizer::StarkgateDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: ParadexGigavaultDecoderAndSanitizerComponent,
        storage: paradex_gigavault_decoder_and_sanitizer,
        event: ParadexGigavaultDecoderAndSanitizerEvent,
    );

    component!(
        path: Erc4626DecoderAndSanitizerComponent,
        storage: erc4626_decoder_and_sanitizer,
        event: Erc4626DecoderAndSanitizerEvent,
    );

    component!(
        path: StarkgateDecoderAndSanitizerComponent,
        storage: starkgate_decoder_and_sanitizer,
        event: StarkgateDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl ParadexGigavaultDecoderAndSanitizerImpl =
        ParadexGigavaultDecoderAndSanitizerComponent::ParadexGigavaultDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[abi(embed_v0)]
    impl Erc4626DecoderAndSanitizerImpl =
        Erc4626DecoderAndSanitizerComponent::Erc4626DecoderAndSanitizerImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub paradex_gigavault_decoder_and_sanitizer: ParadexGigavaultDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub erc4626_decoder_and_sanitizer: Erc4626DecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starkgate_decoder_and_sanitizer: StarkgateDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        ParadexGigavaultDecoderAndSanitizerEvent: ParadexGigavaultDecoderAndSanitizerComponent::Event,
        #[flat]
        Erc4626DecoderAndSanitizerEvent: Erc4626DecoderAndSanitizerComponent::Event,
        #[flat]
        StarkgateDecoderAndSanitizerEvent: StarkgateDecoderAndSanitizerComponent::Event,
    }
}
