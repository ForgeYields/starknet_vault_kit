// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ClassHash, ContractAddress};
use vault::redeem_request::interface::IRedeemRequestDispatcher;
use vault::vault::interface::IVaultDispatcher;
use vault::vault::vault::Vault;
use vault_allocator::mocks::counter::ICounterDispatcher;

pub const WAD: u256 = 1_000_000_000_000_000_000;

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

pub fn FEES_RECIPIENT() -> ContractAddress {
    'FEES_RECIPIENT'.try_into().unwrap()
}

pub fn PAUSER() -> ContractAddress {
    'PAUSER'.try_into().unwrap()
}

pub fn ORACLE() -> ContractAddress {
    'ORACLE'.try_into().unwrap()
}

pub fn DUMMY_ADDRESS() -> ContractAddress {
    'DUMMY_ADDRESS'.try_into().unwrap()
}

pub fn OTHER_DUMMY_ADDRESS() -> ContractAddress {
    'OTHER_DUMMY_ADDRESS'.try_into().unwrap()
}

pub fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

pub fn USER2() -> ContractAddress {
    'USER2'.try_into().unwrap()
}


pub fn VAULT_ALLOCATOR() -> ContractAddress {
    'VAULT_ALLOCATOR'.try_into().unwrap()
}

pub fn VAULT_NAME() -> ByteArray {
    "Vault"
}

pub fn VAULT_SYMBOL() -> ByteArray {
    "VLT"
}

pub fn REDEEM_FEES() -> u256 {
    Vault::WAD / 1000
}

pub fn MANAGEMENT_FEES() -> u256 {
    Vault::WAD / 100
}

pub fn PERFORMANCE_FEES() -> u256 {
    Vault::WAD / 10
}

pub fn REPORT_DELAY() -> u64 {
    Vault::HOUR
}

pub fn MAX_DELTA() -> u256 {
    Vault::WAD / 100
}

pub fn deploy_vault(underlying_asset: ContractAddress) -> IVaultDispatcher {
    let vault = declare("Vault").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    VAULT_NAME().serialize(ref calldata);
    VAULT_SYMBOL().serialize(ref calldata);
    underlying_asset.serialize(ref calldata);
    OWNER().serialize(ref calldata);
    FEES_RECIPIENT().serialize(ref calldata);
    REDEEM_FEES().serialize(ref calldata);
    MANAGEMENT_FEES().serialize(ref calldata);
    PERFORMANCE_FEES().serialize(ref calldata);
    REPORT_DELAY().serialize(ref calldata);
    MAX_DELTA().serialize(ref calldata);
    let (vault_allocator_address, _) = vault.deploy(@calldata).unwrap();
    IVaultDispatcher { contract_address: vault_allocator_address }
}

pub fn deploy_erc721_receiver_at(targetAddress: ContractAddress) -> ContractAddress {
    let vault_erc721_receiver = declare("MockERC721Receiver").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    let (vault_erc721_receiver_address, _) = vault_erc721_receiver
        .deploy_at(@calldata, targetAddress)
        .unwrap();
    vault_erc721_receiver_address
}

pub fn deploy_redeem_request(vault: ContractAddress) -> IRedeemRequestDispatcher {
    let redeem_request = declare("RedeemRequest").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    vault.serialize(ref calldata);
    let (redeem_request_address, _) = redeem_request.deploy(@calldata).unwrap();
    IRedeemRequestDispatcher { contract_address: redeem_request_address }
}


pub fn deploy_counter() -> (ICounterDispatcher, ClassHash) {
    let counter = declare("Counter").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    let initial_value: u128 = 0;
    initial_value.serialize(ref calldata);
    let (counter_address, _) = counter.deploy(@calldata).unwrap();
    (ICounterDispatcher { contract_address: counter_address }, *counter.class_hash)
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


pub fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address(:contract_address, :caller_address, span: CheatSpan::TargetCalls(1));
}


pub fn between<
    T,
    impl TIntoU256: Into<T, u256>,
    impl TPartialOrd: PartialOrd<T>,
    impl TAdd: Add<T>,
    impl TSub: Sub<T>,
    impl TMod: Rem<T>,
    impl TFromOne: TryInto<felt252, T>,
    impl TDrop: Drop<T>,
    impl TCopy: Copy<T>,
>(
    min: T, max: T, val: T,
) -> T {
    min + (val % (max - min + TryInto::<felt252, T>::try_into(1).unwrap()))
}
