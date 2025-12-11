// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

//! # AssetTransferPod Contract
//!
//! Upgradeable and ownable contract that can transfer assets to a vault.
//! Owner can authorize addresses to transfer ERC20 tokens to the configured vault.

#[starknet::contract]
pub mod AssetTransferPod {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::ContractAddress;
    use vault_allocator::pods::components::asset_transfer_pod::AssetTransferPodComponent;
    use vault_allocator::pods::components::asset_transfer_pod::AssetTransferPodComponent::InternalTrait as AssetTransferPodInternalTrait;

    // --- OpenZeppelin Component Integrations ---
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(
        path: AssetTransferPodComponent, storage: asset_transfer_pod, event: AssetTransferPodEvent,
    );

    // --- Component Implementations ---
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AssetTransferPodImpl =
        AssetTransferPodComponent::AssetTransferPodImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pub asset_transfer_pod: AssetTransferPodComponent::Storage,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        AssetTransferPodEvent: AssetTransferPodComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        vault_allocator: ContractAddress,
        owner: ContractAddress,
        authorized_caller: ContractAddress,
    ) {
        self
            .asset_transfer_pod
            .initialize_asset_transfer_pod(vault_allocator, owner, authorized_caller);
    }
}
