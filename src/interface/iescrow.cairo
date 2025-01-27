use starknet::ContractAddress;
use crate::escrow::types::Escrow;


#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn initialize_escrow(
        ref self: TContractState,
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider_address: ContractAddress,
        amount: u256
    );
    fn approve(ref self: TContractState, benefeciary: ContractAddress);
    fn get_escrow_details(ref self: TContractState, escrow_id: u256) -> Escrow;
}
