// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::component]
pub mod BaseAumProviderComponent {
    use core::num::traits::Zero;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use vault::aum_provider::errors::Errors;
    use vault::aum_provider::interface::IBaseAumProvider;
    use vault::vault::interface::{IVaultDispatcher, IVaultDispatcherTrait};
    #[storage]
    pub struct Storage {
        pub vault: IVaultDispatcher,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {}


    pub trait AumTrait<TContractState, +HasComponent<TContractState>> {
        fn get_aum(self: @ComponentState<TContractState>) -> u256;
    }


    #[embeddable_as(BaseAumProviderImpl)]
    impl BaseAumProvider<
        TContractState, +HasComponent<TContractState>, impl Aum: AumTrait<TContractState>,
    > of IBaseAumProvider<ComponentState<TContractState>> {
        fn aum(self: @ComponentState<TContractState>) -> u256 {
            Aum::get_aum(self)
        }

        fn report(ref self: ComponentState<TContractState>) {
            self.vault.read().report(Aum::get_aum(@self));
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, vault: ContractAddress) {
            if (vault.is_zero()) {
                Errors::invalid_vault_address();
            }
            self.vault.write(IVaultDispatcher { contract_address: vault });
        }
    }
}
