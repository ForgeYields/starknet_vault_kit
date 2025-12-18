use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct CctpConfig {
    pub cctp_contract: ContractAddress,
    pub burn_token: ContractAddress,
    pub destination_domain: u32,
    pub mint_recipient: u256,
    pub destination_caller: u256,
}


pub fn _add_cctp_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    cctp_configs: Span<CctpConfig>,
) {
    for i in 0..cctp_configs.len() {
        let config = cctp_configs.at(i);
        let cctp_contract = *config.cctp_contract;
        let burn_token = *config.burn_token;
        let destination_domain = *config.destination_domain;
        let mint_recipient = *config.mint_recipient;
        let destination_caller = *config.destination_caller;

        // Approval for burn_token to the cctp contract
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: burn_token,
                    selector: selector!("approve"),
                    argument_addresses: array![cctp_contract.into()].span(),
                    description: "Approve"
                        + " "
                        + "cctp"
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(burn_token),
                },
            );
        leaf_index += 1;

        // Deposit for burn operation
        let mut argument_addresses_burn = ArrayTrait::new();

        // destination_domain
        destination_domain.serialize(ref argument_addresses_burn);

        // mint_recipient
        mint_recipient.serialize(ref argument_addresses_burn);

        // burn_token
        burn_token.serialize(ref argument_addresses_burn);

        // destination_caller
        destination_caller.serialize(ref argument_addresses_burn);

        // Format addresses for description
        let recipient_str: ByteArray = FormatAsByteArray::format_as_byte_array(@mint_recipient, 16);
        let domain_felt: felt252 = destination_domain.into();
        let domain_str: ByteArray = FormatAsByteArray::format_as_byte_array(@domain_felt, 16);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: cctp_contract,
                    selector: selector!("deposit_for_burn"),
                    argument_addresses: argument_addresses_burn.span(),
                    description: "CCTP: burn"
                        + " "
                        + get_symbol(burn_token)
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


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct CctpMiddlewareConfig {
    pub middleware: ContractAddress,
    pub burn_token: ContractAddress,
    pub token_to_claim: ContractAddress,
    pub destination_domain: u32,
    pub mint_recipient: u256,
    pub destination_caller: u256,
}


pub fn _add_cctp_middleware_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    cctp_configs: Span<CctpMiddlewareConfig>,
) {
    for i in 0..cctp_configs.len() {
        let config = cctp_configs.at(i);
        let middleware = *config.middleware;
        let burn_token = *config.burn_token;
        let token_to_claim = *config.token_to_claim;
        let destination_domain = *config.destination_domain;
        let mint_recipient = *config.mint_recipient;
        let destination_caller = *config.destination_caller;

        let middleware_felt: felt252 = middleware.into();
        let middleware_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @middleware_felt, 16,
        );

        // Approval for burn_token to the middleware
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: burn_token,
                    selector: selector!("approve"),
                    argument_addresses: array![middleware.into()].span(),
                    description: "Approve"
                        + " "
                        + "cctp_middleware"
                        + "_"
                        + middleware_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(burn_token),
                },
            );
        leaf_index += 1;

        // Deposit for burn operation
        let mut argument_addresses_burn = ArrayTrait::new();

        // destination_domain
        destination_domain.serialize(ref argument_addresses_burn);

        // mint_recipient
        mint_recipient.serialize(ref argument_addresses_burn);

        // burn_token
        burn_token.serialize(ref argument_addresses_burn);

        // token_to_claim
        token_to_claim.serialize(ref argument_addresses_burn);

        // destination_caller
        destination_caller.serialize(ref argument_addresses_burn);

        // Format addresses for description
        let recipient_str: ByteArray = FormatAsByteArray::format_as_byte_array(@mint_recipient, 16);
        let domain_felt: felt252 = destination_domain.into();
        let domain_str: ByteArray = FormatAsByteArray::format_as_byte_array(@domain_felt, 16);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: middleware,
                    selector: selector!("deposit_for_burn"),
                    argument_addresses: argument_addresses_burn.span(),
                    description: "CCTP: burn"
                        + " "
                        + get_symbol(burn_token)
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
