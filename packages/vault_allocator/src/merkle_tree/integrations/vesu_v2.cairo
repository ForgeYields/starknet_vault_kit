use core::to_byte_array::FormatAsByteArray;
use starknet::ContractAddress;
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct VesuV2Config {
    pub pool_contract: ContractAddress,
    pub collateral_asset: ContractAddress,
    pub debt_assets: Span<ContractAddress>,
}


pub fn _add_vesu_v2_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    vesu_v2_configs: Span<VesuV2Config>,
) {
    for i in 0..vesu_v2_configs.len() {
        let vesu_v2_config_elem = vesu_v2_configs.at(i);
        let pool_contract = *vesu_v2_config_elem.pool_contract;
        let collateral_asset = *vesu_v2_config_elem.collateral_asset;
        let debt_assets = *vesu_v2_config_elem.debt_assets;
        let pool_contract_felt: felt252 = pool_contract.into();
        let mut pool_contract_str: ByteArray = FormatAsByteArray::format_as_byte_array(
            @pool_contract_felt, 16,
        );

        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer,
                    target: collateral_asset,
                    selector: selector!("approve"),
                    argument_addresses: array![pool_contract.into()].span(),
                    description: "Approve"
                        + " "
                        + "pool contract"
                        + "_"
                        + pool_contract_str.clone()
                        + " "
                        + "to spend"
                        + " "
                        + get_symbol(collateral_asset),
                },
            );
        leaf_index += 1;

        // debt mode
        let debt_assets_len = debt_assets.len();
        for j in 0..debt_assets_len {
            let debt_asset = *debt_assets.at(j);

            // APPROVAL of debt asset to the pool contract (needed for repayment)
            leafs
                .append(
                    ManageLeaf {
                        decoder_and_sanitizer,
                        target: debt_asset,
                        selector: selector!("approve"),
                        argument_addresses: array![pool_contract.into()].span(),
                        description: "Approve"
                            + " "
                            + "pool contract"
                            + "_"
                            + pool_contract_str.clone()
                            + " "
                            + "to spend"
                            + " "
                            + get_symbol(debt_asset),
                    },
                );
            leaf_index += 1;

            // MODIFY POSITION
            let mut argument_addresses_modify_position = ArrayTrait::new();

            // collateral_asset
            collateral_asset.serialize(ref argument_addresses_modify_position);

            // debt_asset
            debt_asset.serialize(ref argument_addresses_modify_position);

            // user
            vault_allocator.serialize(ref argument_addresses_modify_position);

            leafs
                .append(
                    ManageLeaf {
                        decoder_and_sanitizer,
                        target: pool_contract,
                        selector: selector!("modify_position"),
                        argument_addresses: argument_addresses_modify_position.span(),
                        description: "Modify position"
                            + " "
                            + "extension_pid"
                            + "_"
                            + pool_contract_str.clone()
                            + " "
                            + "with collateral"
                            + " "
                            + get_symbol(collateral_asset)
                            + " "
                            + "and debt"
                            + " "
                            + get_symbol(debt_asset),
                    },
                );
            leaf_index += 1;
        }
    }
}
