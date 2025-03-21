// SPDX-License-Identifier: MIT
pub use starknet::{
    ContractAddress, class_hash::ClassHash, syscalls::deploy_syscall, SyscallResultTrait,
};
use escrownet_contract::interface::iescrow::{IEscrowDispatcher, IEscrowDispatcherTrait};

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

#[starknet::component]
pub mod EscrowFactory {
    use super::IEscrowDispatcherTrait;
    use super::IEscrowDispatcher;
    use super::IEscrowFactory;
    use starknet::{
        ContractAddress, class_hash::ClassHash, syscalls::deploy_syscall, SyscallResultTrait,
        storage::{Map},
    };
    use core::traits::{TryInto, Into};

    const ESCROW_CONTRACT_CLASS_HASH: felt252 =
        0x7df01639865aa375e6c7d9fb1ce5bbc3cbc404ac10984d5f3d76edfe6db3933;

    #[storage]
    struct Storage {
        escrow_count: u64,
        escrow_addresses: Map<u64, ContractAddress>,
    }

    #[embeddable_as(Escrows)]
    impl EscrowFactoryImpl<
        TContractState, +HasComponent<TContractState>,
    > of IEscrowFactory<ComponentState<TContractState>> {
        fn deploy_escrow(
            ref self: ComponentState<TContractState>,
            beneficiary: ContractAddress,
            depositor: ContractAddress,
            arbiter: ContractAddress,
            salt: felt252,
            milestone_description: ByteArray,
            milestone_amount: u256,
            milestone_dueDate: u256,
        ) -> ContractAddress {
            let escrow_id = self.escrow_count.read() + 1;

            let mut constructor_calldata: Array = array![
                beneficiary.into(), depositor.into(), arbiter.into(),
            ];

            // Deploy the Escrow contract
            let class_hash: ClassHash = ESCROW_CONTRACT_CLASS_HASH.try_into().unwrap();
            let result = deploy_syscall(class_hash, salt, constructor_calldata.span(), true);
            let (escrow_address, _) = result.unwrap_syscall();

            // Update storage with the new Escrow instance
            self.escrow_addresses.write(escrow_id, escrow_address);
            self.escrow_count.write(escrow_id);

            // Initialize milestone for every deployed escrow
            let escrow_contract = IEscrowDispatcher { contract_address: escrow_address };

            escrow_contract
                .add_milestone(
                    description: milestone_description,
                    amount: milestone_amount,
                    dueDate: milestone_dueDate
                );

            escrow_address
        }

        fn get_escrow_contracts(self: @ComponentState<TContractState>,) -> Array<ContractAddress> {
            let escrow_count = self.escrow_count.read();
            let mut escrow_addresses: Array<ContractAddress> = array![];

            for i in 1..escrow_count {
                escrow_addresses.append(self.escrow_addresses.read(i));
            };

            escrow_addresses
        }
    }
}
