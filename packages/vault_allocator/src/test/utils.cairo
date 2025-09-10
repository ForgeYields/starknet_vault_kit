// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use core::hash::HashStateTrait;
use core::num::traits::Zero;
use core::pedersen::PedersenTrait;
use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
use openzeppelin::merkle_tree::hashes::PedersenCHasher;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::syscalls::call_contract_syscall;
use starknet::{ClassHash, ContractAddress};
use vault_allocator::integration_interfaces::vesu::{
    IDefaultExtensionPOV2Dispatcher, IDefaultExtensionPOV2DispatcherTrait, ISingletonV2Dispatcher,
    ISingletonV2DispatcherTrait,
};
use vault_allocator::manager::interface::IManagerDispatcher;
use vault_allocator::mocks::counter::ICounterDispatcher;
use vault_allocator::mocks::vault::MockVault::MockVaultTraitDispatcher;
use vault_allocator::periphery::price_router::interface::{
    IPriceRouterDispatcher, IPriceRouterDispatcherTrait,
};
use vault_allocator::test::register::{
    AVNU_ROUTER, DAI, DAI_PRAGMA_ID, ETH, ETH_PRAGMA_ID, PRAGMA, STRK, STRK_PRAGMA_ID, USDC,
    USDC_PRAGMA_ID, USDT, USDT_PRAGMA_ID, VESU_SINGLETON, WBTC, WBTC_PRAGMA_ID, wstETH,
    wstETH_PRAGMA_ID,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcher;
pub const WAD: u256 = 1_000_000_000_000_000_000;
pub const INITIAL_SLIPPAGE_BPS: u256 = 100; // 1%
use core::to_byte_array::FormatAsByteArray;


pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn MANAGER() -> ContractAddress {
    'MANAGER'.try_into().unwrap()
}

pub fn STRATEGIST() -> ContractAddress {
    'STRATEGIST'.try_into().unwrap()
}

pub fn DUMMY_ADDRESS() -> ContractAddress {
    'DUMMY_ADDRESS'.try_into().unwrap()
}


pub fn deploy_vault_allocator() -> IVaultAllocatorDispatcher {
    let vault_allocator = declare("VaultAllocator").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    let (vault_allocator_address, _) = vault_allocator.deploy(@calldata).unwrap();
    IVaultAllocatorDispatcher { contract_address: vault_allocator_address }
}

pub fn deploy_manager(vault_allocator: IVaultAllocatorDispatcher) -> IManagerDispatcher {
    let manager = declare("Manager").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.contract_address.serialize(ref calldata);
    let (manager_address, _) = manager.deploy(@calldata).unwrap();
    IManagerDispatcher { contract_address: manager_address }
}

pub fn deploy_counter() -> (ICounterDispatcher, ClassHash) {
    let counter = declare("Counter").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    let initial_value: u128 = 0;
    initial_value.serialize(ref calldata);
    let (counter_address, _) = counter.deploy(@calldata).unwrap();
    (ICounterDispatcher { contract_address: counter_address }, *counter.class_hash)
}


pub fn deploy_erc4626_mock(underlying: ContractAddress) -> ContractAddress {
    let erc4626 = declare("Erc4626Mock").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    underlying.serialize(ref calldata);
    let (erc4626_address, _) = erc4626.deploy(@calldata).unwrap();
    erc4626_address
}

pub fn deploy_erc20_mock() -> ContractAddress {
    let erc20 = declare("Erc20Mock").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    (WAD * 100).serialize(ref calldata);
    OWNER().serialize(ref calldata);
    OWNER().serialize(ref calldata);
    let (erc20_address, _) = erc20.deploy(@calldata).unwrap();
    erc20_address
}

pub fn deploy_mock_vault(underlying: ContractAddress) -> MockVaultTraitDispatcher {
    let mock_vault = declare("MockVault").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    underlying.serialize(ref calldata);
    let (mock_vault_address, _) = mock_vault.deploy(@calldata).unwrap();
    MockVaultTraitDispatcher { contract_address: mock_vault_address }
}

pub fn deploy_simple_decoder_and_sanitizer() -> ContractAddress {
    let simple_decoder_and_sanitizer = declare("SimpleDecoderAndSanitizer")
        .unwrap()
        .contract_class();
    let mut calldata = ArrayTrait::new();
    let (simple_decoder_and_sanitizer_address, _) = simple_decoder_and_sanitizer
        .deploy(@calldata)
        .unwrap();
    simple_decoder_and_sanitizer_address
}

pub fn deploy_price_router() -> ContractAddress {
    let price_router = declare("PriceRouter").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    PRAGMA().serialize(ref calldata);
    let (price_router_address, _) = price_router.deploy(@calldata).unwrap();
    price_router_address
}

pub fn initialize_price_router(price_router: ContractAddress) {
    let price_router = IPriceRouterDispatcher { contract_address: price_router };
    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(wstETH(), wstETH_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(STRK(), STRK_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(WBTC(), WBTC_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(USDC(), USDC_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(USDT(), USDT_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(ETH(), ETH_PRAGMA_ID());

    cheat_caller_address_once(price_router.contract_address, OWNER());
    price_router.set_asset_to_id(DAI(), DAI_PRAGMA_ID());
}

pub fn deploy_avnu_middleware(price_router: ContractAddress) -> ContractAddress {
    let avnu_middleware = declare("AvnuMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    AVNU_ROUTER().serialize(ref calldata);
    price_router.serialize(ref calldata);
    INITIAL_SLIPPAGE_BPS.serialize(ref calldata);
    let (avnu_middleware_address, _) = avnu_middleware.deploy(@calldata).unwrap();
    avnu_middleware_address
}


pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}


#[derive(PartialEq, Drop, Serde, Debug, Clone)]
pub struct ManageLeaf {
    pub decoder_and_sanitizer: ContractAddress,
    pub target: ContractAddress,
    pub selector: felt252,
    pub argument_addresses: Span<felt252>,
    pub description: ByteArray,
}

pub fn get_leaf_hash(leaf: ManageLeaf) -> felt252 {
    let mut serialized_struct: Array<felt252> = ArrayTrait::new();
    leaf.decoder_and_sanitizer.serialize(ref serialized_struct);
    leaf.target.serialize(ref serialized_struct);
    leaf.selector.serialize(ref serialized_struct);
    leaf.argument_addresses.serialize(ref serialized_struct);
    let first_element = serialized_struct.pop_front().unwrap();
    let mut state = PedersenTrait::new(first_element);
    while let Some(value) = serialized_struct.pop_front() {
        state = state.update(value);
    }
    state.finalize()
}

pub fn generate_merkle_tree(manage_leafs: Span<ManageLeaf>) -> Array<Array<felt252>> {
    let mut first_layer = ArrayTrait::new();
    let leafs_length = manage_leafs.len();
    for i in 0..leafs_length {
        first_layer.append(get_leaf_hash(manage_leafs.at(i).clone()));
    }
    let mut leafs = ArrayTrait::new();
    leafs.append(first_layer);
    _build_tree(leafs)
}

pub fn _build_tree(merkle_tree_in: Array<Array<felt252>>) -> Array<Array<felt252>> {
    let merkle_tree_in_length = merkle_tree_in.len();

    let mut current_layer_index = merkle_tree_in_length - 1;
    let current_layer_length = merkle_tree_in[current_layer_index].len();
    let mut next_layer_length = 0;
    if (current_layer_length % 2 != 0) {
        next_layer_length = (current_layer_length + 1) / 2;
    } else {
        next_layer_length = current_layer_length / 2;
    }
    let mut current_layer = ArrayTrait::new();
    let mut count = 0;
    let mut i = 0;
    while i < current_layer_length {
        current_layer
            .append(
                PedersenCHasher::commutative_hash(
                    *merkle_tree_in[current_layer_index].at(i),
                    *merkle_tree_in[current_layer_index].at(i + 1),
                ),
            );
        count += 1;
        i += 2;
    }

    let mut merkle_tree_out = merkle_tree_in.clone();
    merkle_tree_out.append(current_layer);

    if (next_layer_length > 1) {
        _build_tree(merkle_tree_out)
    } else {
        merkle_tree_out
    }
}

fn _next_power_of_two(x: u256) -> u256 {
    let mut power = 1_u256;
    while power < x {
        power = power * 2_u256;
    }
    power
}


pub fn _pad_leafs_to_power_of_two(ref leafs: Array<ManageLeaf>, ref leaf_index: u256) {
    let target_len = if leaf_index < 4_u256 {
        4_u256
    } else {
        _next_power_of_two(leaf_index)
    };
    let padding_needed = target_len - leaf_index;

    let mut i: u256 = 0_u256;
    while i < padding_needed {
        leafs
            .append(
                ManageLeaf {
                    decoder_and_sanitizer: Zero::zero(),
                    target: Zero::zero(),
                    selector: Zero::zero(),
                    argument_addresses: ArrayTrait::new().span(),
                    description: "",
                },
            );
        leaf_index += 1_u256;
        i += 1_u256;
    }
}


pub fn _get_proofs_using_tree(
    leafs: Array<ManageLeaf>, tree: Array<Array<felt252>>,
) -> Array<Span<felt252>> {
    let mut proofs = ArrayTrait::new();
    for i in 0..leafs.len() {
        let leaf = leafs.at(i);
        let mut serialized_struct: Array<felt252> = ArrayTrait::new();
        leaf.decoder_and_sanitizer.serialize(ref serialized_struct);
        leaf.target.serialize(ref serialized_struct);
        leaf.selector.serialize(ref serialized_struct);
        leaf.argument_addresses.serialize(ref serialized_struct);
        let first_element = serialized_struct.pop_front().unwrap();
        let mut state = PedersenTrait::new(first_element);

        while let Some(value) = serialized_struct.pop_front() {
            state = state.update(value);
        }
        let leaf_hash = state.finalize();
        let proof = _generate_proof(leaf_hash, tree.clone());
        proofs.append(proof);
    }
    proofs
}

pub fn _generate_proof(mut leaf: felt252, tree: Array<Array<felt252>>) -> Span<felt252> {
    let tree_length = tree.len();
    let mut proof = ArrayTrait::new();
    for i in 0..tree_length - 1 {
        let tree_current_layer = tree.at(i);
        let tree_current_layer_length = tree_current_layer.len();
        for j in 0..tree_current_layer_length {
            if leaf == *tree_current_layer.at(j) {
                let element_to_append = if j % 2 == 0 {
                    *tree_current_layer.at(j + 1)
                } else {
                    *tree_current_layer.at(j - 1)
                };
                leaf = PedersenCHasher::commutative_hash(leaf, element_to_append);
                proof.append(element_to_append);
                break;
            } else {
                assert(j != tree_current_layer_length - 1, 'leaf not found in tree');
            }
        }
    }
    proof.span()
}


// ========================================= VaultAllocator
// =========================================

pub fn _add_vault_allocator_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault_allocator: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    vault: IERC4626Dispatcher,
) {
    let underlying_asset = vault.asset();

    // Approvals
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: underlying_asset,
                selector: selector!("approve"),
                argument_addresses: array![vault.contract_address.into()].span(),
                description: "Approve"
                    + " "
                    + get_symbol(vault.contract_address)
                    + " "
                    + "to spend"
                    + " "
                    + get_symbol(underlying_asset),
            },
        );
    leaf_index += 1;

    // Bring liquidity

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: vault.contract_address,
                selector: selector!("bring_liquidity"),
                argument_addresses: array![].span(),
                description: "Bring liquidity" + " " + get_symbol(vault.contract_address),
            },
        );
    leaf_index += 1;
}


// ========================================= ERC4626 =========================================

pub fn _add_erc4626_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    erc4626: ContractAddress,
) {
    let erc4626_erc4646_disp = IERC4626Dispatcher { contract_address: erc4626 };
    let asset = erc4626_erc4646_disp.asset();

    // Approvals
    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: asset,
                selector: selector!("approve"),
                argument_addresses: array![erc4626.into()].span(),
                description: "Approve"
                    + " "
                    + get_symbol(erc4626)
                    + " "
                    + "to spend"
                    + " "
                    + get_symbol(asset),
            },
        );
    leaf_index += 1;

    // Deposits

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: erc4626,
                selector: selector!("deposit"),
                argument_addresses: array![vault.into()].span(),
                description: "Deposit"
                    + " "
                    + get_symbol(asset)
                    + " "
                    + "for"
                    + " "
                    + get_symbol(erc4626),
            },
        );
    leaf_index += 1;

    // Withdrawals

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: erc4626,
                selector: selector!("withdraw"),
                argument_addresses: array![vault.into(), vault.into()].span(),
                description: "Withdraw"
                    + " "
                    + get_symbol(asset)
                    + " "
                    + "from"
                    + " "
                    + get_symbol(erc4626),
            },
        );
    leaf_index += 1;

    // Minting

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: erc4626,
                selector: selector!("mint"),
                argument_addresses: array![vault.into()].span(),
                description: "Mint"
                    + " "
                    + get_symbol(erc4626)
                    + " "
                    + "from"
                    + " "
                    + get_symbol(asset),
            },
        );
    leaf_index += 1;

    // Redeeming

    leafs
        .append(
            ManageLeaf {
                decoder_and_sanitizer,
                target: erc4626,
                selector: selector!("redeem"),
                argument_addresses: array![vault.into(), vault.into()].span(),
                description: "Redeem"
                    + " "
                    + get_symbol(erc4626)
                    + " "
                    + "for"
                    + " "
                    + get_symbol(asset),
            },
        );
    leaf_index += 1;
}


