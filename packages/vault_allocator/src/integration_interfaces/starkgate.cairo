use starknet::{ContractAddress, EthereumAddress};
#[starknet::interface]
pub trait IStarkgateABI<TContractState> {
    fn l1_token(self: @TContractState) -> EthereumAddress;
    fn l2_token(self: @TContractState) -> ContractAddress;
}
