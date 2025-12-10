use starknet::ContractAddress;

#[starknet::interface]
pub trait ICctpTokenBridge<TStorage> {
    fn deposit_for_burn(
        ref self: TStorage,
        amount: u256,
        destination_domain: u32,
        mint_recipient: u256,
        burn_token: ContractAddress,
        destination_caller: u256,
        max_fee: u256,
        min_finality_threshold: u32,
    );
}
