// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod SimpleDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::avnu_exchange_decoder_and_sanitizer::avnu_exchange_decoder_and_sanitizer::AvnuExchangeDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::erc4626_decoder_and_sanitizer::erc4626_decoder_and_sanitizer::Erc4626DecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starkgate_decoder_and_sanitizer::starkgate_decoder_and_sanitizer::StarkgateDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starknet_vault_kit_decoder_and_sanitizer::starknet_vault_kit_decoder_and_sanitizer::StarknetVaultKitDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::vesu_v2_decoder_and_sanitizer::vesu_v2_decoder_and_sanitizer::VesuV2DecoderAndSanitizerComponent;

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
        path: VesuV2DecoderAndSanitizerComponent,
        storage: vesu_v2_decoder_and_sanitizer,
        event: VesuV2DecoderAndSanitizerEvent,
    );

    component!(
        path: AvnuExchangeDecoderAndSanitizerComponent,
        storage: avnu_exchange_decoder_and_sanitizer,
        event: AvnuExchangeDecoderAndSanitizerEvent,
    );

    component!(
        path: StarkgateDecoderAndSanitizerComponent,
        storage: starkgate_decoder_and_sanitizer,
        event: StarkgateDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl StarkgateDecoderAndSanitizerImpl =
        StarkgateDecoderAndSanitizerComponent::StarkgateDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl Erc4626DecoderAndSanitizerImpl =
        Erc4626DecoderAndSanitizerComponent::Erc4626DecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl VesuV2DecoderAndSanitizerImpl =
        VesuV2DecoderAndSanitizerComponent::VesuV2DecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl AvnuExchangeDecoderAndSanitizerImpl =
        AvnuExchangeDecoderAndSanitizerComponent::AvnuExchangeDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[abi(embed_v0)]
    impl StarknetVaultKitDecoderAndSanitizerImpl =
        StarknetVaultKitDecoderAndSanitizerComponent::StarknetVaultKitDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub erc4626_decoder_and_sanitizer: Erc4626DecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub vesu_v2_decoder_and_sanitizer: VesuV2DecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub avnu_exchange_decoder_and_sanitizer: AvnuExchangeDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starknet_vault_kit_decoder_and_sanitizer: StarknetVaultKitDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starkgate_decoder_and_sanitizer: StarkgateDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        Erc4626DecoderAndSanitizerEvent: Erc4626DecoderAndSanitizerComponent::Event,
        #[flat]
        VesuV2DecoderAndSanitizerEvent: VesuV2DecoderAndSanitizerComponent::Event,
        #[flat]
        AvnuExchangeDecoderAndSanitizerEvent: AvnuExchangeDecoderAndSanitizerComponent::Event,
        #[flat]
        StarknetVaultKitDecoderAndSanitizerEvent: StarknetVaultKitDecoderAndSanitizerComponent::Event,
        #[flat]
        StarkgateDecoderAndSanitizerEvent: StarkgateDecoderAndSanitizerComponent::Event,
    }
}
