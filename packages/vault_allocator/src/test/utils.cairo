// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use openzeppelin::merkle_tree::hashes::PedersenCHasher;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    map_entry_address, store,
};
use starknet::{ClassHash, ContractAddress};
use vault_allocator::adapters::ekubo_adapter::interface::IEkuboAdapterDispatcher;
use vault_allocator::integration_interfaces::ekubo::{Bounds, PoolKey};
use vault_allocator::manager::interface::IManagerDispatcher;
use vault_allocator::merkle_tree::registery::{
    DAI, DAI_PRAGMA_ID, ETH, ETH_PRAGMA_ID, PRAGMA, STRK, STRK_PRAGMA_ID, USDC, USDC_PRAGMA_ID,
    USDT, USDT_PRAGMA_ID, WBTC, WBTC_PRAGMA_ID, wstETH, wstETH_PRAGMA_ID,
};
use vault_allocator::mocks::counter::ICounterDispatcher;
use vault_allocator::mocks::vault::MockVault::MockVaultTraitDispatcher;
use vault_allocator::periphery::price_router::interface::{
    IPriceRouterDispatcher, IPriceRouterDispatcherTrait,
};
use vault_allocator::vault_allocator::interface::IVaultAllocatorDispatcher;

pub const WAD: u256 = 1_000_000_000_000_000_000;
pub const INITIAL_SLIPPAGE_BPS: u256 = 100; // 1%


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

pub fn deploy_ekubo_adapter(
    owner: ContractAddress,
    vault_allocator: ContractAddress,
    ekubo_positions_contract: ContractAddress,
    bounds_settings: Bounds,
    pool_key: PoolKey,
    ekubo_positions_nft: ContractAddress,
    ekubo_core: ContractAddress,
) -> IEkuboAdapterDispatcher {
    let ekubo_adapter = declare("EkuboAdapter").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    ekubo_positions_contract.serialize(ref calldata);
    bounds_settings.serialize(ref calldata);
    pool_key.serialize(ref calldata);
    ekubo_positions_nft.serialize(ref calldata);
    ekubo_core.serialize(ref calldata);
    let (ekubo_adapter_address, _) = ekubo_adapter.deploy(@calldata).unwrap();
    IEkuboAdapterDispatcher { contract_address: ekubo_adapter_address }
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

pub fn deploy_avnu_middleware(
    vault_allocator: ContractAddress,
    price_router: ContractAddress,
    slippage: u16,
    period: u64,
    allowed_calls_per_period: u64,
) -> ContractAddress {
    let avnu_middleware = declare("AvnuMiddleware").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault_allocator.serialize(ref calldata);
    price_router.serialize(ref calldata);
    slippage.serialize(ref calldata);
    period.serialize(ref calldata);
    allowed_calls_per_period.serialize(ref calldata);
    let (avnu_middleware_address, _) = avnu_middleware.deploy(@calldata).unwrap();
    avnu_middleware_address
}


pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}

/// Sets the ERC20 balance of `account` for the given `token` to `amount`.
/// This directly writes to the contract storage, bypassing normal transfer logic.
pub fn set_token_balance(token: ContractAddress, account: ContractAddress, amount: u256) {
    let mut calldata = ArrayTrait::new();
    amount.serialize(ref calldata);
    store(
        token,
        map_entry_address(selector!("ERC20_balances"), array![account.into()].span()),
        calldata.span(),
    );
}

/// Sets the ERC20 balance for tokens that use 'balances' storage selector (e.g., Circle USDC_CCTP).
pub fn set_token_balance_circle(token: ContractAddress, account: ContractAddress, amount: u256) {
    let mut calldata = ArrayTrait::new();
    amount.serialize(ref calldata);
    store(
        token,
        map_entry_address(selector!("balances"), array![account.into()].span()),
        calldata.span(),
    );
}

