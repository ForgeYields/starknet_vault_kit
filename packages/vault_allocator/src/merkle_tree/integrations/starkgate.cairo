use core::to_byte_array::FormatAsByteArray;
use starknet::{ContractAddress, EthAddress};
use vault_allocator::integration_interfaces::starkgate::{
    IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait,
};
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct StarkgateConfig {
    pub l2_bridge: ContractAddress,
    pub l2_token: ContractAddress,
    pub l1_recipient: EthAddress,
}


pub fn _add_starkgate_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    starkgate_configs: Span<StarkgateConfig>,
) {
    for i in 0..starkgate_configs.len() {
        let config = starkgate_configs.at(i);
        let l2_bridge = *config.l2_bridge;
        let l2_token = *config.l2_token;
        let l1_recipient = *config.l1_recipient;

        let starkgate_disp = IStarkgateABIDispatcher { contract_address: l2_bridge };
        let l1_token = starkgate_disp.get_l1_token(l2_token);

        // Format addresses for description
        let l1_recipient_felt: felt252 = l1_recipient.into();
        let l1_recipient_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @l1_recipient_felt, 16,
        );

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: l2_bridge,
                    selector: selector!("initiate_token_withdraw"),
                    argument_addresses: array![l1_token.into(), l1_recipient.into()].span(),
                    description: "Starkgate: withdraw"
                        + " "
                        + get_symbol(l2_token)
                        + " "
                        + "to recipient"
                        + " "
                        + l1_recipient_str,
                },
            );
        leaf_index += 1;
    }
}

#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct StarkgateMiddlewareConfig {
    pub middleware: ContractAddress,
    pub l2_bridge: ContractAddress,
    pub l2_token: ContractAddress,
    pub l1_recipient: EthAddress,
    pub token_to_claim: ContractAddress,
}


pub fn _add_starkgate_middleware_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    decoder_and_sanitizer: ContractAddress,
    starkgate_configs: Span<StarkgateMiddlewareConfig>,
) {
    for i in 0..starkgate_configs.len() {
        let config = starkgate_configs.at(i);
        let middleware = *config.middleware;
        let l2_bridge = *config.l2_bridge;
        let l2_token = *config.l2_token;
        let l1_recipient = *config.l1_recipient;
        let token_to_claim = *config.token_to_claim;

        let middleware_felt: felt252 = middleware.into();
        let middleware_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @middleware_felt, 16,
        );

        // Approval for middleware to spend l2_token
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: l2_token,
                    selector: selector!("approve"),
                    argument_addresses: array![middleware.into()].span(),
                    description: "Approve"
                        + " "
                        + "starkgate_middleware"
                        + "_"
                        + middleware_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(l2_token),
                },
            );
        leaf_index += 1;

        let starkgate_disp = IStarkgateABIDispatcher { contract_address: l2_bridge };
        let l1_token = starkgate_disp.get_l1_token(l2_token);

        // Initiate token withdraw operation
        let mut argument_addresses_withdraw = ArrayTrait::new();

        // starkgate_token_bridge
        l2_bridge.serialize(ref argument_addresses_withdraw);

        // l1_token
        l1_token.serialize(ref argument_addresses_withdraw);

        // l1_recipient
        l1_recipient.serialize(ref argument_addresses_withdraw);

        // token_to_claim
        token_to_claim.serialize(ref argument_addresses_withdraw);

        // Format addresses for description
        let l1_recipient_felt: felt252 = l1_recipient.into();
        let l1_recipient_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @l1_recipient_felt, 16,
        );

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: middleware,
                    selector: selector!("initiate_token_withdraw"),
                    argument_addresses: argument_addresses_withdraw.span(),
                    description: "Starkgate: bridge"
                        + " "
                        + get_symbol(l2_token)
                        + " "
                        + "for"
                        + " "
                        + get_symbol(token_to_claim)
                        + " "
                        + "to recipient"
                        + " "
                        + l1_recipient_str,
                },
            );
        leaf_index += 1;
    }
}
