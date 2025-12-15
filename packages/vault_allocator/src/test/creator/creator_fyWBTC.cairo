// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.
use alexandria_math::i257::I257Impl;
use starknet::{ContractAddress, EthAddress};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _pad_leafs_to_power_of_two, generate_merkle_tree, get_leaf_hash,
};
use vault_allocator::merkle_tree::integrations::avnu::{AvnuConfig, _add_avnu_leafs};
use vault_allocator::merkle_tree::integrations::ekubo_adapter::_add_ekubo_adapter_leafs;
use vault_allocator::merkle_tree::integrations::starkgate::{StarkgateConfig, _add_starkgate_leafs};
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
    let mut avnu_configs: Array<AvnuConfig> = ArrayTrait::new();
    let vault_allocator = 0x7347602aedf0197492a6d10f7e9d9dda45493e62b26bd540e980617e92b4e38
        .try_into()
        .unwrap();
    let decoder_and_sanitizer = 0x2daef50b554d472437b781db309760d13006904e5d85b697df7b730afa5cb4e
        .try_into()
        .unwrap();
    let avnu_router_middleware = 0x165cdb71573a3d4518cf0dd326aee8dd46eeec3cbe3ecdbbd57146c0a52b202
        .try_into()
        .unwrap();

    let ekubo_adapter = 0x59053bd0f16f755b83bb556ef75e7527d29ae27e4da437b94cdc323e3665182
        .try_into()
        .unwrap();

    // pairs:
    // STRK -> WBTC
    // STRK -> solbBTC
    // WBTC -> solbBTC
    // solbBTC -> WBTC
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
    avnu_configs
        .append(
            AvnuConfig {
                sell_token: 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d
                    .try_into()
                    .unwrap(),
                buy_token: 0x0593e034DdA23eea82d2bA9a30960ED42CF4A01502Cc2351Dc9B9881F9931a68
                    .try_into()
                    .unwrap(),
            },
        );

    avnu_configs
        .append(
            AvnuConfig {
                sell_token: 0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC
                    .try_into()
                    .unwrap(),
                buy_token: 0x0593e034DdA23eea82d2bA9a30960ED42CF4A01502Cc2351Dc9B9881F9931a68
                    .try_into()
                    .unwrap(),
            },
        );

    avnu_configs
        .append(
            AvnuConfig {
                sell_token: 0x0593e034DdA23eea82d2bA9a30960ED42CF4A01502Cc2351Dc9B9881F9931a68
                    .try_into()
                    .unwrap(),
                buy_token: 0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC
                    .try_into()
                    .unwrap(),
            },
        );

    // wBTC bridge
    let starkgate_bridge = 0x07aeec4870975311a7396069033796b61cd66ed49d22a786cba12a8d76717302
        .try_into()
        .unwrap();
    let starkgate_l1_recipient = 0xaA1032BC95d09373E84452b9DdCb23464f8c294D.try_into().unwrap();
    let starkgate_token = 0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac
        .try_into()
        .unwrap();

    _generate_merkle_tree(
        vault_allocator,
        decoder_and_sanitizer,
        avnu_router_middleware,
        avnu_configs.span(),
        ekubo_adapter,
        starkgate_bridge,
        starkgate_l1_recipient,
        starkgate_token,
    );
}


fn _generate_merkle_tree(
    vault_allocator: ContractAddress,
    vault_decoder_and_sanitizer: ContractAddress,
    avnu_router_middleware: ContractAddress,
    avnu_configs: Span<AvnuConfig>,
    ekubo_adapter: ContractAddress,
    starkgate_bridge: ContractAddress,
    starkgate_l1_recipient: EthAddress,
    starkgate_token: ContractAddress,
) {
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    _add_avnu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator,
        vault_decoder_and_sanitizer,
        avnu_router_middleware,
        avnu_configs,
    );

    let mut starkgate_configs: Array<StarkgateConfig> = ArrayTrait::new();
    starkgate_configs
        .append(
            StarkgateConfig {
                l2_bridge: starkgate_bridge,
                l2_token: starkgate_token,
                l1_recipient: starkgate_l1_recipient,
            },
        );

    _add_starkgate_leafs(
        ref leafs, ref leaf_index, vault_decoder_and_sanitizer, starkgate_configs.span(),
    );

    _add_ekubo_adapter_leafs(
        ref leafs, ref leaf_index, vault_allocator, vault_decoder_and_sanitizer, ekubo_adapter,
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
    println!("vault_allocator: {:?}", vault_allocator);
    println!("root: {:?}", root);
    println!("tree_capacity: {:?}", tree_capacity);
    println!("leaf_used: {:?}", leaf_used);
    println!("leaf_additional_data: {:?}", leaf_additional_data);
    println!("tree: {:?}", tree);
}
