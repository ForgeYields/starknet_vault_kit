// ═══════════════════════════════════════════════════════════════════════════════════════════════════
//
// STARKNET VAULT CONTRACT
//
// An ERC-4626 compatible vault implementation with epoched redemption system and fee management.
// This contract allows users to deposit assets and receive vault shares, request redemptions during
// specific epochs, and handles management and performance fees. It includes access control,
// pausable functionality, and integrates with external vault allocators for asset management.
//
// Key Features:
// - ERC-4626 compliant vault with share-based accounting
// - Epoched redemption system to manage liquidity and prevent runs
// - Configurable fees (management, performance, redemption)
// - Role-based access control (OWNER, ORACLE, PAUSER)
// - Integration with external allocators for yield generation
// - Pausable deposits for emergency situations
//
// ═══════════════════════════════════════════════════════════════════════════════════════════════════

#[starknet::contract]
pub mod Vault {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::interfaces::erc20::{
        ERC20ABIDispatcher, ERC20ABIDispatcherTrait, IERC20Metadata,
    };
    use openzeppelin::interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::extensions::erc4626::ERC4626Component::Fee;
    use openzeppelin::token::erc20::extensions::erc4626::{
        DefaultConfig, ERC4626Component, ERC4626DefaultNoFees, ERC4626DefaultNoLimits,
    };
    use openzeppelin::token::erc20::{
        DefaultConfig as ERC20DefaultConfig, ERC20Component, ERC20HooksEmptyImpl,
    };
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use openzeppelin::utils::math;
    use openzeppelin::utils::math::Rounding;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use vault::redeem_request::interface::{
        IRedeemRequestDispatcher, IRedeemRequestDispatcherTrait, RedeemRequestInfo,
    };
    use vault::vault::errors::Errors;
    use vault::vault::interface::IVault;

    // --- Access Control Roles ---
    pub const OWNER_ROLE: felt252 = selector!("OWNER_ROLE"); // Admin role for configuration
    pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE"); // Role to pause/unpause operations
    pub const ORACLE_ROLE: felt252 = selector!(
        "ORACLE_ROLE",
    ); // Role to report AUM and trigger epochs

    // --- Mathematical Constants ---
    pub const WAD: u256 = 1_000_000_000_000_000_000; // 1e18 - standard precision unit
    pub const MAX_REDEEM_FEE: u256 = WAD / 1000; // 0.1% - maximum redemption fee
    pub const MAX_MANAGEMENT_FEE: u256 = WAD / 50; // 2% - maximum annual management fee
    pub const MAX_PERFORMANCE_FEE: u256 = WAD / 5; // 20% - maximum performance fee
    pub const MIN_REPORT_DELAY: u64 = HOUR; // 1 hour - minimum report delay

    // --- Time Constants ---
    pub const MIN: u64 = 60; // Seconds in a minute
    pub const HOUR: u64 = MIN * 60; // Seconds in an hour
    pub const DAY: u64 = HOUR * 24; // Seconds in a day
    pub const YEAR: u64 = DAY * 365; // Seconds in a year (for fee calculations)


    // --- OpenZeppelin Component Integrations ---
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: ERC4626Component, storage: erc4626, event: ERC4626Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    // --- ERC4626 Implementation ---
    // Standard vault interface with deposit/withdraw/mint/redeem functionality
    #[abi(embed_v0)]
    impl ERC4626Impl = ERC4626Component::ERC4626Impl<ContractState>;
    impl ERC4626InternalImpl = ERC4626Component::InternalImpl<ContractState>;

    // --- ERC20 Implementation ---
    // Share token functionality with standard and camelCase interfaces
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    // --- Access Control Implementation ---
    // Role-based permissions for administrative functions
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // --- Pausable Implementation ---
    // Emergency pause functionality for deposits
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;


