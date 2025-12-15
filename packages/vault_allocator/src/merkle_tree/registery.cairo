// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

// tokens
use starknet::ContractAddress;

pub fn STRK() -> ContractAddress {
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d.try_into().unwrap()
}

pub fn WBTC() -> ContractAddress {
    0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac.try_into().unwrap()
}

pub fn USDC() -> ContractAddress {
    0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8.try_into().unwrap()
}

pub fn USN() -> ContractAddress {
    0x02411565ef1a14decfbe83d2e987cced918cd752508a3d9c55deb67148d14d17.try_into().unwrap()
}


pub fn USDC_CCTP() -> ContractAddress {
    0x033068F6539f8e6e6b131e6B2B814e6c34A5224bC66947c47DaB9dFeE93b35fb.try_into().unwrap()
}

pub fn USDT() -> ContractAddress {
    0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8.try_into().unwrap()
}

pub fn ETH() -> ContractAddress {
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7.try_into().unwrap()
}

pub fn DAI() -> ContractAddress {
    0x05574eb6b8789a91466f902c380d978e472db68170ff82a5b650b95a58ddf4ad.try_into().unwrap()
}

pub fn wstETH() -> ContractAddress {
    0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b.try_into().unwrap()
}

// Starkgate
pub fn STARKGATE_USDC_BRIDGE() -> ContractAddress {
    0x05cd48fccbfd8aa2773fe22c217e808319ffcc1c5a6a463f7d8fa2da48218196.try_into().unwrap()
}

// Price router
pub fn PRICE_ROUTER() -> ContractAddress {
    0x566440457a0c6189c5dcbb661bd8f9a09961c78bfb50f6648977e9ca5972619.try_into().unwrap()
}

// CCTP
pub fn CCTP_USDC_BRIDGE() -> ContractAddress {
    0x7d421b9ca8aa32df259965cda8acb93f7599f69209a41872ae84638b2a20f2a.try_into().unwrap()
}


// VESU

pub fn VESU_SINGLETON() -> ContractAddress {
    0x000d8d6dfec4d33bfb6895de9f3852143a17c6f92fd2a21da3d6924d34870160.try_into().unwrap()
}

pub const GENESIS_POOL_ID: felt252 =
    2198503327643286920898110335698706244522220458610657370981979460625005526824;

pub fn VESU_GENESIS_POOL_V_TOKEN_WSTETH() -> ContractAddress {
    0x7cb1a46709214b94f51655be696a4ff6f9bdbbb6edb19418b6a55d190536048.try_into().unwrap()
}

pub fn VESU_GENESIS_POOL_V_TOKEN_USDT() -> ContractAddress {
    0x40e480d202b47eb9335c31fc328ecda216231425dae74f87d1a97e6e7901dce.try_into().unwrap()
}


// PRAGMA

pub fn PRAGMA() -> ContractAddress {
    0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b.try_into().unwrap()
}


pub fn STRK_PRAGMA_ID() -> felt252 {
    6004514686061859652.try_into().unwrap()
}

pub fn WBTC_PRAGMA_ID() -> felt252 {
    6287680677296296772.try_into().unwrap()
}

pub fn USDC_PRAGMA_ID() -> felt252 {
    6148332971638477636.try_into().unwrap()
}

pub fn USDT_PRAGMA_ID() -> felt252 {
    6148333044652921668.try_into().unwrap()
}

pub fn ETH_PRAGMA_ID() -> felt252 {
    19514442401534788.try_into().unwrap()
}

pub fn DAI_PRAGMA_ID() -> felt252 {
    19212080998863684.try_into().unwrap()
}

pub fn wstETH_PRAGMA_ID() -> felt252 {
    412383036120118613857092.try_into().unwrap()
}


// AVNU
pub fn AVNU_ROUTER() -> ContractAddress {
    0x04270219d365d6b017231b52e92b3fb5d7c8378b05e9abc97724537a80e93b0f.try_into().unwrap()
}
