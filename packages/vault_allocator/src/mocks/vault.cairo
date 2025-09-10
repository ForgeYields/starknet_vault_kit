#[starknet::contract]
pub mod MockVault {
    use openzeppelin::interfaces::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626Component, ERC4626DefaultNoFees, ERC4626DefaultNoLimits,
    };
    use openzeppelin::token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    // --- OpenZeppelin Component Integrations ---
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC4626Component, storage: erc4626, event: ERC4626Event);

    // --- ERC4626 Implementation ---
    #[abi(embed_v0)]
    impl ERC4626Impl = ERC4626Component::ERC4626Impl<ContractState>;
    impl ERC4626InternalImpl = ERC4626Component::InternalImpl<ContractState>;

    // --- ERC20 Implementation ---
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // --- ERC20 Metadata Implementation ---
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;

    #[storage]
    pub struct Storage {
        // --- Component Storage ---
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        erc4626: ERC4626Component::Storage,
        // --- Vault State ---
        buffer: u256, // Assets available in vault for instant redemption
        aum: u256 // Assets under management (deployed to allocators)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ERC20Event: ERC20Component::Event,
        ERC4626Event: ERC4626Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, underlying_asset: ContractAddress) {
        self.erc20.initializer("MockVault", "MVAULT");
        self.erc4626.initializer(underlying_asset);
    }


    /// Implementation of asset management for ERC4626 compatibility
    impl MockVaultAssetsManagementImpl of ERC4626Component::AssetsManagementTrait<ContractState> {
        fn get_total_assets(self: @ERC4626Component::ComponentState<ContractState>) -> u256 {
            let contract_state = self.get_contract();
            contract_state.buffer.read() + contract_state.aum.read()
        }

        fn transfer_assets_in(
            ref self: ERC4626Component::ComponentState<ContractState>,
            from: ContractAddress,
            assets: u256,
        ) {
            let this = starknet::get_contract_address();
            let asset_dispatcher = ERC20ABIDispatcher {
                contract_address: self.ERC4626_asset.read(),
            };
            assert(
                asset_dispatcher.transfer_from(from, this, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }

        fn transfer_assets_out(
            ref self: ERC4626Component::ComponentState<ContractState>,
            to: ContractAddress,
            assets: u256,
        ) {
            let asset_dispatcher = ERC20ABIDispatcher {
                contract_address: self.ERC4626_asset.read(),
            };
            assert(
                asset_dispatcher.transfer(to, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }
    }

    pub impl MockVaultHooksImpl of ERC4626Component::ERC4626HooksTrait<ContractState> {
        fn before_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<ERC4626Component::Fee>,
        ) {}

        fn after_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<ERC4626Component::Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.buffer.write(contract_state.buffer.read() - assets);
        }

        fn before_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<ERC4626Component::Fee>,
        ) {}

        fn after_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<ERC4626Component::Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.buffer.write(contract_state.buffer.read() + assets);
        }
    }

    #[abi(embed_v0)]
    impl MockVaultImpl of MockVaultTrait<ContractState> {
        /// Bring assets back from allocators to vault buffer
        fn bring_liquidity(ref self: ContractState, amount: u256) {
            ERC20ABIDispatcher { contract_address: self.erc4626.asset() }
                .transfer_from(get_caller_address(), starknet::get_contract_address(), amount);
            self.buffer.write(self.buffer.read() + amount);
            self.aum.write(self.aum.read() - amount);
        }

        /// Get current buffer amount
        fn buffer(self: @ContractState) -> u256 {
            self.buffer.read()
        }

        /// Get current assets under management
        fn aum(self: @ContractState) -> u256 {
            self.aum.read()
        }

        /// Set buffer for testing purposes
        fn set_buffer(ref self: ContractState, amount: u256) {
            self.buffer.write(amount);
        }

        /// Set AUM for testing purposes
        fn set_aum(ref self: ContractState, amount: u256) {
            self.aum.write(amount);
        }
    }

    #[starknet::interface]
    pub trait MockVaultTrait<TContractState> {
        fn bring_liquidity(ref self: TContractState, amount: u256);
        fn buffer(self: @TContractState) -> u256;
        fn aum(self: @TContractState) -> u256;
        fn set_buffer(ref self: TContractState, amount: u256);
        fn set_aum(ref self: TContractState, amount: u256);
    }
}
