// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.
use starknet::ContractAddress;
use alexandria_math::i257::I257Impl;
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _pad_leafs_to_power_of_two, generate_merkle_tree, get_leaf_hash,

};
use vault_allocator::merkle_tree::integrations::avnu::{AvnuConfig, _add_avnu_leafs};
use vault_allocator::merkle_tree::integrations::vesu_v1::{VesuV1Config, _add_vesu_v1_leafs};
use vault_allocator::merkle_tree::integrations::vesu_v2::{VesuV2Config, _add_vesu_v2_leafs};
use vault_allocator::merkle_tree::integrations::erc4626::_add_erc4626_leafs;
use vault_allocator::merkle_tree::integrations::starknet_vault_kit_strategies::_add_starknet_vault_kit_strategies;
use vault_allocator::merkle_tree::integrations::extended::_add_extended_leafs;
use vault_allocator::merkle_tree::integrations::starkgate::_add_starkgate_leafs;
use vault_allocator::merkle_tree::base::_add_vault_allocator_leafs;



#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct ManageLeafAdditionalData {
    pub decoder_and_sanitizer: ContractAddress,
    pub target: ContractAddress,
    pub selector: felt252,
    pub argument_addresses: Span<felt252>,
    pub description: ByteArray,
    pub leaf_index: u32,
    pub leaf_hash: felt252,
}

#[fork("MAINNET")]
#[test]
fn test_creator() {
    let mut vesu_v1_configs: Array<VesuV1Config> = ArrayTrait::new();
    let mut vesu_v2_configs: Array<VesuV2Config> = ArrayTrait::new();
    let mut erc4626_strategies: Array<ContractAddress> = ArrayTrait::new();
    let mut starknet_vault_kit_strategies = ArrayTrait::new();
    let mut avnu_configs: Array<AvnuConfig> = ArrayTrait::new();

    // USDC Carry Trade Config
    // ADD VAULT PERIPHERY ADDRESSES
    let vault = 0x783b6c014ae99767df5120dd5c4ebea998e78944d92aee457dfc7e86a405349
        .try_into()
        .unwrap();
    let vault_allocator = 0x482ff2e4bed4531116bd58117bca31d1e1e6d940323e4562ea270cb6b3c00ed
        .try_into()
        .unwrap();
    let vault_decoder_and_sanitizer =
        0x02F3C36C681b4B0DbE0314586B5fD23e7F790509DE958683f3d3DA41Ba98A8d8
        .try_into()
        .unwrap();
    let vault_vesu_v2_specific_decoder_and_sanitizer =
        0x047602348703E0d7bDAFD0e14cf93ee386337AD1455c94F9e242399513599Bb0
        .try_into()
        .unwrap();
    let avnu_router_middleware = 0x076C30f11D9d28c0Cc5f2E7cBfAB07441931DAF47CE4dc38B4fd7bBf509112Ff
        .try_into()
        .unwrap();

    // ADD INTEGRATIONS ADDRESSES
    vesu_v2_configs
        .append(
            VesuV2Config {
                pool_contract: 0x02eef0c13b10b487ea5916b54c0a7f98ec43fb3048f60fdeedaf5b08f6f88aaf
                    .try_into()
                    .unwrap(),
                collateral_asset: 0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac
                    .try_into()
                    .unwrap(),
                debt_assets: array![
                    0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
                        .try_into()
                        .unwrap(),
                ]
                    .span(),
            },
        );

    avnu_configs
        .append(
            AvnuConfig {
                sell_token: 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
                    .try_into()
                    .unwrap(),
                buy_token: 0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC
                    .try_into()
                    .unwrap(),
            },
        );

    _generate_merkle_tree(
        vault,
        vault_allocator,
        vault_decoder_and_sanitizer,
        vault_vesu_v2_specific_decoder_and_sanitizer,
        vesu_v1_configs.span(),
        vesu_v2_configs.span(),
        erc4626_strategies.span(),
        starknet_vault_kit_strategies.span(),
        avnu_configs.span(),
        avnu_router_middleware,
    );
}


