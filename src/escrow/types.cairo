use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Escrow {
    pub client_address: ContractAddress,
    pub provider_address: ContractAddress,
    pub amount: u256,
    pub balance: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Milestone {
    pub id: u64,
    pub description: ByteArray,
    pub amount: u256,
    pub dueDate: u256,
    pub isCompleted: bool,
    pub isApproved: bool,
    pub isPaid: bool,
}

#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn get_escrow(self: @TContractState, escrow_id: u256) -> Escrow;
    fn initialize_escrow(
        ref self: TContractState,
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider_address: ContractAddress,
        amount: u256,
    );
}
