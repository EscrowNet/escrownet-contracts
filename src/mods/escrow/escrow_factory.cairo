// SPDX-License-Identifier: MIT
pub use starknet::{
    ContractAddress, class_hash::ClassHash, syscalls::deploy_syscall, SyscallResultTrait,
};

#[starknet::interface]
pub trait IEscrowFactory<TContractState> {
    fn deploy_escrow(
        ref self: TContractState,
        beneficiary: ContractAddress,
        depositor: ContractAddress,
        arbiter: ContractAddress,
        salt: felt252,
    ) -> ContractAddress;

    fn get_escrow_contracts(ref self: TContractState) -> Array<ContractAddress>;
}


#[starknet::component]
pub mod EscrowFactory {
    use super::IEscrowFactory;
    use starknet::{
        ContractAddress, class_hash::ClassHash, syscalls::deploy_syscall, SyscallResultTrait,
        storage::{Map},
    };
    use core::traits::{TryInto, Into};

    const ESCROW_CONTRACT_CLASS_HASH: felt252 = 0x123;

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

            escrow_address
        }

        fn get_escrow_contracts(
            ref self: ComponentState<TContractState>,
        ) -> Array<ContractAddress> {
            let escrow_count = self.escrow_count.read();
            let mut escrow_addresses: Array<ContractAddress> = array![];

            for i in 1..escrow_count {
                escrow_addresses.append(self.escrow_addresses.read(i));
            };

            escrow_addresses
        }
    }
}
