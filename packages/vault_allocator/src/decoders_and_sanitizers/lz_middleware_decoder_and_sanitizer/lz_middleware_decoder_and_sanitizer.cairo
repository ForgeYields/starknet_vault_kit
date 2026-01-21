// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod LzMiddlewareDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::lz_middleware_decoder_and_sanitizer::interface::ILzMiddlewareDecoderAndSanitizer;
    use vault_allocator::integration_interfaces::lz::{MessagingFee, SendParam};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(LzMiddlewareDecoderAndSanitizerImpl)]
    impl LzMiddlewareDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of ILzMiddlewareDecoderAndSanitizer<ComponentState<TContractState>> {
        fn send(
            self: @ComponentState<TContractState>,
            oft: ContractAddress,
            underlying_token: ContractAddress,
            token_to_claim: ContractAddress,
            send_param: SendParam,
            fee: MessagingFee,
            refund_address: ContractAddress,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            oft.serialize(ref serialized_struct);
            underlying_token.serialize(ref serialized_struct);
            token_to_claim.serialize(ref serialized_struct);
            send_param.dst_eid.serialize(ref serialized_struct);
            send_param.to.serialize(ref serialized_struct);
            refund_address.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
