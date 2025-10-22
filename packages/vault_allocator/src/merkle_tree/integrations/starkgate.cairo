use starknet::{ContractAddress, EthAddress};
use vault_allocator::integration_interfaces::starkgate::{
    IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait,
};
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


pub fn _add_starkgate_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    l2_bridge: ContractAddress,
    l1_recipient: EthAddress,
    decoder_and_sanitizer: ContractAddress,
) {
    let starkgate_disp = IStarkgateABIDispatcher { contract_address: l2_bridge };
    let l2_token = starkgate_disp.get_l2_token();
    let l1_token = starkgate_disp.get_l1_token();
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: l2_bridge,
                selector: selector!("initiate_token_withdraw"),
                argument_addresses: array![l1_token.into(), l1_recipient.into()].span(),
                description: "Initiate token withdraw" + " " + get_symbol(l2_token),
            },
        );
    leaf_index += 1;
}
