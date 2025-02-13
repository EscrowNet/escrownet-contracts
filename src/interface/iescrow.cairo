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
    fn get_escrow_details(ref self: TContractState) -> Escrow;
    fn get_depositor(self: @TContractState) -> ContractAddress;
    fn distribute_escrow_earnings(ref self: TContractState, escrow_id: u64, release_address: ContractAddress);
}