    #[storage]
    pub struct Storage {
        // --- Component Storage ---
        #[substorage(v0)]
        erc20: ERC20Component::Storage, // Share token state
        #[substorage(v0)]
        erc4626: ERC4626Component::Storage, // Vault standard state
        #[substorage(v0)]
        src5: SRC5Component::Storage, // Interface detection
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage, // Role management
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage, // Contract upgradeability
        #[substorage(v0)]
        pausable: PausableComponent::Storage, // Emergency pause state
        // --- Token Configuration ---
        decimals: u8, // Decimals for share token
        // --- Epoch Management ---
        epoch: u256, // Current epoch number
        handled_epoch_len: u256, // Number of epochs fully processed
        // --- Asset Management ---
        buffer: u256, // Assets available in vault for instant redemption
        aum: u256, // Assets under management (deployed to allocators)
        redeem_assets: Map<u256, u256>, // Assets allocated per epoch for redemptions
        redeem_nominal: Map<u256, u256>, // Nominal redemption requests per epoch
        max_delta: u256, // Maximum allowed AUM change per report
        last_report_timestamp: u64, // Timestamp of last oracle report
        report_delay: u64, // Minimum time delay between reports for redemption processing
        vault_allocator: ContractAddress, // External contract managing deployed assets
        // --- Fee Configuration ---
        fees_recipient: ContractAddress, // Address receiving all fee shares
        redeem_fees: u256, // Fee charged on redemption requests (in WAD)
        management_fees: u256, // Annual management fee rate (in WAD)
        performance_fees: u256, // Performance fee on profits (in WAD)
        // --- Redemption System ---
        redeem_request: IRedeemRequestDispatcher // NFT contract for tracking redemption requests
    }