fn _generate_merkle_tree(
    vault: ContractAddress,
    vault_allocator: ContractAddress,
    vault_decoder_and_sanitizer: ContractAddress,
    vault_vesu_v2_specific_decoder_and_sanitizer: ContractAddress,
    vesu_v1_configs: Span<VesuV1Config>,
    vesu_v2_configs: Span<VesuV2Config>,
    erc4626_strategies: Span<ContractAddress>,
    starknet_vault_kit_strategies: Span<ContractAddress>,
    avnu_configs: Span<AvnuConfig>,
    avnu_router_middleware: ContractAddress,
) {
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    // base leafs mandatory
    _add_vault_allocator_leafs(
        ref leafs, ref leaf_index, vault_allocator, vault_decoder_and_sanitizer, vault,
    );

    // vesu V1 leafs
    _add_vesu_v1_leafs(
        ref leafs, ref leaf_index, vault_allocator, vault_decoder_and_sanitizer, vesu_v1_configs,
    );

    // vesu V2 leafs
    _add_vesu_v2_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator,
        vault_vesu_v2_specific_decoder_and_sanitizer,
        vesu_v2_configs,
    );

    for erc4626_strategy_elem in erc4626_strategies {
        _add_erc4626_leafs(
            ref leafs,
            ref leaf_index,
            vault_allocator,
            vault_decoder_and_sanitizer,
            *erc4626_strategy_elem,
        )
    }
    for starknet_vault_kit_strategy_elem in starknet_vault_kit_strategies {
        _add_starknet_vault_kit_strategies(
            ref leafs,
            ref leaf_index,
            vault_allocator,
            vault_decoder_and_sanitizer,
            *starknet_vault_kit_strategy_elem,
        )
    }

    _add_avnu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator,
        vault_decoder_and_sanitizer,
        avnu_router_middleware,
        avnu_configs,
    );

    // Extended leafs
    let extended_recipient = 0x006f28120907c8cfbcd71df2c5fb44a205989aa41c8d36c85723a54d60782cfc
        .try_into()
        .unwrap();
    let usdc_address = 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8
        .try_into()
        .unwrap();
    let vault_number = 206770;
    _add_extended_leafs(
        ref leafs,
        ref leaf_index,
        extended_recipient,
        usdc_address,
        vault_number,
        vault_decoder_and_sanitizer,
    );

    // Starkgate withdraw leafs
    let l2_bridge = 0x05cd48fccbfd8aa2773fe22c217e808319ffcc1c5a6a463f7d8fa2da48218196
        .try_into()
        .unwrap();
    let l1_recipient = 0x732357e321Bf7a02CbB690fc2a629161D7722e29.try_into().unwrap();
    _add_starkgate_leafs(
        ref leafs,
        ref leaf_index,
        l2_bridge,
        l1_recipient,
        vault_decoder_and_sanitizer,
    );

    let leaf_used = leafs.len();

    // MERKLE TREE CREATION
    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree_capacity = leafs.len();
    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);

    let mut leaf_additional_data = ArrayTrait::new();
    for i in 0..leaf_used {
        leaf_additional_data
            .append(
                ManageLeafAdditionalData {
                    decoder_and_sanitizer: *leafs.at(i).decoder_and_sanitizer,
                    target: *leafs.at(i).target,
                    selector: *leafs.at(i).selector,
                    argument_addresses: *leafs.at(i).argument_addresses,
                    description: leafs.at(i).description.clone(),
                    leaf_index: i,
                    leaf_hash: get_leaf_hash(leafs.at(i).clone()),
                },
            );
    }

    // PRINT
    println!("vault: {:?}", vault);
    println!("vault_allocator: {:?}", vault_allocator);
    println!("root: {:?}", root);
    println!("tree_capacity: {:?}", tree_capacity);
    println!("leaf_used: {:?}", leaf_used);
    println!("leaf_additional_data: {:?}", leaf_additional_data);
    println!("tree: {:?}", tree);
}