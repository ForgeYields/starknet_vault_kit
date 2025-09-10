// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.
use alexandria_math::i257::I257Impl;
use starknet::ContractAddress;
use vault_allocator::test::register::{ETH, GENESIS_POOL_ID, wstETH};
use vault_allocator::test::utils::{
    ManageLeaf, _add_avnu_leafs, _add_vesu_leafs, _pad_leafs_to_power_of_two, generate_merkle_tree,
    get_leaf_hash,
};
use super::utils::DUMMY_ADDRESS;

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
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    // MANDATORY
    let vault: ContractAddress = DUMMY_ADDRESS();
    let vault_allocator = DUMMY_ADDRESS();
    let manager = DUMMY_ADDRESS();
    let decoder_and_sanitizer = DUMMY_ADDRESS();
    let router = DUMMY_ADDRESS();

    // INTEGRATIONS

    let pool_id = GENESIS_POOL_ID;
    let mut assets_to_supply = ArrayTrait::new();
    assets_to_supply.append(wstETH());
    let mut assets_to_borrow_per_assets_to_supply = ArrayTrait::new();
    assets_to_borrow_per_assets_to_supply.append(array![ETH()].span());

    _add_vesu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator,
        decoder_and_sanitizer,
        pool_id,
        assets_to_supply.span(),
        assets_to_borrow_per_assets_to_supply.span(),
    );

    let mut pairs_to_swap = ArrayTrait::new();
    pairs_to_swap.append((ETH(), wstETH()));

    _add_avnu_leafs(
        ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, router, pairs_to_swap,
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
    println!("manager: {:?}", manager);
    println!("decoder_and_sanitizer: {:?}", decoder_and_sanitizer);
    println!("root: {:?}", root);
    println!("tree_capacity: {:?}", tree_capacity);
    println!("leaf_used: {:?}", leaf_used);
    println!("leaf_additional_data: {:?}", leaf_additional_data);
    println!("tree: {:?}", tree);
}
