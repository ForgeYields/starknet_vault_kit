use starknet::ContractAddress;

/// Struct representing token parameters for the OFT send() operation.
#[derive(Clone, Drop, Serde, Default)]
pub struct SendParam {
    pub dst_eid: u32, // Destination endpoint ID
    pub to: u256, // Recipient address
    pub amount_ld: u256, // Amount to send in local decimals
    pub min_amount_ld: u256, // Minimum amount to send in local decimals
    pub extra_options: ByteArray, // Additional options supplied by the caller
    pub compose_msg: ByteArray, // The composed message for the send() operation
    pub oft_cmd: ByteArray // The OFT command to be executed
}

#[derive(Drop, Serde, Default, PartialEq, Clone, Debug)]
pub struct MessagingFee {
    pub native_fee: u256,
    pub lz_token_fee: u256,
}


/// Struct representing OFT send result.
#[derive(Drop, Serde, Default)]
pub struct OFTSendResult {
    pub message_receipt: MessageReceipt, // The LayerZero messaging receipt
    pub oft_receipt: OFTReceipt // The OFT receipt information
}

#[derive(Drop, Serde, Default, PartialEq, Clone, Debug)]
pub struct MessageReceipt {
    pub guid: u256,
    pub nonce: u64,
    pub payees: Array<Payee>,
}

/// Struct representing OFT receipt information.
#[derive(Debug, Drop, Serde, Default, PartialEq)]
pub struct OFTReceipt {
    pub amount_sent_ld: u256, // Amount of tokens ACTUALLY debited from the sender in local decimals
    pub amount_received_ld: u256 // Amount of tokens to be received on the remote side
}

#[derive(Drop, Clone, Serde, PartialEq, Debug)]
pub struct Payee {
    pub receiver: ContractAddress,
    pub native_amount: u256,
    pub lz_token_amount: u256,
}


#[starknet::interface]
pub trait IOFT<TContractState> {
    fn send(
        ref self: TContractState,
        send_param: SendParam,
        fee: MessagingFee,
        refund_address: ContractAddress,
    ) -> OFTSendResult;
}
