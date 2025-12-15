// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// Comprehensive test strategy for SDK testing
// Includes: Starkgate middleware, Hyperlane middleware, CCTP middleware,
// Vesu V2, Ekubo adapter, ERC4626, Defi Spring, Starknet Vault Kit strategies

use starknet::{ContractAddress, EthAddress};
use vault_allocator::merkle_tree::base::{
    ManageLeaf, _add_vault_allocator_leafs, _pad_leafs_to_power_of_two, generate_merkle_tree,
    get_leaf_hash,
};
use vault_allocator::merkle_tree::integrations::avnu::{AvnuConfig, _add_avnu_leafs};
use vault_allocator::merkle_tree::integrations::cctp::{
    CctpMiddlewareConfig, _add_cctp_middleware_leafs,
};
use vault_allocator::merkle_tree::integrations::defi_spring::{
    DefiSpringConfig, _add_defi_spring_leafs,
};
use vault_allocator::merkle_tree::integrations::ekubo_adapter::_add_ekubo_adapter_leafs;
use vault_allocator::merkle_tree::integrations::erc4626::_add_erc4626_leafs;
use vault_allocator::merkle_tree::integrations::hyperlane::{
    HyperlaneMiddlewareConfig, _add_hyperlane_middleware_leafs,
};
use vault_allocator::merkle_tree::integrations::starkgate::{
    StarkgateMiddlewareConfig, _add_starkgate_middleware_leafs,
};
use vault_allocator::merkle_tree::integrations::starknet_vault_kit_strategies::_add_starknet_vault_kit_strategies;
use vault_allocator::merkle_tree::integrations::vesu_v2::{VesuV2Config, _add_vesu_v2_leafs};
use vault_allocator::merkle_tree::registery::{
    ETH, STARKGATE_USDC_BRIDGE, STRK, USDC, USDC_CCTP, USDT, WBTC, wstETH,
};

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
fn test_creator_sdk_comprehensive() {
    // Vault and periphery addresses (wrong addresses just for testing)
    let vault: ContractAddress = 0x54187c3709bdf5db61040b93305384d18538b8fa59f756e5dcec455c268772e
        .try_into()
        .unwrap();
    let vault_allocator: ContractAddress =
        0x6f5da376a9bee7398765a57554ae0aa31697b4acaf3b08b8d2630f5bb3279d3
        .try_into()
        .unwrap();

    // Single decoder and sanitizer for all integrations
    let decoder_and_sanitizer: ContractAddress =
        0x02F3C36C681b4B0DbE0314586B5fD23e7F790509DE958683f3d3DA41Ba98A8d8
        .try_into()
        .unwrap();

    // AVNU router middleware
    let avnu_router_middleware: ContractAddress =
        0x076C30f11D9d28c0Cc5f2E7cBfAB07441931DAF47CE4dc38B4fd7bBf509112Ff
        .try_into()
        .unwrap();

    // Integration addresses
    // ERC4626 vault (e.g., a yield-bearing vault)
    let erc4626_vault: ContractAddress =
        0x050707bc3b8730022f10530c2c6f6b9467644129c50c2868ad0036c5e4e9e616
        .try_into()
        .unwrap();

    // Starknet Vault Kit strategy (another SVK vault)
    let svk_strategy: ContractAddress =
        0x07fDcec0ceF01294C9C3D52415215949805C77bAe8003702A7928fd6D2c36BC1
        .try_into()
        .unwrap();

    // Ekubo adapter for USDC/USDT pair
    let ekubo_adapter: ContractAddress =
        0x59053bd0f16f755b83bb556ef75e7527d29ae27e4da437b94cdc323e3665182
        .try_into()
        .unwrap();

    // Middleware addresses
    let starkgate_middleware: ContractAddress =
        0x057c3e904b23095e905e00e61f49ef46007f64f8b0ceb3c1de729d936f4c4203
        .try_into()
        .unwrap();
    let hyperlane_middleware: ContractAddress =
        0x057c3e904b23095e905e00e61f49ef46007f64f8b0ceb3c1de729d936f4c4204
        .try_into()
        .unwrap();
    let cctp_middleware: ContractAddress =
        0x057c3e904b23095e905e00e61f49ef46007f64f8b0ceb3c1de729d936f4c4205
        .try_into()
        .unwrap();

    // Defi Spring claim contract
    let defi_spring_claim_contract: ContractAddress =
        0x057c3e904b23095e905e00e61f49ef46007f64f8b0ceb3c1de729d936f4c4206
        .try_into()
        .unwrap();

    // L1 recipient for bridge operations
    let l1_recipient: EthAddress = 0x732357e321Bf7a02CbB690fc2a629161D7722e29.try_into().unwrap();

    // Hyperlane destination (e.g., Ethereum mainnet domain)
    let hyperlane_destination: u32 = 1; // Ethereum domain
    let hyperlane_recipient: u256 =
        0x732357e321Bf7a02CbB690fc2a629161D7722e29; // Same as l1_recipient for simplicity

    // CCTP destination (e.g., Ethereum)
    let cctp_destination_domain: u32 = 0; // Ethereum CCTP domain
    let cctp_mint_recipient: u256 = 0x732357e321Bf7a02CbB690fc2a629161D7722e29;
    let cctp_destination_caller: u256 = 0; // No specific caller restriction

    // Build configs
    let mut vesu_v2_configs: Array<VesuV2Config> = array![
        VesuV2Config {
            pool_contract: 0x02eef0c13b10b487ea5916b54c0a7f98ec43fb3048f60fdeedaf5b08f6f88aaf
                .try_into()
                .unwrap(),
            collateral_asset: WBTC(),
            debt_assets: array![USDC()].span(),
        },
        VesuV2Config {
            pool_contract: 0x02eef0c13b10b487ea5916b54c0a7f98ec43fb3048f60fdeedaf5b08f6f88aaf
                .try_into()
                .unwrap(),
            collateral_asset: wstETH(),
            debt_assets: array![USDC(), USDT()].span(),
        },
    ];

    let mut avnu_configs: Array<AvnuConfig> = array![
        AvnuConfig { sell_token: STRK(), buy_token: USDC() },
        AvnuConfig { sell_token: USDC(), buy_token: STRK() },
        AvnuConfig { sell_token: ETH(), buy_token: USDC() },
        AvnuConfig { sell_token: USDC(), buy_token: ETH() },
    ];

    let mut starkgate_middleware_configs: Array<StarkgateMiddlewareConfig> = array![
        StarkgateMiddlewareConfig {
            middleware: starkgate_middleware,
            l2_bridge: STARKGATE_USDC_BRIDGE(),
            l2_token: USDC(),
            l1_recipient: l1_recipient,
            token_to_claim: USDC(),
        },
    ];

    let mut hyperlane_middleware_configs: Array<HyperlaneMiddlewareConfig> = array![
        HyperlaneMiddlewareConfig {
            middleware: hyperlane_middleware,
            token_to_bridge: USDC(),
            token_to_claim: USDC(),
            destination_domain: hyperlane_destination,
            recipient: hyperlane_recipient,
        },
    ];

    let mut cctp_middleware_configs: Array<CctpMiddlewareConfig> = array![
        CctpMiddlewareConfig {
            middleware: cctp_middleware,
            burn_token: USDC_CCTP(),
            token_to_claim: USDC(),
            destination_domain: cctp_destination_domain,
            mint_recipient: cctp_mint_recipient,
            destination_caller: cctp_destination_caller,
        },
    ];

    let mut defi_spring_configs: Array<DefiSpringConfig> = array![
        DefiSpringConfig { claim_contract: defi_spring_claim_contract, reward_token: STRK() },
    ];

    // Generate the merkle tree
    _generate_sdk_test_merkle_tree(
        vault,
        vault_allocator,
        decoder_and_sanitizer,
        avnu_router_middleware,
        vesu_v2_configs.span(),
        avnu_configs.span(),
        array![erc4626_vault].span(),
        array![svk_strategy].span(),
        ekubo_adapter,
        starkgate_middleware_configs.span(),
        hyperlane_middleware_configs.span(),
        cctp_middleware_configs.span(),
        defi_spring_configs.span(),
    );
}


