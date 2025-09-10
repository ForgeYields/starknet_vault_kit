// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod AumProvider4626 {
    use core::num::traits::Zero;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::interfaces::erc4626::{IERC4626Dispatcher, IERC4626DispatcherTrait};
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use vault::aum_provider::aum_provider_4626::errors::Errors;
    use vault::aum_provider::aum_provider_4626::interface::IAumProvider4626;
    use vault::aum_provider::base_aum_provider::BaseAumProviderComponent;
    use vault::vault::interface::IVaultDispatcherTrait;
    component!(
        path: BaseAumProviderComponent, storage: base_aum_provider, event: BaseAumProviderEvent,
    );

    #[abi(embed_v0)]
    impl BaseAumProviderImpl =
        BaseAumProviderComponent::BaseAumProviderImpl<ContractState>;
    impl BaseAumProviderInternalImpl = BaseAumProviderComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        base_aum_provider: BaseAumProviderComponent::Storage,
        strategy4626: IERC4626Dispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BaseAumProviderEvent: BaseAumProviderComponent::Event,
    }

    #[abi(embed_v0)]
    impl AumProvider4626Impl of IAumProvider4626<ContractState> {
        fn get_strategy_4626(self: @ContractState) -> ContractAddress {
            self.strategy4626.read().contract_address
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState, vault: ContractAddress, strategy4626: ContractAddress) {
        self.base_aum_provider.initializer(vault);
        if (strategy4626.is_zero()) {
            Errors::invalid_strategy4626_address();
        }

        self.strategy4626.write(IERC4626Dispatcher { contract_address: strategy4626 });
    }

    // --- AUM Trait Implementation ---
    impl AumTrait of BaseAumProviderComponent::AumTrait<ContractState> {
        fn get_aum(self: @BaseAumProviderComponent::ComponentState<ContractState>) -> u256 {
            let contract_state = self.get_contract();
            let strategy = contract_state.strategy4626.read();
            let vault_allocator_address = contract_state
                .base_aum_provider
                .vault
                .read()
                .vault_allocator();

            // .vault.vault_allocator();
            let underlying_asset = strategy.asset();
            let underlying_dispatcher = ERC20ABIDispatcher { contract_address: underlying_asset };
            let underlying_balance = underlying_dispatcher.balance_of(vault_allocator_address);
            let strategy_shares = ERC20ABIDispatcher { contract_address: strategy.contract_address }
                .balance_of(vault_allocator_address);
            let strategy_assets = if strategy_shares > 0 {
                strategy.convert_to_assets(strategy_shares)
            } else {
                0
            };

            underlying_balance + strategy_assets
        }
    }
}
