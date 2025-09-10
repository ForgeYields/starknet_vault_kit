// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Starknet Vault Kit
// Licensed under the MIT License. See LICENSE file for details.

#[starknet::contract]
pub mod Manager {
    // Role constants
    pub const OWNER_ROLE: felt252 = selector!("OWNER_ROLE");
    pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
    use core::hash::HashStateTrait;
    use core::pedersen::PedersenTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::merkle_tree::merkle_proof;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::account::Call;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use vault_allocator::manager::errors::Errors;
    use vault_allocator::manager::interface::IManager;
    use vault_allocator::vault_allocator::interface::{
        IVaultAllocatorDispatcher, IVaultAllocatorDispatcherTrait,
    };

    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        vault_allocator: IVaultAllocatorDispatcher,
        manage_root: Map<ContractAddress, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SRC5Event: SRC5Component::Event,
        AccessControlEvent: AccessControlComponent::Event,
        UpgradeableEvent: UpgradeableComponent::Event,
        PausableEvent: PausableComponent::Event,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, vault_allocator: ContractAddress,
    ) {
        self.access_control.initializer();
        self.access_control.set_role_admin(OWNER_ROLE, OWNER_ROLE);
        self.access_control.set_role_admin(PAUSER_ROLE, OWNER_ROLE);
        self.access_control._grant_role(OWNER_ROLE, owner);
        self.access_control._grant_role(PAUSER_ROLE, owner);
        self.vault_allocator.write(IVaultAllocatorDispatcher { contract_address: vault_allocator });
    }


    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.access_control.assert_only_role(OWNER_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl ManagerImpl of IManager<ContractState> {
        fn vault_allocator(self: @ContractState) -> ContractAddress {
            self.vault_allocator.read().contract_address
        }

        fn set_manage_root(ref self: ContractState, target: ContractAddress, root: felt252) {
            self.access_control.assert_only_role(OWNER_ROLE);
            self.manage_root.write(target, root);
        }

        fn manage_root(self: @ContractState, target: ContractAddress) -> felt252 {
            self.manage_root.read(target)
        }

        fn pause(ref self: ContractState) {
            self.access_control.assert_only_role(PAUSER_ROLE);
            self.pausable.pause();
        }
        fn unpause(ref self: ContractState) {
            self.access_control.assert_only_role(OWNER_ROLE);
            self.pausable.unpause();
        }

        fn manage_vault_with_merkle_verification(
            ref self: ContractState,
            proofs: Span<Span<felt252>>,
            decoder_and_sanitizers: Span<ContractAddress>,
            targets: Span<ContractAddress>,
            selectors: Span<felt252>,
            calldatas: Span<Span<felt252>>,
        ) {
            self.pausable.assert_not_paused();
            let proofs_len = proofs.len();

            if (proofs_len != decoder_and_sanitizers.len()
                || proofs_len != targets.len()
                || proofs_len != selectors.len()
                || proofs_len != calldatas.len()) {
                Errors::inconsistent_lengths();
            }

            let strategist_root = self.manage_root.read(get_caller_address());
            for i in 0..proofs_len {
                let proof = *proofs.at(i);
                let decoder_and_sanitizer = *decoder_and_sanitizers.at(i);
                let target = *targets.at(i);
                let selector = *selectors.at(i);
                let calldata = *calldatas.at(i);
                self
                    ._verify_calldata(
                        strategist_root, proof, decoder_and_sanitizer, target, selector, calldata,
                    );

                self
                    .vault_allocator
                    .read()
                    .manage(Call { to: target, selector: selector, calldata: calldata });
            }
        }
    }


    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _verify_calldata(
            self: @ContractState,
            root: felt252,
            proof: Span<felt252>,
            decoder_and_sanitizer: ContractAddress,
            target: ContractAddress,
            selector: felt252,
            calldata: Span<felt252>,
        ) {
            let mut packed_argument_addresses = ArrayTrait::new();
            let ret_data = starknet::syscalls::call_contract_syscall(
                decoder_and_sanitizer, selector, calldata,
            );

            match ret_data {
                Ok(res) => {
                    let res_len: u32 = (*res.at(0)).try_into().unwrap();
                    for i in 0..res_len {
                        packed_argument_addresses.append(*res.at(i + 1));
                    }
                },
                Err(revert_reason) => { panic!("revert_reason: {:?}", revert_reason); },
            }

            if (!self
                ._verify_manage_proof(
                    root,
                    proof,
                    decoder_and_sanitizer,
                    target,
                    selector,
                    packed_argument_addresses.span(),
                )) {
                Errors::invalid_manage_proof();
            }
        }


        fn _verify_manage_proof(
            self: @ContractState,
            root: felt252,
            proof: Span<felt252>,
            decoder_and_sanitizer: ContractAddress,
            target: ContractAddress,
            selector: felt252,
            packed_argument_addresses: Span<felt252>,
        ) -> bool {
            let mut serialized_struct: Array<felt252> = ArrayTrait::new();
            decoder_and_sanitizer.serialize(ref serialized_struct);
            target.serialize(ref serialized_struct);
            selector.serialize(ref serialized_struct);
            packed_argument_addresses.serialize(ref serialized_struct);
            let first_element = serialized_struct.pop_front().unwrap();
            let mut state = PedersenTrait::new(first_element);
            while let Some(value) = serialized_struct.pop_front() {
                state = state.update(value);
            }
            let leaf_hash = state.finalize();
            merkle_proof::verify_pedersen(proof, root, leaf_hash)
        }
    }
}
