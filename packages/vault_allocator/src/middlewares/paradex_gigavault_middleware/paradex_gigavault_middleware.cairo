// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod ParadexGigaVaultMiddleware {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_contract_address};
    use vault_allocator::integration_interfaces::paradex_gigavault::{
        IParadexGigaVaultDispatcher, IParadexGigaVaultDispatcherTrait,
    };
    use vault_allocator::middlewares::paradex_gigavault_middleware::interface::IParadexGigaVaultMiddleware;
    use vault_allocator::pods::components::asset_transfer_pod::AssetTransferPodComponent;
    use vault_allocator::pods::components::asset_transfer_pod::AssetTransferPodComponent::InternalTrait as AssetTransferPodInternalTrait;
    use crate::pods::components::interface::IAssetTransferPod;
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
        pub paradex_gigavault_vault: IParadexGigaVaultDispatcher,
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
        vault: ContractAddress,
        owner: ContractAddress,
        authorized_caller: ContractAddress,
        paradex_gigavault_vault: ContractAddress,
    ) {
        self.asset_transfer_pod.initialize_asset_transfer_pod(vault, owner, authorized_caller);
        self
            .paradex_gigavault_vault
            .write(IParadexGigaVaultDispatcher { contract_address: paradex_gigavault_vault });
    }


    #[abi(embed_v0)]
    impl ParadexGigaVaultMiddlewareImpl of IParadexGigaVaultMiddleware<ContractState> {
        fn request_withdrawal(ref self: ContractState, shares: u256) {
            let paradex_gigavault_vault = self.paradex_gigavault_vault.read();
            let asset_dispatcher = ERC20ABIDispatcher {
                contract_address: paradex_gigavault_vault.contract_address,
            };
            // Transfer assets from vault allocator vault to the middleware vault and approve +
            // request withdrawal from Paradex GigaVault
            asset_dispatcher.transfer_from(self.get_vault(), get_contract_address(), shares);
            asset_dispatcher.approve(paradex_gigavault_vault.contract_address, shares);
            paradex_gigavault_vault.request_withdrawal(shares);
        }
    }
}
