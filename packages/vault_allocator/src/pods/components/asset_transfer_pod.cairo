// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod AssetTransferPodComponent {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent::InternalTrait as UpgradeableInternalTrait;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use vault_allocator::pods::components::errors::Errors;
    use vault_allocator::pods::components::interface::IAssetTransferPod;

    #[storage]
    pub struct Storage {
        pub vault: ContractAddress,
        pub authorized_caller: ContractAddress,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        AssetTransferred: AssetTransferred,
        AuthorizedCallerSet: AuthorizedCallerSet,
        VaultSet: VaultSet,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct AssetTransferred {
        #[key]
        pub asset: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct AuthorizedCallerSet {
        #[key]
        pub caller: ContractAddress,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct VaultSet {
        #[key]
        pub vault: ContractAddress,
    }


    #[embeddable_as(AssetTransferPodImpl)]
    impl AssetTransferPod<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        impl Upgradeable: UpgradeableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IAssetTransferPod<ComponentState<TContractState>> {
        fn set_authorized_caller(
            ref self: ComponentState<TContractState>, authorized_caller: ContractAddress,
        ) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();

            self.authorized_caller.write(authorized_caller);
            self.emit(AuthorizedCallerSet { caller: authorized_caller });
        }

        fn set_vault(ref self: ComponentState<TContractState>, vault: ContractAddress) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();

            if vault.is_zero() {
                Errors::zero_address();
            }
            self.vault.write(vault);
            self.emit(VaultSet { vault });
        }

        fn transfer_assets(
            ref self: ComponentState<TContractState>, asset: ContractAddress, amount: u256,
        ) {
            self._assert_only_authorized_caller();
            if amount == 0 {
                Errors::zero_amount();
            }

            let vault = self.vault.read();

            // Transfer ERC20 token to vault
            let erc20 = ERC20ABIDispatcher { contract_address: asset };
            let success = erc20.transfer(vault, amount);
            if !success {
                Errors::transfer_failed();
            }

            self.emit(AssetTransferred { asset, amount });
        }

        fn get_vault(self: @ComponentState<TContractState>) -> ContractAddress {
            self.vault.read()
        }

        fn get_authorized_caller(self: @ComponentState<TContractState>) -> ContractAddress {
            self.authorized_caller.read()
        }

        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: starknet::ClassHash) {
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.assert_only_owner();

            let mut upgradeable_component = get_dep_component_mut!(ref self, Upgradeable);
            upgradeable_component.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl Ownable: OwnableComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initialize_asset_transfer_pod(
            ref self: ComponentState<TContractState>,
            vault: ContractAddress,
            owner: ContractAddress,
            authorized_caller: ContractAddress,
        ) {
            if vault.is_zero() {
                Errors::zero_address();
            }
            if owner.is_zero() {
                Errors::zero_address();
            }

            // Initialize ownable component
            let mut ownable_component = get_dep_component_mut!(ref self, Ownable);
            ownable_component.initializer(owner);

            // Set storage values
            self.vault.write(vault);
            self.authorized_caller.write(authorized_caller);

            // Emit events
            self.emit(VaultSet { vault });
            self.emit(AuthorizedCallerSet { caller: authorized_caller });
        }

        fn _assert_only_authorized_caller(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            let authorized = self.authorized_caller.read();
            if caller != authorized {
                Errors::unauthorized();
            }
        }
    }
}
