use starknet::{ContractAddress, EthAddress};


#[starknet::interface]
pub trait IStarkgateABI<TContractState> {
    fn get_l1_token(self: @TContractState, l2_token: ContractAddress) -> EthAddress;
    fn get_l2_token(self: @TContractState, l1_token: EthAddress) -> ContractAddress;
    fn initiate_token_withdraw(
        ref self: TContractState, l1_token: EthAddress, l1_recipient: EthAddress, amount: u256,
    );
}


#[starknet::interface]
pub trait IStarkgateABIInitiateTokenWithdraw<TContractState> {
    fn initiate_token_withdraw(
        ref self: TContractState, l1_token: EthAddress, l1_recipient: EthAddress, amount: u256,
    );
}
