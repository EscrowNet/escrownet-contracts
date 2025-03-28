use starknet::ContractAddress;

#[starknet::interface]
pub trait IEscrowFactory<TContractState> {
    fn deploy_escrow(
        ref self: TContractState,
        beneficiary: ContractAddress,
        depositor: ContractAddress,
        arbiter: ContractAddress,
        salt: felt252,
        milestone_description: ByteArray,
        milestone_amount: u256,
        milestone_dueDate: u256,
    ) -> ContractAddress;

    fn get_escrow_contracts(self: @TContractState) -> Array<ContractAddress>;
}
