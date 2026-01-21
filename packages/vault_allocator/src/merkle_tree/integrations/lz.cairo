use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};
use vault_allocator::merkle_tree::registery::STRK;


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct LzConfig {
    pub oft: ContractAddress,
    pub underlying_token: ContractAddress, // If oft != underlying_token, it's adapter OFT
    pub dst_eid: u32,
    pub to: u256,
}


pub fn _add_lz_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    vault_allocator: ContractAddress,
    lz_configs: Span<LzConfig>,
) {
    for i in 0..lz_configs.len() {
        let config = lz_configs.at(i);
        let oft = *config.oft;
        let underlying_token = *config.underlying_token;
        let dst_eid = *config.dst_eid;
        let to = *config.to;

        // If adapter OFT (oft != underlying_token), we need to approve the underlying token
        if oft != underlying_token {
            leafs
                .append(
                    ManageLeaf {
                        decoder_and_sanitizer,
                        target: underlying_token,
                        selector: selector!("approve"),
                        argument_addresses: array![oft.into()].span(),
                        description: "Approve"
                            + " "
                            + "lz_oft"
                            + " "
                            + "to spend"
                            + " "
                            + get_symbol(underlying_token),
                    },
                );
            leaf_index += 1;
        }

        // Approval for gas token (STRK) to the OFT
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: STRK(),
                    selector: selector!("approve"),
                    argument_addresses: array![oft.into()].span(),
                    description: "Approve"
                        + " "
                        + "lz_oft"
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(STRK()),
                },
            );
        leaf_index += 1;

        // Send operation
        let mut argument_addresses_send = ArrayTrait::new();

        // dst_eid
        dst_eid.serialize(ref argument_addresses_send);

        // to
        to.serialize(ref argument_addresses_send);

        // refund_address (vault_allocator receives excess fees)
        vault_allocator.serialize(ref argument_addresses_send);

        // Format addresses for description
        let to_str: ByteArray = FormatAsByteArray::format_as_byte_array(@to, 16);
        let dst_eid_felt: felt252 = dst_eid.into();
        let dst_eid_str: ByteArray = FormatAsByteArray::format_as_byte_array(@dst_eid_felt, 16);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: oft,
                    selector: selector!("send"),
                    argument_addresses: argument_addresses_send.span(),
                    description: "LayerZero: send"
                        + " "
                        + get_symbol(underlying_token)
                        + " "
                        + "to eid"
                        + " "
                        + dst_eid_str
                        + " "
                        + "to"
                        + " "
                        + to_str,
                },
            );
        leaf_index += 1;
    }
}


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct LzMiddlewareConfig {
    pub middleware: ContractAddress,
    pub oft: ContractAddress,
    pub underlying_token: ContractAddress, // If oft != underlying_token, it's adapter OFT
    pub token_to_claim: ContractAddress,
    pub dst_eid: u32,
    pub to: u256,
}


pub fn _add_lz_middleware_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    vault_allocator: ContractAddress,
    lz_configs: Span<LzMiddlewareConfig>,
) {
    for i in 0..lz_configs.len() {
        let config = lz_configs.at(i);
        let middleware = *config.middleware;
        let oft = *config.oft;
        let underlying_token = *config.underlying_token;
        let token_to_claim = *config.token_to_claim;
        let dst_eid = *config.dst_eid;
        let to = *config.to;

        let middleware_felt: felt252 = middleware.into();
        let middleware_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @middleware_felt, 16,
        );

        // Approval for underlying_token to the middleware
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: underlying_token,
                    selector: selector!("approve"),
                    argument_addresses: array![middleware.into()].span(),
                    description: "Approve"
                        + " "
                        + "lz_middleware"
                        + "_"
                        + middleware_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(underlying_token),
                },
            );
        leaf_index += 1;

        // Approval for gas token (STRK) to the middleware
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: STRK(),
                    selector: selector!("approve"),
                    argument_addresses: array![middleware.into()].span(),
                    description: "Approve"
                        + " "
                        + "lz_middleware"
                        + "_"
                        + middleware_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(STRK()),
                },
            );
        leaf_index += 1;

        // Send operation on middleware
        let mut argument_addresses_send = ArrayTrait::new();

        // oft
        oft.serialize(ref argument_addresses_send);

        // underlying_token
        underlying_token.serialize(ref argument_addresses_send);

        // token_to_claim
        token_to_claim.serialize(ref argument_addresses_send);

        // dst_eid
        dst_eid.serialize(ref argument_addresses_send);

        // to
        to.serialize(ref argument_addresses_send);

        // refund_address (vault_allocator receives excess fees)
        vault_allocator.serialize(ref argument_addresses_send);

        // Format addresses for description
        let to_str: ByteArray = FormatAsByteArray::format_as_byte_array(@to, 16);
        let dst_eid_felt: felt252 = dst_eid.into();
        let dst_eid_str: ByteArray = FormatAsByteArray::format_as_byte_array(@dst_eid_felt, 16);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: middleware,
                    selector: selector!("send"),
                    argument_addresses: argument_addresses_send.span(),
                    description: "LayerZero: send via middleware"
                        + " "
                        + get_symbol(underlying_token)
                        + " "
                        + "for"
                        + " "
                        + get_symbol(token_to_claim)
                        + " "
                        + "to eid"
                        + " "
                        + dst_eid_str
                        + " "
                        + "to"
                        + " "
                        + to_str,
                },
            );
        leaf_index += 1;
    }
}
