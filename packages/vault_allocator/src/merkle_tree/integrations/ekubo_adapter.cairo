use starknet::ContractAddress;
use vault_allocator::adapters::ekubo_adapter::interface::{
    IEkuboAdapterDispatcher, IEkuboAdapterDispatcherTrait,
};
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


pub fn _add_ekubo_adapter_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    ekubo_adapter: ContractAddress,
) {
    let adapter_disp = IEkuboAdapterDispatcher { contract_address: ekubo_adapter };
    let pool_key = adapter_disp.get_pool_key();
    let token0 = pool_key.token0;
    let token1 = pool_key.token1;

    // Approvals for token0 to ekubo adapter
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: token0,
                selector: selector!("approve"),
                argument_addresses: array![ekubo_adapter.into()].span(),
                description: "Approve"
                    + " "
                    + "ekubo_adapter"
                    + " "
                    + "to spend"
                    + " "
                    + get_symbol(token0),
            },
        );
    leaf_index += 1;

    // Approvals for token1 to ekubo adapter
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: token1,
                selector: selector!("approve"),
                argument_addresses: array![ekubo_adapter.into()].span(),
                description: "Approve"
                    + " "
                    + "ekubo_adapter"
                    + " "
                    + "to spend"
                    + " "
                    + get_symbol(token1),
            },
        );
    leaf_index += 1;

    // Deposit liquidity
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: ekubo_adapter,
                selector: selector!("deposit_liquidity"),
                argument_addresses: array![].span(),
                description: "Deposit liquidity to Ekubo"
                    + "for"
                    + " "
                    + get_symbol(token0)
                    + " "
                    + "and"
                    + " "
                    + get_symbol(token1)
                    + " "
                    + "via"
                    + " "
                    + "ekubo_adapter",
            },
        );
    leaf_index += 1;

    // Withdraw liquidity
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: ekubo_adapter,
                selector: selector!("withdraw_liquidity"),
                argument_addresses: array![].span(),
                description: "Withdraw liquidity from Ekubo"
                    + " "
                    + "for"
                    + " "
                    + get_symbol(token0)
                    + " "
                    + "and"
                    + " "
                    + get_symbol(token1)
                    + " "
                    + "via"
                    + " "
                    + "ekubo_adapter",
            },
        );
    leaf_index += 1;

    // Collect fees
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: ekubo_adapter,
                selector: selector!("collect_fees"),
                argument_addresses: array![].span(),
                description: "Collect fees from Ekubo"
                    + " "
                    + "for"
                    + " "
                    + get_symbol(token0)
                    + " "
                    + "and"
                    + " "
                    + get_symbol(token1)
                    + " "
                    + "via"
                    + " "
                    + "ekubo_adapter",
            },
        );
    leaf_index += 1;

    // Harvest rewards
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: ekubo_adapter,
                selector: selector!("harvest"),
                argument_addresses: array![].span(),
                description: "Harvest rewards from Ekubo"
                    + " "
                    + "for"
                    + " "
                    + get_symbol(token0)
                    + " "
                    + "and"
                    + " "
                    + get_symbol(token1)
                    + " "
                    + "via"
                    + " "
                    + "ekubo_adapter",
            },
        );
    leaf_index += 1;
}