    // --- Events ---
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // Component events
        ERC20Event: ERC20Component::Event,
        ERC4626Event: ERC4626Component::Event,
        SRC5Event: SRC5Component::Event,
        AccessControlEvent: AccessControlComponent::Event,
        UpgradeableEvent: UpgradeableComponent::Event,
        PausableEvent: PausableComponent::Event,
        // Vault-specific events
        RedeemRequested: RedeemRequested, // Emitted when a redemption is requested
        RedeemClaimed: RedeemClaimed, // Emitted when a redemption is claimed
        Report: Report, // Emitted when oracle reports new AUM
        BringLiquidity: BringLiquidity // Emitted when liquidity is brought back from allocators
    }

    /// Event emitted when a user requests a redemption
    #[derive(Drop, starknet::Event)]
    pub struct RedeemRequested {
        pub owner: ContractAddress, // Share owner requesting redemption
        pub receiver: ContractAddress, // Address to receive the redemption NFT
        pub shares: u256, // Original shares requested for redemption
        pub assets: u256, // Assets allocated after fees
        pub id: u256, // NFT ID for the redemption request
        pub epoch: u256 // Epoch when redemption was requested
    }

    /// Event emitted when a redemption is claimed
    #[derive(Drop, starknet::Event)]
    pub struct RedeemClaimed {
        pub receiver: ContractAddress, // Address receiving the assets
        pub redeem_request_nominal: u256, // Original shares amount
        pub assets: u256, // Actual assets received (may be less due to losses)
        pub id: u256, // NFT ID that was burned
        pub epoch: u256 // Epoch when redemption was originally requested
    }

    /// Event emitted when oracle reports new AUM
    #[derive(Drop, starknet::Event)]
    pub struct Report {
        pub new_epoch: u256, // Epoch that was processed
        pub new_handled_epoch_len: u256, // Number of epochs that are now fully handled
        pub total_supply: u256, // Total supply of shares
        pub total_assets: u256, // Total assets under management
        pub management_fee_shares: u256, // Management fee shares minted
        pub performance_fee_shares: u256 // Performance fee shares minted
    }

    /// Event emitted when liquidity is brought back from allocators
    #[derive(Drop, starknet::Event)]
    pub struct BringLiquidity {
        pub caller: ContractAddress, // Address that initiated the liquidity transfer
        pub amount: u256, // Amount of assets brought back to vault
        pub new_buffer: u256, // New buffer amount after the transfer
        pub new_aum: u256, // New AUM amount after the transfer
        pub epoch: u256 // Epoch when the liquidity was brought back
    }

    /// Initialize the vault with configuration parameters
    /// Sets up all components, roles, and fee structure
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray, // Share token name
        symbol: ByteArray, // Share token symbol
        underlying_asset: ContractAddress, // Address of the underlying asset token
        owner: ContractAddress, // Initial owner with all admin roles
        fees_recipient: ContractAddress, // Address to receive fee shares
        redeem_fees: u256, // Redemption fee rate in WAD
        management_fees: u256, // Annual management fee rate in WAD
        performance_fees: u256, // Performance fee rate in WAD
        report_delay: u64, // Minimum delay between reports for redemption processing
        max_delta: u256 // Maximum allowed AUM change per report in WAD
    ) {
        // Initialize all components
        self.erc20.initializer(name, symbol);
        self.erc4626.initializer(underlying_asset);
        self.access_control.initializer();

        // Set up role hierarchy - OWNER_ROLE is admin for all roles
        self.access_control.set_role_admin(OWNER_ROLE, OWNER_ROLE);
        self.access_control.set_role_admin(PAUSER_ROLE, OWNER_ROLE);
        self.access_control.set_role_admin(ORACLE_ROLE, OWNER_ROLE);

        // Grant all roles to the initial owner
        self.access_control._grant_role(OWNER_ROLE, owner);
        self.access_control._grant_role(PAUSER_ROLE, owner);
        self.access_control._grant_role(ORACLE_ROLE, owner);

        // Set share token decimals to match underlying asset
        self.decimals.write(ERC20ABIDispatcher { contract_address: underlying_asset }.decimals());

        // Configure fees with validation
        self._set_fees_config(fees_recipient, redeem_fees, management_fees, performance_fees);

        // Set redeem delay
        self._set_report_delay(report_delay);

        // Set max delta
        self.max_delta.write(max_delta);

        // Initialize timestamp for fee calculations
        self.last_report_timestamp.write(get_block_timestamp());

        self
            .emit(
                Report {
                    new_epoch: 0,
                    new_handled_epoch_len: 0,
                    total_supply: 0,
                    total_assets: 0,
                    management_fee_shares: 0,
                    performance_fee_shares: 0,
                },
            );
    }

    // --- Contract Upgradeability ---

    /// Allow contract upgrades by owner
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: starknet::ClassHash) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can upgrade
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // --- ERC4626 Asset Management ---

    /// Implementation of asset management for ERC4626 compatibility
    /// Handles the accounting of vault's total assets and transfers
    impl VaultAssetsManagementImpl of ERC4626Component::AssetsManagementTrait<ContractState> {
        /// Calculate total assets under management
        /// Total = buffer + deployed_assets - pending_redemptions
        fn get_total_assets(self: @ERC4626Component::ComponentState<ContractState>) -> u256 {
            let contract_state = self.get_contract();
            contract_state.buffer.read() // Assets in vault buffer
                + contract_state.aum.read() // Assets deployed to allocators  
                - contract_state._pending_redeem_assets() // Assets committed to redemptions
        }

        /// Transfer assets from user to vault during deposits
        fn transfer_assets_in(
            ref self: ERC4626Component::ComponentState<ContractState>,
            from: ContractAddress, // User depositing assets
            assets: u256 // Amount to transfer
        ) {
            let this = starknet::get_contract_address();
            let asset_dispatcher = ERC20ABIDispatcher {
                contract_address: self.ERC4626_asset.read(),
            };
            // Ensure transfer succeeds - will revert on failure
            assert(
                asset_dispatcher.transfer_from(from, this, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }

        /// Transfer assets from vault to user during withdrawals
        fn transfer_assets_out(
            ref self: ERC4626Component::ComponentState<ContractState>,
            to: ContractAddress, // User receiving assets
            assets: u256 // Amount to transfer
        ) {
            let asset_dispatcher = ERC20ABIDispatcher {
                contract_address: self.ERC4626_asset.read(),
            };
            // Ensure transfer succeeds - will revert on failure
            assert(
                asset_dispatcher.transfer(to, assets),
                ERC4626Component::Errors::TOKEN_TRANSFER_FAILED,
            );
        }
    }


    // --- ERC4626 Hooks ---

    /// Custom hooks for ERC4626 operations to implement vault-specific logic
    /// Hooks allow customization of deposit/withdrawal behavior
    pub impl VaultHooksImpl of ERC4626Component::ERC4626HooksTrait<ContractState> {
        /// Hook executed before burning shares and transferring assets during withdrawal
        /// Direct withdrawals are not supported - users must use epoched redemption system
        fn before_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            Errors::not_implemented(); // Withdrawals disabled - use request_redeem instead
        }


        /// Hook executed after burning shares and transferring assets during withdrawal
        /// No additional logic needed since withdrawals are disabled
        fn after_withdraw(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            owner: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {}


        /// Hook executed before transferring assets and minting shares during deposit
        /// Ensures vault is not paused before accepting deposits
        fn before_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.pausable.assert_not_paused(); // Prevent deposits when paused
        }


        /// Hook executed after transferring assets and minting shares during deposit
        /// Updates buffer to track assets available for immediate use
        fn after_deposit(
            ref self: ERC4626Component::ComponentState<ContractState>,
            caller: ContractAddress,
            receiver: ContractAddress,
            assets: u256,
            shares: u256,
            fee: Option<Fee>,
        ) {
            let mut contract_state = self.get_contract_mut();
            contract_state.buffer.write(contract_state.buffer.read() + assets);
        }
    }

    // --- Token Metadata ---

    /// ERC20 metadata implementation for vault shares
    /// Provides token name, symbol, and decimals
    #[abi(embed_v0)]
    pub impl VaultMetadataImpl of IERC20Metadata<ContractState> {
        /// Get vault share token name
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }

        /// Get vault share token symbol
        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_symbol.read()
        }

        /// Get vault share token decimals (matches underlying asset)
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    // --- Main Vault Implementation ---

    /// Core vault functionality including epoched redemptions, reporting, and configuration
    #[abi(embed_v0)]
    pub impl VaultImpl of IVault<ContractState> {
        // --- Administrative Functions ---

        /// Register the NFT contract for tracking redemption requests
        /// Only callable by owner to ensure proper integration
        fn register_redeem_request(ref self: ContractState, redeem_request: ContractAddress) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can configure
            if (self.redeem_request.read().contract_address.is_non_zero()) {
                Errors::redeem_request_already_registered();
            }
            self
                .redeem_request
                .write(IRedeemRequestDispatcher { contract_address: redeem_request });
        }

        /// Register the vault allocator contract for asset management
        /// Only callable by owner to ensure proper integration
        fn register_vault_allocator(ref self: ContractState, vault_allocator: ContractAddress) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can configure
            if (self.vault_allocator.read().is_non_zero()) {
                Errors::vault_allocator_already_registered();
            }
            self.vault_allocator.write(vault_allocator);
        }

        /// Update fee configuration with validation
        /// Only callable by owner to prevent unauthorized changes
        fn set_fees_config(
            ref self: ContractState,
            fees_recipient: ContractAddress, // Address to receive fee shares
            redeem_fees: u256, // Redemption fee rate in WAD
            management_fees: u256, // Annual management fee rate in WAD
            performance_fees: u256 // Performance fee rate in WAD
        ) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can update fees
            self._set_fees_config(fees_recipient, redeem_fees, management_fees, performance_fees);
        }

        /// Set the minimum delay between reports for redemption processing
        /// Only callable by owner to prevent unauthorized changes
        fn set_report_delay(ref self: ContractState, report_delay: u64) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can update redeem delay
            self._set_report_delay(report_delay);
        }

        /// Set the maximum allowed AUM change per report
        /// Only callable by owner to prevent unauthorized changes
        fn set_max_delta(ref self: ContractState, max_delta: u256) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can update max delta
            self.max_delta.write(max_delta);
        }

        // --- Emergency Controls ---

        /// Pause vault operations (deposits and redemptions)
        /// Only callable by addresses with PAUSER_ROLE for emergency response
        fn pause(ref self: ContractState) {
            self.access_control.assert_only_role(PAUSER_ROLE); // Only pauser can pause operations
            self.pausable.pause();
        }

        /// Unpause vault operations (deposits and redemptions)
        /// Only callable by owner to ensure proper authorization for resuming operations
        fn unpause(ref self: ContractState) {
            self.access_control.assert_only_role(OWNER_ROLE); // Only owner can unpause operations
            self.pausable.unpause();
        }

        // --- Redemption System ---

        /// Request redemption of vault shares using epoched system
        /// Users receive an NFT representing their redemption claim
        fn request_redeem(
            ref self: ContractState,
            shares: u256, // Number of shares to redeem
            receiver: ContractAddress, // Address to receive redemption NFT
            owner: ContractAddress // Owner of the shares being redeemed
        ) -> u256 { // Returns NFT ID for redemption claim
            self.pausable.assert_not_paused(); // Prevent redemptions when paused

            // Validate redemption amount doesn't exceed maximum allowed
            if (self.max_redeem(owner) < shares) {
                Errors::exceeded_max_redeem();
            }

            // Handle allowance if caller is not the owner
            let spender = get_caller_address();
            if spender != owner {
                self
                    .erc20
                    ._spend_allowance(
                        owner, spender, shares,
                    ); // Spend allowance for third-party redemption
            }

            // Calculate and collect redemption fees
            let fees_recipient = self.fees_recipient.read();
            let redeem_fees = if (owner == fees_recipient) {
                0
            } else {
                self.redeem_fees.read()
            };
            let fee_shares = (shares * redeem_fees)
                / WAD; // Fee calculation: shares * fee_rate / 1e18

            if (fee_shares.is_non_zero()) {
                self
                    .erc20
                    .update(owner, fees_recipient, fee_shares); // Transfer fee shares to recipient
            }
            let remaining_shares = shares - fee_shares; // Shares after fee deduction

            // Convert remaining shares to assets for redemption
            let assets = self.erc4626._convert_to_assets(remaining_shares, Rounding::Floor);

            if (assets.is_zero()) {
                Errors::zero_assets(); // Prevent zero-asset redemptions
            }
            self.erc20.burn(owner, remaining_shares); // Burn redeemed shares

            // Record redemption request in current epoch
            let epoch = self.epoch.read();
            let new_redeem_epoch_nominal = self.redeem_nominal.read(epoch) + assets;
            self.redeem_nominal.write(epoch, new_redeem_epoch_nominal);
            self.redeem_assets.write(epoch, new_redeem_epoch_nominal);

            // Mint NFT representing the redemption claim
            let id = self
                .redeem_request
                .read()
                .mint(receiver, RedeemRequestInfo { epoch, nominal: assets });

            self.emit(RedeemRequested { owner, receiver, shares, assets, id, epoch });
            id
        }

        /// Claim assets from a processed redemption request
        /// Burns the NFT and transfers the proportional assets to the owner
        fn claim_redeem(
            ref self: ContractState, id: u256,
        ) -> u256 { // Returns actual assets received
            self.pausable.assert_not_paused(); // Prevent claiming redemptions when paused

            let redeem_request_disp = self.redeem_request.read();
            let erc721_disp = ERC721ABIDispatcher {
                contract_address: redeem_request_disp.contract_address,
            };

            // Verify ownership and burn the redemption NFT
            let owner_of_id = erc721_disp.owner_of(id); // Get NFT owner (will revert if not exists)
            redeem_request_disp.burn(id); // Burn NFT to prevent double-claiming
            let redeem_request_info = redeem_request_disp.id_to_info(id);

            // Verify epoch has been processed
            let epoch = redeem_request_info.epoch;
            let handled_epoch_len = self.handled_epoch_len.read();
            if (handled_epoch_len <= epoch) { // Epoch must be fully processed
                Errors::redeem_assets_not_claimable();
            }

            // Calculate proportional assets based on epoch results
            let redeem_request_nominal = redeem_request_info
                .nominal; // Original asset amount requested
            let redeem_assets = self
                .redeem_assets
                .read(epoch); // Total assets available for this epoch
            let redeem_nominal = self
                .redeem_nominal
                .read(epoch); // Total nominal requests for this epoch
            self
                .redeem_nominal
                .write(epoch, redeem_nominal - redeem_request_nominal); // Reduce nominal tracking

            // Proportional distribution: (user_shares * total_available) / total_nominal
            let assets = (redeem_request_nominal * redeem_assets) / redeem_nominal;

            // Update epoch accounting and transfer assets
            self.redeem_assets.write(epoch, redeem_assets - assets);
            ERC20ABIDispatcher { contract_address: self.erc4626.asset() }
                .transfer(owner_of_id, assets);
            self
                .emit(
                    RedeemClaimed {
                        receiver: owner_of_id, redeem_request_nominal, assets, id, epoch,
                    },
                );
            assets
        }

        // --- Oracle Reporting ---

        /// Process epoch and report new AUM from external allocators
        /// This is the core function that handles fees, losses, and epoch transitions
        fn report(ref self: ContractState, new_aum: u256) { // New assets under management value
            self.pausable.assert_not_paused(); // Prevent reporting when paused
            self.access_control.assert_only_role(ORACLE_ROLE); // Only oracle can report AUM

            let new_epoch = self.epoch.read() + 1;
            self.epoch.write(new_epoch); // Advance to next epoch

            // Check redeem delay constraint
            let current_timestamp = get_block_timestamp();
            let dt: u64 = current_timestamp - self.last_report_timestamp.read();
            if (dt < self.report_delay.read()) {
                Errors::report_too_early(); // Must wait for redeem delay to pass
            }
            self.last_report_timestamp.write(current_timestamp);

            let prev_aum = self.aum.read();

            // 1) Validate AUM change is within acceptable bounds
            if (prev_aum.is_non_zero()) {
                let abs_diff = if (new_aum >= prev_aum) {
                    new_aum - prev_aum
                } else {
                    prev_aum - new_aum
                };
                // Calculate percentage change: (abs_diff * 1e18) / prev_aum
                let mut delta_ratio_wad = (abs_diff * WAD) / prev_aum;
                if ((abs_diff * WAD) % prev_aum).is_non_zero() {
                    delta_ratio_wad += 1; // Round up for safety
                }
                if (delta_ratio_wad > self.max_delta.read()) {
                    Errors::aum_delta_too_high(delta_ratio_wad, self.max_delta.read());
                }
            } else if (new_aum.is_non_zero()) {
                Errors::invalid_new_aum(new_aum);
            }

            let buffer = self.buffer.read();
            let liquidity_before = prev_aum + buffer; // Total liquidity before losses

            if (liquidity_before.is_zero()) {
                Errors::liquidity_is_zero(); // Cannot process without liquidity
            }

            // 2) Apply market losses proportionally to redemptions
            let market_loss_assets = if (new_aum < prev_aum) {
                prev_aum - new_aum // Loss from market/strategy performance
            } else {
                0
            };

            let handled_epoch_len = self.handled_epoch_len.read();
            let total_redeem_assets_after_loss_cut = self
                ._apply_loss_on_redeems(
                    market_loss_assets, liquidity_before, new_epoch, handled_epoch_len,
                );

            let liquidity_after = new_aum + buffer; // Liquidity after market losses

            // 3) Calculate and apply management fees
            // Annual fee formula: (fee_rate * time_elapsed * liquidity) / (seconds_per_year * 1e18)
            let management_fee_assets = (self.management_fees.read()
                * (dt.into())
                * liquidity_after)
                / (YEAR.into() * WAD);

            let total_redeem_assets_after_mgmt_cut = self
                ._apply_loss_on_redeems(
                    management_fee_assets, liquidity_after, new_epoch, handled_epoch_len,
                );

            // Management fee allocated to shareholders vs redemptions
            let management_fee_assets_for_shareholders = management_fee_assets
                - (total_redeem_assets_after_loss_cut - total_redeem_assets_after_mgmt_cut);

            // 4) Calculate performance fees on net profit
            let net_profit_after_mgmt = if (new_aum > prev_aum
                + management_fee_assets_for_shareholders) {
                new_aum
                    - (prev_aum
                        + management_fee_assets_for_shareholders) // Profit after management fees
            } else {
                0
            };
            let mut performance_fee_assets = 0;
            if (net_profit_after_mgmt.is_non_zero()) {
                // Performance fee: fee_rate * profit / 1e18
                performance_fee_assets = (self.performance_fees.read() * net_profit_after_mgmt)
                    / WAD;
            }

            // 5) Process epochs and allocate buffer to satisfy redemptions
            let mut remaining_buffer = buffer;
            let mut new_handled_epoch_len = handled_epoch_len;

            // Satisfy redemptions in FIFO order while buffer allows
            while (new_handled_epoch_len < new_epoch) {
                let need = self
                    .redeem_assets
                    .read(new_handled_epoch_len); // Assets needed for this epoch
                if (remaining_buffer >= need) {
                    remaining_buffer -= need;
                    new_handled_epoch_len += 1; // Mark epoch as handled
                } else {
                    break; // Not enough buffer, stop processing
                }
            }
            if (new_handled_epoch_len > handled_epoch_len) {
                self.handled_epoch_len.write(new_handled_epoch_len);
            }

            // 6) Deploy remaining buffer if all epochs are handled
            if (new_handled_epoch_len == new_epoch) {
                let alloc = self.vault_allocator.read();
                if (alloc.is_zero()) {
                    Errors::vault_allocator_not_set();
                }
                // Deploy all remaining buffer to allocator
                ERC20ABIDispatcher { contract_address: self.erc4626.asset() }
                    .transfer(alloc, remaining_buffer);
                self.aum.write(new_aum + remaining_buffer); // Update AUM to include deployed assets
                self.buffer.write(0); // Buffer is now empty
            } else {
                self.aum.write(new_aum); // Keep buffer for pending redemptions
                self.buffer.write(remaining_buffer);
            }

            // 7) Mint fee shares to recipient
            let recipient = self.fees_recipient.read();
            if (recipient.is_zero()) {
                Errors::fees_recipient_not_set();
            }

            // Mint management fee shares

            let mut total_supply = self.erc20.total_supply();
            let total_assets = liquidity_after - total_redeem_assets_after_mgmt_cut;
            assert(total_assets == self.erc4626.total_assets(), 'Invalid total assets');

            let management_fee_shares = math::u256_mul_div(
                management_fee_assets,
                total_supply + 1,
                (total_assets - management_fee_assets) + 1,
                Rounding::Floor,
            );
            if (management_fee_shares.is_non_zero()) {
                self.erc20.update(Zero::zero(), recipient, management_fee_shares);
                total_supply += management_fee_shares;
            }

            let performance_fee_shares = math::u256_mul_div(
                performance_fee_assets,
                total_supply + 1,
                (total_assets - performance_fee_assets) + 1,
                Rounding::Floor,
            );
            if (performance_fee_shares.is_non_zero()) {
                self.erc20.update(Zero::zero(), recipient, performance_fee_shares);
                total_supply += performance_fee_shares;
            }
            assert(total_supply == self.erc20.total_supply(), 'Invalid total supply');
            self
                .emit(
                    Report {
                        new_epoch,
                        new_handled_epoch_len,
                        total_supply,
                        total_assets,
                        management_fee_shares,
                        performance_fee_shares,
                    },
                );
        }

        // --- Liquidity Management ---

        /// Bring assets back from allocators to vault buffer
        /// Used by allocators to return assets for redemptions or rebalancing
        fn bring_liquidity(
            ref self: ContractState, amount: u256,
        ) { // Amount of assets to bring back
            let caller = get_caller_address();
            ERC20ABIDispatcher { contract_address: self.erc4626.asset() }
                .transfer_from(caller, starknet::get_contract_address(), amount);
            let new_buffer = self.buffer.read() + amount; // Calculate new buffer
            let new_aum = self.aum.read() - amount; // Calculate new AUM
            self.buffer.write(new_buffer); // Increase buffer
            self.aum.write(new_aum); // Decrease deployed AUM

            self
                .emit(
                    BringLiquidity {
                        caller, amount, new_buffer, new_aum, epoch: self.epoch.read(),
                    },
                );
        }

        // --- State Getter Functions ---

        /// Get current epoch number
        fn epoch(self: @ContractState) -> u256 {
            self.epoch.read()
        }

        /// Get number of epochs that have been fully processed for redemptions
        fn handled_epoch_len(self: @ContractState) -> u256 {
            self.handled_epoch_len.read()
        }

        /// Get current buffer amount (assets available for immediate redemption)
        fn buffer(self: @ContractState) -> u256 {
            self.buffer.read()
        }

        /// Get current assets under management (deployed to allocators)
        fn aum(self: @ContractState) -> u256 {
            self.aum.read()
        }

        /// Get total assets allocated for redemptions in a specific epoch
        fn redeem_assets(self: @ContractState, epoch: u256) -> u256 {
            self.redeem_assets.read(epoch)
        }

        /// Get total nominal redemption requests for a specific epoch
        fn redeem_nominal(self: @ContractState, epoch: u256) -> u256 {
            self.redeem_nominal.read(epoch)
        }

        // --- Configuration Getter Functions ---

        /// Get address that receives all fee shares
        fn fees_recipient(self: @ContractState) -> ContractAddress {
            self.fees_recipient.read()
        }

        /// Get current redemption fee rate (in WAD format)
        fn redeem_fees(self: @ContractState) -> u256 {
            self.redeem_fees.read()
        }

        /// Get current annual management fee rate (in WAD format)
        fn management_fees(self: @ContractState) -> u256 {
            self.management_fees.read()
        }

        /// Get current performance fee rate (in WAD format)
        fn performance_fees(self: @ContractState) -> u256 {
            self.performance_fees.read()
        }

        /// Get address of the redemption request NFT contract
        fn redeem_request(self: @ContractState) -> ContractAddress {
            self.redeem_request.read().contract_address
        }

        /// Get current redeem delay (minimum time between reports)
        fn report_delay(self: @ContractState) -> u64 {
            self.report_delay.read()
        }

        /// Get address of the vault allocator contract
        fn vault_allocator(self: @ContractState) -> ContractAddress {
            self.vault_allocator.read()
        }

        /// Get timestamp of the last oracle report
        fn last_report_timestamp(self: @ContractState) -> u64 {
            self.last_report_timestamp.read()
        }

        /// Get maximum allowed AUM change per report (in WAD format)
        fn max_delta(self: @ContractState) -> u256 {
            self.max_delta.read()
        }

        fn due_assets_from_id(self: @ContractState, id: u256) -> u256 {
            let redeem_request_info = self.redeem_request.read().id_to_info(id);
            let redeem_request_nominal = redeem_request_info
                .nominal; // Original asset amount requested
            let redeem_assets = self.redeem_assets.read(redeem_request_info.epoch);
            let redeem_nominal = self.redeem_nominal.read(redeem_request_info.epoch);
            (redeem_request_nominal * redeem_assets) / redeem_nominal
        }
    }

    // --- Internal Helper Functions ---

    /// Internal helper functions for fee management, loss allocation, and accounting
    #[generate_trait]
    pub impl InternalFunctions of InternalFunctionsTrait {
        /// Set and validate fee configuration
        /// Ensures all fees are within acceptable limits
        fn _set_fees_config(
            ref self: ContractState,
            fees_recipient: ContractAddress, // Address to receive fee shares
            redeem_fees: u256, // Redemption fee rate
            management_fees: u256, // Annual management fee rate
            performance_fees: u256 // Performance fee rate
        ) {
            self.fees_recipient.write(fees_recipient);

            // Validate redemption fee is within bounds (max 0.1%)
            if (redeem_fees > MAX_REDEEM_FEE) {
                Errors::invalid_redeem_fees();
            }
            self.redeem_fees.write(redeem_fees);

            // Validate management fee is within bounds (max 2% annually)
            if (management_fees > MAX_MANAGEMENT_FEE) {
                Errors::invalid_management_fees();
            }
            self.management_fees.write(management_fees);

            // Validate performance fee is within bounds (max 20%)
            if (performance_fees > MAX_PERFORMANCE_FEE) {
                Errors::invalid_performance_fees();
            }
            self.performance_fees.write(performance_fees);
        }

        fn _set_report_delay(ref self: ContractState, report_delay: u64) {
            if (report_delay < MIN_REPORT_DELAY) {
                Errors::invalid_report_delay();
            }
            self.report_delay.write(report_delay);
        }

        /// Apply losses proportionally across all pending redemption epochs
        /// This ensures losses are shared fairly among all redemption requests
        fn _apply_loss_on_redeems(
            ref self: ContractState,
            loss_assets: u256, // Total loss amount to distribute
            base: u256, // Base for proportional calculation (prev_aum + buffer)
            new_epoch: u256,
            handled_epoch_len: u256,
        ) -> u256 { // Returns total assets after loss application
            let mut i = handled_epoch_len;
            let mut remaining: u256 = loss_assets; // Remaining loss to distribute
            let mut total_after: u256 = 0; // Total redemption assets after losses

            // Iterate through all pending epochs to apply losses proportionally
            while (i < new_epoch) {
                let ra = self.redeem_assets.read(i); // Redemption assets for this epoch
                let num = ra * loss_assets; // Proportional loss calculation
                let mut cut = num / base; // Loss amount for this epoch

                // Round up to ensure all losses are allocated
                if ((num % base).is_non_zero()) {
                    cut += 1;
                }

                // Don't cut more than remaining loss
                if (cut > remaining) {
                    cut = remaining;
                }

                let new_ra = ra - cut; // Assets after loss
                self.redeem_assets.write(i, new_ra); // Update epoch redemption assets
                total_after += new_ra; // Accumulate total
                remaining -= cut; // Reduce remaining loss

                i += 1;
            }

            total_after // Return total assets after loss application
        }

        /// Calculate total assets committed to pending redemptions
        /// Used in total asset calculation to account for committed redemptions
        fn _pending_redeem_assets(self: @ContractState) -> u256 {
            let mut i = self.handled_epoch_len.read(); // Start from first unhandled epoch
            let mut total_redeem_assets = 0;
            let epoch = self.epoch.read();

            // Sum all redemption assets from unhandled epochs
            while (i <= epoch) {
                total_redeem_assets += self.redeem_assets.read(i);
                i += 1;
            }
            total_redeem_assets
        }
    }
}
