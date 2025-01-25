use starknet::ContractAddress;

#[starknet::interface]
pub trait IEscrow<TContractState> {
    fn get_beneficiary(self: @TContractState) -> ContractAddress;
    fn initialize_escrow(
        ref self: TContractState,
        escrow_id: u64,
        beneficiary: ContractAddress,
        provider_address: ContractAddress,
        amount: u256,
    );
}
