use ekubo::types::delta::Delta;
use ekubo::types::i129::i129;
use ekubo::types::pool_price::PoolPrice;
use ekubo::types::position::Position;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IEkuboNFT<TContractState> {
    fn get_next_token_id(ref self: TContractState) -> u64;
    fn ownerOf(self: @TContractState, token_id: u256) -> ContractAddress;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
}
// Returns the dispatcher for the math library that is deployed on sepolia and mainnet with the
// given interface.
pub fn dispatcher() -> IMathLibLibraryDispatcher {
    IMathLibLibraryDispatcher {
        class_hash: 0x037d63129281c4c42cba74218c809ffc9e6f87ca74e0bdabb757a7f236ca59c3
            .try_into()
            .unwrap(),
    }
}

#[starknet::interface]
pub trait IMathLib<TContractState> {
    // Computes the difference in token0 reserves between the two prices given the constant
    // liquidity, optionally rounded up
    fn amount0_delta(
        self: @TContractState,
        sqrt_ratio_a: u256,
        sqrt_ratio_b: u256,
        liquidity: u128,
        round_up: bool,
    ) -> u128;
    // Computes the difference in token1 reserves between the two prices given the constant
    // liquidity, optionally rounded up
    fn amount1_delta(
        self: @TContractState,
        sqrt_ratio_a: u256,
        sqrt_ratio_b: u256,
        liquidity: u128,
        round_up: bool,
    ) -> u128;
    // Computes the difference in token0 and token1 given a liquidity delta, rounding up for
    // positive and down for negative
    fn liquidity_delta_to_amount_delta(
        self: @TContractState,
        sqrt_ratio: u256,
        liquidity_delta: i129,
        sqrt_ratio_lower: u256,
        sqrt_ratio_upper: u256,
    ) -> Delta;
    // Computes the max liquidity that can be received for the given amount of token0 and the
    // lower/upper bounds, assuming the current price is not within the bounds
    fn max_liquidity_for_token0(
        self: @TContractState, sqrt_ratio_lower: u256, sqrt_ratio_upper: u256, amount: u128,
    ) -> u128;
    // Computes the max liquidity that can be received for the given amount of token1 and the
    // lower/upper bounds, assuming the current price is not within the bounds
    fn max_liquidity_for_token1(
        self: @TContractState, sqrt_ratio_lower: u256, sqrt_ratio_upper: u256, amount: u128,
    ) -> u128;
    // Computes the max liquidity that can be received for the given amount of token0 and token1 and
    // the lower/upper bounds and current price
    fn max_liquidity(
        self: @TContractState,
        sqrt_ratio: u256,
        sqrt_ratio_lower: u256,
        sqrt_ratio_upper: u256,
        amount0: u128,
        amount1: u128,
    ) -> u128;

    // Compute the next sqrt ratio that will be reached from a swap given an amount of token0. Can
    // return an Option::None in case of overflow or underflow
    fn next_sqrt_ratio_from_amount0(
        self: @TContractState, sqrt_ratio: u256, liquidity: u128, amount: i129,
    ) -> Option<u256>;
    // Compute the next sqrt ratio that will be reached from a swap given an amount of token1. Can
    // return an Option::None in case of overflow or underflow
    fn next_sqrt_ratio_from_amount1(
        self: @TContractState, sqrt_ratio: u256, liquidity: u128, amount: i129,
    ) -> Option<u256>;

    // Converts a tick to the sqrt ratio
    fn tick_to_sqrt_ratio(self: @TContractState, tick: i129) -> u256;

    // Finds the tick s.t. tick_to_sqrt_ratio(tick) <= sqrt_ratio and tick_to_sqrt_ratio(tick + 1) >
    // sqrt_ratio
    fn sqrt_ratio_to_tick(self: @TContractState, sqrt_ratio: u256) -> i129;
}


#[derive(Copy, Drop, Serde, PartialEq)]
pub struct GetTokenInfoResult {
    pub pool_price: PoolPrice,
    pub liquidity: u128,
    pub amount0: u128,
    pub amount1: u128,
    pub fees0: u128,
    pub fees1: u128,
}

#[starknet::interface]
pub trait IEkubo<TContractState> {
    fn mint_and_deposit(
        ref self: TContractState, pool_key: PoolKey, bounds: Bounds, min_liquidity: u128,
    );
    fn deposit(
        ref self: TContractState, id: u64, pool_key: PoolKey, bounds: Bounds, min_liquidity: u128,
    ) -> u128;
    fn withdraw(
        ref self: TContractState,
        id: u64,
        pool_key: PoolKey,
        bounds: Bounds,
        liquidity: u128,
        min_token: u128,
        min_token1: u128,
        collect_fees: bool,
    ) -> (u128, u128);
    fn collect_fees(
        ref self: TContractState, id: u64, pool_key: PoolKey, bounds: Bounds,
    ) -> (u128, u128);
    fn get_pool_price(ref self: TContractState, pool_key: PoolKey) -> PoolPrice;
    fn get_token_info(
        self: @TContractState, id: u64, pool_key: PoolKey, bounds: Bounds,
    ) -> GetTokenInfoResult;
    fn clear(ref self: TContractState, token: ContractAddress) -> u256;
    fn clear_minimum_to_recipient(
        ref self: TContractState, token: ContractAddress, minimum: u256, recipient: ContractAddress,
    ) -> u256;
}

// Tick bounds for a position
#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct Bounds {
    pub lower: i129,
    pub upper: i129,
}

#[derive(Copy, Drop, Serde, PartialEq, Hash, starknet::Store)]
pub struct PoolKey {
    pub token0: ContractAddress,
    pub token1: ContractAddress,
    pub fee: u128,
    pub tick_spacing: u128,
    pub extension: ContractAddress,
}

#[derive(Copy, Drop, Serde, PartialEq, Hash)]
pub struct PositionKey {
    pub salt: u64,
    pub owner: ContractAddress,
    pub bounds: Bounds,
}

#[starknet::interface]
pub trait IEkuboCore<TContractState> {
    fn get_position(
        ref self: TContractState, pool_key: PoolKey, position_key: PositionKey,
    ) -> Position;
}


#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct ClSettings {
    pub ekubo_positions_contract: ContractAddress,
    pub bounds_settings: Bounds,
    pub pool_key: PoolKey,
    pub ekubo_positions_nft: ContractAddress,
    pub contract_nft_id: u64, // NFT position id of Ekubo position
    pub ekubo_core: ContractAddress,
}

#[derive(Drop, Copy, Serde)]
pub struct MyPosition {
    pub liquidity: u256,
    pub amount0: u256,
    pub amount1: u256,
}
