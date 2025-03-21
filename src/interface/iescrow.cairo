use starknet::ContractAddress;
use crate::escrow::types::Escrow;

#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn initialize_escrow(
        ref self: TContractState,
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider_address: ContractAddress,
        amount: u256,
    );
    
    fn get_escrow_details(ref self: TContractState, escrow_id: u64) -> Escrow;
    fn get_depositor(self: @TContractState) -> ContractAddress;
    fn get_beneficiary(self: @TContractState) -> ContractAddress;
    fn refundTimer(ref self: TContractState, escrow_id: u64, refund_period: u64);
    fn get_arbiter(self: @TContractState) -> ContractAddress;
    fn fund_escrow(
        ref self: TContractState, escrow_id: u64, amount: u256, token_address: ContractAddress,
    );
    fn is_escrow_funded(self: @TContractState, escrow_id: u64) -> bool;
    fn check_approvals(self: @TContractState, escrow_id: u64) -> (bool, bool);
    fn release_funds(ref self: TContractState, escrow_id: u64, token_address: ContractAddress);
    fn depositor_approve(ref self: TContractState, escrow_id: u64);
    fn arbiter_approve(ref self: TContractState, escrow_id: u64);
}
