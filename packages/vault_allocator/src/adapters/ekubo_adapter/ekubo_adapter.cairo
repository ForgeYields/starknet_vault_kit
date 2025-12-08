// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod EkuboAdapter {
    use core::num::traits::Zero;
    use ekubo::types::i129::i129;
    use ekubo::types::pool_price::PoolPrice;
    use ekubo::types::position::Position;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::interfaces::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use vault_allocator::adapters::ekubo_adapter::errors::Errors;
    use vault_allocator::adapters::ekubo_adapter::interface::{
        IEkuboAdapter, IRewardContractDispatcher, IRewardContractDispatcherTrait,
    };
    use vault_allocator::integration_interfaces::ekubo::{
        Bounds, IEkuboCoreDispatcher, IEkuboCoreDispatcherTrait, IEkuboDispatcher,
        IEkuboDispatcherTrait, IEkuboNFTDispatcher, IEkuboNFTDispatcherTrait,
        IMathLibDispatcherTrait, PoolKey, PositionKey, dispatcher as ekuboLibDispatcher,
    };

    const WAD: u128 = 1_000_000_000_000_000_000;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        vault_allocator: ContractAddress,
        ekubo_positions_contract: IEkuboDispatcher,
        pool_key: PoolKey,
        ekubo_positions_nft: ContractAddress,
        ekubo_core: ContractAddress,
        bounds_settings: Bounds,
        contract_nft_id: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        vault_allocator: ContractAddress,
        ekubo_positions_contract: ContractAddress,
        bounds_settings: Bounds,
        pool_key: PoolKey,
        ekubo_positions_nft: ContractAddress,
        ekubo_core: ContractAddress,
    ) {
        let owner = IOwnableDispatcher { contract_address: vault_allocator }.owner();
        self.ownable.initializer(owner);
        self.vault_allocator.write(vault_allocator);
        self
            .ekubo_positions_contract
            .write(IEkuboDispatcher { contract_address: ekubo_positions_contract });
        self.bounds_settings.write(bounds_settings);
        self.pool_key.write(pool_key);
        self.ekubo_positions_nft.write(ekubo_positions_nft);
        self.ekubo_core.write(ekubo_core);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl EkuboAdapterImpl of IEkuboAdapter<ContractState> {
        fn deposit_liquidity(ref self: ContractState, amount0: u256, amount1: u256) {
            let vault_allocator = self._only_vault_allocator();
            if (amount0.is_zero() && amount1.is_zero()) {
                Errors::zero_amount();
            }
            let liquidity_expected = self._max_liquidity(amount0, amount1);
            let pool_key = self.pool_key.read();
            let token0 = pool_key.token0;
            let token1 = pool_key.token1;
            let positions_disp = self.ekubo_positions_contract.read();
            ERC20ABIDispatcher { contract_address: token0 }
                .transfer_from(vault_allocator, positions_disp.contract_address, amount0);
            ERC20ABIDispatcher { contract_address: token1 }
                .transfer_from(vault_allocator, positions_disp.contract_address, amount1);
            let liq_before_deposit = self.get_position().liquidity;
            let nft_id = self.contract_nft_id.read();
            if nft_id.is_zero() {
                self
                    .contract_nft_id
                    .write(
                        IEkuboNFTDispatcher { contract_address: self.ekubo_positions_nft.read() }
                            .get_next_token_id(),
                    );
                positions_disp
                    .mint_and_deposit(self.pool_key.read(), self.bounds_settings.read(), 0);
            } else {
                positions_disp
                    .deposit(nft_id, self.pool_key.read(), self.bounds_settings.read(), 0);
            }
            positions_disp.clear_minimum_to_recipient(token0, 0, vault_allocator);
            positions_disp.clear_minimum_to_recipient(token1, 0, vault_allocator);

            let liq_after_deposit = self.get_position().liquidity;
            let liquidity_actual = (liq_after_deposit - liq_before_deposit).into();
            if (liquidity_expected != liquidity_actual) {
                Errors::invalid_liquidity_added();
            }
        }

        fn withdraw_liquidity(
            ref self: ContractState, ratioWad: u256, min_token0: u128, min_token1: u128,
        ) {
            let vault_allocator = self._only_vault_allocator();
            let pool_key = self.pool_key.read();
            let current_liquidity = self.get_position().liquidity;
            let liquidity_to_withdraw = current_liquidity * ratioWad.try_into().unwrap() / WAD;
            let (amt0, amt1) = self
                .ekubo_positions_contract
                .read()
                .withdraw(
                    self.contract_nft_id.read(),
                    self.pool_key.read(),
                    self.bounds_settings.read(),
                    liquidity_to_withdraw,
                    min_token0,
                    min_token1,
                    false,
                );
            ERC20ABIDispatcher { contract_address: pool_key.token0 }
                .transfer(vault_allocator, amt0.into());
            ERC20ABIDispatcher { contract_address: pool_key.token1 }
                .transfer(vault_allocator, amt1.into());
            let current_liq = self.get_position().liquidity;
            if (current_liq == 0) {
                self.contract_nft_id.write(0);
            }
            if (current_liquidity - current_liq != liquidity_to_withdraw) {
                Errors::invalid_liquidity_removed();
            }
        }

        fn get_position_key(self: @ContractState) -> PositionKey {
            PositionKey {
                salt: self.contract_nft_id.read(),
                owner: self.ekubo_positions_contract.read().contract_address,
                bounds: self.bounds_settings.read(),
            }
        }

        fn get_position(self: @ContractState) -> Position {
            let position_key = self.get_position_key();
            IEkuboCoreDispatcher { contract_address: self.ekubo_core.read() }
                .get_position(self.pool_key.read(), position_key)
        }

        fn get_ekubo_positions_contract(self: @ContractState) -> ContractAddress {
            self.ekubo_positions_contract.read().contract_address
        }

        fn get_bounds_settings(self: @ContractState) -> Bounds {
            self.bounds_settings.read()
        }

        fn get_pool_key(self: @ContractState) -> PoolKey {
            self.pool_key.read()
        }

        fn get_ekubo_positions_nft(self: @ContractState) -> ContractAddress {
            self.ekubo_positions_nft.read()
        }

        fn get_contract_nft_id(self: @ContractState) -> u64 {
            self.contract_nft_id.read()
        }

        fn get_ekubo_core(self: @ContractState) -> ContractAddress {
            self.ekubo_core.read()
        }

        fn get_vault_allocator(self: @ContractState) -> ContractAddress {
            self.vault_allocator.read()
        }

        fn total_liquidity(self: @ContractState) -> u256 {
            self.get_position().liquidity.into()
        }

        fn underlying_balance(self: @ContractState) -> (u256, u256) {
            let contract_nft_id = self.contract_nft_id.read();
            if contract_nft_id.is_zero() {
                (0, 0)
            } else {
                let token_info = self
                    .ekubo_positions_contract
                    .read()
                    .get_token_info(
                        self.contract_nft_id.read(),
                        self.pool_key.read(),
                        self.bounds_settings.read(),
                    );
                (token_info.amount0.into(), token_info.amount1.into())
            }
        }

        fn pending_fees(self: @ContractState) -> (u256, u256) {
            let contract_nft_id = self.contract_nft_id.read();
            if contract_nft_id.is_zero() {
                (0, 0)
            } else {
                let token_info = self
                    .ekubo_positions_contract
                    .read()
                    .get_token_info(
                        self.contract_nft_id.read(),
                        self.pool_key.read(),
                        self.bounds_settings.read(),
                    );
                (token_info.fees0.into(), token_info.fees1.into())
            }
        }

        fn collect_fees(ref self: ContractState) {
            let vault_allocator = self._only_vault_allocator();
            let nft_id = self.contract_nft_id.read();
            if (nft_id.is_non_zero()) {
                let pool_key = self.pool_key.read();
                let bounds = self.bounds_settings.read();
                let token0 = pool_key.token0;
                let token1 = pool_key.token1;
                let (fee0, fee1) = self
                    .ekubo_positions_contract
                    .read()
                    .collect_fees(nft_id, pool_key, bounds);
                ERC20ABIDispatcher { contract_address: token0 }
                    .transfer(vault_allocator, fee0.into());
                ERC20ABIDispatcher { contract_address: token1 }
                    .transfer(vault_allocator, fee1.into());
            }
        }

        fn get_deposit_ratio(self: @ContractState) -> (u256, u256) {
            let bounds = self.bounds_settings.read();
            let sqrt_ratio_lower = self._tick_to_sqrt_ratio(bounds.lower);
            let sqrt_ratio_upper = self._tick_to_sqrt_ratio(bounds.upper);
            let sqrt_ratio_current = self._get_pool_price().sqrt_ratio;
            let wad: u256 = WAD.into();
            let (token0_ratio_wad, token1_ratio_wad) = if sqrt_ratio_current <= sqrt_ratio_lower {
                (wad, Zero::zero())
            } else if sqrt_ratio_current >= sqrt_ratio_upper {
                (Zero::zero(), wad)
            } else {
                let range = sqrt_ratio_upper - sqrt_ratio_lower;
                let position_in_range = sqrt_ratio_current - sqrt_ratio_lower;
                let token1_ratio_wad = (position_in_range * wad) / range;
                let token0_ratio_wad = wad - token1_ratio_wad;
                (token0_ratio_wad, token1_ratio_wad)
            };
            (token0_ratio_wad, token1_ratio_wad)
        }

        fn set_bounds_settings(ref self: ContractState, bounds: Bounds) {
            self.ownable.assert_only_owner();
            if self.contract_nft_id.read().is_non_zero() {
                Errors::position_exists();
            }
            self.bounds_settings.write(bounds);
        }

        fn harvest(
            ref self: ContractState,
            reward_contract: ContractAddress,
            amount: u128,
            proof: Span<felt252>,
            reward_token: ContractAddress,
        ) {
            let vault_allocator = self._only_vault_allocator();
            IRewardContractDispatcher { contract_address: reward_contract }.claim(amount, proof);
            let token_dispatcher = ERC20ABIDispatcher { contract_address: reward_token };
            let balance = token_dispatcher.balance_of(starknet::get_contract_address());
            token_dispatcher.transfer(vault_allocator, balance);
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        fn _tick_to_sqrt_ratio(self: @ContractState, tick: i129) -> u256 {
            ekuboLibDispatcher().tick_to_sqrt_ratio(tick)
        }

        fn _get_pool_price(self: @ContractState) -> PoolPrice {
            self.ekubo_positions_contract.read().get_pool_price(self.pool_key.read())
        }

        fn _max_liquidity(self: @ContractState, amount0: u256, amount1: u256) -> u256 {
            let current_sqrt_price = self._get_pool_price().sqrt_ratio;
            let liquidity = ekuboLibDispatcher()
                .max_liquidity(
                    current_sqrt_price,
                    self._tick_to_sqrt_ratio(self.bounds_settings.read().lower),
                    self._tick_to_sqrt_ratio(self.bounds_settings.read().upper),
                    amount0.try_into().unwrap(),
                    amount1.try_into().unwrap(),
                );
            liquidity.into()
        }

        fn _only_vault_allocator(self: @ContractState) -> ContractAddress {
            let vault_allocator = self.vault_allocator.read();
            if (get_caller_address() != vault_allocator) {
                Errors::only_vault_allocator();
            }
            vault_allocator
        }
    }
}