fn _generate_sdk_test_merkle_tree(
    vault: ContractAddress,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    avnu_router_middleware: ContractAddress,
    vesu_v2_configs: Span<VesuV2Config>,
    avnu_configs: Span<AvnuConfig>,
    erc4626_vaults: Span<ContractAddress>,
    svk_strategies: Span<ContractAddress>,
    ekubo_adapter: ContractAddress,
    starkgate_middleware_configs: Span<StarkgateMiddlewareConfig>,
    hyperlane_middleware_configs: Span<HyperlaneMiddlewareConfig>,
    cctp_middleware_configs: Span<CctpMiddlewareConfig>,
    defi_spring_configs: Span<DefiSpringConfig>,
) {
    let mut leafs: Array<ManageLeaf> = ArrayTrait::new();
    let mut leaf_index: u256 = 0;

    // 1. Base vault allocator leafs (mandatory)
    println!("Adding vault allocator base leafs");
    _add_vault_allocator_leafs(
        ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, vault,
    );

    // 2. Vesu V2 leafs
    println!("Adding Vesu V2 leafs");
    _add_vesu_v2_leafs(
        ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, vesu_v2_configs,
    );

    // 3. ERC4626 leafs
    println!("Adding ERC4626 leafs");
    for erc4626_vault in erc4626_vaults {
        _add_erc4626_leafs(
            ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, *erc4626_vault,
        );
    }

    // 4. Starknet Vault Kit strategies leafs
    println!("Adding Starknet Vault Kit strategies leafs");
    for svk_strategy in svk_strategies {
        _add_starknet_vault_kit_strategies(
            ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, *svk_strategy,
        );
    }

    // 5. Ekubo adapter leafs
    println!("Adding Ekubo adapter leafs");
    _add_ekubo_adapter_leafs(
        ref leafs, ref leaf_index, vault_allocator, decoder_and_sanitizer, ekubo_adapter,
    );

    // 6. AVNU swap leafs
    println!("Adding AVNU leafs");
    _add_avnu_leafs(
        ref leafs,
        ref leaf_index,
        vault_allocator,
        decoder_and_sanitizer,
        avnu_router_middleware,
        avnu_configs,
    );

    // 7. Starkgate middleware leafs
    println!("Adding Starkgate middleware leafs");
    _add_starkgate_middleware_leafs(
        ref leafs, ref leaf_index, decoder_and_sanitizer, starkgate_middleware_configs,
    );

    // 8. Hyperlane middleware leafs
    println!("Adding Hyperlane middleware leafs");
    _add_hyperlane_middleware_leafs(
        ref leafs, ref leaf_index, decoder_and_sanitizer, hyperlane_middleware_configs,
    );

    // 9. CCTP middleware leafs
    println!("Adding CCTP middleware leafs");
    _add_cctp_middleware_leafs(
        ref leafs, ref leaf_index, decoder_and_sanitizer, cctp_middleware_configs,
    );

    // 10. Defi Spring leafs
    println!("Adding Defi Spring leafs");
    _add_defi_spring_leafs(ref leafs, ref leaf_index, decoder_and_sanitizer, defi_spring_configs);

    // Finalize merkle tree
    let leaf_used = leafs.len();
    println!("Total leafs before padding: {:?}", leaf_used);

    _pad_leafs_to_power_of_two(ref leafs, ref leaf_index);
    let tree_capacity = leafs.len();
    let tree = generate_merkle_tree(leafs.span());
    let root = *tree.at(tree.len() - 1).at(0);

    // Generate leaf additional data for export
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

    // Print output for export_merkle.sh
    println!("=== SDK TEST MERKLE TREE ===");
    println!("vault: {:?}", vault);
    println!("vault_allocator: {:?}", vault_allocator);
    println!("root: {:?}", root);
    println!("tree_capacity: {:?}", tree_capacity);
    println!("leaf_used: {:?}", leaf_used);
    println!("leaf_additional_data: {:?}", leaf_additional_data);
    println!("tree: {:?}", tree);
}
