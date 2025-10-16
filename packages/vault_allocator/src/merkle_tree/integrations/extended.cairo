use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use starknet::{ContractAddress, EthereumAddress};
use vault_allocator::integration_interfaces::starkgate::{
    IStarkgateABIDispatcher, IStarkgateABIDispatcherTrait,
};
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


pub fn _add_extended_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    extended_recipient: ContractAddress,
    usdc_address: ContractAddress,
    vault_number: felt252,
    decoder_and_sanitizer: ContractAddress,
) {
    // Approvals
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: usdc_address,
                selector: selector!("approve"),
                argument_addresses: array![extended_recipient.into()].span(),
                description: "Approve extended recipient to spend USDC",
            },
        );
    leaf_index += 1;

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: extended_recipient,
                selector: selector!("deposit"),
                argument_addresses: array![vault_number.into()].span(),
                description: "Deposit USDC into extended recipient",
            },
        );
    leaf_index += 1;
}
