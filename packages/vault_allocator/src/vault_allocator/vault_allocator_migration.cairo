// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::interface]
pub trait IVaultMigration<TContractState> {
    fn bring_liquidity(ref self: TContractState, amount: u256);
}


#[starknet::contract]
pub mod VaultAllocatorMigration {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::interfaces::erc721::{ERC721ReceiverMixin, IERC721_RECEIVER_ID};
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::account::Call;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResultTrait, get_caller_address};
    use vault_allocator::vault_allocator::errors::Errors;
    use vault_allocator::vault_allocator::interface::IVaultAllocator;
    use super::{IVaultMigrationDispatcher, IVaultMigrationDispatcherTrait};

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        manager: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        CallPerformed: CallPerformed,
    }

    /// Event emitted when a user requests a redemption
    #[derive(Drop, starknet::Event)]
    pub struct CallPerformed {
        pub to: ContractAddress,
        pub selector: felt252,
        pub calldata: Span<felt252>,
        pub result: Span<felt252>,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }


    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl VaultAllocatorImpl of IVaultAllocator<ContractState> {
        fn manager(self: @ContractState) -> ContractAddress {
            self.manager.read()
        }

        fn set_manager(ref self: ContractState, manager: ContractAddress) {
            self.ownable.assert_only_owner();
            self.manager.write(manager);
        }

        fn manage(ref self: ContractState, call: Call) -> Span<felt252> {
            self._only_manager();
            self.call_contract(call.to, call.selector, call.calldata)
        }

        fn manage_multi(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            self._only_manager();
            let mut results = ArrayTrait::new();
            let calls_len = calls.len();
            for i in 0..calls_len {
                let call = *calls.at(i);
                results.append(self.call_contract(call.to, call.selector, call.calldata));
            }
            results
        }
    }

    #[abi(embed_v0)]
    fn bring_liquidity(ref self: ContractState, vault: ContractAddress, amount: u256) {
        self.ownable.assert_only_owner();
        IVaultMigrationDispatcher { contract_address: vault }.bring_liquidity(amount);
    }

    #[abi(embed_v0)]
    impl ERC721ReceiverMixinImpl of ERC721ReceiverMixin<ContractState> {
        fn on_erc721_received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) -> felt252 {
            IERC721_RECEIVER_ID
        }
        fn onERC721Received(
            self: @ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>,
        ) -> felt252 {
            IERC721_RECEIVER_ID
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
            self.src5.supports_interface(interface_id)
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _only_manager(ref self: ContractState) {
            if get_caller_address() != self.manager.read() {
                Errors::only_manager();
            }
        }

        fn call_contract(
            ref self: ContractState,
            to: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>,
        ) -> Span<felt252> {
            self.src5.register_interface(IERC721_RECEIVER_ID);
            let result = call_contract_syscall(to, selector, calldata).unwrap_syscall();
            self.src5.deregister_interface(IERC721_RECEIVER_ID);
            self.emit(CallPerformed { to, selector, calldata, result });
            result
        }
    }
}
