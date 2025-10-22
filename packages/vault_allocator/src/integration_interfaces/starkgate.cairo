use starknet::{ContractAddress, EthAddress};
#[starknet::interface]
pub trait IStarkgateABI<TContractState> {
    fn get_l1_token(self: @TContractState) -> EthAddress;
    fn get_l2_token(self: @TContractState) -> ContractAddress;
}
