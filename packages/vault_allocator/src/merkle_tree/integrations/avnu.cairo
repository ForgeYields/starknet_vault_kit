use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, _contains_address, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone, starknet::Store)]
pub struct AvnuConfig {
    pub sell_token: ContractAddress,
    pub buy_token: ContractAddress,
}

// work for interacting directly with the avnu router or using the avnu middleware
pub fn _add_avnu_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    router: ContractAddress,
    avnu_configs: Span<AvnuConfig>,
) {
    let mut seen_sells: Array<ContractAddress> = ArrayTrait::new();

    for i in 0..avnu_configs.len() {
        let avnu_config_elem = avnu_configs.at(i);
        let sell_token_address = *avnu_config_elem.sell_token;
        let buy_token_address = *avnu_config_elem.buy_token;

        if !_contains_address(seen_sells.span(), sell_token_address) {
            leafs
                .append(
                    ManageLeaf {
                        decoder_and_sanitizer,
                        target: sell_token_address,
                        selector: selector!("approve"),
                        argument_addresses: array![router.into()].span(),
                        description: "Approve"
                            + " "
                            + "avnu_router"
                            + " "
                            + "to spend"
                            + " "
                            + get_symbol(sell_token_address),
                    },
                );
            leaf_index += 1;
            seen_sells.append(sell_token_address);
        }

        // swap leaf à chaque paire
        let mut argument_addresses = ArrayTrait::new();
        sell_token_address.serialize(ref argument_addresses);
        buy_token_address.serialize(ref argument_addresses);
        vault_allocator.serialize(ref argument_addresses);

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: router,
                    selector: selector!("multi_route_swap"),
                    argument_addresses: argument_addresses.span(),
                    description: "Multi route swap"
                        + " "
                        + get_symbol(sell_token_address)
                        + " "
                        + "for"
                        + " "
                        + get_symbol(buy_token_address),
                },
            );
        leaf_index += 1;
    }
}
