use starknet::ContractAddress;
use crate::mods::types::Escrow;

#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn initialize_escrow(
        ref self: TContractState,
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider_address: ContractAddress,
        amount: u256,
    );
    fn approve(ref self: TContractState, benefeciary: ContractAddress);
    fn get_escrow_details(ref self: TContractState, escrow_id: u64) -> Escrow;
    fn get_depositor(self: @TContractState) -> ContractAddress;
    fn get_beneficiary(self: @TContractState) -> ContractAddress;
    fn fund_escrow(
        ref self: TContractState, escrow_id: u64, amount: u256, token_address: ContractAddress,
    );

    fn get_escrow_exists(self: @TContractState, escrow_id: u64) -> bool;
    fn get_provider_address(self: @TContractState) -> ContractAddress;
    fn get_arbiter(self: @TContractState) -> ContractAddress;

    // Token set up
    
    fn set_erc20(ref self: TContractState, address: ContractAddress);
    fn token_address(self: @TContractState) -> ContractAddress;
}
