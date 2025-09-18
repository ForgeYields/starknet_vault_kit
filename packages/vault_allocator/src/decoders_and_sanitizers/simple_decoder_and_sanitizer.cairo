// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod SimpleDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::avnu_exchange_decoder_and_sanitizer::avnu_exchange_decoder_and_sanitizer::AvnuExchangeDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::multiply_decoder_and_sanitizer::multiply_decoder_and_sanitizer::MultiplyDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starknet_vault_kit_decoder_and_sanitizer::starknet_vault_kit_decoder_and_sanitizer::StarknetVaultKitDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::vesu_decoder_and_sanitizer::vesu_decoder_and_sanitizer::VesuDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::defi_spring_snf_style::defi_spring_snf_style_decoder_and_sanitizer::DefiSpringSNFStyleDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );
    component!(
        path: Erc4626DecoderAndSanitizerComponent,
        storage: erc4626_decoder_and_sanitizer,
        event: Erc4626DecoderAndSanitizerEvent,
    );

    component!(
        path: StarknetVaultKitDecoderAndSanitizerComponent,
        storage: starknet_vault_kit_decoder_and_sanitizer,
        event: StarknetVaultKitDecoderAndSanitizerEvent,
    );

    component!(
        path: VesuDecoderAndSanitizerComponent,
        storage: vesu_decoder_and_sanitizer,
        event: VesuDecoderAndSanitizerEvent,
    );

    component!(
        path: AvnuExchangeDecoderAndSanitizerComponent,
        storage: avnu_exchange_decoder_and_sanitizer,
        event: AvnuExchangeDecoderAndSanitizerEvent,
    );

    component!(
        path: MultiplyDecoderAndSanitizerComponent,
        storage: multiply_decoder_and_sanitizer,
        event: MultiplyDecoderAndSanitizerEvent,
    );

    component!(
        path: DefiSpringSNFStyleDecoderAndSanitizerComponent,
        storage: defi_spring_snf_style_decoder_and_sanitizer,
        event: DefiSpringSNFStyleDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl Erc4626DecoderAndSanitizerImpl =
        Erc4626DecoderAndSanitizerComponent::Erc4626DecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl VesuDecoderAndSanitizerImpl =
        VesuDecoderAndSanitizerComponent::VesuDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl AvnuExchangeDecoderAndSanitizerImpl =
        AvnuExchangeDecoderAndSanitizerComponent::AvnuExchangeDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[abi(embed_v0)]
    impl MultiplyDecoderAndSanitizerImpl =
        MultiplyDecoderAndSanitizerComponent::MultiplyDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl DefiSpringSNFStyleDecoderAndSanitizerImpl =
        DefiSpringSNFStyleDecoderAndSanitizerComponent::DefiSpringSNFStyleDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub erc4626_decoder_and_sanitizer: Erc4626DecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub vesu_decoder_and_sanitizer: VesuDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub avnu_exchange_decoder_and_sanitizer: AvnuExchangeDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starknet_vault_kit_decoder_and_sanitizer: StarknetVaultKitDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub multiply_decoder_and_sanitizer: MultiplyDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub defi_spring_snf_style_decoder_and_sanitizer: DefiSpringSNFStyleDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        Erc4626DecoderAndSanitizerEvent: Erc4626DecoderAndSanitizerComponent::Event,
        #[flat]
        VesuDecoderAndSanitizerEvent: VesuDecoderAndSanitizerComponent::Event,
        #[flat]
        AvnuExchangeDecoderAndSanitizerEvent: AvnuExchangeDecoderAndSanitizerComponent::Event,
        #[flat]
        StarknetVaultKitDecoderAndSanitizerEvent: StarknetVaultKitDecoderAndSanitizerComponent::Event,
        #[flat]
        MultiplyDecoderAndSanitizerEvent: MultiplyDecoderAndSanitizerComponent::Event,
        #[flat]
        DefiSpringSNFStyleDecoderAndSanitizerEvent: DefiSpringSNFStyleDecoderAndSanitizerComponent::Event,
    }
}
