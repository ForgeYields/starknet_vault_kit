// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use starknet::ContractAddress;
use vault_allocator::integration_interfaces::endur::{IEndurLstDispatcher, IEndurLstDispatcherTrait};
use vault_allocator::merkle_tree::base::{ManageLeaf, get_symbol};

/// Adds the leafs to stake into and unstake from an Endur LST (xSTRK, xWBTC, ...).
/// The decoder and sanitizer must embed both the ERC-4626 and the Endur components.
/// The withdraw queue is read from the LST config, and the withdraw queue NFT minted on
/// `withdraw` / `redeem` is always sent to the vault allocator.
pub fn _add_endur_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    lst: ContractAddress,
) {
    let asset = IERC4626Dispatcher { contract_address: lst }.asset();
    let withdraw_queue = IEndurLstDispatcher { contract_address: lst }.get_config().withdraw_queue;
    let lst_symbol = get_symbol(lst);
    let asset_symbol = get_symbol(asset);

    // Approval
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: asset,
                selector: selector!("approve"),
                argument_addresses: array![lst.into()].span(),
                description: "Approve " + lst_symbol.clone() + " to spend " + asset_symbol.clone(),
            },
        );
    leaf_index += 1;

    // Deposit
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: lst,
                selector: selector!("deposit"),
                argument_addresses: array![vault_allocator.into()].span(),
                description: "Endur: deposit "
                    + asset_symbol.clone()
                    + " for "
                    + lst_symbol.clone(),
            },
        );
    leaf_index += 1;

    // Deposit with referral
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: lst,
                selector: selector!("deposit_with_referral"),
                argument_addresses: array![vault_allocator.into()].span(),
                description: "Endur: deposit with referral "
                    + asset_symbol.clone()
                    + " for "
                    + lst_symbol.clone(),
            },
        );
    leaf_index += 1;

    // Request withdrawal by assets
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: lst,
                selector: selector!("withdraw"),
                argument_addresses: array![vault_allocator.into(), vault_allocator.into()].span(),
                description: "Endur: request withdrawal of "
                    + asset_symbol.clone()
                    + " from "
                    + lst_symbol.clone(),
            },
        );
    leaf_index += 1;

    // Request withdrawal by shares
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: lst,
                selector: selector!("redeem"),
                argument_addresses: array![vault_allocator.into(), vault_allocator.into()].span(),
                description: "Endur: request redeem of "
                    + lst_symbol.clone()
                    + " for "
                    + asset_symbol.clone(),
            },
        );
    leaf_index += 1;

    // Claim withdrawal
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: withdraw_queue,
                selector: selector!("claim_withdrawal"),
                argument_addresses: array![].span(),
                description: "Endur: claim " + asset_symbol + " withdrawal from " + lst_symbol,
            },
        );
    leaf_index += 1;
}