// ========================================= VESU =========================================

pub fn _add_vesu_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    pool_id: felt252,
    collateral_assets: Span<ContractAddress>,
    debt_assets_per_collateral_asset: Span<Span<ContractAddress>>,
) {
    assert(collateral_assets.len() == debt_assets_per_collateral_asset.len(), 'inconsistent len');
    let singleton = ISingletonV2Dispatcher { contract_address: VESU_SINGLETON() };
    let pool_extension = singleton.extension(pool_id);
    assert(pool_extension != Zero::zero(), 'pool extension not found');
    let pool_extension = IDefaultExtensionPOV2Dispatcher { contract_address: pool_extension };

    for i in 0..collateral_assets.len() {
        let collateral_asset = *collateral_assets.at(i);
        let debt_assets = *debt_assets_per_collateral_asset.at(i);

        let v_token = pool_extension.v_token_for_collateral_asset(pool_id, collateral_asset);
        assert(v_token != Zero::zero(), 'v token not found');

        // earn mode
        _add_erc4626_leafs(ref leafs, ref leaf_index, vault, decoder_and_sanitizer, v_token);

        // debt mode
        let debt_assets_len = debt_assets.len();
        if debt_assets_len > 0 {
            for j in 0..debt_assets_len {
                let mut pool_id_str: ByteArray = FormatAsByteArray::format_as_byte_array(
                    @pool_id, 16,
                );

                // APPROVAL of collateral asset to the singleton
                leafs
                    .append(
                        ManageLeaf {
                            decoder_and_sanitizer,
                            target: collateral_asset,
                            selector: selector!("approve"),
                            argument_addresses: array![VESU_SINGLETON().into()].span(),
                            description: "Approve"
                                + " "
                                + "singleton"
                                + "_"
                                + pool_id_str.clone()
                                + " "
                                + "to spend"
                                + " "
                                + get_symbol(collateral_asset),
                        },
                    );
                leaf_index += 1;

                let debt_asset = *debt_assets.at(j);

                // MODIFY POSITION
                let mut argument_addresses_modify_position = ArrayTrait::new();

                // pool_id
                pool_id.serialize(ref argument_addresses_modify_position);

                // collateral_asset
                collateral_asset.serialize(ref argument_addresses_modify_position);

                // debt_asset
                debt_asset.serialize(ref argument_addresses_modify_position);

                // user
                vault.serialize(ref argument_addresses_modify_position);

                leafs
                    .append(
                        ManageLeaf {
                            decoder_and_sanitizer,
                            target: singleton.contract_address,
                            selector: selector!("modify_position"),
                            argument_addresses: argument_addresses_modify_position.span(),
                            description: "Modify position"
                                + " "
                                + "extension_pid"
                                + "_"
                                + pool_id_str
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
}


// ========================================= AVNU =========================================
pub fn _add_avnu_leafs(
    ref leafs: Array<ManageLeaf>,
    ref leaf_index: u256,
    vault: ContractAddress,
    decoder_and_sanitizer: ContractAddress,
    router: ContractAddress,
    sell_and_buy_token_address: Array<(ContractAddress, ContractAddress)>,
) {
    let mut seen_sells: Array<ContractAddress> = ArrayTrait::new();

    for i in 0..sell_and_buy_token_address.len() {
        let (sell_token_address, buy_token_address) = *sell_and_buy_token_address.at(i);

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
        vault.serialize(ref argument_addresses);

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

fn _contains_address(span: Span<ContractAddress>, addr: ContractAddress) -> bool {
    let mut i = 0;
    while i < span.len() {
        if *span.at(i) == addr {
            return true;
        }
        i += 1;
    }
    false
}


fn get_symbol(contract_address: ContractAddress) -> ByteArray {
    let ret_data = call_contract_syscall(contract_address, selector!("symbol"), array![].span());
    match ret_data {
        Ok(res) => {
            let res_len: u32 = res.len();
            if (res_len == 1) {
                let symbol_felt = *res.at(0);
                let mut symbol_byte_array: ByteArray = "";
                symbol_byte_array.append_word(symbol_felt, bytes_in_felt(symbol_felt));
                symbol_byte_array
            } else {
                let mut res_span = res;
                Serde::<ByteArray>::deserialize(ref res_span).unwrap()
            }
        },
        Err(revert_reason) => { panic!("revert_reason: {:?}", revert_reason); },
    }
}


fn bytes_in_felt(word: felt252) -> usize {
    if word == 0 {
        return 0;
    }
    let x: u256 = word.try_into().unwrap();

    let mut p: u256 = 1_u256;
    let mut bytes: usize = 0;

    while p <= x && bytes < 31 {
        p = p * 256_u256;
        bytes += 1;
    }

    bytes
}
