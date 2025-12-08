// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod FyWBTCDecoderAndSanitizer {
    use vault_allocator::decoders_and_sanitizers::avnu_exchange_decoder_and_sanitizer::avnu_exchange_decoder_and_sanitizer::AvnuExchangeDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::base_decoder_and_sanitizer::BaseDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::ekubo_adapter_decoder_and_sanitizer::ekubo_adapter_decoder_and_sanitizer::EkuboAdapterDecoderAndSanitizerComponent;
    use vault_allocator::decoders_and_sanitizers::starkgate_decoder_and_sanitizer::starkgate_decoder_and_sanitizer::StarkgateDecoderAndSanitizerComponent;

    component!(
        path: BaseDecoderAndSanitizerComponent,
        storage: base_decoder_and_sanitizer,
        event: BaseDecoderAndSanitizerEvent,
    );

    component!(
        path: EkuboAdapterDecoderAndSanitizerComponent,
        storage: ekubo_adapter_decoder_and_sanitizer,
        event: EkuboAdapterDecoderAndSanitizerEvent,
    );

    component!(
        path: StarkgateDecoderAndSanitizerComponent,
        storage: starkgate_decoder_and_sanitizer,
        event: StarkgateDecoderAndSanitizerEvent,
    );

    component!(
        path: AvnuExchangeDecoderAndSanitizerComponent,
        storage: avnu_exchange_decoder_and_sanitizer,
        event: AvnuExchangeDecoderAndSanitizerEvent,
    );

    #[abi(embed_v0)]
    impl BaseDecoderAndSanitizerImpl =
        BaseDecoderAndSanitizerComponent::BaseDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl EkuboAdapterDecoderAndSanitizerImpl =
        EkuboAdapterDecoderAndSanitizerComponent::EkuboAdapterDecoderAndSanitizerImpl<
            ContractState,
        >;

    #[abi(embed_v0)]
    impl StarkgateDecoderAndSanitizerImpl =
        StarkgateDecoderAndSanitizerComponent::StarkgateDecoderAndSanitizerImpl<ContractState>;

    #[abi(embed_v0)]
    impl AvnuExchangeDecoderAndSanitizerImpl =
        AvnuExchangeDecoderAndSanitizerComponent::AvnuExchangeDecoderAndSanitizerImpl<
            ContractState,
        >;


    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub base_decoder_and_sanitizer: BaseDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub starkgate_decoder_and_sanitizer: StarkgateDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub ekubo_adapter_decoder_and_sanitizer: EkuboAdapterDecoderAndSanitizerComponent::Storage,
        #[substorage(v0)]
        pub avnu_exchange_decoder_and_sanitizer: AvnuExchangeDecoderAndSanitizerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        BaseDecoderAndSanitizerEvent: BaseDecoderAndSanitizerComponent::Event,
        #[flat]
        StarkgateDecoderAndSanitizerEvent: StarkgateDecoderAndSanitizerComponent::Event,
        #[flat]
        EkuboAdapterDecoderAndSanitizerEvent: EkuboAdapterDecoderAndSanitizerComponent::Event,
        #[flat]
        AvnuExchangeDecoderAndSanitizerEvent: AvnuExchangeDecoderAndSanitizerComponent::Event,
    }
}
