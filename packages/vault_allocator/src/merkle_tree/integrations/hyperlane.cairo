use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct HyperlaneConfig {
    pub middleware: ContractAddress,
    pub token_to_bridge: ContractAddress,
    pub token_to_claim: ContractAddress,
    pub destination_domain: u32,
    pub recipient: ContractAddress,
}


pub fn _add_hyperlane_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    hyperlane_configs: Span<HyperlaneConfig>,
) {
    for i in 0..hyperlane_configs.len() {
        let config = hyperlane_configs.at(i);
        let middleware = *config.middleware;
        let token_to_bridge = *config.token_to_bridge;
        let token_to_claim = *config.token_to_claim;
        let destination_domain = *config.destination_domain;
        let recipient = *config.recipient;

        let middleware_felt: felt252 = middleware.into();
        let mut middleware_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @middleware_felt, 16,
        );

        // Approval for token_to_bridge to the middleware
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: token_to_bridge,
                    selector: selector!("approve"),
                    argument_addresses: array![middleware.into()].span(),
                    description: "Approve"
                        + " "
                        + "hyperlane_middleware"
                        + "_"
                        + middleware_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(token_to_bridge),
                },
            );
        leaf_index += 1;

        // Bridge token operation
        let mut argument_addresses_bridge = ArrayTrait::new();

        // token_to_bridge
        token_to_bridge.serialize(ref argument_addresses_bridge);

        // token_to_claim
        token_to_claim.serialize(ref argument_addresses_bridge);

        // destination_domain
        destination_domain.serialize(ref argument_addresses_bridge);

        // recipient
        recipient.serialize(ref argument_addresses_bridge);

        // Format addresses for description
        let recipient_felt: felt252 = recipient.into();
        let recipient_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @recipient_felt, 16,
        );
        let domain_felt: felt252 = destination_domain.into();
        let domain_str: ByteArray = FormatAsByteArray::format_as_byte_array(@domain_felt, 16);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: middleware,
                    selector: selector!("bridge_token"),
                    argument_addresses: argument_addresses_bridge.span(),
                    description: "Hyperlane: bridge"
                        + " "
                        + get_symbol(token_to_bridge)
                        + " "
                        + "for"
                        + " "
                        + get_symbol(token_to_claim)
                        + " "
                        + "on domain"
                        + " "
                        + domain_str
                        + " "
                        + "to recipient"
                        + " "
                        + recipient_str,
                },
            );
        leaf_index += 1;
    }
}