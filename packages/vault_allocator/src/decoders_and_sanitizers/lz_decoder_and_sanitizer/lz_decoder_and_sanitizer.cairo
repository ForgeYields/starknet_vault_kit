// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod LzDecoderAndSanitizerComponent {
    use starknet::ContractAddress;
    use vault_allocator::decoders_and_sanitizers::lz_decoder_and_sanitizer::interface::ILzDecoderAndSanitizer;
    use vault_allocator::integration_interfaces::lz::{SendParam, MessagingFee};

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(LzDecoderAndSanitizerImpl)]
    impl LzDecoderAndSanitizer<
        TContractState, +HasComponent<TContractState>,
    > of ILzDecoderAndSanitizer<ComponentState<TContractState>> {
        fn send(
            self: @ComponentState<TContractState>,
            send_param: SendParam,
            fee: MessagingFee,
            refund_address: ContractAddress,
        ) -> Span<felt252> {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            send_param.dst_eid.serialize(ref serialized_struct);
            send_param.to.serialize(ref serialized_struct);
            refund_address.serialize(ref serialized_struct);
            serialized_struct.span()
        }
    }
}
